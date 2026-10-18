/// Model-independent part of the inpainters: high-resolution strategies,
/// padding and blending. Port of `InpaintModel.__call__` and helpers from
/// `modules/inpainting/base.py` and `modules/utils/inpainting.py`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/contours.dart';
import '../imaging/pil.dart';
import '../model/geometry.dart';
import '../plugins/engines.dart';

/// An inpainting network: fills the masked pixels of [image] (mask 0/255,
/// same size). Image sizes passed in are already padded to the model's
/// modulo.
typedef InpaintForward = RgbImage Function(RgbImage image, GrayImage mask);

/// `InpaintModel` without the network: [forward] runs the model.
class InpaintModel {
  InpaintModel(this.forward, {this.padMod = 8, this.minSize});

  final InpaintForward forward;
  final int padMod;
  final int? minSize;

  /// `__call__`: inpaints [image] where [mask] is set, following the
  /// high-resolution strategy of [config]. Pixels outside the mask keep their
  /// original values.
  RgbImage call(RgbImage image, GrayImage mask, InpaintConfig config) {
    final longSide = math.max(image.width, image.height);
    switch (config.strategy) {
      case HdStrategy.crop:
        // The original compares max(image.shape), which includes the channel
        // count; it never exceeds the sides of a real page.
        if (math.max(longSide, 3) > config.cropTriggerSize) {
          final result = image.clone();
          for (final box in boxesFromMask(mask)) {
            final (crop, (l, t, r, b)) = _runBox(image, mask, box, config);
            for (var y = t; y < b; y++) {
              result.data.setRange(result.offset(l, y), result.offset(r, y), crop.data, crop.offset(0, y - t));
            }
          }
          return result;
        }
      case HdStrategy.resize:
        if (math.max(longSide, 3) > config.resizeLimit) {
          final small = resizeMaxSize(image, config.resizeLimit);
          final smallMask = resizeMaxSizeGray(mask, config.resizeLimit);
          final blended = _padForward(small, smallMask);
          // ensure_uint8 (clip + truncate), then Pillow bicubic back up.
          final up = pilResize(_truncate(blended, small.width, small.height), image.width, image.height);
          for (var i = 0; i < mask.data.length; i++) {
            if (mask.data[i] < 127) {
              up.data.setRange(i * 3, i * 3 + 3, image.data, i * 3);
            }
          }
          return up;
        }
      case HdStrategy.original:
        break;
    }
    return _truncate(_padForward(image, mask), image.width, image.height);
  }

  /// `_pad_forward`: pad, run, crop, blend with the original by the mask.
  /// Returns float values like numpy (truncated by the caller).
  Float64List _padForward(RgbImage image, GrayImage mask) {
    final w = image.width, h = image.height;
    final padded = padToModulo(image, padMod, minSize: minSize);
    final paddedMask = padGrayToModulo(mask, padMod, minSize: minSize);
    final result = forward(padded, paddedMask);
    final out = Float64List(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final m = mask.data[y * w + x] / 255;
        final r = result.offset(x, y), o = (y * w + x) * 3;
        for (var c = 0; c < 3; c++) {
          out[o + c] = result.data[r + c] * m + image.data[o + c] * (1 - m);
        }
      }
    }
    return out;
  }

  /// `_crop_box` + `_run_box`.
  (RgbImage, (int, int, int, int)) _runBox(RgbImage image, GrayImage mask, (int, int, int, int) box, InpaintConfig config) {
    final (x1, y1, x2, y2) = box;
    final boxH = y2 - y1, boxW = x2 - x1;
    final cx = (x1 + x2) ~/ 2, cy = (y1 + y2) ~/ 2;
    final imgH = image.height, imgW = image.width;
    final w = boxW + config.cropMargin * 2, h = boxH + config.cropMargin * 2;
    final l0 = cx - w ~/ 2, r0 = cx + w ~/ 2, t0 = cy - h ~/ 2, b0 = cy + h ~/ 2;
    var l = math.max(l0, 0), r = math.min(r0, imgW), t = math.max(t0, 0), b = math.min(b0, imgH);
    // More context when the crop touches the image edge.
    if (l0 < 0) r += -l0;
    if (r0 > imgW) l -= r0 - imgW;
    if (t0 < 0) b += -t0;
    if (b0 > imgH) t -= b0 - imgH;
    l = math.max(l, 0);
    r = math.min(r, imgW);
    t = math.max(t, 0);
    b = math.min(b, imgH);
    final cropImg = image.crop(BBox(l, t, r, b));
    final cropMask = mask.crop(BBox(l, t, r, b));
    final blended = _padForward(cropImg, cropMask);
    return (_truncate(blended, cropImg.width, cropImg.height), (l, t, r, b));
  }
}

