// The look of single words: editing runs, keeping them through text edits,
// marking them for the layout, bold words from a chat's stars.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

const bold = RunStyle(bold: true);
const red = RunStyle(color: 0xFFFF0000);

void main() {
  group('restyle a range', () {
    test('a new run, then one over half of it: split, joined where equal', () {
      var runs = restyleRange(const [], 2, 6, (s) => s.copyWith(bold: true));
      expect(runs, [const StyledRun(2, 6, bold)]);
      runs = restyleRange(runs, 4, 8, (s) => s.copyWith(color: 0xFFFF0000));
      expect(runs, [
        const StyledRun(2, 4, bold),
        const StyledRun(4, 6, RunStyle(bold: true, color: 0xFFFF0000)),
        const StyledRun(6, 8, red),
      ]);
      runs = restyleRange(runs, 4, 6, (s) => s.copyWith(color: null));
      expect(runs, [const StyledRun(2, 6, bold), const StyledRun(6, 8, red)]);
    });

    test('clearing a range drops what is left without a look', () {
      final runs = restyleRange([const StyledRun(0, 5, bold)], 0, 5, (_) => const RunStyle());
      expect(runs, isEmpty);
    });
  });

  group('runs follow text edits', () {
    test('typing before a run moves it, inside it grows it, after it leaves it', () {
      expect(shiftRuns([const StyledRun(0, 2, bold)], 'НЕ пойду', 'Я НЕ пойду'), [const StyledRun(2, 4, bold)]);
      expect(shiftRuns([const StyledRun(0, 2, bold)], 'НЕ пойду', 'НЕТ пойду'), [const StyledRun(0, 2, bold)]);
      const runs = [StyledRun(4, 6, bold)];
      expect(shiftRuns(runs, 'Я НЕ пойду', 'Ну Я НЕ пойду'), [const StyledRun(7, 9, bold)]);
      expect(shiftRuns(runs, 'Я, НЕ пойду', 'Я, НЕТ пойду'), [const StyledRun(4, 7, bold)]);
      expect(shiftRuns(runs, 'Я, НЕ пойду', 'Я, НЕ пойду!'), runs);
    });

    test('a run whose text is deleted goes', () {
      expect(shiftRuns([const StyledRun(3, 5, bold)], 'Я, НЕ пойду', 'Я, пойду'), isEmpty);
    });
  });

  group('marks for the layout', () {
    test('marked text splits back into pieces, marks go away for showing', () {
      const runs = [StyledRun(2, 4, bold), StyledRun(5, 10, red)];
      final marked = markRuns('Я НЕ пойду', runs);
      expect(marked.length, 'Я НЕ пойду'.length + 4);
      expect(unmarkRuns(marked), 'Я НЕ пойду');
      expect(runPieces(marked), [('Я ', null), ('НЕ', 0), (' ', null), ('пойду', 1)]);
    });

    test('a run goes on over a line break', () {
      final marked = markRuns('один два', [const StyledRun(0, 8, bold)]).replaceFirst(' ', '\n');
      expect(runPieces(marked), [('один\nдва', 0)]);
    });

    test('runs outside the text are left out', () {
      expect(markRuns('да', [const StyledRun(1, 9, bold)]), 'да');
    });

    test('wrapping and hyphenation keep marks with their words', () {
      final marked = markRuns('ну и превосходительство', [const StyledRun(5, 23, bold)]);
      double measure(String s) => unmarkRuns(s).length.toDouble();
      final wrapped = wrapTextGreedily(marked, measure, 12, hyphenate: true);
      expect(unmarkRuns(wrapped), 'ну и превос-\nходительство');
      expect(runPieces(wrapped).last.$2, 0);
    });
  });

  group('stars from a chat', () {
    test('stressed words become bold runs; lone stars stay', () {
      final (text, runs) = boldFromStars('Я *НЕ* пойду, **никогда**! 2 * 3');
      expect(text, 'Я НЕ пойду, никогда! 2 * 3');
      expect(runs, [const StyledRun(2, 4, bold), const StyledRun(12, 19, bold)]);
    });

    test('a reply with stars sets the bold words of the block', () {
      final block = TextBlock(xyxy: const BBox(0, 0, 10, 10), text: "I'm NOT going!");
      applyExchangeReply(block, const ExchangeReply(translation: 'Я *НЕ* пойду!'), ExchangeMode.translate);
      expect(block.translation, 'Я НЕ пойду!');
      expect(block.style?.runs, [const StyledRun(2, 4, bold)]);
      applyExchangeReply(block, const ExchangeReply(translation: 'Не пойду!'), ExchangeMode.translate);
      expect(block.style, isNull, reason: 'a new translation without stars has no bold words');
    });
  });

  test('layout: runs go to the drawn text as marks, presets are looked up by name', () {
    const presets = {'Крик': BlockStyle(color: 0xFFFF0000, bold: true, fontFamily: 'Russo One')};
    final block = TextBlock(
      xyxy: const BBox(100, 100, 400, 300),
      text: 'Hello there',
      translation: 'Привет всем',
      style: const BlockStyle(
        preset: 'Крик',
        runs: [
          StyledRun(0, 6, RunStyle(italic: true)),
          StyledRun(7, 11, RunStyle(preset: 'Крик')),
        ],
      ),
    )..sourceLang = 'en';
    final item = layoutPage(
      [block],
      1000,
      1000,
      _Measurer(),
      settings: const RenderSettings(presets: presets, textCase: TextCase.normal),
      targetLanguage: 'Russian',
    ).single;
    expect(unmarkRuns(item.text).replaceAll('\n', ' '), 'Привет всем');
    expect(runPieces(item.text).map((p) => p.$2).where((r) => r != null), [0, 1]);
    expect(item.toJson()['text'], isNot(contains('')), reason: 'marks are never shown');
    expect(item.color, 0xFFFF0000, reason: "the preset's colour");
    final s = item.settings!;
    expect((s.bold, s.fontFamily), (true, 'Russo One'));
    expect(s.runs[1], const RunStyle(color: 0xFFFF0000, bold: true, fontFamily: 'Russo One'));
  });

  test('JSON round trip of a block style with runs', () {
    const style = BlockStyle(runs: [StyledRun(0, 2, RunStyle(scale: 1.3, preset: 'Крик'))]);
    expect(BlockStyle.fromJson(style.toJson()), style);
  });
}

/// Monospace measurer that does not count run marks.
class _Measurer implements TextMeasurer {
  @override
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical}) {
    final px = fontSizePt * 4 / 3;
    final lines = unmarkRuns(text).split('\n');
    final longest = lines.map((l) => l.length).fold(0, (a, b) => a > b ? a : b);
    return (width: longest * 0.6 * px + 8, height: lines.length * 1.2 * px + 8);
  }
}
