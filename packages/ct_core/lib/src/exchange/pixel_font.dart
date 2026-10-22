/// A tiny block font for the labels on exchange sheets (`[01-003]`): only
/// digits, brackets and the dash, drawn without any font engine so the core
/// stays free of `dart:ui`.
library;

import '../image/raster.dart';

const _glyphs = {
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '[': ['01110', '01000', '01000', '01000', '01000', '01000', '01110'],
  ']': ['01110', '00010', '00010', '00010', '00010', '00010', '01110'],
  '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

const _glyphW = 5, _glyphH = 7, _gap = 1;

/// Size of [text] drawn with cells of [scale] pixels.
(int, int) pixelTextSize(String text, int scale) => ((text.length * (_glyphW + _gap) - _gap) * scale, _glyphH * scale);

/// Draws [text] at ([x], [y]) (top left) in [color]; characters the font
/// does not have are left blank, pixels outside the image are skipped.
void drawPixelText(RgbImage image, String text, int x, int y, int scale, List<int> color) {
  for (final (n, ch) in text.split('').indexed) {
    final rows = _glyphs[ch];
    if (rows == null) continue;
    final gx = x + n * (_glyphW + _gap) * scale;
    for (var r = 0; r < _glyphH; r++) {
      for (var c = 0; c < _glyphW; c++) {
        if (rows[r][c] == '1') fillRect(image, gx + c * scale, y + r * scale, scale, scale, color);
      }
    }
  }
}

/// Fills a rectangle (clipped to the image).
void fillRect(RgbImage image, int x, int y, int w, int h, List<int> color) {
  final x1 = x.clamp(0, image.width), x2 = (x + w).clamp(0, image.width);
  final y1 = y.clamp(0, image.height), y2 = (y + h).clamp(0, image.height);
  final d = image.data;
  for (var yy = y1; yy < y2; yy++) {
    for (var xx = x1; xx < x2; xx++) {
      final o = (yy * image.width + xx) * 3;
      d[o] = color[0];
      d[o + 1] = color[1];
      d[o + 2] = color[2];
    }
  }
}

/// A rectangle outline [t] pixels thick.
void strokeRect(RgbImage image, int x, int y, int w, int h, int t, List<int> color) {
  fillRect(image, x, y, w, t, color);
  fillRect(image, x, y + h - t, w, t, color);
  fillRect(image, x, y, t, h, color);
  fillRect(image, x + w - t, y, t, h, color);
}

/// Copies [src] into [dst] with its top left corner at ([x], [y]).
void blit(RgbImage dst, RgbImage src, int x, int y) {
  for (var row = 0; row < src.height; row++) {
    final yy = y + row;
    if (yy < 0 || yy >= dst.height) continue;
    final x1 = x.clamp(0, dst.width), x2 = (x + src.width).clamp(0, dst.width);
    if (x2 <= x1) continue;
    final from = (row * src.width + (x1 - x)) * 3;
    dst.data.setRange((yy * dst.width + x1) * 3, (yy * dst.width + x2) * 3, src.data, from);
  }
}