/// numpy float → uint8 assignment / `convert_scale_abs`: clip and truncate.
RgbImage _truncate(Float64List values, int w, int h) {
  final out = Uint8List(values.length);
  for (var i = 0; i < values.length; i++) {
    final v = values[i].abs();
    out[i] = v >= 255 ? 255 : v.toInt();
  }
  return RgbImage(w, h, out);
}

/// `ceil_modulo`.
int ceilModulo(int x, int mod) => x % mod == 0 ? x : (x ~/ mod + 1) * mod;

(int, int) _paddedSize(int w, int h, int mod, int? minSize) {
  var ow = ceilModulo(w, mod), oh = ceilModulo(h, mod);
  if (minSize != null) {
    ow = math.max(minSize, ow);
    oh = math.max(minSize, oh);
  }
  return (ow, oh);
}

/// `np.pad(..., mode="symmetric")` index for a coordinate past the end.
int _symmetric(int i, int n) {
  if (n == 1) return 0;
  final period = 2 * n;
  var k = i % period;
  if (k >= n) k = period - 1 - k;
  return k;
}

/// `pad_img_to_modulo`: pads right and bottom by mirroring (numpy
/// "symmetric") to a multiple of [mod], at least [minSize].
RgbImage padToModulo(RgbImage image, int mod, {int? minSize}) {
  final (ow, oh) = _paddedSize(image.width, image.height, mod, minSize);
  if (ow == image.width && oh == image.height) return image;
  final out = Uint8List(ow * oh * 3);
  for (var y = 0; y < oh; y++) {
    final sy = _symmetric(y, image.height);
    for (var x = 0; x < ow; x++) {
      final s = image.offset(_symmetric(x, image.width), sy);
      final d = (y * ow + x) * 3;
      out[d] = image.data[s];
      out[d + 1] = image.data[s + 1];
      out[d + 2] = image.data[s + 2];
    }
  }
  return RgbImage(ow, oh, out);
}

GrayImage padGrayToModulo(GrayImage image, int mod, {int? minSize}) {
  final (ow, oh) = _paddedSize(image.width, image.height, mod, minSize);
  if (ow == image.width && oh == image.height) return image;
  final out = Uint8List(ow * oh);
  for (var y = 0; y < oh; y++) {
    final sy = _symmetric(y, image.height);
    for (var x = 0; x < ow; x++) {
      out[y * ow + x] = image.data[sy * image.width + _symmetric(x, image.width)];
    }
  }
  return GrayImage(ow, oh, out);
}

(int, int) _maxSize(int w, int h, int limit) {
  final ratio = limit / math.max(h, w);
  return ((w * ratio + 0.5).toInt(), (h * ratio + 0.5).toInt());
}

/// `resize_max_size`: shrinks the longer side to [sizeLimit] (bicubic).
RgbImage resizeMaxSize(RgbImage image, int sizeLimit) {
  if (math.max(image.width, image.height) <= sizeLimit) return image;
  final (w, h) = _maxSize(image.width, image.height, sizeLimit);
  return pilResize(image, w, h);
}

GrayImage resizeMaxSizeGray(GrayImage image, int sizeLimit) {
  if (math.max(image.width, image.height) <= sizeLimit) return image;
  final (w, h) = _maxSize(image.width, image.height, sizeLimit);
  return pilResizeGray(image, w, h);
}

/// `boxes_from_mask`: bounding boxes `(x1, y1, x2, y2)` of the mask's
/// contours (pixels above 127).
List<(int, int, int, int)> boxesFromMask(GrayImage mask) => [
      for (final c in findContours(mask, threshold: 127))
        () {
          final (x, y, w, h) = boundingRect(c);
          return (
            (x).clamp(0, mask.width),
            (y).clamp(0, mask.height),
            (x + w).clamp(0, mask.width),
            (y + h).clamp(0, mask.height),
          );
        }(),
    ];
