/// Image comparison for `cts compare` and golden checks.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import 'pil.dart';

/// How far two images of the same size are apart.
class ImageDiff {
  const ImageDiff({
    required this.width,
    required this.height,
    required this.psnr,
    required this.maxDiff,
    required this.meanAbsDiff,
    required this.changedFraction,
  });

  final int width;
  final int height;

  /// Peak signal-to-noise ratio in dB; infinite for identical images.
  final double psnr;

  /// Largest per-channel difference (0–255).
  final int maxDiff;

  /// Mean per-channel absolute difference.
  final double meanAbsDiff;

  /// Share of pixels whose largest channel difference exceeds the threshold.
  final double changedFraction;

  bool get identical => maxDiff == 0;

  Map<String, Object?> toJson() => {
        'width': width,
        'height': height,
        'psnr': psnr.isFinite ? double.parse(psnr.toStringAsFixed(3)) : 'inf',
        'max_diff': maxDiff,
        'mean_abs_diff': double.parse(meanAbsDiff.toStringAsFixed(4)),
        'changed_fraction': double.parse(changedFraction.toStringAsFixed(6)),
      };

  @override
  String toString() => 'PSNR ${psnr.isFinite ? '${psnr.toStringAsFixed(2)} dB' : 'inf'}, '
      'max diff $maxDiff, changed ${(changedFraction * 100).toStringAsFixed(3)}%';
}

/// Compares [a] and [b] (same size). A pixel counts as changed when a channel
/// differs by more than [threshold].
ImageDiff compareImages(RgbImage a, RgbImage b, {int threshold = 16}) {
  if (a.width != b.width || a.height != b.height) {
    throw ArgumentError('Sizes differ: ${a.width}x${a.height} vs ${b.width}x${b.height}');
  }
  var sq = 0, abs = 0, maxDiff = 0, changed = 0;
  final da = a.data, db = b.data;
  for (var i = 0; i < da.length; i += 3) {
    var pixelMax = 0;
    for (var c = 0; c < 3; c++) {
      final d = (da[i + c] - db[i + c]).abs();
      sq += d * d;
      abs += d;
      if (d > pixelMax) pixelMax = d;
    }
    if (pixelMax > maxDiff) maxDiff = pixelMax;
    if (pixelMax > threshold) changed++;
  }
  final n = da.length;
  final mse = n == 0 ? 0.0 : sq / n;
  return ImageDiff(
    width: a.width,
    height: a.height,
    psnr: mse == 0 ? double.infinity : 10 * math.log(255 * 255 / mse) / math.ln10,
    maxDiff: maxDiff,
    meanAbsDiff: n == 0 ? 0 : abs / n,
    changedFraction: n == 0 ? 0 : changed / (n ~/ 3),
  );
}

/// A picture of the differences: [a] faded to grey, changed pixels in red.
RgbImage diffImage(RgbImage a, RgbImage b, {int threshold = 16}) {
  final out = Uint8List(a.data.length);
  final da = a.data, db = b.data;
  for (var i = 0; i < da.length; i += 3) {
    var pixelMax = 0;
    for (var c = 0; c < 3; c++) {
      pixelMax = math.max(pixelMax, (da[i + c] - db[i + c]).abs());
    }
    if (pixelMax > threshold) {
      out[i] = 255;
      out[i + 1] = 0;
      out[i + 2] = 0;
    } else {
      final g = 160 + ((da[i] * 299 + da[i + 1] * 587 + da[i + 2] * 114) ~/ 1000) * 95 ~/ 255;
      out[i] = out[i + 1] = out[i + 2] = g;
    }
  }
  return RgbImage(a.width, a.height, out);
}

/// Scales [image] so its longer side is at most [maxSide] (bilinear).
RgbImage fitWithin(RgbImage image, int maxSide) {
  final longest = math.max(image.width, image.height);
  if (longest <= maxSide) return image;
  final scale = maxSide / longest;
  return pilResize(image, math.max(1, (image.width * scale).round()), math.max(1, (image.height * scale).round()),
      filter: PilFilter.bilinear);
}
