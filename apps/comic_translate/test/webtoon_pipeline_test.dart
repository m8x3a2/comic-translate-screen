// Webtoon pages: a bubble cut by the edge between two pages is found, read
// and cleaned whole with the upper page; the page below leaves it alone and
// shows the cleaned part.

import 'package:comic_translate/pipeline/page_pipeline.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

/// White page with "text" (short dark dashes) in the rows [from, to).
RgbImage page(int w, int h, List<(int, int)> texts) {
  final img = RgbImage.filled(w, h, 255, 255, 255);
  for (final (from, to) in texts) {
    for (var y = from; y < to; y++) {
      if (y % 6 >= 3) continue;
      for (var x = 30; x < 70; x++) {
        if (x % 5 == 4) continue;
        final o = (y * w + x) * 3;
        img.data.fillRange(o, o + 3, 0);
      }
    }
  }
  return img;
}

/// Finds the rows with dark pixels: one block per run of rows.
class RowDetector implements TextDetector {
  final seen = <(int, int)>[];

  @override
  PluginInfo get info => fakeInfo('rows', PluginKind.detector);

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async {
    seen.add((image.width, image.height));
    final out = <TextBlock>[];
    int? start;
    var last = -100;
    for (var y = 0; y < image.height; y++) {
      var dark = false;
      for (var x = 0; x < image.width && !dark; x++) {
        dark = image.data[(y * image.width + x) * 3] < 100;
      }
      if (dark) {
        if (start == null || y - last > 8) {
          if (start != null) out.add(TextBlock(xyxy: BBox(25, start, 75, last + 1)));
          start = y;
        }
        last = y;
      }
    }
    if (start != null) out.add(TextBlock(xyxy: BBox(25, start, 75, last + 1)));
    return out;
  }

  @override
  Future<void> dispose() async {}
}

class ReadAll implements OcrEngine {
  final heights = <int>[];

  @override
  PluginInfo get info => fakeInfo('read', PluginKind.ocr);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    heights.add(image.height);
    for (final b in blocks) {
      b.text = 'TEXT ${b.xyxy.y1}';
    }
  }

  @override
  Future<void> dispose() async {}
}

class Echo implements Translator {
  @override
  PluginInfo get info => fakeInfo('echo', PluginKind.translator);

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    for (final b in request.blocks) {
      b.translation = b.text.toLowerCase();
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Paints the masked pixels white.
class Whiten implements Inpainter {
  @override
  PluginInfo get info => fakeInfo('whiten', PluginKind.inpainter);

  @override
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context) async {
    final out = image.clone();
    for (var i = 0; i < mask.data.length; i++) {
      if (mask.data[i] > 0) out.data.fillRange(i * 3, i * 3 + 3, 255);
    }
    return out;
  }

  @override
  Future<void> dispose() async {}
}

int darkRows(RgbImage img, int from, int to) {
  var n = 0;
  for (var y = from; y < to; y++) {
    for (var x = 0; x < img.width; x++) {
      if (img.data[(y * img.width + x) * 3] < 100) {
        n++;
        break;
      }
    }
  }
  return n;
}

void main() {
  test('a bubble cut by the edge belongs to the upper page and is cleaned whole', () async {
    final detector = RowDetector();
    final ocr = ReadAll();
    final pipeline = PagePipeline(
      settings: fakeSettings(),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      detector: detector,
      ocr: ocr,
      translator: Echo(),
      inpainter: Whiten(),
    );
    final context = PluginContext(log: EventLog.silent());
    // Text from row 160 of the upper page to row 40 of the lower one, and
    // another bubble lower down.
    final upper = page(100, 200, [(20, 50), (160, 200)]);
    final lower = page(100, 300, [(0, 40), (150, 180)]);

    final top = await pipeline.prepare(upper, context, next: lower);
    expect(detector.seen.last, (100, 200 + 256), reason: 'the top of the next page is looked at');
    expect(
      [for (final b in top.blocks) b.xyxy.toList()],
      [
        [25, 20, 75, 50],
        [25, 162, 75, 239],
      ],
    );
    expect(ocr.heights.last, 200 + 39 + seamPad, reason: 'the cut bubble is read whole');
    expect(top.clean.height, 200);
    expect(darkRows(top.clean, 0, 200), 0);
    expect(top.overflow, isNotNull);
    final patched = applyPatch(lower, top.overflow!, 100);
    expect(darkRows(patched, 0, 40), 0, reason: 'its part on the next page is cleaned too');
    expect(darkRows(patched, 150, 180), greaterThan(0));

    final covered = reachInto(top.blocks, 200, 100, 100);
    final bottom = await pipeline.prepare(lower, context, covered: covered);
    expect([for (final b in bottom.blocks) b.xyxy.y1], [150], reason: 'not detected a second time');
    expect(bottom.overflow, isNull);

    // Without the next page: as before.
    final alone = await pipeline.prepare(upper, context);
    expect([for (final b in alone.blocks) b.xyxy.y2], [50, 200]);
    expect(alone.overflow, isNull);
  });

  test('the text of a cut bubble goes on in the page below', () async {
    final settings = fakeSettings();
    final blocks = [
      TextBlock(xyxy: const BBox(10, 150, 90, 260))
        ..text = 'x'
        ..translation = 'one two three four five six seven eight nine ten',
    ];
    final above = PageAbove(width: 100, height: 200, blocks: blocks, targetLanguage: 'English');
    expect(above.reaches, isTrue);
    final items = await itemsFromAbove(above, 100, settings, 1.0);
    expect(items, isNotNull);
    // Moved up by the page above's height: what is left starts above 0.
    expect(items!.$1.single.y, lessThan(0));
    expect(items.$1.single.y + items.$1.single.height, greaterThan(0));
    final none = await itemsFromAbove(
      PageAbove(width: 100, height: 400, blocks: blocks, targetLanguage: 'English'),
      100,
      settings,
      1.0,
    );
    expect(none, isNull, reason: 'nothing reaches below a taller page');
  });
}
