// Pages saved as layered Photoshop files and opened again.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:comic_translate/pipeline/page_pipeline.dart';
import 'package:comic_translate/pipeline/psd_page.dart';
import 'package:comic_translate/render/text_renderer.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A white page with a grey "speech" patch, and the page with it cleaned.
(RgbImage, RgbImage) pages() {
  final clean = RgbImage.filled(400, 300, 255, 255, 255);
  final page = RgbImage(400, 300, Uint8List.fromList(clean.data));
  for (var y = 60; y < 90; y++) {
    for (var x = 80; x < 300; x++) {
      page.data.fillRange((y * 400 + x) * 3, (y * 400 + x) * 3 + 3, 60);
    }
  }
  return (page, clean);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Same size as drawn: no enlargement.
  final settings = AppSettings(upscale: const UpscaleSettings(mode: UpscaleMode.off));

  test('a translated page: raw page, patches, text layers, the merged picture as drawn', () async {
    final (page, clean) = pages();
    final blocks = [TextBlock(xyxy: const BBox(60, 40, 320, 120), text: 'HELLO THERE', translation: 'Привет, мир')];
    final doc = await buildPagePsd(page, clean, blocks, settings, targetLanguage: 'Russian');
    final drawn = await renderPage(clean, blocks, settings, targetLanguage: 'Russian');
    expect(doc.composite!.data, drawn.image.data);

    final back = decodePsd(encodePsd(doc));
    final layers = back.flatLayers().toList();
    expect(
      [for (final (l, path) in layers) '${path.join('/')}:${l.name}'],
      ['Editable Text:Text 1', 'Inpaint Patches:Patch 1', ':Raw Image'],
    );
    final text = layers.first.$1.text!;
    expect(text.text.replaceAll('\n', ' '), 'Привет, мир');
    expect(text.font, 'Pangolin-Regular');
    expect(text.justification, PsdJustification.center);
    expect(text.strokeColor, isNull, reason: 'the outline is a layer style');
    final stroke = layers.first.$1.stroke!;
    expect((stroke.color, stroke.size), (0xFFFFFFFF, settings.render.outlineWidth));
    final item = drawn.items.single;
    expect(text.fontSize, closeTo(ptToPx(item.fontSizePt), 1e-4));
    // The text box is inside the item's box, a little wider.
    expect(text.transform[4], lessThan(item.x + documentMargin));
    expect(text.transform[5], item.y + documentMargin);
    expect(layers.first.$1.pixels, isNotNull, reason: 'the text as drawn, for programs without a text engine');
    final patch = layers[1].$1.pixels!;
    expect(patch.left <= 80 && patch.top <= 60 && patch.left + patch.width >= 300, isTrue);

    // Opened again: the same blocks.
    final content = readPagePsd(back);
    expect(content.original.data, page.data);
    expect(content.clean!.data, clean.data);
    final again = psdBlocks(content, back.width, back.height);
    expect(
      [for (final b in again) (b.text, b.translation, b.xyxy)],
      [('HELLO THERE', 'Привет, мир', const BBox(60, 40, 320, 120))],
    );
  });

  test('text changed in Photoshop is taken over, new text layers become blocks', () async {
    final (page, clean) = pages();
    final blocks = [TextBlock(xyxy: const BBox(60, 40, 320, 120), text: 'HELLO', translation: 'Привет')];
    final doc = await buildPagePsd(page, clean, blocks, settings, targetLanguage: 'Russian');
    final written = (doc.layers.first as PsdGroup).children.single as PsdLayer;
    final t = written.text!;
    PsdText edited(String s, List<double> transform) => PsdText(
      text: s,
      font: t.font,
      fontSize: 20,
      transform: transform,
      boxWidth: 100,
      boxHeight: 40,
      color: 0xFF112233,
    );
    final changed = PsdDocument(
      width: doc.width,
      height: doc.height,
      composite: doc.composite,
      resources: doc.resources,
      layers: [
        PsdGroup(psdTextGroup, [
          PsdLayer('Text 1', text: edited('Здравствуй,\nмир', t.transform)),
          PsdLayer('Layer 5', text: edited('Новый', [1, 0, 0, 1, 10, 200])),
        ]),
        ...doc.layers.skip(1),
      ],
    );
    final content = readPagePsd(decodePsd(encodePsd(changed)));
    final again = psdBlocks(content, doc.width, doc.height);
    expect(again.length, 2);
    expect(again[0].text, 'HELLO');
    expect(again[0].translation, 'Здравствуй, мир');
    expect(again[1].translation, 'Новый');
    expect(again[1].style!.fontSizePt, 15, reason: '20 px at 96 dpi');
    expect(again[1].style!.color, 0xFF112233);
    expect(again[1].style!.textBox, const BBox(6, 196, 114, 244));
  });

  test('a rotated item goes into the file and comes back at the same place', () async {
    final engines = await TextEngines.load(const RenderSettings());
    final item = TextItem(
      text: 'КРУГОМ',
      fontSizePt: 20,
      x: 100,
      y: 100,
      width: 120,
      height: 50,
      color: 0xFF000000,
      vertical: false,
      angle: 30,
      block: TextBlock(xyxy: const BBox(100, 100, 220, 150)),
    );
    final t = psdTextOf(item, engines, FontCatalog.of(const []));
    final block = blockOfText(t);
    expect(block.style!.angle, closeTo(30, 1e-6));
    final box = block.style!.textBox!;
    // The box is a little wider (Photoshop measures letters differently)
    // and longer downwards, along the turned text: its centre moved from
    // the item's centre (160, 125) down the text's own vertical.
    final dx = (box.x1 + box.x2) / 2 - 160, dy = (box.y1 + box.y2) / 2 - 125;
    expect(dx * math.cos(math.pi / 6) + dy * math.sin(math.pi / 6), closeTo(0, 1.5));
    expect(dy, greaterThan(0));
    expect(box.x2 - box.x1, inInclusiveRange(120, 132));
  });

  test('the bundled font goes beside the files that use it', () async {
    final (page, clean) = pages();
    final doc = await buildPagePsd(
      page,
      clean,
      [TextBlock(xyxy: const BBox(60, 40, 320, 120), translation: 'Текст')],
      settings,
      targetLanguage: 'Russian',
    );
    expect(usesBundledFont(doc), isTrue);
    final arial = await buildPagePsd(
      page,
      clean,
      [TextBlock(xyxy: const BBox(60, 40, 320, 120), translation: 'Текст')],
      AppSettings(
        upscale: settings.upscale,
        render: const RenderSettings(fontFamily: 'Arial'),
      ),
      targetLanguage: 'Russian',
    );
    expect(usesBundledFont(arial), isFalse);
  });

  test('export: PSD files into a folder, cleaned pages as PNG, the font beside them', () async {
    final dir = Directory.systemTemp.createTempSync('cts_psd_export_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (page, clean) = pages();
    final psd = p.join(dir.path, 'in', 'a.psd');
    final cleanFile = p.join(dir.path, 'in', 'a_clean.png');
    final font = p.join(dir.path, 'in', 'font.ttf');
    Directory(p.dirname(psd)).createSync(recursive: true);
    await writePsdFile(psd, await buildPagePsd(page, clean, const [], settings, targetLanguage: 'Russian'));
    await ImageCodec.writeFile(cleanFile, clean);
    File(font).writeAsStringSync('font');
    final out = p.join(dir.path, 'out');
    await exportPages(
      [ExportPage(name: 'page 1', translatedImage: psd, cleanImage: cleanFile)],
      const ExportOptions(imageFormat: 'psd', cleaned: true).withExtraFiles({'fonts/Pangolin-Regular.ttf': font}),
      out,
    );
    final files = [
      for (final f in Directory(out).listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: out).replaceAll(r'\', '/'),
    ]..sort();
    expect(files, ['cleaned/page 1.png', 'fonts/Pangolin-Regular.ttf', 'translated/page 1.psd']);
    await expectLater(
      exportPages(
        [ExportPage(name: 'x', translatedImage: psd)],
        const ExportOptions(imageFormat: 'psd', container: ExportContainer.cbz),
        p.join(dir.path, 'x.cbz'),
      ),
      throwsA(isA<ExportException>()),
    );
  });

  test('opening a PSD gives a translated, cleaned page', () async {
    final dir = Directory.systemTemp.createTempSync('cts_psd_open_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (page, clean) = pages();
    final psd = p.join(dir.path, 'page.psd');
    final blocks = [TextBlock(xyxy: const BBox(60, 40, 320, 120), text: 'HI', translation: 'Привет')];
    await writePsdFile(psd, await buildPagePsd(page, clean, blocks, settings, targetLanguage: 'Russian'));
    final [opened] = await importPages([psd], cacheDir: Directory(p.join(dir.path, 'cache')));
    expect(opened.name, 'page.psd');
    expect((await ImageCodec.readFile(opened.path)).data, page.data);
    expect((await ImageCodec.readFile(opened.cleanPath!)).data, clean.data);
    expect([for (final b in opened.blocks) b.translation], ['Привет']);
    expect(opened.notices, isEmpty);
  });
}
