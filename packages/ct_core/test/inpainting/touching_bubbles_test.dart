import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// Two touching bubbles: A has a shaded background (left to the network),
/// B is plain white (flat-filled). The end of A's text lies inside B's box.
(RgbImage, TextBlock, TextBlock) _page() {
  const w = 400, h = 200;
  final data = Uint8List(w * h * 3);
  void put(int x, int y, int v) => data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, v);
  bool inEllipse(int x, int y, double cx, double cy, double rx, double ry, [double grow = 0]) {
    final dx = (x - cx) / (rx + grow), dy = (y - cy) / (ry + grow);
    return dx * dx + dy * dy <= 1;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = (x * 7 + y * 13) % 90 + 40; // busy artwork
      if (inEllipse(x, y, 150, 80, 100, 60, 3)) v = 0;
      if (inEllipse(x, y, 150, 80, 100, 60)) v = 150 + (x - 50) * 80 ~/ 200; // shaded
      if (inEllipse(x, y, 280, 120, 70, 55, 3)) v = 0; // B in front of A
      if (inEllipse(x, y, 280, 120, 70, 55)) v = 255;
      put(x, y, v);
    }
  }
  // A's letters, the last ones inside B's box but outside B's ellipse.
  for (var x0 = 95; x0 < 230; x0 += 14) {
    for (var y = 70; y < 84; y++) {
      for (var x = x0; x < x0 + 8; x++) {
        put(x, y, 0);
      }
    }
  }
  for (var x0 = 250; x0 < 310; x0 += 14) {
    for (var y = 112; y < 126; y++) {
      for (var x = x0; x < x0 + 8; x++) {
        put(x, y, 0);
      }
    }
  }
  final a = TextBlock(
    xyxy: const BBox(93, 68, 225, 86),
    bubbleXyxy: const BBox(50, 20, 250, 140),
    textClass: TextClass.bubble,
    text: 'a',
  );
  final b = TextBlock(
    xyxy: const BBox(248, 110, 306, 128),
    bubbleXyxy: const BBox(210, 65, 350, 175),
    textClass: TextClass.bubble,
    text: 'b',
  );
  return (RgbImage(w, h, data), a, b);
}

void main() {
  test('letters of a bubble left to the network are kept in a touching bubble\'s box', () {
    final (image, a, b) = _page();
    final mask = generateMask(image, [a, b]);
    expect(mask.data[76 * image.width + 219], isNot(0), reason: 'the mask covers the last letter of A');

    final report = InpaintReport();
    final (_, residual, filled) = applyFastBubbleCleanup(image, mask, [a, b], report: report);
    expect(filled, 1, reason: report.notes.join('; '));
    expect(report.notes.first, contains('routed to NN'));
    expect(residual.data[76 * image.width + 219], isNot(0));
    expect(residual.data[118 * image.width + 260], 0, reason: 'B itself is flat-filled');
  });
}
