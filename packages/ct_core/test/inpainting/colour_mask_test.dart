import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

const _w = 120, _h = 60;

/// Orange background; dark red letters (bars) at x 10–49 and black drawing
/// (bars) at x 70–109, both in rows 20–39.
RgbImage _page() {
  final data = Uint8List(_w * _h * 3);
  for (var i = 0; i < _w * _h; i++) {
    final x = i % _w, y = i ~/ _w;
    var c = const [240, 160, 60];
    if (y >= 20 && y < 40 && x % 6 < 2) {
      if (x >= 10 && x < 50) c = const [150, 20, 20];
      if (x >= 70 && x < 110) c = const [0, 0, 0];
    }
    data.setRange(i * 3, i * 3 + 3, c);
  }
  return RgbImage(_w, _h, data);
}

int _count(GrayImage m, int x1, int x2) {
  var n = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = x1; x < x2; x++) {
      if (m.data[y * _w + x] != 0) n++;
    }
  }
  return n;
}

void main() {
  test('a clicked colour is sampled as the median around the click', () {
    final image = _page();
    expect(sampleColour(image, 12, 30), (150, 20, 20));
    expect(sampleColour(image, 3, 3), (240, 160, 60));
  });

  test('pixels of the picked colour become letters; other colours stay out', () {
    final m = maskByColours(_page(), GrayImage.zeros(_w, _h), [(150, 20, 20)], grow: 0);
    expect(_count(m, 0, 60), 7 * 2 * 20, reason: 'the red bars');
    expect(_count(m, 60, _w), 0, reason: 'the black drawing');
    expect(m.data[30 * _w + 12], 255);
  });

  test('a near shade is taken within the tolerance; black on colour can be picked too', () {
    final near = maskByColours(_page(), GrayImage.zeros(_w, _h), [(165, 30, 25)], tolerance: 20, grow: 0);
    expect(_count(near, 0, 60), 7 * 2 * 20);
    final strict = maskByColours(_page(), GrayImage.zeros(_w, _h), [(165, 30, 25)], tolerance: 4, grow: 0);
    expect(_count(strict, 0, 60), 0);
    final black = maskByColours(_page(), GrayImage.zeros(_w, _h), [(0, 0, 0)], grow: 0);
    expect(_count(black, 60, _w), 7 * 2 * 20);
  });

  test('a wide tolerance takes the soft edges of the letters, never the grey drawing', () {
    // White paper; columns: red letter, its edges (blends with the paper and
    // with black ink under it), and the drawing in black and greys.
    const columns = [
      [200, 40, 40], // 0 the letter
      [228, 148, 148], // 1 half-faded edge
      [244, 205, 205], // 2 faint edge
      [120, 24, 24], // 3 the letter over black ink
      [0, 0, 0], // 4 drawing
      [60, 60, 60], // 5
      [150, 150, 150], // 6
      [200, 200, 200], // 7
      [235, 235, 235], // 8
    ];
    const w = 40, h = 4;
    final data = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 255);
    for (var y = 0; y < h; y++) {
      for (var i = 0; i < columns.length; i++) {
        data.setRange((y * w + i * 4) * 3, (y * w + i * 4) * 3 + 3, columns[i]);
      }
    }
    final image = RgbImage(w, h, data);
    List<int> taken(double tolerance) {
      final m = maskByColours(image, GrayImage.zeros(w, h), [(200, 40, 40)], tolerance: tolerance, grow: 0);
      return [
        for (var i = 0; i < columns.length; i++)
          if (m.data[i * 4] != 0) i,
      ];
    }

    expect(taken(pipetteTolerance), [0]);
    expect(taken(maxPipetteTolerance), [0, 1, 2, 3]);
    for (var t = minPipetteTolerance; t <= maxPipetteTolerance; t += 8) {
      expect(taken(t).where((i) => i >= 4), isEmpty, reason: 'tolerance $t');
    }
  });

  test('whole pieces only: the drawing of the letters\' colour around a bubble stays out', () {
    // Black page; a white bubble (x 10–69, y 10–49) with black letters
    // (bars) inside; the region is a box a little larger than the bubble.
    const w = 80, h = 60;
    final data = Uint8List(w * h * 3);
    bool letter(int x, int y) => y >= 25 && y < 35 && x >= 20 && x < 60 && x % 6 < 2;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final paper = x >= 10 && x < 70 && y >= 10 && y < 50 && !letter(x, y);
        if (paper) data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, 255);
      }
    }
    final image = RgbImage(w, h, data);
    int count(GrayImage m, bool Function(int x, int y) where) {
      var n = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (where(x, y) && m.data[y * w + x] != 0) n++;
        }
      }
      return n;
    }

    bool outside(int x, int y) => !(x >= 10 && x < 70 && y >= 10 && y < 50);
    const region = [BBox(5, 5, 75, 55)];
    final all = maskByColours(image, GrayImage.zeros(w, h), [(0, 0, 0)], regions: region, grow: 0);
    expect(count(all, outside), greaterThan(0), reason: 'everything of the colour: the background too');
    final whole = maskByColours(image, GrayImage.zeros(w, h), [(0, 0, 0)], regions: region, grow: 2, wholePieces: true);
    expect(count(whole, letter), 6 * 2 * 10, reason: 'bars at x 24, 30 … 54');
    expect(count(whole, outside), 0);
  });

  test('only inside the regions; the base mask is kept; grown by a pixel', () {
    final base = GrayImage.zeros(_w, _h + 10)..data[_w * 2 + 2] = 128;
    final m = maskByColours(_page(), base, [(150, 20, 20), (0, 0, 0)], regions: [const BBox(0, 0, 60, _h)]);
    expect(m.height, _h + 10);
    expect(m.data[_w * 2 + 2], 128, reason: 'the base');
    expect(_count(m, 60, _w), 0, reason: 'outside the region');
    expect(m.data[30 * _w + 14], 255, reason: 'grown from x 13 into the gap');
    expect(m.data[30 * _w + 15], 0);
  });

  test('the regions of blocks: the bubble, or the box grown a little', () {
    final boxed = TextBlock(xyxy: const BBox(20, 20, 60, 40));
    final bubble = TextBlock(xyxy: const BBox(20, 20, 60, 40), bubbleXyxy: const BBox(5, 5, 100, 55))
      ..textClass = TextClass.bubble;
    expect(textRegions([boxed, bubble], _w, _h), [const BBox(12, 13, 68, 47), const BBox(5, 5, 100, 55)]);
  });
}
