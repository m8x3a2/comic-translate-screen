/// Letters found by their colour (new in this project): coloured text over
/// a drawing, where the text masker sees the letters on plain background
/// but misses them over hatching and screentone.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../model/geometry.dart';

/// Chroma (max − min of r, g, b) from which a letter pixel counts as coloured.
const _colouredChroma = 50;

/// How far a pixel's hue may be from the letters' hue, in degrees.
const _hueTolerance = 22.0;

/// The pixels of [box] that have the colour of the letters [letters] found
/// there, as 0/255 of the box's size, or null when the letters are not of
/// one clear colour (black, white, grey or mixed), too few of them were
/// found, or the drawing around the box has that colour too.
///
/// Only the hue is compared, so letters thinned over white (pink for red)
/// and darkened over black ink (dark red) are both taken; black, white and
/// grey drawing never is.
GrayImage? colourLetters(RgbImage image, GrayImage letters, BBox box) {
  final w = image.width, h = image.height, data = image.data;
  final x1 = math.max(0, box.x1), y1 = math.max(0, box.y1);
  final x2 = math.min(w, box.x2), y2 = math.min(h, box.y2);
  if (x2 - x1 < 4 || y2 - y1 < 4) return null;

  // The letters' colour: the found letter pixels that are ink (dark or
  // coloured); most of the ink must be coloured, of one hue.
  var ink = 0, coloured = 0;
  var sumX = 0.0, sumY = 0.0;
  final chromas = <int>[];
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      if (letters.data[y * w + x] == 0) continue;
      final o = (y * w + x) * 3;
      final r = data[o], g = data[o + 1], b = data[o + 2];
      final c = _chroma(r, g, b);
      if (c >= _colouredChroma) {
        ink++;
        coloured++;
        final hue = _hue(r, g, b) * math.pi / 180;
        sumX += c * math.cos(hue);
        sumY += c * math.sin(hue);
        chromas.add(c);
      } else if (0.299 * r + 0.587 * g + 0.114 * b < 110) {
        ink++;
      }
    }
  }
  if (coloured < 120 || coloured < 0.6 * ink) return null;
  final hue = (math.atan2(sumY, sumX) * 180 / math.pi + 360) % 360;
  // One hue: the chroma-weighted mean is long compared with the chroma.
  chromas.sort();
  final total = chromas.fold(0, (s, c) => s + c);
  if (math.sqrt(sumX * sumX + sumY * sumY) < 0.85 * total) return null;
  final minChroma = math.max(30, chromas[chromas.length ~/ 2] * 0.3);

  bool matches(int i) {
    final o = i * 3;
    final r = data[o], g = data[o + 1], b = data[o + 2];
    if (_chroma(r, g, b) < minChroma) return false;
    final d = (_hue(r, g, b) - hue).abs();
    return math.min(d, 360 - d) <= _hueTolerance;
  }

  // The drawing just around the box must not have that colour: else the
  // colour would take the drawing (a red cloak next to red text).
  final ring = math.max(16, math.min(64, math.max(x2 - x1, y2 - y1) ~/ 10));
  final rx1 = math.max(0, x1 - ring), ry1 = math.max(0, y1 - ring);
  final rx2 = math.min(w, x2 + ring), ry2 = math.min(h, y2 + ring);
  var around = 0, aroundMatching = 0;
  for (var y = ry1; y < ry2; y++) {
    for (var x = rx1; x < rx2; x++) {
      if (x >= x1 && x < x2 && y >= y1 && y < y2) continue;
      around++;
      if (matches(y * w + x)) aroundMatching++;
    }
  }
  if (around > 0 && aroundMatching > 0.02 * around) return null;

  final bw = x2 - x1, bh = y2 - y1;
  final out = Uint8List(bw * bh);
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      if (matches(y * w + x)) out[(y - y1) * bw + x - x1] = 255;
    }
  }
  // Single specks are noise of the picture (JPEG colour fringes).
  final cc = connectedComponentsWithStats(GrayImage(bw, bh, out), connectivity: 8);
  for (var i = 0; i < out.length; i++) {
    final l = cc.labels[i];
    if (l != 0 && cc.stats[l].area < 4) out[i] = 0;
  }
  return GrayImage(bw, bh, out);
}

int _chroma(int r, int g, int b) => math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));

/// HSV hue in degrees, 0..360.
double _hue(int r, int g, int b) {
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  final c = mx - mn;
  if (c == 0) return 0;
  double h;
  if (mx == r) {
    h = ((g - b) / c) % 6;
  } else if (mx == g) {
    h = (b - r) / c + 2;
  } else {
    h = (r - g) / c + 4;
  }
  return (h * 60 + 360) % 360;
}
