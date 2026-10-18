/// Exact ports of the Pillow operations the original pipeline relies on.
library;

import 'dart:math' as math;
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

double _sinc(double x) {
  if (x == 0.0) return 1.0;
  x = x * math.pi;
  return math.sin(x) / x;
}

double _bilinear(double x) {
  if (x < 0.0) x = -x;
  if (x < 1.0) return 1.0 - x;
  return 0.0;
}

double _lanczos(double x) {
  if (-3.0 <= x && x < 3.0) return _sinc(x) * _sinc(x / 3);
  return 0.0;
}

/// Pillow resampling filters used by the original.
enum PilFilter {
  /// `Image.Resampling.BICUBIC` (the default of `Image.resize`).
  bicubic(_bicubic, 2.0),

  /// `Image.Resampling.BILINEAR`.
  bilinear(_bilinear, 1.0),

  /// `Image.Resampling.LANCZOS` (the default of `imkit.resize`).
  lanczos(_lanczos, 3.0);

  const PilFilter(this.fn, this.support);

  final double Function(double) fn;
  final double support;
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
_Coeffs _precompute(int inSize, double in0, double in1, int outSize, PilFilter filter) {
  final support0 = filter.support;
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
      final w = filter.fn((x + xmin - center + 0.5) * ss);
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

/// `Image.resize((width, height))` with Pillow's default bicubic filter.
RgbImage pilResizeBicubic(RgbImage image, int width, int height) => pilResize(image, width, height);

/// `Image.resize((width, height), resample=filter)` for RGB images (two-pass
/// convolution with antialiasing when downscaling).
///
/// Follows `ImagingResampleInner` of Pillow 13 including its pass order:
/// when the height shrinks more than twice as much as the width, the
/// vertical pass runs first. The order changes intermediate rounding, so it
/// matters for bit-exact results.
RgbImage pilResize(RgbImage image, int width, int height, {PilFilter filter = PilFilter.bicubic}) {
  if (width == image.width && height == image.height) return image.clone();
  return RgbImage(width, height, _resample(image.data, image.width, image.height, 3, width, height, filter));
}

/// `Image.resize` for an 8-bit single-channel ("L") image.
GrayImage pilResizeGray(GrayImage image, int width, int height, {PilFilter filter = PilFilter.bicubic}) {
  if (width == image.width && height == image.height) return image.clone();
  return GrayImage(width, height, _resample(image.data, image.width, image.height, 1, width, height, filter));
}

Uint8List _resample(Uint8List data, int inW, int inH, int ch, int width, int height, PilFilter filter) {
  final needH = width != inW;
  final needV = height != inH;
  final horizontalFirst = !((inH - height) > 0 && (inH - height) > (inW - width) * 2);
  final vert = _precompute(inH, 0, inH.toDouble(), height, filter);
  final horiz = _precompute(inW, 0, inW.toDouble(), width, filter);

  if (horizontalFirst) {
    var src = data;
    var srcW = inW;
    final vBounds = Int32List.fromList(vert.bounds);
    if (needH) {
      final yFirst = vBounds[0];
      final yLast = vBounds[height * 2 - 2] + vBounds[height * 2 - 1];
      for (var i = 0; i < height; i++) {
        vBounds[i * 2] -= yFirst;
      }
      src = _horizontalPass(src, inW, yFirst, yLast - yFirst, width, horiz, ch);
      srcW = width;
    }
    if (!needV) return src;
    return _verticalPass(src, srcW, height, vBounds, vert, ch);
  }

  var src = data;
  var srcW = inW;
  if (needV) src = _verticalPass(src, inW, height, vert.bounds, vert, ch);
  if (needH) {
    src = _horizontalPass(src, srcW, 0, height, width, horiz, ch);
    srcW = width;
  }
  return src;
}

Uint8List _horizontalPass(Uint8List src, int srcW, int rowOffset, int rows, int outW, _Coeffs c, int ch) {
  final out = Uint8List(outW * rows * ch);
  const half = 1 << (_precisionBits - 1);
  final s = List<int>.filled(ch, 0);
  for (var yy = 0; yy < rows; yy++) {
    final srcRow = (yy + rowOffset) * srcW * ch;
    final dstRow = yy * outW * ch;
    for (var xx = 0; xx < outW; xx++) {
      final xmin = c.bounds[xx * 2];
      final xmax = c.bounds[xx * 2 + 1];
      final kb = xx * c.ksize;
      s.fillRange(0, ch, half);
      for (var x = 0; x < xmax; x++) {
        final k = c.kk[kb + x];
        final p = srcRow + (x + xmin) * ch;
        for (var b = 0; b < ch; b++) {
          s[b] += src[p + b] * k;
        }
      }
      final d = dstRow + xx * ch;
      for (var b = 0; b < ch; b++) {
        out[d + b] = _clip8(s[b]);
      }
    }
  }
  return out;
}

Uint8List _verticalPass(Uint8List src, int srcW, int outH, Int32List bounds, _Coeffs c, int ch) {
  final out = Uint8List(srcW * outH * ch);
  const half = 1 << (_precisionBits - 1);
  final s = List<int>.filled(ch, 0);
  for (var yy = 0; yy < outH; yy++) {
    final ymin = bounds[yy * 2];
    final ymax = bounds[yy * 2 + 1];
    final kb = yy * c.ksize;
    final dstRow = yy * srcW * ch;
    for (var xx = 0; xx < srcW; xx++) {
      s.fillRange(0, ch, half);
      for (var y = 0; y < ymax; y++) {
        final k = c.kk[kb + y];
        final p = ((y + ymin) * srcW + xx) * ch;
        for (var b = 0; b < ch; b++) {
          s[b] += src[p + b] * k;
        }
      }
      final d = dstRow + xx * ch;
      for (var b = 0; b < ch; b++) {
        out[d + b] = _clip8(s[b]);
      }
    }
  }
  return out;
}

final _f32 = Float32List(1);

double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// `_gaussian_blur_radius` (BoxBlur.c) in C `float` arithmetic.
double _gaussianBlurRadius(double radius, int passes) {
  final r = _fround(radius);
  final sigma2 = _fround(_fround(r * r) / passes);
  final bigL = _fround(math.sqrt(12.0 * sigma2 + 1.0));
  final l = _fround(((bigL - 1.0) / 2.0).floorToDouble());
  var a = _fround(_fround(2 * l + 1) * _fround(_fround(l * _fround(l + 1)) - _fround(3 * sigma2)));
  a = _fround(a / _fround(6 * _fround(sigma2 - _fround(_fround(l + 1) * _fround(l + 1)))));
  return _fround(l + a);
}

/// `ImagingHorizontalBoxBlur` with `ImagingLineBoxBlur8` on every row.
void _boxBlurRows(Uint8List data, int w, int h, double floatRadius) {
  final radius = floatRadius.toInt();
  // C: (UINT32)(1 << 24) / (float) is a float division.
  final ww = _fround(16777216 / _fround(floatRadius * 2 + 1)).toInt();
  final fw = (16777216 - (radius * 2 + 1) * ww) ~/ 2;
  final edgeA = math.min(radius + 1, w);
  final edgeB = math.max(w - radius - 1, 0);
  final lastx = w - 1;
  final line = Uint8List(w);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    int px(int i) => data[row + i];
    var acc = px(0) * (radius + 1);
    for (var x = 0; x < edgeA - 1; x++) {
      acc += px(x);
    }
    acc += px(lastx) * (radius - edgeA + 1);
    void save(int x, int left, int right) {
      final bulk = (acc * ww + (px(left) + px(right)) * fw) & 0xFFFFFFFF;
      line[x] = ((bulk + (1 << 23)) >> 24) & 0xFF;
    }

    if (edgeA <= edgeB) {
      for (var x = 0; x < edgeA; x++) {
        acc += px(x + radius) - px(0);
        save(x, 0, x + radius + 1);
      }
      for (var x = edgeA; x < edgeB; x++) {
        acc += px(x + radius) - px(x - radius - 1);
        save(x, x - radius - 1, x + radius + 1);
      }
      for (var x = edgeB; x <= lastx; x++) {
        acc += px(lastx) - px(x - radius - 1);
        save(x, x - radius - 1, lastx);
      }
    } else {
      for (var x = 0; x < edgeB; x++) {
        acc += px(x + radius) - px(0);
        save(x, 0, x + radius + 1);
      }
      for (var x = edgeB; x < edgeA; x++) {
        acc += px(lastx) - px(0);
        save(x, 0, lastx);
      }
      for (var x = edgeA; x <= lastx; x++) {
        acc += px(lastx) - px(x - radius - 1);
        save(x, x - radius - 1, lastx);
      }
    }
    data.setRange(row, row + w, line);
  }
}

Uint8List _transpose(Uint8List data, int w, int h) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out[x * h + y] = data[y * w + x];
    }
  }
  return out;
}

