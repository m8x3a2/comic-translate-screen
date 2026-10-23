import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// Remembers what it was asked to read.
class _Recorder implements OcrEngine {
  final calls = <({int width, int height, List<BBox> boxes})>[];

  @override
  PluginInfo get info => const PluginInfo(id: 'rec', displayName: 'rec', kind: PluginKind.ocr, privacy: Privacy.local);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    calls.add((width: image.width, height: image.height, boxes: [for (final b in blocks) b.xyxy]));
    for (final b in blocks) {
      b.text = '${image.width}';
    }
  }

  @override
  Future<void> dispose() async {}
}

TextBlock _withLines(BBox box, int lineHeight) => TextBlock(
  xyxy: box,
  direction: TextDirection.horizontal,
  lines: [
    for (var y = box.y1; y + lineHeight <= box.y2; y += lineHeight + 4)
      TextLine.box(BBox(box.x1, y, box.x2, y + lineHeight - 1)),
  ],
);

/// Plain ×2 that counts its pieces and tells each one to [onCall].
class _Counting extends PlainTextUpscaler {
  _Counting({required this.onCall}) : super(plainX2Info, 2);

  final void Function(int n) onCall;
  var calls = 0;

  @override
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context) {
    onCall(++calls);
    return super.enlarge(piece, width, height, context);
  }
}

/// A "neural network" whose every piece is estimated at [estimate] ms and
/// done at once; remembers the pieces it enlarged.
class _Estimated extends PlainTextUpscaler {
  _Estimated(this.estimate) : super(plainX2Info, 2);

  final double estimate;
  final enlarged = <(int, int)>[];

  @override
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context) {
    enlarged.add((piece.width, piece.height));
    return super.enlarge(piece, width, height, context);
  }

  @override
  double estimateMs(int width, int height) => estimate;
}

final _x2 = PlainTextUpscaler.x2();
final _context = PluginContext(log: EventLog.silent());

