import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// A line detector that returns [lines] and counts its calls.
class _Lines implements LineDetector {
  _Lines(this.lines);

  final List<BBox> lines;
  var calls = 0;

  @override
  PluginInfo get info =>
      const PluginInfo(id: 'lines', displayName: 'lines', kind: PluginKind.detector, privacy: Privacy.local);

  @override
  Future<List<BBox>> findLines(RgbImage image, PluginContext context) async {
    calls++;
    return lines;
  }

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async => const [];

  @override
  Future<void> dispose() async {}
}

/// White page with black bars (rows of "text") at [rows] (y1, y2), x 20–380.
RgbImage _page(List<(int, int)> rows) {
  final img = RgbImage.filled(400, 300, 255, 255, 255);
  for (final (y1, y2) in rows) {
    for (var y = y1; y < y2; y++) {
      for (var x = 20; x < 380; x++) {
        // Letters: dark columns with gaps, like text.
        if (x % 6 < 4) img.data.fillRange(img.offset(x, y), img.offset(x, y) + 3, 0);
      }
    }
  }
  return img;
}

TextBlock _block(BBox box, List<BBox> lines, {TextDirection direction = TextDirection.horizontal}) =>
    TextBlock(xyxy: box, direction: direction, lines: [for (final l in lines) TextLine.box(l)]);

final _context = PluginContext(log: EventLog.silent());

/// Reads every block as [text] and counts its calls.
class _Ocr implements OcrEngine {
  _Ocr(this.text);

  final String text;
  var calls = 0;

