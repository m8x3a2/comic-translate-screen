/// Exact ports of the Pillow operations the original pipeline relies on.
library;

import 'dart:typed_data';

import '../image/raster.dart';

/// `Image.convert("L")` for RGB (ITU-R 601-2 luma, Pillow fixed point).
GrayImage pilToGray(RgbImage image) {
  final src = image.data;
  final out = Uint8List(image.width * image.height);
  for (var i = 0, j = 0; j < out.length; i += 3, j++) {
    out[j] = (src[i] * 19595 + src[i + 1] * 38470 + src[i + 2] * 7471 + 0x8000) >> 16;
  }
  return GrayImage(image.width, image.height, out);
}

const _precisionBits = 32 - 8 - 2;

double _bicubic(double x) {
  const a = -0.5;
  if (x < 0) x = -x;
  if (x < 1.0) return ((a + 2.0) * x - (a + 3.0)) * x * x + 1;
  if (x < 2.0) return (((x - 5) * x + 8) * x - 4) * a;
  return 0.0;
}

class _Coeffs {
  _Coeffs(this.ksize, this.bounds, this.kk);

  final int ksize;

  /// `[xmin, count]` per output pixel.
  final Int32List bounds;

  /// Fixed-point coefficients, `ksize` per output pixel.
  final Int32List kk;
}

/// Pillow `precompute_coeffs` + `normalize_coeffs_8bpc` (Resample.c).
_Coeffs _precompute(int inSize, double in0, double in1, int outSize) {
  const support0 = 2.0; // bicubic
  final scale = (in1 - in0) / outSize;
  final filterscale = scale < 1.0 ? 1.0 : scale;
  final support = support0 * filterscale;
  final ksize = support.ceil() * 2 + 1;
  final bounds = Int32List(outSize * 2);
  final pre = Float64List(outSize * ksize);
  for (var xx = 0; xx < outSize; xx++) {
    final center = in0 + (xx + 0.5) * scale;
    var ww = 0.0;
    final ss = 1.0 / filterscale;
    var xmin = (center - support + 0.5).toInt();
    if (xmin < 0) xmin = 0;
    var xmax = (center + support + 0.5).toInt();
    if (xmax > inSize) xmax = inSize;
    xmax -= xmin;
    final base = xx * ksize;
    for (var x = 0; x < xmax; x++) {
      final w = _bicubic((x + xmin - center + 0.5) * ss);
      pre[base + x] = w;
      ww += w;
    }
    for (var x = 0; x < xmax; x++) {
      if (ww != 0.0) pre[base + x] /= ww;
    }
    bounds[xx * 2] = xmin;
    bounds[xx * 2 + 1] = xmax;
  }
  final kk = Int32List(pre.length);
  const one = 1 << _precisionBits;
  for (var i = 0; i < pre.length; i++) {
    final v = pre[i];
    kk[i] = v < 0 ? (-0.5 + v * one).toInt() : (0.5 + v * one).toInt();
  }
  return _Coeffs(ksize, bounds, kk);
}

int _clip8(int v) {
  if (v >= (1 << _precisionBits << 8)) return 255;
  if (v <= 0) return 0;
  return v >> _precisionBits;
}

/// `Image.resize((width, height))` with Pillow's default bicubic filter for
/// RGB images (two-pass convolution with antialiasing when downscaling).
///
/// Follows `ImagingResampleInner` of Pillow 13 including its pass order:
/// when the height shrinks more than twice as much as the width, the
/// vertical pass runs first. The order changes intermediate rounding, so it
/// matters for bit-exact results.
RgbImage pilResizeBicubic(RgbImage image, int width, int height) {
  final inW = image.width, inH = image.height;
  final needH = width != inW;
  final needV = height != inH;
  if (!needH && !needV) return image.clone();

  final horizontalFirst = !((inH - height) > 0 && (inH - height) > (inW - width) * 2);
  final vert = _precompute(inH, 0, inH.toDouble(), height);
  final horiz = _precompute(inW, 0, inW.toDouble(), width);

  if (horizontalFirst) {
    var src = image.data;
    var srcW = inW, srcH = inH;
    final vBounds = Int32List.fromList(vert.bounds);
    if (needH) {
      final yFirst = vBounds[0];
      final yLast = vBounds[height * 2 - 2] + vBounds[height * 2 - 1];
      for (var i = 0; i < height; i++) {
        vBounds[i * 2] -= yFirst;
      }
      src = _horizontalPass(src, inW, yFirst, yLast - yFirst, width, horiz);
      srcW = width;
      srcH = yLast - yFirst;
    }
    if (!needV) return RgbImage(srcW, srcH, src);
    return RgbImage(srcW, height, _verticalPass(src, srcW, height, vBounds, vert));
  }

  var src = image.data;
  var srcW = inW;
  if (needV) {
    src = _verticalPass(src, inW, height, vert.bounds, vert);
  }
  if (needH) {
    src = _horizontalPass(src, srcW, 0, height, width, horiz);
    srcW = width;
  }
  return RgbImage(srcW, height, src);
}

Uint8List _horizontalPass(Uint8List src, int srcW, int rowOffset, int rows, int outW, _Coeffs c) {
  final out = Uint8List(outW * rows * 3);
  const half = 1 << (_precisionBits - 1);
  for (var yy = 0; yy < rows; yy++) {
    final srcRow = (yy + rowOffset) * srcW * 3;
    final dstRow = yy * outW * 3;
    for (var xx = 0; xx < outW; xx++) {
      final xmin = c.bounds[xx * 2];
      final xmax = c.bounds[xx * 2 + 1];
      final kb = xx * c.ksize;
      var s0 = half, s1 = half, s2 = half;
      for (var x = 0; x < xmax; x++) {
        final k = c.kk[kb + x];
        final p = srcRow + (x + xmin) * 3;
        s0 += src[p] * k;
        s1 += src[p + 1] * k;
        s2 += src[p + 2] * k;
      }
      final d = dstRow + xx * 3;
      out[d] = _clip8(s0);
      out[d + 1] = _clip8(s1);
      out[d + 2] = _clip8(s2);
    }
  }
  return out;
}

Uint8List _verticalPass(Uint8List src, int srcW, int outH, Int32List bounds, _Coeffs c) {
  final out = Uint8List(srcW * outH * 3);
  const half = 1 << (_precisionBits - 1);
  for (var yy = 0; yy < outH; yy++) {
    final ymin = bounds[yy * 2];
    final ymax = bounds[yy * 2 + 1];
    final kb = yy * c.ksize;
    final dstRow = yy * srcW * 3;
    for (var xx = 0; xx < srcW; xx++) {
      var s0 = half, s1 = half, s2 = half;
      for (var y = 0; y < ymax; y++) {
        final k = c.kk[kb + y];
        final p = ((y + ymin) * srcW + xx) * 3;
        s0 += src[p] * k;
        s1 += src[p + 1] * k;
        s2 += src[p + 2] * k;
      }
      final d = dstRow + xx * 3;
      out[d] = _clip8(s0);
      out[d + 1] = _clip8(s1);
      out[d + 2] = _clip8(s2);
    }
  }
  return out;
}
