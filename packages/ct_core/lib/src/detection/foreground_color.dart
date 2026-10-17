/// Text (foreground) colour of a text crop. Port of
/// `modules/detection/font/engine.py`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/py_compat.dart';

/// `extract_foreground_color`: border pixels give the background, Otsu on
/// the colour distance separates text pixels, and a brightness-dependent
/// percentile of those pixels is the text colour. Returns `[r, g, b]` or
/// null when the crop is too small or has no text-like pixels.
List<int>? extractForegroundColor(RgbImage? image) {
  if (image == null) return null;
  final h = image.height, w = image.width;
  if (h < 6 || w < 6) return null;

  final bw = math.max(2, math.min(h, w) ~/ 8);
  if (h <= bw * 2 || w <= bw * 2) return null;

  final data = image.data;
  final border = <List<double>>[[], [], []];
  void addPixel(int x, int y) {
    final o = (y * w + x) * 3;
    border[0].add(data[o].toDouble());
    border[1].add(data[o + 1].toDouble());
    border[2].add(data[o + 2].toDouble());
  }

  // top = work[:bw, bw:-bw], bottom = work[-bw:, bw:-bw],
  // left = work[bw:-bw, :bw], right = work[bw:-bw, -bw:]
  for (var y = 0; y < bw; y++) {
    for (var x = bw; x < w - bw; x++) {
      addPixel(x, y);
    }
  }
  for (var y = h - bw; y < h; y++) {
    for (var x = bw; x < w - bw; x++) {
      addPixel(x, y);
    }
  }
  for (var y = bw; y < h - bw; y++) {
    for (var x = 0; x < bw; x++) {
      addPixel(x, y);
    }
    for (var x = w - bw; x < w; x++) {
      addPixel(x, y);
    }
  }
  if (border[0].isEmpty) return null;
  final bg = [npMedian(border[0]), npMedian(border[1]), npMedian(border[2])];

  final n = w * h;
  final dist = Float64List(n);
  final distU8 = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final dr = data[i * 3] - bg[0];
    final dg = data[i * 3 + 1] - bg[1];
    final db = data[i * 3 + 2] - bg[2];
    final d = math.sqrt(dr * dr + dg * dg + db * db);
    dist[i] = d;
    distU8[i] = d >= 255 ? 255 : d.toInt();
  }
  final otsu = mahotasOtsu(distU8).toDouble();
  final threshold = math.max(otsu, 25.0);

  final text = <List<double>>[[], [], []];
  for (var i = 0; i < n; i++) {
    if (dist[i] > threshold) {
      text[0].add(data[i * 3].toDouble());
      text[1].add(data[i * 3 + 1].toDouble());
      text[2].add(data[i * 3 + 2].toDouble());
    }
  }
  final nText = text[0].length;
  if (nText < 5) return null;
  final textRatio = nText / n;
  final bgLuma = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2];

  List<double> fg;
  if (bgLuma >= 170) {
    fg = [for (final c in text) npPercentile(c, 20)];
  } else if (bgLuma <= 85) {
    fg = [for (final c in text) npPercentile(c, 80)];
  } else {
    fg = [for (final c in text) npMedian(c)];
  }
  var snapped = snapExtremeNeutrals([for (final v in fg) pyRound(v)]);

  final isExtreme = (snapped[0] == 0 && snapped[1] == 0 && snapped[2] == 0) ||
      (snapped[0] == 255 && snapped[1] == 255 && snapped[2] == 255);
  if (!isExtreme && bgLuma <= 85 && textRatio >= 0.45) {
    final luma = [for (var i = 0; i < nText; i++) 0.299 * text[0][i] + 0.587 * text[1][i] + 0.114 * text[2][i]];
    final dominant = npMedian(luma);
    final spread = npPercentile(luma, 90) - npPercentile(luma, 10);
    if (dominant >= 140 && spread >= 30) {
      final dark = [for (final c in text) npPercentile(c, 20)];
      snapped = snapExtremeNeutrals([for (final v in dark) pyRound(v)]);
    }
  }
  return snapped;
}

/// `snap_extreme_neutrals`: achromatic colours become pure black or white.
List<int> snapExtremeNeutrals(List<int> rgb) {
  final r = rgb[0], g = rgb[1], b = rgb[2];
  final luma = 0.299 * r + 0.587 * g + 0.114 * b;
  final chroma = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
  if (chroma < 40) return luma < 128 ? [0, 0, 0] : [255, 255, 255];
  return [r, g, b];
}
