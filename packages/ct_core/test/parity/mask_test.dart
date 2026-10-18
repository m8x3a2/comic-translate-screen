// Parity of the text-removal mask with the original: mahotas morphology,
// imkit contours, Pillow blur and "L" resize on random inputs, and
// generate_mask / build_block_mask_data on every test page.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'reference.dart';

GrayImage img(Map c, String key) => GrayImage(c['w'] as int, c['h'] as int, b64Bytes(c[key]));

StructuringElement se(String name) => switch (name) {
      'rect3' => StructuringElement.rect(3, 3),
      'rect4' => StructuringElement.rect(4, 4),
      'rect5' => StructuringElement.rect(5, 5),
      'rect17' => StructuringElement.rect(17, 17),
      'cross3' => StructuringElement.cross(3, 3),
      _ => throw ArgumentError(name),
    };

String sha(Uint8List data) => sha256.convert(data).toString();

void main() {
  final prim = loadReference('mask_primitives.json');

  test('mahotas dilate / erode / close and imkit wrappers', () {
    for (final (i, c) in (prim['morph'] as List).cast<Map>().indexed) {
      final a = img(c, 'a');
      final u8 = toMask255(a);
      final s = se(c['se'] as String);
      final why = 'case $i ${c['se']} ${c['w']}x${c['h']}';
      expect(dilateBinary(a, s).data, b64Bytes(c['dilate_bool']), reason: '$why dilate bool');
      expect(erodeBinary(a, s).data, b64Bytes(c['erode_bool']), reason: '$why erode bool');
      expect(dilateGray(u8, s).data, b64Bytes(c['dilate_u8']), reason: '$why dilate u8');
      expect(erodeGray(u8, s).data, b64Bytes(c['erode_u8']), reason: '$why erode u8');
      expect(closeGray(u8, s).data, b64Bytes(c['close_u8']), reason: '$why close u8');
      expect(imkDilate(u8, s, iterations: 3).data, b64Bytes(c['imk_dilate3']), reason: '$why imk.dilate');
      expect(imkErode(u8, s, iterations: 2).data, b64Bytes(c['imk_erode2']), reason: '$why imk.erode');
    }
  });

  test('close_holes', () {
    for (final (i, c) in (prim['close_holes'] as List).cast<Map>().indexed) {
      expect(closeHoles(img(c, 'a')).data, b64Bytes(c['out']), reason: 'case $i');
    }
  });

  test('find_contours / bounding_rect', () {
    for (final (i, c) in (prim['contours'] as List).cast<Map>().indexed) {
      final contours = findContours(img(c, 'a'));
      expect([for (final k in contours) [for (final (x, y) in k) [x, y]]], c['contours'], reason: 'case $i');
      expect([for (final k in contours) [boundingRect(k).$1, boundingRect(k).$2, boundingRect(k).$3, boundingRect(k).$4]], c['rects'], reason: 'case $i');
    }
  });

  test('Pillow GaussianBlur on L images', () {
    for (final (i, c) in (prim['blur'] as List).cast<Map>().indexed) {
      expect(pilGaussianBlurGray(img(c, 'a'), (c['radius'] as num).toDouble()).data, b64Bytes(c['out']),
          reason: 'case $i radius ${c['radius']}');
    }
  });

  test('Pillow resize on L images', () {
    for (final (i, c) in (prim['resize_l'] as List).cast<Map>().indexed) {
      final filter = c['mode'] == 'bicubic' ? PilFilter.bicubic : PilFilter.bilinear;
      expect(pilResizeGray(img(c, 'a'), c['nw'] as int, c['nh'] as int, filter: filter).data, b64Bytes(c['out']),
          reason: 'case $i');
    }
  });

  final dir = Directory(p.join(repoRoot, 'test_data', 'reference', 'mask'));
  final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = p.basenameWithoutExtension(file.path);
    test('generate_mask $name', () async {
      final r = loadReference('mask/$name.json');
      final det = loadReference('detection/$name.json');
      final image = await ImageCodec.readFile(pagePath(name));
      final blocks = [
        for (final b in (det['blocks'] as List).cast<Map<String, Object?>>()) TextBlock.fromJson(b)..text = 'text',
      ];
      final expected = (r['blocks'] as List).cast<Map>();
      var k = 0;
      for (final (bi, b) in blocks.indexed) {
        for (final clip in [true, false]) {
          final e = expected[k++];
          expect(e['clip'], clip);
          final m = buildBlockMaskData(image, b, clipToBubble: clip);
          final why = 'block $bi clip=$clip';
          expect(m?.bounds.toList(), e['bounds'], reason: '$why bounds');
          expect(m == null ? null : sha(m.mask.data), e['sha256'], reason: '$why mask');
        }
      }
      final mask = generateMask(image, blocks);
      expect(mask.data.where((v) => v != 0).length, r['mask_nonzero']);
      expect(sha(mask.data), r['mask_sha256']);
    });
  }
}
