import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _fixtures = p.join('..', '..', 'test_data', 'psd');

RgbImage _page() {
  final page = RgbImage.filled(64, 48, 255, 255, 255);
  for (var y = 10; y < 30; y++) {
    for (var x = 10; x < 40; x++) {
      page.data.fillRange((y * 64 + x) * 3, (y * 64 + x) * 3 + 3, 90);
    }
  }
  return page;
}

void main() {
  test('changed places: joined squares around the differences', () {
    final a = RgbImage.filled(100, 80, 255, 255, 255);
    final b = RgbImage(100, 80, Uint8List.fromList(a.data));
    void dot(int x, int y) => b.data.fillRange((y * 100 + x) * 3, (y * 100 + x) * 3 + 3, 0);
    dot(5, 5);
    dot(40, 5); // the next square but one: separate
    dot(70, 70);
    dot(75, 75); // same square
    expect(changedRegions(a, b, tile: 16), [
      const BBox(0, 0, 16, 16),
      const BBox(32, 0, 48, 16),
      const BBox(64, 64, 80, 80),
    ]);
    expect(changedRegions(a, a), isEmpty);
  });

  test('a page written and read back', () {
    final raw = _page();
    final clean = RgbImage(64, 48, Uint8List.fromList(raw.data))..data.fillRange(0, 64 * 48 * 3, 255);
    final doc = pagePsd(
      raw: raw,
      clean: clean,
      composite: clean,
      texts: [
        const PageTextLayer(
          'Text 1',
          null,
          PsdText(
            text: 'Hi',
            font: 'ArialMT',
            fontSize: 12,
            transform: [1, 0, 0, 1, 2, 3],
            boxWidth: 20,
            boxHeight: 10,
          ),
        ),
      ],
      meta: {
        'blocks': [42],
      },
    );
    expect([for (final n in doc.layers) n.name], [psdTextGroup, psdPatchGroup, psdRawLayer]);
    final page = readPagePsd(decodePsd(encodePsd(doc)));
    expect(page.ours, isTrue);
    expect(page.original.data, raw.data);
    expect(page.clean!.data, clean.data);
    expect(page.meta!['blocks'], [42]);
    expect([for (final (name, t, _) in page.texts) '$name:${t.text}'], ['Text 1:Hi']);
    expect(page.unsupported, isEmpty);
  });

  test('a page exported by the original program (PhotoshopAPI)', () async {
    final page = readPagePsd(await readPsdFile(p.join(_fixtures, 'original_export.psd')));
    expect(page.ours, isTrue);
    expect(page.meta, isNull);
    expect(page.original.data, _page().data);
    // The white patch over the grey square.
    expect(page.clean!.data[(22 * 64 + 22) * 3], 255);
    expect(page.clean!.data[(12 * 64 + 12) * 3], 90);
    final [(name, t, _)] = page.texts;
    expect(name, 'Text 1');
    expect(t.text, 'HELLO,\nworld');
    expect(t.font, 'ArialMT');
    expect(t.fontSize, 18);
    expect((t.transform[4], t.transform[5], t.boxWidth, t.boxHeight), (12, 14, 40, 24));
  });

  test('another program\'s file: visible picture layers joined, text kept apart', () async {
    final page = readPagePsd(await readPsdFile(p.join(_fixtures, 'other_program.psd')));
    expect(page.ours, isFalse);
    expect(page.clean, isNull);
    final o = page.original;
    expect(o.data.sublist((5 * 64 + 55) * 3, (5 * 64 + 55) * 3 + 3), [255, 0, 0], reason: 'the red layer');
    expect(o.data[(20 * 64 + 20) * 3], 90, reason: 'the background; the hidden layer is left out');
    expect([for (final (name, t, _) in page.texts) '$name:${t.text}'], ['Caption:Hi']);
  });

  test('features the import does not carry over are listed', () {
    final doc = PsdDocument(
      width: 4,
      height: 4,
      layers: [
        PsdLayer('a', pixels: PsdPixels.opaque(RgbImage.filled(4, 4, 0, 0, 0)), blendMode: 'mul ', opacity: 128),
        PsdLayer('b', hasMask: true, isSmartObject: true),
        PsdLayer('hidden', hidden: true, isAdjustment: true),
      ],
    );
    expect(readPagePsd(doc).unsupported, unorderedEquals(['blend modes', 'layer opacity', 'masks', 'smart objects']));
  });

  test('opening files of other programs: picture, text as blocks, a notice', () async {
    final dir = Directory.systemTemp.createTempSync('cts_psd_import_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final other = await importPsdPage(p.join(_fixtures, 'other_program.psd'), Directory(p.join(dir.path, 'a')));
    expect(other.notices.single, isA<PsdForeign>());
    expect(other.clean, other.image, reason: 'the text is not in the picture: nothing to clean');
    final [block] = other.blocks;
    expect(block.translation, 'Hi');
    expect(block.style!.fontSizePt, 14, reason: '18 px');
    expect(block.style!.textBox, const BBox(0, 26, 38, 50), reason: "the layer's box and the text margin");

    final original = await importPsdPage(p.join(_fixtures, 'original_export.psd'), Directory(p.join(dir.path, 'b')));
    expect(original.notices, isEmpty);
    expect(original.clean, isNot(original.image));
    expect([for (final b in original.blocks) b.translation], ['HELLO, world']);
  });
}