void main() {
  test('only blocks with thin lines are enlarged, each as a piece', () async {
    final page = RgbImage.filled(1000, 1400, 255, 255, 255);
    final small = _withLines(const BBox(100, 100, 300, 160), 12);
    final large = _withLines(const BBox(500, 800, 900, 1000), 80);
    final ocr = _Recorder();
    final reading = await readBlocks(
      ocr,
      page,
      [small, large],
      sourceLanguage: 'English',
      context: _context,
      upscaler: _x2,
    );
    expect(reading.factor, 2.0);
    expect(reading.pieces, 1);
    expect(ocr.calls, hasLength(2));
    // Large text on the page itself, small text on a canvas of its piece only.
    expect(ocr.calls.first.width, 1000);
    expect(ocr.calls.first.boxes, [const BBox(500, 800, 900, 1000)]);
    expect((ocr.calls.last.width, ocr.calls.last.height), (2 * 216, 2 * 76));
    expect(ocr.calls.last.boxes, [const BBox(16, 16, 416, 136)]);
    expect(small.xyxy, const BBox(100, 100, 300, 160), reason: 'restored');
    expect(small.linePx, 12);
    expect(large.lines, hasLength(2));
  });

  test('nothing is enlarged without a text preparation, with "no enlargement" or for large text', () async {
    final page = RgbImage.filled(400, 600, 255, 255, 255);
    for (final upscaler in [null, PlainTextUpscaler(textPrepOffInfo, 1)]) {
      final block = _withLines(const BBox(0, 0, 200, 100), 12);
      final reading = await prepareReading(page, [block], upscaler: upscaler);
      expect(reading.scaled, isFalse);
      expect(reading.asIs, [block]);
    }
    final reading = await prepareReading(page, [_withLines(const BBox(0, 0, 200, 100), 30)], upscaler: _x2);
    expect(reading.scaled, isFalse);
  });

  test('on a page with small text, blocks of seemingly thick lines are enlarged too', () async {
    // Tiny text often looks like one thick line to the splitter.
    final page = RgbImage.filled(800, 800, 255, 255, 255);
    final small = _withLines(const BBox(100, 100, 300, 160), 12);
    final unsure = _withLines(const BBox(400, 100, 500, 140), 30);
    final large = _withLines(const BBox(100, 400, 700, 700), 80);
    final reading = await prepareReading(page, [small, unsure, large], upscaler: _x2);
    expect(reading.asIs, [large]);
    expect(reading.canvases.single.blocks, unorderedEquals([small, unsure]));
  });

  test('overlapping pieces are enlarged once; far apart ones share a canvas', () async {
    final page = RgbImage.filled(800, 800, 255, 255, 255);
    final a = _withLines(const BBox(100, 100, 200, 140), 10);
    final b = _withLines(const BBox(190, 130, 300, 170), 10);
    final c = _withLines(const BBox(600, 600, 700, 640), 10);
    final reading = await prepareReading(page, [a, b, c], upscaler: _x2);
    expect(reading.pieces, 2);
    expect(reading.canvases, hasLength(1));
    expect(reading.canvases.single.region, const BBox(92, 92, 708, 648));
    reading.restore();
    expect(
      [a.xyxy, b.xyxy, c.xyxy],
      [const BBox(100, 100, 200, 140), const BBox(190, 130, 300, 170), const BBox(600, 600, 700, 640)],
    );
  });

  test('pieces of a long page are spread over several canvases', () async {
    final page = RgbImage.filled(1000, 20000, 255, 255, 255);
    final blocks = [for (var y = 0; y < 20000; y += 1000) _withLines(BBox(100, y + 100, 900, y + 300), 12)];
    final reading = await prepareReading(page, blocks, upscaler: _x2);
    expect(reading.pieces, 20);
    expect(reading.canvases.length, greaterThan(1));
    for (final c in reading.canvases) {
      expect(c.image.width * c.image.height, lessThanOrEqualTo(readingMaxPixels));
    }
    expect(reading.canvases.expand((c) => c.blocks).toSet(), blocks.toSet());
  });

  test('a box drawn by hand (no lines) is split into lines and its small text enlarged', () async {
    // Three rows of tiny "letters" (5×7 px), as on a low-resolution screenshot.
    final page = RgbImage.filled(200, 120, 255, 255, 255);
    for (var row = 0; row < 3; row++) {
      for (var letter = 0; letter < 12; letter++) {
        for (var y = 0; y < 7; y++) {
          for (var x = 0; x < 5; x++) {
            final px = 40 + letter * 7 + (letter ~/ 4) * 4 + x, py = 30 + row * 12 + y;
            final i = (py * page.width + px) * 3;
            page.data[i] = page.data[i + 1] = page.data[i + 2] = 0;
          }
        }
      }
    }
    final hand = TextBlock(xyxy: const BBox(34, 24, 136, 72));
    final reading = await prepareReading(page, [hand], sourceLanguageCode: 'en', upscaler: _x2);
    expect(reading.scaled, isTrue, reason: 'small text counts once its lines are known');
    expect(hand.lines, hasLength(3));
    reading.restore();
    expect(hand.xyxy, const BBox(34, 24, 136, 72));
    expect(hand.lines, hasLength(3));
    for (final l in hand.lines) {
      expect(hand.xyxy.inflate(4, 4).containsBox(l.axisBox), isTrue, reason: 'lines back on the page');
    }
  });

  test('a cancel coming in from elsewhere stops between pieces; the blocks stay in place', () async {
    final page = RgbImage.filled(1000, 20000, 255, 255, 255);
    final blocks = [for (var y = 0; y < 20000; y += 1000) _withLines(BBox(100, y + 100, 900, y + 300), 12)];
    final boxes = [for (final b in blocks) b.xyxy];
    final cancel = CancelToken();
    final upscaler = _Counting(
      onCall: (n) {
        // As a cancel message from the main isolate would: after this piece.
        if (n == 7) Timer.run(cancel.cancel);
      },
    );
    await expectLater(
      prepareReading(
        page,
        blocks,
        upscaler: upscaler,
        context: PluginContext(log: EventLog.silent(), cancel: cancel),
      ),
      throwsA(isA<CancelledException>()),
    );
    expect(upscaler.calls, lessThan(9), reason: 'stopped right after the cancel');
    expect([for (final b in blocks) b.xyxy], boxes);
  });

  test('plain enlargement is PIL Lanczos to the size asked for', () async {
    final piece = RgbImage.filled(10, 6, 10, 20, 30);
    final out = await _x2.enlarge(piece, 20, 12, _context);
    expect((out.width, out.height), (20, 12));
    expect(out.data.take(3), [10, 20, 30]);
  });

  test('the neural network keeps to its time on a page: smallest text first, the rest plainly', () async {
    final page = RgbImage.filled(1000, 1400, 255, 255, 255);
    // The top block has larger text: it goes plainly, the bottom one gets the network.
    const topBox = BBox(100, 100, 300, 160), bottomBox = BBox(100, 900, 260, 950);
    final top = _withLines(topBox, 16);
    final bottom = _withLines(bottomBox, 8);
    final half = _Estimated(readingNeuralBudgetMs * 0.8);
    final reading = await prepareReading(page, [top, bottom], upscaler: half);
    expect(reading.pieces, 2);
    expect(reading.plainPieces, 1);
    expect(half.enlarged, [(160 + 16, 50 + 16)]);

    // Every piece estimated over the budget: all plainly, same factor.
    final slow = _Estimated(readingNeuralBudgetMs * 2.0);
    final all = await prepareReading(page, [_withLines(topBox, 16), _withLines(bottomBox, 8)], upscaler: slow);
    expect((all.pieces, all.plainPieces, all.factor), (2, 2, 2.0));
    expect(slow.enlarged, isEmpty);
  });

  test('merging overlapping boxes', () {
    expect(mergeOverlapping(const [BBox(0, 0, 10, 10), BBox(5, 5, 20, 20), BBox(30, 30, 40, 40)]), const [
      BBox(0, 0, 20, 20),
      BBox(30, 30, 40, 40),
    ]);
    expect(mergeOverlapping(const [BBox(0, 0, 10, 10), BBox(20, 0, 30, 10), BBox(5, 0, 25, 10)]), const [
      BBox(0, 0, 30, 10),
    ]);
  });
}
