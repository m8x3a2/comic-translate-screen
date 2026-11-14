// "Apply this look": the ticked parts of one bubble's look go to others.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  const from = BlockStyle(
    fontFamily: 'Bangers',
    fontSizePt: 30,
    color: 0xFFFF0000,
    outline: true,
    outlineWidth: 2,
    bold: true,
    alignment: TextAlignment.left,
    angle: 15,
    preset: 'Shout',
  );
  const other = BlockStyle(
    fontSizePt: 12,
    italic: true,
    textBox: BBox(1, 2, 30, 40),
    color: 0xFF0000FF,
    runs: [StyledRun(0, 2, RunStyle(bold: true))],
  );

  test('the usual parts: the look, not the size, the turn or the place', () {
    final s = other.withPartsOf(from, LookPart.usual);
    expect((s.fontFamily, s.color, s.outline, s.outlineWidth, s.preset), ('Bangers', 0xFFFF0000, true, 2.0, 'Shout'));
    // Bold, italic and underline go together: italic is unset as in the source.
    expect((s.bold, s.italic, s.alignment), (true, null, TextAlignment.left));
    expect((s.fontSizePt, s.angle, s.textBox, s.runs.length), (12, null, const BBox(1, 2, 30, 40), 1));
  });

  test('size and turn when ticked; an unset part unsets', () {
    final s = other.withPartsOf(from, {LookPart.size, LookPart.angle});
    expect((s.fontSizePt, s.angle, s.color), (30, 15.0, 0xFF0000FF));
    expect(other.withPartsOf(const BlockStyle(), {LookPart.color}).color, isNull);
    expect(LookPart.parseAll(['font', 'nope', 'size']), {LookPart.font, LookPart.size});
  });
}
