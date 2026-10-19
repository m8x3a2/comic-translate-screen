/// Enlarging a cleaned page before the translation is drawn on it. Not in
/// the original: text drawn on a small page (screenshots, low-resolution
/// scans) gets only a few pixels per letter and is hard to read once the
/// result is viewed larger or printed. Letters drawn on an enlarged page are
/// sharp whatever enlarged the picture; the method only affects the artwork.
library;

import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../imaging/py_compat.dart';
import '../model/text_block.dart';
import '../ocr/reading_scale.dart';

enum UpscaleMode {
  /// Enlarge only pages with small text (see [autoUpscaleFactor]).
  auto,
  off,
  x2,
  x3,
  x4,

  /// Enlarge narrower pages to [UpscaleSettings.targetWidth].
  width,
}

/// How the picture is enlarged. Neural upscalers ("good", "best") are planned
/// for stage 2.
enum UpscaleMethod {
  /// Lanczos interpolation, no model.
  fast,
}

class UpscaleSettings {
  const UpscaleSettings({this.mode = UpscaleMode.auto, this.targetWidth = 1080, this.method = UpscaleMethod.fast});

  final UpscaleMode mode;
  final int targetWidth;
  final UpscaleMethod method;

  UpscaleSettings copyWith({UpscaleMode? mode, int? targetWidth, UpscaleMethod? method}) => UpscaleSettings(
        mode: mode ?? this.mode,
        targetWidth: targetWidth ?? this.targetWidth,
        method: method ?? this.method,
      );

  Map<String, Object?> toJson() => {'mode': mode.name, 'target_width': targetWidth, 'method': method.name};

  factory UpscaleSettings.fromJson(Map<String, Object?> json) {
    const d = UpscaleSettings();
    final width = json['target_width'];
    return UpscaleSettings(
      mode: UpscaleMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => d.mode),
      targetWidth: width is num && width >= 64 ? width.toInt() : d.targetWidth,
      method: UpscaleMethod.values.firstWhere((m) => m.name == json['method'], orElse: () => d.method),
    );
  }
}

/// Source text lines thinner than this (pixels) count as small.
const upscaleSmallLinePx = 20.0;

/// Small lines are enlarged to about this thickness.
const upscaleTargetLinePx = 32.0;
const upscaleMaxFactor = 4.0;

/// The auto mode skips gains below this.
const upscaleMinGain = 1.25;

/// Upper bound for the enlarged page (pixels), to keep memory in check.
const upscaleMaxPixels = 40000000;

/// Caps [factor] by [upscaleMaxFactor] and [upscaleMaxPixels]; 1 when there
/// is nothing to gain.
double limitUpscaleFactor(double factor, int width, int height) {
  var f = math.min(factor, upscaleMaxFactor);
  f = math.min(f, math.sqrt(upscaleMaxPixels / (width * height)));
  return f > 1.0 ? f : 1.0;
}

/// Auto mode: from the smaller source lines (25th percentile of line
/// thickness, as for reading). Pages with ordinary text stay as they are.
double autoUpscaleFactor(List<TextBlock> blocks, int width, int height) {
  final t = lineThicknesses(blocks);
  if (t.isEmpty) return 1.0;
  final small = npPercentile(t, 25);
  if (small >= upscaleSmallLinePx) return 1.0;
  final f = limitUpscaleFactor(upscaleTargetLinePx / math.max(1.0, small), width, height);
  return f >= upscaleMinGain ? f : 1.0;
}

/// The factor of the fixed modes; for [UpscaleMode.auto] see
/// [autoUpscaleFactor].
double fixedUpscaleFactor(UpscaleSettings settings, int width, int height) => switch (settings.mode) {
      UpscaleMode.auto || UpscaleMode.off => 1.0,
      UpscaleMode.x2 => limitUpscaleFactor(2, width, height),
      UpscaleMode.x3 => limitUpscaleFactor(3, width, height),
      UpscaleMode.x4 => limitUpscaleFactor(4, width, height),
      UpscaleMode.width => limitUpscaleFactor(settings.targetWidth / width, width, height),
    };

/// [image] enlarged [factor] times with [method].
RgbImage upscaleImage(RgbImage image, double factor, {UpscaleMethod method = UpscaleMethod.fast}) {
  final w = (image.width * factor).round(), h = (image.height * factor).round();
  final src = CvBridge.rgbToMat(image);
  try {
    final dst = cv.resize(src, (w, h), interpolation: cv.INTER_LANCZOS4);
    try {
      return CvBridge.matToRgb(dst);
    } finally {
      dst.dispose();
    }
  } finally {
    src.dispose();
  }
}

/// Copies of [blocks] moved to a page enlarged to [width]×[height] from
/// [srcWidth]×[srcHeight].
List<TextBlock> scaleBlocks(List<TextBlock> blocks, int srcWidth, int srcHeight, int width, int height) {
  final sx = width / srcWidth, sy = height / srcHeight;
  return [
    for (final b in blocks)
      b.copy()
        ..xyxy = scaleBox(b.xyxy, sx, sy)
        ..bubbleXyxy = b.bubbleXyxy == null ? null : scaleBox(b.bubbleXyxy!, sx, sy)
        ..lines = [for (final l in b.lines) scaleLine(l, sx, sy)]
        ..style = b.style?.scaled(sx, sy),
  ];
}
