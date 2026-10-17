import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_core/src/detection/foreground_color.dart';
import 'package:ct_core/src/detection/geometry.dart';
import 'package:ct_core/src/detection/reading_order.dart';
import 'package:ct_core/src/detection/slicer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'reference.dart';

List<BBox> boxes(Object? json) => [for (final b in json as List) BBox.fromList((b as List).cast<num>())];
List<List<int>> lists(List<BBox> bs) => [for (final b in bs) b.toList()];

void main() {
  final ref = loadReference('geometry.json');
  List<Map<String, Object?>> cases(String key) =>
      (ref[key] as List).map((e) => (e as Map).cast<String, Object?>()).toList();

  test('filterAndFixBboxes', () {
    for (final c in cases('filter_and_fix')) {
      final out = filterAndFixBboxes(boxes(c['boxes']), imageHeight: c['h'] as int, imageWidth: c['w'] as int);
      expect(lists(out), c['out']);
    }
  });

  test('mergeOverlappingBoxes', () {
    var i = 0;
    for (final c in cases('merge_overlapping')) {
      expect(lists(mergeOverlappingBoxes(boxes(c['boxes']))), c['out'], reason: 'case $i');
      i++;
    }
  });

  test('ImageSlicer.mergeOverlappingBoxes', () {
    const slicer = ImageSlicer();
    var i = 0;
    for (final c in cases('slicer_merge')) {
      final out = slicer.mergeOverlappingBoxes(boxes(c['boxes']), imageHeight: c['image_height'] as int);
      final expected = [for (final b in c['out'] as List) [for (final v in b as List) (v as num).toInt()]];
      expect(lists(out), expected, reason: 'case $i');
      i++;
    }
  });

  test('ImageSlicer parameters', () {
    const slicer = ImageSlicer();
    for (final c in cases('slicer_params')) {
      final w = c['w'] as int, h = c['h'] as int;
      expect(slicer.shouldSlice(w, h), c['should_slice'], reason: '${w}x$h');
      if (c['params'] != null) expect(slicer.calculateSliceParams(w, h).toList(), c['params']);
    }
  });

  test('sortBlocks matches sort_blk_list', () {
    var i = 0;
    for (final c in cases('sort_blocks')) {
      final blocks = [
        for (final b in (c['blocks'] as List).cast<Map>())
          TextBlock(
            xyxy: BBox.fromJson(b['xyxy']),
            direction: TextDirection.parse(b['direction'] as String),
          ),
      ];
      final sorted = sortBlocks(blocks, rightToLeft: c['rtl'] as bool);
      expect([for (final b in sorted) blocks.indexOf(b)], c['order'], reason: 'case $i');
      i++;
    }
  });

  group('per page', () {
    final dir = Directory(p.join(repoRoot, 'test_data', 'reference', 'detection'));
    final files = dir.listSync().whereType<File>().where((f) => !p.basename(f.path).startsWith('webtoon')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = p.basenameWithoutExtension(file.path);
      test(name, () async {
        final r = loadReference('detection/${p.basename(file.path)}');
        final image = await ImageCodec.readFile(pagePath(name));
        expect(sha256.convert(image.data).toString(), r['rgb_sha256'], reason: 'decoded pixels differ from the reference');

        final texts = boxes(r['text_boxes']);
        final filtered = filterAndFixBboxes(texts, imageHeight: image.height, imageWidth: image.width);
        expect(lists(filtered), r['filtered_text_boxes']);
        expect(lists(mergeOverlappingBoxes(filtered)), r['merged_text_boxes']);
        expect(
          lists(filterAndFixBboxes(boxes(r['bubble_boxes']), imageHeight: image.height, imageWidth: image.width)),
          r['filtered_bubble_boxes'],
        );

        final colors = [
          for (final b in boxes(r['merged_text_boxes']))
            extractForegroundColor(image.crop(BBox(b.x1, b.y1, b.x2, b.y2))),
        ];
        expect(colors, r['foreground_colors']);
      });
    }
  });
}
