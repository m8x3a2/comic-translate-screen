import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// Letters are black bars 8×14 px, 3 px apart; words 8 px apart.
const _letterW = 8, _letterH = 14, _letterGap = 3, _space = 8;

/// Draws [words] (letter counts) on a row of [image] from [x] at [y];
/// returns the box of the ink.
BBox _row(RgbImage image, int x, int y, List<int> words) {
  final x0 = x;
  for (final (i, n) in words.indexed) {
    if (i > 0) x += _space - _letterGap;
    for (var k = 0; k < n; k++) {
      for (var yy = y; yy < y + _letterH; yy++) {
        image.data.fillRange(image.offset(x, yy), image.offset(x + _letterW, yy), 0);
      }
      x += _letterW + _letterGap;
    }
  }
  return BBox(x0, y, x - _letterGap, y + _letterH);
}

RgbImage _page() => RgbImage.filled(700, 300, 255, 255, 255);

BBox _around(Iterable<BBox> boxes) => boxes.reduce((a, b) => a.union(b)).padded(6);

extension on BBox {
  BBox padded(int m) => BBox(x1 - m, y1 - m, x2 + m, y2 + m);
}

void main() {
  test('names and descriptions in one block become blocks of their own', () {
    final image = _page();
    // Names end at x 150, descriptions start 40 px later; two entries, the
    // second far below the first.
    final rows = <BBox>[
      _row(image, 150 - 7 * 11 + 3, 20, [7]),
      _row(image, 190, 20, [5, 4, 6]),
      _row(image, 190, 40, [6, 3]),
      _row(image, 150 - 5 * 11 + 3, 120, [5]),
      _row(image, 190, 120, [4, 7, 5]),
    ];
    final block = TextBlock(xyxy: _around(rows), textClass: TextClass.free);
    final out = splitColumnBlocks(image, [block]);
    expect(out, hasLength(4));
    final names = out.where((b) => b.xyxy.x2 < 170).toList();
    final texts = out.where((b) => b.xyxy.x1 > 170).toList();
    expect(names, hasLength(2));
    expect(texts, hasLength(2));
    // The first description keeps both its lines.
    expect(texts.any((b) => b.xyxy.y1 < 20 && b.xyxy.y2 > 54), isTrue);
  });

  test('a paragraph with ordinary spaces stays one block', () {
    final image = _page();
    final rows = [
      _row(image, 20, 20, [4, 6, 3, 5, 7]),
      _row(image, 20, 40, [5, 2, 6, 4]),
      _row(image, 20, 60, [3, 6, 5]),
    ];
    final block = TextBlock(xyxy: _around(rows), textClass: TextClass.free);
    expect(splitColumnBlocks(image, [block]), [same(block)]);
  });

  test('one wide gap in a lone line is not enough', () {
    final image = _page();
    final rows = [
      _row(image, 20, 20, [5, 4]),
      _row(image, 200, 20, [6, 5]),
    ];
    final block = TextBlock(xyxy: _around(rows), textClass: TextClass.free);
    expect(splitColumnBlocks(image, [block]), [same(block)]);
  });

  test('single lines are split when other blocks have the gap at the same place', () {
    final image = _page();
    final blocks = <TextBlock>[];
    for (final y in [20, 80, 140]) {
      final line = _around([
        _row(image, 150 - 6 * 11 + 3, y, [6]),
        _row(image, 190, y, [5, 6]),
      ]);
      blocks.add(TextBlock(xyxy: line, textClass: TextClass.free, lines: [TextLine.box(line)])..fixedLines = true);
    }
    final out = splitColumnBlocks(image, blocks);
    expect(out, hasLength(6));
    expect(out.every((b) => b.xyxy.x2 < 170 || b.xyxy.x1 > 170), isTrue);
    expect(out.every((b) => b.fixedLines && b.lines.length == 1), isTrue);
  });

  test('a short word beside a wide gap is not a column', () {
    final image = _page();
    // Two letters on the left: spacing, not a column of names.
    final rows = [
      _row(image, 20, 20, [2]),
      _row(image, 80, 20, [5, 6]),
      _row(image, 20, 40, [2]),
      _row(image, 80, 40, [4, 7]),
    ];
    final block = TextBlock(xyxy: _around(rows), textClass: TextClass.free);
    expect(splitColumnBlocks(image, [block]), [same(block)]);
  });

  test('vertical blocks and blocks over a drawing are left alone', () {
    final image = _page();
    final rows = [
      _row(image, 20, 20, [6]),
      _row(image, 120, 20, [6]),
      _row(image, 20, 40, [6]),
      _row(image, 120, 40, [6]),
    ];
    final vertical = TextBlock(xyxy: _around(rows), direction: TextDirection.vertical);
    expect(splitColumnBlocks(image, [vertical]), [same(vertical)]);

    // Grey noise everywhere: no empty stripe.
    final busy = _page();
    for (var i = 0; i < busy.data.length; i += 3) {
      busy.data.fillRange(i, i + 3, (i ~/ 3 * 7919) % 200);
    }
    final block = TextBlock(xyxy: const BBox(10, 10, 400, 100));
    expect(splitColumnBlocks(busy, [block]), [same(block)]);
  });
}
