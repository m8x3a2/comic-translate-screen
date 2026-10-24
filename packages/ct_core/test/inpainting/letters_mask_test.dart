import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// A white bubble with two words of black "letters" on a busy background.
(RgbImage, List<TextBlock>) _page() {
  const w = 300, h = 160;
  final data = Uint8List(w * h * 3);
  void put(int x, int y, int v) => data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, v);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - 150) / 120, dy = (y - 80) / 60;
      final d = dx * dx + dy * dy;
      put(x, y, d <= 1 ? 255 : (d <= 1.08 ? 0 : (x * 7 + y * 13) % 90 + 40));
    }
  }
  for (var x0 = 70; x0 < 230; x0 += 16) {
    for (var y = 70; y < 90; y++) {
      for (var x = x0; x < x0 + 9; x++) {
        put(x, y, 0);
      }
    }
  }
  final block = TextBlock(
    xyxy: const BBox(66, 66, 234, 94),
    bubbleXyxy: const BBox(30, 20, 270, 140),
    textClass: TextClass.bubble,
    text: 'text',
  );
  return (RgbImage(w, h, data), [block]);
}

GrayImage _letters(RgbImage image, bool Function(int x, int y) isLetter) {
  final out = GrayImage.zeros(image.width, image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (isLetter(x, y)) out.data[y * image.width + x] = 255;
    }
  }
  return out;
}

void main() {
  final (image, blocks) = _page();
  bool glyph(int x, int y) => y >= 70 && y < 90 && x >= 70 && x < 230 && (x - 70) % 16 < 9;

  test('without letters the mask is the original one value', () {
    final mask = generateMask(image, blocks);
    expect(mask.data.toSet(), {0, 255});
  });

  test('letters make a two-value mask: letters plus margin for the network, the rest fill only', () {
    final plain = generateMask(image, blocks);
    final mask = generateMask(image, blocks, letters: _letters(image, glyph));
    expect(mask.data.toSet(), {0, maskMarginValue, 255});
    // Letters and the margin of letterMaskMargin px are for the network.
    expect(mask.data[80 * image.width + 70], 255);
    expect(mask.data[80 * image.width + 70 - letterMaskMargin], 255);
    // Farther away, only where the original mask is.
    final far = 80 * image.width + 70 - letterMaskMargin - 2;
    expect(mask.data[far], plain.data[far] != 0 ? maskMarginValue : 0);
    for (var i = 0; i < mask.data.length; i++) {
      if (plain.data[i] != 0) expect(mask.data[i], isNot(0));
    }
  });

  test('a block where the masker found almost nothing keeps the original mask for the network', () {
    final plain = generateMask(image, blocks);
    final mask = generateMask(image, blocks, letters: GrayImage.zeros(image.width, image.height));
    for (var i = 0; i < mask.data.length; i++) {
      expect(mask.data[i], plain.data[i] != 0 ? 255 : 0);
    }
  });

  test('the network repaints the letters, never the fill-only margin', () async {
    final mask = generateMask(image, blocks, letters: _letters(image, glyph));
    // Without a bubble there is no flat fill: everything left goes to the network.
    final noFill = [for (final b in blocks) b.copy()..bubbleXyxy = null];
    const mark = [1, 2, 3];
    final clean = await inpaintPage(image, mask, const InpaintConfig(), (img, m) async {
      final out = img.clone();
      for (var i = 0; i < m.data.length; i++) {
        if (m.data[i] != 0) out.data.setRange(i * 3, i * 3 + 3, mark);
      }
      return out;
    }, blocks: noFill);
    bool marked(int i) => clean.data[i * 3] == 1 && clean.data[i * 3 + 1] == 2 && clean.data[i * 3 + 2] == 3;
    var letters = 0;
    for (var i = 0; i < mask.data.length; i++) {
      if (mask.data[i] == maskMarginValue) expect(marked(i), isFalse);
      if (mask.data[i] == 255 && marked(i)) letters++;
    }
    expect(letters, greaterThan(0));
  });
}