  @override
  PluginInfo get info => const PluginInfo(id: 'ocr', displayName: 'ocr', kind: PluginKind.ocr, privacy: Privacy.local);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    calls++;
    for (final b in blocks) {
      b.text = text;
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('bands of text across a line', () {
    final two = _page([(20, 40), (50, 70)]);
    expect(inkBands(two, const BBox(10, 10, 390, 80)), 2);
    expect(inkBands(two, const BBox(10, 10, 390, 45)), 1);
  });

  test('doubtful lines: several bands, or vertical text outside Japanese and Chinese', () {
    final img = _page([(20, 40), (50, 70), (100, 120)]);
    final merged = _block(const BBox(10, 10, 390, 130), [const BBox(10, 10, 390, 75), const BBox(10, 95, 390, 125)]);
    expect(doubtfulLines(img, merged, 'en'), 'bands');
    final fine = _block(const BBox(10, 10, 390, 130), [
      const BBox(10, 15, 390, 45),
      const BBox(10, 45, 390, 75),
      const BBox(10, 95, 390, 125),
    ]);
    expect(doubtfulLines(img, fine, 'en'), isNull);

    final vertical = _block(const BBox(10, 10, 390, 130), [
      const BBox(200, 10, 390, 130),
    ], direction: TextDirection.vertical);
    expect(doubtfulLines(img, vertical, 'en'), 'vertical');
    expect(doubtfulLines(img, vertical, ''), 'vertical');
    expect(doubtfulLines(img, vertical, 'ja'), isNull);

    // Lines of a line detector are not checked.
    expect(doubtfulLines(img, merged..fixedLines = true, 'en'), isNull);
  });

  test('found lines win only when there are more of them and they are thinner', () {
    final block = _block(const BBox(0, 0, 400, 100), [const BBox(0, 0, 400, 100)]);
    final four = [for (var y = 0; y < 100; y += 25) BBox(0, y, 400, y + 20)];
    expect(preferFoundLines(block, four), isTrue);
    expect(preferFoundLines(block, four.take(1).toList()), isFalse);

    final three = _block(const BBox(0, 0, 400, 100), [for (var y = 0; y < 90; y += 30) BBox(0, y, 400, y + 24)]);
    expect(preferFoundLines(three, four), isFalse, reason: 'the found lines are hardly thinner');

    // Horizontal text taken for one vertical column: measured across the found lines.
    final column = _block(const BBox(0, 0, 400, 100), [const BBox(0, 0, 400, 100)], direction: TextDirection.vertical);
    expect(preferFoundLines(column, four), isTrue);
  });

  test('lines are given to the smallest block their centre is in, clipped to it', () {
    final big = _block(const BBox(0, 0, 400, 300), const []);
    final small = _block(const BBox(100, 100, 200, 150), const []);
    final got = assignLines(
      [big, small],
      const [BBox(90, 110, 210, 130), BBox(0, 10, 400, 30), BBox(500, 500, 520, 520)],
    );
    expect(got[0], const [BBox(0, 10, 400, 30)]);
    expect(got[1], const [BBox(96, 110, 204, 130)]);
  });

  test('a page is checked by the line detector only when a block looks wrong', () async {
    final img = _page([(20, 40), (50, 70)]);
    final found = [const BBox(15, 18, 385, 42), const BBox(15, 48, 385, 72)];

    final good = _block(const BBox(10, 10, 390, 80), [const BBox(10, 15, 390, 45), const BBox(10, 45, 390, 75)]);
    final detector = _Lines(found);
    expect(await checkBlockLines(img, [good], detector, _context, languageCode: 'en'), 0);
    expect(detector.calls, 0);

    final merged = _block(const BBox(10, 10, 390, 80), [const BBox(10, 10, 390, 80)]);
    expect(await checkBlockLines(img, [merged], detector, _context, languageCode: 'en'), 1);
    expect(detector.calls, 1);
    expect([for (final l in merged.lines) l.axisBox], found);
    expect((merged.fixedLines, merged.direction), (true, TextDirection.horizontal));
  });

  test('prepareReading checks the lines before taking the text size from them', () async {
    final img = _page([(20, 40), (50, 70)]);
    final merged = _block(const BBox(10, 10, 390, 80), [const BBox(10, 10, 390, 80)]);
    await prepareReading(
      img,
      [merged],
      sourceLanguageCode: 'en',
      lineChecker: _Lines([const BBox(15, 18, 385, 42), const BBox(15, 48, 385, 72)]),
    );
    expect(merged.lines.length, 2);
    expect(merged.linePx, 25);
  });

  test('junk in recognized text: symbols and letters of another script', () {
    expect(junkShare('Hello, world! 10% "yes" — no…', 'en'), 0);
    expect(looksLikeJunk('Istatde ①11∄¼1∄₿₿71118171¥Ⅱ❻¼¼¼❻Ⅺ7θθ7θ⑩', 'en'), isTrue);
    expect(junkShare('Привет', 'ru'), 0);
    expect(junkShare('Привет', 'en'), 1);
    expect(junkShare('HET, Привет', 'ru'), 0, reason: 'Latin look-alikes are common in Cyrillic OCR');
    expect(junkShare('こんにちは', 'ja'), 0);
    expect(looksLikeJunk('√∏', 'en'), isFalse, reason: 'too short to tell');
  });

  test('a block read as junk is read again with the found lines; a worse reading is not kept', () async {
    final img = _page([(20, 40), (50, 70)]);
    final lines = _Lines([const BBox(15, 18, 385, 42), const BBox(15, 48, 385, 72)]);
    TextBlock junk() =>
        _block(const BBox(10, 10, 390, 80), [const BBox(10, 15, 390, 45), const BBox(10, 45, 390, 75)])
          ..text = '①11∄¼1∄₿₿71¥❻¼¼';
    final ok = _block(const BBox(10, 100, 390, 130), [const BBox(10, 100, 390, 130)])..text = 'FINE TEXT';

    final a = junk();
    final good = _Ocr('DID SHE ALSO HAPPEN TO--?');
    expect(await rereadJunk(good, img, [a, ok], lines, _context, sourceLanguage: 'English', languageCode: 'en'), 1);
    expect((a.text, a.fixedLines, a.lines.length, a.linePx), ('DID SHE ALSO HAPPEN TO--?', true, 2, 25));
    expect(ok.text, 'FINE TEXT');

    final b = junk();
    expect(
      await rereadJunk(_Ocr('√∏√∏√∏√∏√∏√∏'), img, [b], lines, _context, sourceLanguage: 'English', languageCode: 'en'),
      0,
    );
    expect((b.text, b.fixedLines), ('①11∄¼1∄₿₿71¥❻¼¼', false));

    // Nothing looks like junk: neither the line detector nor the OCR runs.
    final quiet = _Lines(const []);
    final idle = _Ocr('x');
    expect(await rereadJunk(idle, img, [ok], quiet, _context, sourceLanguage: 'English', languageCode: 'en'), 0);
    expect((quiet.calls, idle.calls), (0, 0));
  });

  test('a block with lines of ink read as nothing is read again; an empty block on blank paper is not', () async {
    final img = _page([(20, 40), (50, 70)]);
    final lines = _Lines([const BBox(15, 18, 385, 42), const BBox(15, 48, 385, 72)]);
    // Prose split into two "vertical" strips: the recognizer read nothing.
    TextBlock lost() => _block(const BBox(10, 10, 390, 80), [
      const BBox(10, 10, 200, 80),
      const BBox(200, 10, 390, 80),
    ], direction: TextDirection.vertical);
    final blank = _block(const BBox(10, 150, 390, 250), [const BBox(10, 150, 390, 250)]);
    expect((readNothing(img, lost()), readNothing(img, blank)), (true, false));

    final a = lost();
    final good = _Ocr('DID SHE ALSO HAPPEN TO--?');
    expect(await rereadJunk(good, img, [a, blank], lines, _context, sourceLanguage: 'English', languageCode: 'en'), 1);
    expect(
      (a.text, a.direction, a.fixedLines, a.lines.length),
      ('DID SHE ALSO HAPPEN TO--?', TextDirection.horizontal, true, 2),
    );
    expect(blank.text, '');

    // Still nothing, or junk, the second time: the block stays as it was.
    for (final text in ['', '√∏√∏√∏√∏√∏√∏']) {
      final b = lost();
      expect(await rereadJunk(_Ocr(text), img, [b], lines, _context, sourceLanguage: 'English', languageCode: 'en'), 0);
      expect((b.text, b.fixedLines, b.direction), ('', false, TextDirection.vertical));
    }
  });
}
