import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A white page with dark "drawing" rows except in the given calm rows.
RgbImage busy(int w, int h, {Set<int> calm = const {}, int seed = 0}) {
  final data = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 255);
  for (var y = 0; y < h; y++) {
    if (calm.contains(y)) continue;
    for (var x = (y + seed) % 7; x < w; x += 7) {
      data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, 0);
    }
  }
  return RgbImage(w, h, data);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_strip_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> save(String name, RgbImage image) async {
    final path = p.join(dir.path, 'src', name);
    Directory(p.dirname(path)).createSync(recursive: true);
    await ImageCodec.writeFile(path, image);
    return path;
  }

  test('pages are centred on each other', () {
    expect(stripOffsets([100, 80, 100, 120]), [10, 20, 10, 0]);
    expect(stripOffsets([]), isEmpty);
  });

  test('a cut goes along the calmest row near the wanted height', () {
    final image = busy(50, 400, calm: {90, 140});
    expect(chooseCut(image, 100), 90);
    expect(chooseCut(busy(50, 400, calm: {80, 130}), 100), 80);
    expect(chooseCut(busy(50, 400), 100), 100, reason: 'all rows alike: the wanted height');
    expect(chooseCut(busy(50, 400, calm: {10}), 100), 100, reason: 'too far from the wanted height');
    expect(chooseCut(busy(50, 400, calm: {65}), 100), 65, reason: 'within 40 %');
  });

  test('one long picture; tall ones are saved as PNG', () async {
    final a = await save('a.png', RgbImage.filled(40, 30, 0, 0, 0));
    final b = await save('b.png', RgbImage.filled(20, 10, 100, 100, 100));
    final (files, cuts) = await joinStrip([a, b], p.join(dir.path, 'one'), 'book', '.jpg');
    expect([for (final f in files) p.basename(f)], ['book.jpg']);
    expect(cuts, isEmpty);
    final strip = await ImageCodec.readFile(files.single);
    expect((strip.width, strip.height), (40, 40));
    // The narrower page is centred, white around it.
    expect(strip.data[(35 * 40 + 5) * 3], greaterThan(240));
    expect(strip.data[(35 * 40 + 20) * 3], closeTo(100, 8));
    expect(stripExtension('.jpg', 70000), '.png');
    expect(stripExtension('.webp', 17000), '.png');
    expect(stripExtension('.webp', 1000), '.webp');
  });

  test('cut again into parts; the cleaned pages are cut at the same rows', () async {
    final pages = [
      for (var i = 0; i < 3; i++) await save('t$i.png', busy(30, 300, calm: {if (i == 1) 50, if (i == 2) 100})),
    ];
    final clean = [for (var i = 0; i < 3; i++) await save('c$i.png', RgbImage.filled(30, 300, 255, 255, 255))];
    final (files, cuts) = await joinStrip(pages, p.join(dir.path, 's'), 'part', '.png', sliceHeight: 330);
    // Calm rows at 350 and 700 of the strip (900 rows in all).
    expect(cuts, [350, 700]);
    expect([for (final f in files) p.basename(f)], ['part_001.png', 'part_002.png', 'part_003.png']);
    final heights = [for (final f in files) (await ImageCodec.readFile(f)).height];
    expect(heights, [350, 350, 200]);
    final (cleanFiles, same) = await joinStrip(
      clean,
      p.join(dir.path, 'c'),
      'part',
      '.png',
      sliceHeight: 330,
      cuts: cuts,
    );
    expect(same, cuts);
    expect([for (final f in cleanFiles) (await ImageCodec.readFile(f)).height], heights);
  });

  test('export: one picture per chapter, texts still per page', () async {
    Future<List<ExportPage>> chapter(String name) async => [
      for (var i = 0; i < 2; i++)
        ExportPage(
          name: 'p$i',
          chapter: name,
          translatedImage: await save('${name}t$i.png', RgbImage.filled(20, 50, 0, 0, 0)),
          cleanImage: await save('${name}c$i.png', RgbImage.filled(20, 50, 255, 255, 255)),
          translations: {'block_0': '$name $i'},
        ),
    ];
    final out = p.join(dir.path, 'out');
    final r = await exportPages(
      [...await chapter('ch1'), ...await chapter('ch2')],
      const ExportOptions(byChapter: true, translatedText: true, imageFormat: 'png', strip: StripExport.single),
      out,
    );
    expect(r.pages, 4);
    final files = [
      for (final f in Directory(out).listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: out).replaceAll(r'\', '/'),
    ]..sort();
    expect(files, [
      'ch1/translated/ch1.png',
      'ch1/translated_texts/p0_translated.json',
      'ch1/translated_texts/p1_translated.json',
      'ch2/translated/ch2.png',
      'ch2/translated_texts/p0_translated.json',
      'ch2/translated_texts/p1_translated.json',
    ]);
    expect((await ImageCodec.readFile(p.join(out, 'ch1/translated/ch1.png'))).height, 100);

    // Cut again into a CBZ: parts named in order.
    final cbz = p.join(dir.path, 'book.cbz');
    await exportPages(
      await chapter('x'),
      const ExportOptions(container: ExportContainer.cbz, strip: StripExport.slices, sliceHeight: 400),
      cbz,
    );
    expect(File(cbz).existsSync(), isTrue);
  });
}
