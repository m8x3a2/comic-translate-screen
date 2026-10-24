// Text layout: greedy wrapping matches the original's render.py; fitting,
// render areas and colours behave like pyside_word_wrap and the batch step.

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

import 'reference.dart';

double measure(String text) => text.split('\n').map((l) => l.length).fold(0, math.max) * 7.0;

/// Monospace measurer: 0.6 em per character, 1.2 em per line, 4 px margin.
class FakeMeasurer implements TextMeasurer {
  @override
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical}) {
    final px = fontSizePt * 4 / 3;
    final lines = text.split('\n');
    final longest = lines.map((l) => l.runes.length).fold(0, math.max);
    final w = longest * 0.6 * px + 8, h = lines.length * 1.2 * px + 8;
    return vertical ? (width: h, height: w) : (width: w, height: h);
  }
}

void main() {
  test('greedy wrapping matches the original', () {
    for (final c in (loadReference('render.json')['wrap'] as List).cast<Map>()) {
      final text = c['text'] as String, max = (c['max'] as num).toDouble();
      final out = c['no_space'] as bool ? wrapNoSpaceTextGreedily(text, measure, max) : wrapTextGreedily(text, measure, max);
      expect(out, c['out'], reason: '"$text" max=$max');
    }
  });

  test('fitText picks the largest size that fits, outline included', () {
    const s = RenderSettings(minFontSize: 9, maxFontSize: 40, outlineWidth: 1.0);
    final fit = fitText('Hello there, how are you today?', FakeMeasurer(), 200, 120, settings: s);
    expect(fit.fontSizePt, inInclusiveRange(9, 40));
    final m = FakeMeasurer().measure(fit.text, fit.fontSizePt, vertical: false);
    expect(m.width + 2, lessThanOrEqualTo(200));
    expect(m.height + 2, lessThanOrEqualTo(120));
    final bigger = FakeMeasurer().measure(
        wrapTextGreedily('Hello there, how are you today?', (t) => FakeMeasurer().measure(t, fit.fontSizePt + 1, vertical: false).width + 2, 200),
        fit.fontSizePt + 1,
        vertical: false);
    expect(bigger.width + 2 > 200 || bigger.height + 2 > 120 || fit.fontSizePt == 40, isTrue, reason: 'next size must not fit');
    expect(fit.width, m.width, reason: 'metrics exclude the outline');
  });

  test('nothing fits: minimum size', () {
    const s = RenderSettings(minFontSize: 9, maxFontSize: 40);
    final fit = fitText('Unbreakablewordthatisverylong indeed', FakeMeasurer(), 30, 20, settings: s);
    expect(fit.fontSizePt, 9);
  });

  test('render areas shrink by 5% except for Korean and Chinese sources', () {
    TextBlock b(String lang) => TextBlock(xyxy: const BBox(100, 100, 300, 200))..sourceLang = lang;
    final en = [b('en')];
    adjustRenderAreas(en, 1000, 1000);
    expect(en.first.xyxy, const BBox(105, 102, 295, 198));
    final ko = [b('ko')];
    adjustRenderAreas(ko, 1000, 1000);
    expect(ko.first.xyxy, const BBox(100, 100, 300, 200));
  });

  test('layoutPage: colours, upper case, skipped blocks, vertical targets', () {
    final blocks = [
      TextBlock(xyxy: const BBox(0, 0, 300, 200), translation: 'привет', fontColor: [10, 20, 30])..sourceLang = 'en',
      TextBlock(xyxy: const BBox(0, 300, 300, 500), translation: '...'),
      TextBlock(xyxy: const BBox(400, 0, 500, 400), translation: '縦書き', direction: TextDirection.vertical),
    ];
    final items = layoutPage(blocks, 1000, 1000, FakeMeasurer(),
        settings: const RenderSettings(textCase: TextCase.upper), targetLanguage: 'Russian');
    expect(items.length, 2, reason: 'punctuation-only translation is not drawn');
    expect(items.first.text, 'ПРИВЕТ');
    expect(items.first.color, 0xFF0A141E);
    expect(items.last.vertical, isFalse, reason: 'Russian is not written vertically');
    final ja = layoutPage([blocks.last], 1000, 1000, FakeMeasurer(), settings: const RenderSettings(), targetLanguage: 'Japanese');
    expect(ja.single.vertical, isTrue);
  });

  test('fitted text is placed inside its area (original: top-left corner)', () {
    TextBlock block() => TextBlock(xyxy: const BBox(0, 0, 400, 300), translation: 'Hi')..sourceLang = 'ko';
    final placed = layoutPage([block()], 1000, 1000, FakeMeasurer(), settings: const RenderSettings(), targetLanguage: 'English').single;
    expect(placed.x, closeTo((400 - placed.width) / 2, 1e-9));
    expect(placed.y, closeTo((300 - placed.height) / 2, 1e-9));
    final right = layoutPage([block()], 1000, 1000, FakeMeasurer(),
            settings: const RenderSettings(alignment: TextAlignment.right), targetLanguage: 'English')
        .single;
    expect(right.x, closeTo(400 - right.width, 1e-9));
    final original = layoutPage([block()], 1000, 1000, FakeMeasurer(),
            settings: const RenderSettings(placeInBlock: false), targetLanguage: 'English')
        .single;
    expect((original.x, original.y), (0.0, 0.0));
  });

  test('render settings survive a JSON round trip', () {
    const s = RenderSettings(fontFamily: 'Pangolin', color: 0xFF112233, outlineWidth: 1.5, alignment: TextAlignment.right, placeInBlock: false);
    final back = RenderSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(parseColor('#ff0000'), 0xFFFF0000);
    expect(parseColor('nope'), isNull);
  });
}
