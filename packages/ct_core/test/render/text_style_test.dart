// The look of the source lettering and what the layout makes of it: letter
// case, hyphenation, size as in the source, lines along the bubble's oval.

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// Monospace measurer: 0.6 em per character, 1.2 em per line, 4 px margin;
/// letters 0.7 em (capitals) and 0.5 em (small) high.
class FakeMeasurer implements TextMeasurer, LetterMetrics {
  @override
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical}) {
    final px = fontSizePt * 4 / 3;
    final lines = text.split('\n');
    final longest = lines.map((l) => l.runes.length).fold(0, math.max);
    return (width: longest * 0.6 * px + 8, height: lines.length * 1.2 * px + 8);
  }

  @override
  double get capHeight => 0.7;

  @override
  double get xHeight => 0.5;
}

/// A white page with black bars as letters: [n] bars [stroke] wide and
/// [height] high from (x, y), leaning [slant] px right per px of height.
RgbImage bars({
  int width = 400,
  int height = 200,
  int x = 50,
  int y = 50,
  int n = 8,
  int stroke = 4,
  int barHeight = 30,
  double slant = 0,
  List<int> paper = const [255, 255, 255],
}) {
  final img = RgbImage.filled(width, height, paper[0], paper[1], paper[2]);
  for (var k = 0; k < n; k++) {
    for (var dy = 0; dy < barHeight; dy++) {
      final shift = (slant * (barHeight - dy)).round();
      for (var dx = 0; dx < stroke; dx++) {
        final o = img.offset(x + k * 20 + shift + dx, y + dy);
        img.data[o] = img.data[o + 1] = img.data[o + 2] = 0;
      }
    }
  }
  return img;
}

TextBlock lineBlock(BBox box, {String text = 'HELLO WORLD', TextClass textClass = TextClass.bubble}) => TextBlock(
  xyxy: box,
  lines: [TextLine.box(box)],
  text: text,
  textClass: textClass,
  fontColor: [0, 0, 0],
  direction: TextDirection.horizontal,
);

