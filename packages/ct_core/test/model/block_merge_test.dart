// "Merge into one bubble": blocks cut out of one speech become one again.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('one box, lines and texts in order, the look of the first', () {
    final a = TextBlock(
      xyxy: const BBox(10, 10, 50, 30),
      lines: [TextLine.box(const BBox(12, 12, 48, 28))],
      text: "I'M",
      translation: 'Я',
      bubbleXyxy: const BBox(0, 0, 100, 100),
      style: const BlockStyle(bold: true, textBox: BBox(5, 5, 60, 40)),
    )..sourceLang = 'en';
    final b = TextBlock(
      xyxy: const BBox(12, 40, 60, 70),
      lines: [TextLine.box(const BBox(14, 42, 58, 68))],
      text: 'LATE!',
      translation: 'опоздал!',
      speaker: Speaker.male,
    );
    final m = mergeBlocks([a, b]);
    expect(m.xyxy, const BBox(10, 10, 60, 70));
    expect(m.lines.length, 2);
    expect((m.text, m.translation, m.speaker), ("I'M LATE!", 'Я опоздал!', Speaker.male));
    expect((m.style?.bold, m.style?.textBox), (true, null));
    expect(m.bubbleXyxy, const BBox(0, 0, 100, 100));
    expect(a.xyxy, const BBox(10, 10, 50, 30), reason: 'the blocks themselves stay');
  });

  test('no spaces for Japanese; a bubble that does not hold the box goes', () {
    final a = TextBlock(xyxy: const BBox(0, 0, 10, 10), text: 'こんにちは', bubbleXyxy: const BBox(0, 0, 12, 12))
      ..sourceLang = 'ja';
    final b = TextBlock(xyxy: const BBox(0, 20, 10, 30), text: '世界');
    final m = mergeBlocks([a, b]);
    expect(m.text, 'こんにちは世界');
    expect(m.bubbleXyxy, isNull);
  });
}
