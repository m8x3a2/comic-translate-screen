// Hand-made styles of single blocks: JSON, merging and their effect on the
// layout.

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// Monospace measurer: 0.6 em per character, 1.2 em per line, 4 px margin;
/// bold text is 10% wider.
class FakeMeasurer implements TextMeasurer {
  FakeMeasurer([this.bold = false]);

  final bool bold;

  @override
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical}) {
    final px = fontSizePt * 4 / 3;
    final lines = text.split('\n');
    final longest = lines.map((l) => l.runes.length).fold(0, math.max);
    final w = longest * 0.6 * px * (bold ? 1.1 : 1) + 8, h = lines.length * 1.2 * px + 8;
    return vertical ? (width: h, height: w) : (width: w, height: h);
  }
}

TextBlock block({String translation = 'Hello there friend', BlockStyle? style}) =>
    TextBlock(xyxy: const BBox(100, 100, 400, 300), translation: translation, style: style)..sourceLang = 'en';

void main() {
  test('JSON round trip keeps only set fields; TextBlock carries the style', () {
    const s = BlockStyle(
      fontFamily: 'Comic Sans MS',
      fontSizePt: 18,
      color: 0xFF112233,
      outline: false,
      outlineColor: 0xFFFFFFFF,
      outlineWidth: 2,
      bold: true,
      italic: true,
      underline: false,
      lineSpacing: 1.2,
      alignment: TextAlignment.left,
      vertical: false,
      angle: -12.5,
      textBox: BBox(1, 2, 30, 40),
    );
    expect(BlockStyle.fromJson(s.toJson()), s);
    expect(const BlockStyle(bold: true).toJson(), {'bold': true});
    expect(const BlockStyle().isEmpty, isTrue);

    final b = block(style: const BlockStyle(fontSizePt: 20));
    final json = b.toJson();
    expect(json['style'], {'font_size_pt': 20});
    expect(TextBlock.fromJson(json).style, const BlockStyle(fontSizePt: 20));
    expect(b.copy().style, b.style);
    expect(block().toJson().containsKey('style'), isFalse, reason: 'no key for blocks drawn automatically');
  });

  test('copyWith can unset a field; merge takes only set fields', () {
    const s = BlockStyle(fontSizePt: 20, bold: true);
    expect(s.copyWith(fontSizePt: null), const BlockStyle(bold: true));
    expect(s.copyWith(italic: true), const BlockStyle(fontSizePt: 20, bold: true, italic: true));
    expect(
      s.merge(const BlockStyle(bold: false, color: 0xFF000000)),
      const BlockStyle(fontSizePt: 20, bold: false, color: 0xFF000000),
    );
  });

  test('applyTo: a fixed size becomes both limits', () {
    final r = const BlockStyle(
      fontSizePt: 15,
      bold: true,
      alignment: TextAlignment.right,
    ).applyTo(const RenderSettings());
    expect((r.minFontSize, r.maxFontSize, r.bold, r.alignment), (15, 15, true, TextAlignment.right));
    expect(r.outline, const RenderSettings().outline);
  });

  test('layout: fixed size, colour, angle, own text box, own measurer', () {
    const settings = RenderSettings(minFontSize: 9, maxFontSize: 40);
    final auto = layoutPage(
      [block()],
      1000,
      1000,
      FakeMeasurer(),
      settings: settings,
      targetLanguage: 'English',
    ).single;
    expect(auto.settings, isNull);

    final styled = layoutPage(
      [
        block(
          style: const BlockStyle(
            fontSizePt: 12,
            color: 0xFFFF0000,
            angle: 10,
            bold: true,
            textBox: BBox(500, 500, 900, 600),
          ),
        ),
      ],
      1000,
      1000,
      FakeMeasurer(),
      settings: settings,
      targetLanguage: 'English',
      measurerFor: (s) => FakeMeasurer(s.bold),
    ).single;
    expect(styled.fontSizePt, 12);
    expect(styled.color, 0xFFFF0000);
    expect(styled.angle, 10);
    expect(styled.settings?.bold, isTrue);
    expect(styled.x, greaterThanOrEqualTo(500), reason: 'placed in the chosen box, not the block');
    expect(styled.y, greaterThanOrEqualTo(500));
    expect(styled.x + styled.width, lessThanOrEqualTo(900));
    final bold = FakeMeasurer(true).measure(styled.text, 12, vertical: false);
    expect(styled.width, bold.width, reason: 'measured with the bold measurer');
  });

  test('line breaks typed by the user are kept', () {
    const settings = RenderSettings(minFontSize: 9, maxFontSize: 12);
    final item = layoutPage(
      [block(translation: 'Hi\nthere')],
      1000,
      1000,
      FakeMeasurer(),
      settings: settings,
      targetLanguage: 'English',
    ).single;
    expect(item.text, 'Hi\nthere');
  });

  test('an enlarged page moves the chosen text box', () {
    final b = block(style: const BlockStyle(textBox: BBox(10, 20, 30, 40)));
    final scaled = scaleBlocks([b], 100, 100, 200, 300).single;
    expect(scaled.style!.textBox, const BBox(20, 60, 60, 120));
    expect(b.style!.textBox, const BBox(10, 20, 30, 40), reason: 'the original block is not changed');
  });

  test('mask strokes survive JSON', () {
    const s = MaskStroke(points: [Point2(1, 2), Point2(3.5, 4)], width: 12, erase: true);
    final back = MaskStroke.fromJson(s.toJson());
    expect(back.points, s.points);
    expect((back.width, back.erase), (12.0, true));
    expect(const MaskStroke(points: [], width: 3).toJson().containsKey('erase'), isFalse);
  });
}