void main() {
  group('hyphenation', () {
    List<String> parts(String w) {
      final out = <String>[];
      var last = 0;
      for (final p in hyphenationPoints(w)) {
        out.add(w.substring(last, p));
        last = p;
      }
      return out..add(w.substring(last));
    }

    test('Russian words break by syllables', () {
      expect(parts('молоковоз'), ['мо', 'ло', 'ко', 'воз']);
      expect(parts('сестрица'), ['сес', 'три', 'ца']);
      expect(parts('большой'), ['боль', 'шой'], reason: 'ь stays with the letter before');
      expect(parts('войсками'), ['вой', 'ска', 'ми'], reason: 'й stays with the vowel');
      expect(parts('майорша'), ['май', 'ор', 'ша']);
      expect(parts('оружейник'), ['ору', 'жей', 'ник'], reason: 'no single letter on a line');
      expect(parts('ПРИВЕТИК!'), ['ПРИ', 'ВЕ', 'ТИК!'], reason: 'capitals; punctuation stays with its part');
    });

    test('short, Latin and mixed words are left whole', () {
      expect(hyphenationPoints('привет'), isEmpty, reason: 'shorter than seven letters');
      expect(hyphenationPoints('hello-world'), isEmpty);
      expect(hyphenationPoints('приветhello'), isEmpty);
    });

    test('wrapping breaks a word only where the line has room for a part', () {
      double measure(String s) => s.length.toDouble();
      expect(wrapTextGreedily('я пойду завтракать', measure, 10), 'я пойду\nзавтракать');
      expect(wrapTextGreedily('я пойду завтракать', measure, 10, hyphenate: true), 'я пойду\nзавтракать');
      expect(wrapTextGreedily('ну и завтракать', measure, 10, hyphenate: true), 'ну и зав-\nтракать');
    });
  });

  group('letter case', () {
    TextBlock b(String source, String translation) =>
        TextBlock(xyxy: const BBox(0, 0, 10, 10), text: source)..translation = translation;

    test('as in the source: capitals for capitals, sentence case otherwise', () {
      expect(casedTranslation(b('HELLO THERE', 'Привет'), TextCase.source), 'ПРИВЕТ');
      expect(casedTranslation(b('Hello there', 'ПРИВЕТ. КАК ДЕЛА?'), TextCase.source), 'Привет. Как дела?');
      expect(casedTranslation(b('Hello there', 'Привет, Анна'), TextCase.source), 'Привет, Анна');
    });

    test("a block's own choice wins", () {
      expect(casedTranslation(b('HELLO', 'Привет'), TextCase.source, upperCase: false), 'Привет');
      expect(casedTranslation(b('Hello', 'Привет'), TextCase.normal, upperCase: true), 'ПРИВЕТ');
    });

    test('sentence case: ellipses go on, English I stays', () {
      expect(toSentenceCase('ЭТО... ЭТО ДРУГОЕ!! ПРАВДА?'), 'Это... это другое!! Правда?');
      expect(toSentenceCase('...БЫЛ АНОС.'), '...был анос.');
      expect(toSentenceCase("I'M SURE I DID IT."), "I'm sure I did it.");
    });

    test('mostly capitals: a few misread letters do not count', () {
      expect(isMostlyUpperCase('WAs ANOTH VOLDIGORD.'), isTrue);
      expect(isMostlyUpperCase('Morning, guys'), isFalse);
      expect(isMostlyUpperCase('OK'), isFalse, reason: 'too few letters to tell');
    });
  });

  group('source style', () {
    test('letter height, stroke width and slant of upright letters', () {
      final img = bars();
      final s = measureSourceStyle(img, lineBlock(const BBox(45, 45, 220, 85)))!;
      expect(s.letterPx, closeTo(30, 1));
      expect(s.strokePx, closeTo(4, 0.8));
      expect(s.slant, closeTo(0, 0.05));
      expect(s.italic, isFalse);
      expect(s.hasOutline, isFalse);
    });

    test('leaning letters are italic', () {
      final img = bars(slant: 0.25);
      final s = measureSourceStyle(img, lineBlock(const BBox(45, 45, 240, 85)))!;
      expect(s.slant, closeTo(0.25, 0.05));
      expect(s.italic, isTrue);
    });

    test('an outline around free text, not the paper of a bubble', () {
      // Black letters with a white ring 4 px wide on mid grey.
      final img = bars(paper: const [128, 128, 128]);
      for (var y = 46; y < 84; y++) {
        for (var x = 46; x < 220; x++) {
          final o = img.offset(x, y);
          if (img.data[o] == 0) continue;
          var near = false;
          for (var dy = -4; dy <= 4 && !near; dy++) {
            for (var dx = -4; dx <= 4 && !near; dx++) {
              final q = img.offset(x + dx, y + dy);
              near = dx.abs() + dy.abs() <= 4 && img.data[q] == 0;
            }
          }
          if (near) img.data[o] = img.data[o + 1] = img.data[o + 2] = 255;
        }
      }
      final free = measureSourceStyle(img, lineBlock(const BBox(45, 45, 220, 85), textClass: TextClass.free))!;
      expect(free.hasOutline, isTrue);
      expect(free.outlineColor, 0xFFFFFF);
      expect(free.outlinePx, inInclusiveRange(3, 5));
      final paper = measureSourceStyle(bars(), lineBlock(const BBox(45, 45, 220, 85), textClass: TextClass.free))!;
      expect(paper.hasOutline, isFalse, reason: 'white all the way out is the paper');
    });

    test('JSON round trip and scaling', () {
      const s = SourceStyle(letterPx: 20, strokePx: 3, slant: 0.2, outlineColor: 0xFFFFFF, outlinePx: 2);
      expect(SourceStyle.fromJson(s.toJson()), s);
      final t = TextBlock(xyxy: const BBox(0, 0, 10, 10), sourceStyle: s);
      expect(TextBlock.fromJson(t.toJson()).sourceStyle, s);
      expect(s.scaled(2).letterPx, 40);
      expect(s.scaled(2).outlinePx, 4);
    });

    test('bold: heavier than the rest of the page', () {
      TextBlock w(double weight) => TextBlock(
        xyxy: const BBox(0, 0, 10, 10),
        sourceStyle: SourceStyle(letterPx: 20, strokePx: 20 * weight),
      );
      final page = PageLettering.of([w(0.14), w(0.14), w(0.15), w(0.17)]);
      expect(page.isBold(w(0.14).sourceStyle!), isFalse);
      expect(page.isBold(w(0.17).sourceStyle!), isTrue);
      expect(const PageLettering(null).isBold(w(0.17).sourceStyle!), isFalse, reason: 'too few blocks: absolute');
      expect(const PageLettering(null).isBold(w(0.2).sourceStyle!), isTrue);
    });
  });

  group('layout', () {
    TextBlock block(String translation, {BlockStyle? style, SourceStyle? source, String text = 'HELLO THERE'}) =>
        TextBlock(
          xyxy: const BBox(100, 100, 300, 260),
          bubbleXyxy: const BBox(60, 60, 340, 300),
          text: text,
          translation: translation,
          style: style,
          sourceStyle: source,
        )..sourceLang = 'en';

    List<TextItem> lay(TextBlock b, {RenderSettings settings = const RenderSettings()}) =>
        layoutPage([b], 1000, 1000, FakeMeasurer(), settings: settings, targetLanguage: 'Russian');

    test('case as in the source', () {
      expect(lay(block('привет')).single.text, 'ПРИВЕТ');
      expect(lay(block('привет', text: 'Hello there')).single.text, 'привет');
      expect(lay(block('привет', style: const BlockStyle(upperCase: false))).single.text, 'привет');
    });

    test('source outline, bold and italic go to the drawn text', () {
      const source = SourceStyle(letterPx: 20, strokePx: 5, slant: 0.2, outlineColor: 0x000000, outlinePx: 3);
      final item = lay(block('привет', source: source)).single;
      final s = item.settings!;
      expect((s.bold, s.italic, s.outline, s.outlineColor, s.outlineWidth), (true, true, true, 0xFF000000, 3.0));
      final off = lay(block('привет', source: source), settings: const RenderSettings(matchSource: false)).single;
      expect(off.settings, isNull);
    });

    test('size as in the source: capped by the letters, smaller when it does not fit', () {
      // 21 px capitals = 30 px font (0.7 em) = 22.5 pt.
      final item = lay(block('да', style: const BlockStyle(sourceSizePx: 21))).single;
      expect(item.fontSizePt, 23);
      final long = lay(block('очень длинный перевод этой реплики', style: const BlockStyle(sourceSizePx: 21))).single;
      expect(long.fontSizePt, lessThan(23));
    });

    test('hyphenation only when it makes the text clearly larger', () {
      const text = 'превосходительство';
      final plain = lay(block(text), settings: const RenderSettings(hyphenate: false)).single;
      final broken = lay(block(text)).single;
      expect(broken.text, contains('-\n'));
      expect(broken.fontSizePt, greaterThan(plain.fontSizePt));
      final short = lay(block('да нет')).single;
      expect(short.text.contains('-'), isFalse);
    });

    test('lines along the oval never make the letters much smaller than in the box', () {
      const text = 'превосходительство, вы правы';
      const off = RenderSettings(hyphenate: false);
      const on = RenderSettings(hyphenate: false, shapeFit: true);
      final box = lay(block(text), settings: off).single;
      final oval = lay(block(text), settings: on).single;
      expect(oval.fontSizePt, greaterThanOrEqualTo((box.fontSizePt * 0.9).floor()));
    });

    test('lines along the oval around the text, middle lines widest', () {
      const text = 'раз два три четыре пять шесть семь восемь девять десять';
      final item = lay(block(text), settings: const RenderSettings(shapeFit: true, hyphenate: false)).single;
      final lines = item.text.split('\n');
      expect(lines.length, greaterThanOrEqualTo(3));
      final mid = lines[lines.length ~/ 2].length;
      expect(lines.first.length, lessThanOrEqualTo(mid));
      expect(lines.last.length, lessThanOrEqualTo(mid));
      expect(item.x + item.width / 2, closeTo(200, 1));
      expect(item.y + item.height / 2, closeTo(180, 1));
    });
  });
}
