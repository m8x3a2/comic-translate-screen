// Parity of the RT-DETR-v2 detector with the original comic-translate.
// Needs the downloaded model (`cts models download rtdetr-v2-int8`); skipped
// otherwise (e.g. on CI).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

Map<String, Object?> loadJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

List<List<int>> boxLists(Object? json) => [
      for (final b in json as List) [for (final v in b as List) (v as num).toInt()],
    ];

Future<RgbImage> loadPage(String name) async {
  final dir = p.join(repoRoot, 'test_data', 'pages', 'peppercarrot');
  if (name.startsWith('webtoon_')) {
    final parts = [for (final n in ['en_E01P01', 'en_E01P02', 'en_E01P03']) await ImageCodec.readFile(p.join(dir, '$n.jpg'))];
    final data = Uint8List.fromList([for (final img in parts) ...img.data]);
    return RgbImage(parts.first.width, parts.fold(0, (h, img) => h + img.height), data);
  }
  return ImageCodec.readFile(p.join(dir, '$name.jpg'));
}

void main() {
  final modelPath = p.join(AppPaths.resolve().models.path, 'rtdetr-v2-int8', 'detector-v4-s_int8.onnx');
  final hasModel = File(modelPath).existsSync();
  final refDir = Directory(p.join(repoRoot, 'test_data', 'reference', 'detection'));
  final refs = refDir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));

  late RtDetrV2Detector detector;
  setUpAll(() {
    if (hasModel) detector = RtDetrV2Detector.open(modelPath);
  });
  tearDownAll(() async {
    if (hasModel) await detector.dispose();
  });

  for (final file in refs) {
    final name = p.basenameWithoutExtension(file.path);
    test(name, () async {
      final r = loadJson(file.path);
      final image = await loadPage(name);
      expect(sha256.convert(image.data).toString(), r['rgb_sha256'], reason: 'decoded input differs');

      final resized = pilResizeBicubic(image, 640, 640);
      expect(sha256.convert(resized.data).toString(), r['preprocess_sha256'], reason: 'preprocessing differs');

      // Raw outputs: same labels, scores and boxes as the original session.
      final raw = detector.runModel(image);
      final order = List.generate(raw.scores.length, (i) => i)
        ..sort((a, b) => raw.scores[b].compareTo(raw.scores[a]));
      final top = (r['raw_top'] as List).cast<Map>();
      for (var k = 0; k < top.length; k++) {
        final i = order[k];
        final expected = top[k];
        if ((expected['score'] as num) < 0.05) break; // order of near-zero scores is unstable
        expect(raw.labels[i], expected['label'], reason: 'rank $k label');
        expect(raw.scores[i], closeTo((expected['score'] as num).toDouble(), 1e-4), reason: 'rank $k score');
        final box = (expected['box'] as List).cast<num>();
        for (var c = 0; c < 4; c++) {
          expect(raw.boxes[i * 4 + c], closeTo(box[c].toDouble(), 0.05), reason: 'rank $k box[$c]');
        }
      }

      final sliced = await detector.slicer.processSlicesForDetection(image, (s) async => detector.detectSingle(s));
      expect([for (final b in sliced.bubbles) b.toList()], boxLists(r['bubble_boxes']));
      expect([for (final b in sliced.texts) b.toList()], boxLists(r['text_boxes']));

      final blocks = await detector.detect(image, PluginContext(log: EventLog.silent()));
      final expectedBlocks = (r['blocks'] as List).cast<Map>();
      expect(blocks.length, expectedBlocks.length);
      for (var i = 0; i < blocks.length; i++) {
        final e = expectedBlocks[i];
        expect(blocks[i].xyxy.toList(), e['xyxy'], reason: 'block $i');
        expect(blocks[i].bubbleXyxy?.toList(), e['bubble_xyxy'], reason: 'block $i bubble');
        expect(blocks[i].textClass.id, e['text_class'], reason: 'block $i class');
        expect(blocks[i].fontColor, e['font_color'], reason: 'block $i colour');
        expect([for (final l in blocks[i].lines) l.toJson()], e['lines'], reason: 'block $i lines');
        expect(blocks[i].direction.id, e['direction'], reason: 'block $i direction');
      }
      expect([for (final b in sortBlocks(blocks)) blocks.indexOf(b)], r['sorted_order']);
    }, skip: hasModel ? false : 'model not downloaded: cts models download rtdetr-v2-int8');
  }
}
