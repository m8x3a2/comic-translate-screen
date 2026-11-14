import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

(int, int, int) px(RgbImage im, int x, int y) {
  final i = im.offset(x, y);
  return (im.data[i], im.data[i + 1], im.data[i + 2]);
}

/// A white "bubble" with a 2-pixel black ring at [x1, x2) × [y1, y2) on a
/// gray page.
RgbImage bubblePage({int w = 60, int h = 40}) {
  final im = RgbImage.filled(w, h, 128, 128, 128);
  void set(int x, int y, int v) {
    final i = im.offset(x, y);
    im.data[i] = v;
    im.data[i + 1] = v;
    im.data[i + 2] = v;
  }

  for (var y = 5; y < 35; y++) {
    for (var x = 5; x < 45; x++) {
      final ring = x < 7 || x >= 43 || y < 7 || y >= 33;
      set(x, y, ring ? 0 : 255);
    }
  }
  return im;
}

void main() {
  group('bakePaints', () {
    test('a brush paints its colour; the eraser brings the cleaned page back', () {
      final base = RgbImage.filled(40, 20, 255, 255, 255);
      final painted = bakePaints(base, [
        const PaintOp(kind: PaintKind.brush, points: [Point2(5, 10), Point2(35, 10)], width: 5, color: 0xFFFF0000),
      ]);
      expect(px(painted, 20, 10), (255, 0, 0));
      expect(px(painted, 20, 2), (255, 255, 255));
      // Soft edge: a pixel at the rim is a mix.
      final rim = px(painted, 20, 12);
      expect(rim.$2, inInclusiveRange(1, 254));

      final erased = bakePaints(base, [
        const PaintOp(kind: PaintKind.brush, points: [Point2(5, 10), Point2(35, 10)], width: 6, color: 0xFFFF0000),
        const PaintOp(kind: PaintKind.erase, points: [Point2(15, 10), Point2(25, 10)], width: 10),
      ]);
      expect(px(erased, 20, 10), (255, 255, 255));
      expect(px(erased, 8, 10), (255, 0, 0));
    });

    test('a stroke over its own path is not darker at the joints', () {
      final base = RgbImage.filled(40, 20, 255, 255, 255);
      final painted = bakePaints(base, [
        const PaintOp(
          kind: PaintKind.brush,
          points: [Point2(5, 10), Point2(20, 10), Point2(20.5, 10), Point2(35, 10)],
          width: 4,
          color: 0xFF000000,
        ),
      ]);
      // The rim pixel near a joint matches the one far from it.
      expect(px(painted, 20, 8), px(painted, 10, 8));
    });

    test('"Original" brings back the page before cleaning; without it nothing happens', () {
      final clean = RgbImage.filled(20, 20, 255, 255, 255);
      final original = RgbImage.filled(20, 20, 10, 20, 30);
      const op = PaintOp(kind: PaintKind.original, points: [Point2(10, 10)], width: 8);
      expect(px(bakePaints(clean, [op], original: original), 10, 10), (10, 20, 30));
      expect(px(bakePaints(clean, [op]), 10, 10), (255, 255, 255));
    });

    test('a fill paints its runs; the base is not changed', () {
      final base = RgbImage.filled(10, 10, 0, 0, 0);
      final out = bakePaints(base, [
        const PaintOp(kind: PaintKind.fill, color: 0xFF00FF00, runs: [2, 3, 6]),
      ]);
      expect(px(out, 3, 2), (0, 255, 0));
      expect(px(out, 5, 2), (0, 255, 0));
      expect(px(out, 6, 2), (0, 0, 0));
      expect(px(out, 3, 3), (0, 0, 0));
      expect(px(base, 3, 2), (0, 0, 0));
    });

    test('strokes off the page are ignored', () {
      final base = RgbImage.filled(10, 10, 1, 2, 3);
      final out = bakePaints(base, [
        const PaintOp(kind: PaintKind.brush, points: [Point2(-50, -50)], width: 4),
        const PaintOp(kind: PaintKind.fill, runs: [40, 0, 5]),
      ]);
      expect(out.data, base.data);
    });
  });

  test('JSON keeps every kind of touch-up', () {
    const ops = [
      PaintOp(kind: PaintKind.brush, points: [Point2(1, 2), Point2(3.5, 4)], width: 7, color: 0xFF112233),
      PaintOp(kind: PaintKind.erase, points: [Point2(1, 2)], width: 3),
      PaintOp(kind: PaintKind.original, points: [Point2(5, 5)], width: 9),
      PaintOp(kind: PaintKind.fill, color: 0xFFFFFFFF, runs: [1, 2, 3, 4, 5, 6]),
    ];
    final back = paintOpsFromJson([for (final o in ops) o.toJson()]);
    expect(back.map((o) => o.toJson()).toList(), ops.map((o) => o.toJson()).toList());
    expect(paintOpsFromJson(null), isEmpty);
    expect(paintsUseOriginal(back), isTrue);
  });

  group('floodFillRuns', () {
    Set<(int, int)> pixels(List<int> runs) => {
      for (var k = 0; k < runs.length; k += 3)
        for (var x = runs[k + 1]; x < runs[k + 2]; x++) (x, runs[k]),
    };

    test('fills the inside of a bubble and stops at its ring', () {
      final page = bubblePage();
      final filled = pixels(floodFillRuns(page, 20, 20));
      expect(filled, contains((7, 7)));
      expect(filled, contains((42, 32)));
      expect(filled, isNot(contains((6, 20))));
      expect(filled, isNot(contains((2, 2))));
      expect(filled.length, 36 * 26);
    });

    test('leftover letters inside the bubble are filled too, unless asked not to', () {
      final page = bubblePage();
      for (var y = 15; y < 20; y++) {
        for (var x = 15; x < 18; x++) {
          final i = page.offset(x, y);
          page.data[i] = 30;
          page.data[i + 1] = 30;
          page.data[i + 2] = 30;
        }
      }
      expect(pixels(floodFillRuns(page, 25, 25)), contains((16, 17)));
      expect(pixels(floodFillRuns(page, 25, 25, closeSpots: false)), isNot(contains((16, 17))));
    });

    test('a click on the gutter does not fill the panel it surrounds', () {
      // A gray frame 4 px wide around a large white panel.
      final page = RgbImage.filled(50, 50, 255, 255, 255);
      for (var y = 0; y < 50; y++) {
        for (var x = 0; x < 50; x++) {
          if (x < 4 || y < 4 || x >= 46 || y >= 46) {
            final i = page.offset(x, y);
            page.data[i] = 128;
            page.data[i + 1] = 128;
            page.data[i + 2] = 128;
          }
        }
      }
      final filled = pixels(floodFillRuns(page, 1, 1));
      expect(filled, contains((48, 48)));
      expect(filled, isNot(contains((25, 25))));
    });

    test('tolerance lets a slightly different colour in', () {
      final page = RgbImage.filled(10, 1, 200, 200, 200);
      final i = page.offset(5, 0);
      page.data[i] = 180;
      expect(pixels(floodFillRuns(page, 0, 0, tolerance: 10, closeSpots: false)).length, 5);
      expect(pixels(floodFillRuns(page, 0, 0, tolerance: 30)).length, 10);
      expect(floodFillRuns(page, 20, 0), isEmpty);
    });
  });

  group('polygonRuns', () {
    Set<(int, int)> pixels(List<int> runs) => {
      for (var k = 0; k < runs.length; k += 3)
        for (var x = runs[k + 1]; x < runs[k + 2]; x++) (x, runs[k]),
    };

    test('a rectangle covers the pixels whose centres are inside', () {
      final runs = polygonRuns(rectanglePoints(const Point2(2, 3), const Point2(6, 5)), 20, 20);
      expect(pixels(runs), {
        for (var y = 3; y < 5; y++)
          for (var x = 2; x < 6; x++) (x, y),
      });
    });

    test('a triangle; points off the page are cut at its edges', () {
      final tri = pixels(polygonRuns(const [Point2(0, 0), Point2(10, 0), Point2(0, 10)], 20, 20));
      expect(tri, contains((1, 1)));
      expect(tri, isNot(contains((8, 8))));
      final off = pixels(polygonRuns(rectanglePoints(const Point2(-5, -5), const Point2(3, 3)), 10, 10));
      expect(off, {
        for (var y = 0; y < 3; y++)
          for (var x = 0; x < 3; x++) (x, y),
      });
      expect(polygonRuns(const [Point2(1, 1), Point2(5, 5)], 10, 10), isEmpty);
    });

    test('an ellipse is round: the middle in, the corners of its box out', () {
      final e = pixels(polygonRuns(ellipsePoints(const Point2(0, 0), const Point2(40, 20)), 50, 50));
      expect(e, contains((20, 10)));
      expect(e, isNot(contains((1, 1))));
      expect(e, isNot(contains((39, 19))));
    });

    test('a figure eight (a lasso crossing itself) fills both loops', () {
      final runs = polygonRuns(const [Point2(0, 0), Point2(20, 20), Point2(20, 0), Point2(0, 20)], 30, 30);
      final p = pixels(runs);
      // The loops are left and right of the crossing at (10, 10).
      expect(p, contains((3, 10)));
      expect(p, contains((17, 10)));
      expect(p, isNot(contains((10, 3))));
    });
  });
}
