import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('Latin look-alikes become Cyrillic in Russian text', () {
    expect(fixCyrillicLookalikes('HET! Даже не думай об этом'), 'НЕТ! Даже не думай об этом');
    expect(fixCyrillicLookalikes('пpивeт'), 'привет', reason: 'mixed word');
    expect(fixCyrillicLookalikes('ТОЧHO'), 'ТОЧНО');
  });

  test('Latin words that are not look-alikes, and English-only text, stay', () {
    expect(fixCyrillicLookalikes('Wow, это круто'), 'Wow, это круто');
    expect(fixCyrillicLookalikes('HET'), 'HET', reason: 'no Cyrillic context');
    expect(fixCyrillicLookalikes('THE END'), 'THE END');
  });

  test('only for Cyrillic source languages', () {
    final ru = TextBlock(xyxy: const BBox(0, 0, 1, 1), texts: ['HET!', 'Даже'])..sourceLang = 'ru';
    fixOcrScript([ru], 'ru');
    expect(ru.texts, ['НЕТ!', 'Даже']);
    expect(ru.text, 'НЕТ! Даже');
    final en = TextBlock(xyxy: const BBox(0, 0, 1, 1), texts: ['HET Даже']);
    fixOcrScript([en], 'en');
    expect(en.text, 'HET Даже');
  });

  test('reading scale: large text is not enlarged, small text is', () {
    TextBlock blockWithLines(int lineHeight) => TextBlock(
          xyxy: const BBox(0, 0, 200, 100),
          direction: TextDirection.horizontal,
          lines: [for (var i = 0; i < 3; i++) TextLine.box(BBox(0, i * 30, 200, i * 30 + lineHeight - 1))],
        );
    final page = RgbImage.filled(400, 600, 255, 255, 255);
    expect(readingScaleFactor(page, [blockWithLines(40)]), 1.0);
    expect(readingScaleFactor(page, [blockWithLines(12)]), closeTo(3.0, 1e-9));
    expect(readingScaleFactor(page, []), 1.0);
  });

  test('a box drawn by hand (no lines) is split into lines and its small text enlarged', () {
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
    final reading = prepareReading(page, [hand], sourceLanguageCode: 'en');
    expect(reading.scaled, isTrue, reason: 'small text counts once its lines are known');
    expect(hand.lines, hasLength(3));
    reading.restore();
    expect(hand.xyxy, const BBox(34, 24, 136, 72));
    expect(hand.lines, hasLength(3));
  });
}