/// `image.filter(ImageFilter.GaussianBlur(radius))` for an "L" image
/// (Pillow: three box-blur passes per direction).
GrayImage pilGaussianBlurGray(GrayImage image, double radius, {int passes = 3}) {
  final w = image.width, h = image.height;
  if (w == 0 || h == 0 || radius == 0) return image.clone();
  final r = _gaussianBlurRadius(radius, passes);
  final data = Uint8List.fromList(image.data);
  if (r == 0) return GrayImage(w, h, data);
  for (var i = 0; i < passes; i++) {
    _boxBlurRows(data, w, h, r);
  }
  final t = _transpose(data, w, h);
  for (var i = 0; i < passes; i++) {
    _boxBlurRows(t, h, w, r);
  }
  return GrayImage(w, h, _transpose(t, h, w));
}

int _floorC(double v) => v < 0.0 ? v.floor() : v.toInt();

double _cubic(double v1, double v2, double v3, double v4, double d) {
  final p1 = v2;
  final p2 = -v1 + v3;
  final p3 = 2 * (v1 - v2) + v3 - v4;
  final p4 = -v1 + v2 - v3 + v4;
  return p1 + d * (p2 + d * (p3 + d * p4));
}

/// `Image.transform(size, Transform.PERSPECTIVE, coeffs, Resampling.BICUBIC)`
/// for RGB images (Geometry.c: `perspective_transform` + `bicubic_filter32RGB`);
/// pixels mapped outside the source are black.
RgbImage pilPerspectiveBicubic(RgbImage image, int width, int height, List<double> a) {
  final out = RgbImage(width, height, Uint8List(width * height * 3));
  final xsize = image.width, ysize = image.height;
  final src = image.data;
  int xclip(int x) => x < 0 ? 0 : (x < xsize ? x : xsize - 1);
  int yclip(int y) => y < 0 ? 0 : (y < ysize ? y : ysize - 1);
  final [a0, a1, a2, a3, a4, a5, a6, a7] = a;
  final xs = List<int>.filled(4, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final xi = x + 0.5, yi = y + 0.5;
      var xin = (a0 * xi + a1 * yi + a2) / (a6 * xi + a7 * yi + 1);
      var yin = (a3 * xi + a4 * yi + a5) / (a6 * xi + a7 * yi + 1);
      if (xin < 0.0 || xin >= xsize || yin < 0.0 || yin >= ysize) continue;
      xin -= 0.5;
      yin -= 0.5;
      var ix = _floorC(xin), iy = _floorC(yin);
      final dx = xin - ix, dy = yin - iy;
      ix--;
      iy--;
      for (var k = 0; k < 4; k++) {
        xs[k] = xclip(ix + k) * 3;
      }
      final o = (y * width + x) * 3;
      for (var b = 0; b < 3; b++) {
        double row(int yy) {
          final r = yy * xsize * 3 + b;
          return _cubic(src[r + xs[0]].toDouble(), src[r + xs[1]].toDouble(), src[r + xs[2]].toDouble(),
              src[r + xs[3]].toDouble(), dx);
        }

        final v1 = row(yclip(iy));
        final v2 = (iy + 1 >= 0 && iy + 1 < ysize) ? row(iy + 1) : v1;
        final v3 = (iy + 2 >= 0 && iy + 2 < ysize) ? row(iy + 2) : v2;
        final v4 = (iy + 3 >= 0 && iy + 3 < ysize) ? row(iy + 3) : v3;
        final v = _cubic(v1, v2, v3, v4, dy);
        out.data[o + b] = v <= 0.0 ? 0 : (v >= 255.0 ? 255 : v.toInt());
      }
    }
  }
  return out;
}
