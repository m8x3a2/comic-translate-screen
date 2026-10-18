/// Page-level inpainting: fast flat fill of uniform speech bubbles, then the
/// network on what remains, by patches or on the whole page. Port of
/// `InpaintingHandler.inpaint_image` and its helpers (`pipeline/inpainting.py`,
/// `pipeline/inpainting_boxes.py`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/contours.dart';
import '../imaging/mahotas.dart';
import '../imaging/morphology.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import '../plugins/engines.dart';
import 'mask.dart';

const fastFillBubbleInset = 7;
const fastFillUniformColorTolerance = 12;
const fastFillMinUniformCoverage = 0.94;

final _f32 = Float32List(1);
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// Runs the inpainting network on an image region (`inpainter_cache(...)`).
typedef InpaintRegion = Future<RgbImage> Function(RgbImage image, GrayImage mask);

/// Blocks whose text is removed (`inpaint_blk_list` of the original batch
/// run): with translations, blocks that have text and a renderable
/// translation; otherwise blocks with text; otherwise every block (e.g.
/// straight from detection).
List<TextBlock> selectInpaintBlocks(List<TextBlock> blocks) {
  bool hasRenderable(TextBlock b) => b.translation.trim().isNotEmpty && _alnum.hasMatch(b.translation);
  if (blocks.any((b) => b.translation.trim().isNotEmpty)) {
    return [for (final b in blocks) if (b.text.trim().isNotEmpty && hasRenderable(b)) b];
  }
  if (blocks.any((b) => b.text.trim().isNotEmpty)) return [for (final b in blocks) if (b.text.trim().isNotEmpty) b];
  return [for (final b in blocks) b.copy()..text = 'text'];
}

final _alnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// What [inpaintPage] did, for logs and tests.
class InpaintReport {
  int fastFilledBlocks = 0;
  String mode = 'none';
  int patches = 0;
  final List<String> notes = [];
}

/// `merge_overlapping_padded_boxes`: pads `(x, y, w, h)` boxes and merges
/// those that touch, returning `(x1, y1, x2, y2)`.
List<(int, int, int, int)> mergeOverlappingPaddedBoxes(
  Iterable<(int, int, int, int)> boxes,
  int width,
  int height, {
  int pad = 32,
}) {
  final merged = <(int, int, int, int)>[];
  for (final (x, y, w, h) in boxes) {
    final x1 = math.max(0, x - pad), y1 = math.max(0, y - pad);
    final x2 = math.min(width, x + w + pad), y2 = math.min(height, y + h + pad);
    var done = false;
    for (var i = 0; i < merged.length; i++) {
      final (mx1, my1, mx2, my2) = merged[i];
      if (!(x2 < mx1 || x1 > mx2 || y2 < my1 || y1 > my2)) {
        merged[i] = (math.min(x1, mx1), math.min(y1, my1), math.max(x2, mx2), math.max(y2, my2));
        done = true;
        break;
      }
    }
    if (!done) merged.add((x1, y1, x2, y2));
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < merged.length; i++) {
      for (var j = merged.length - 1; j > i; j--) {
        final (mx1, my1, mx2, my2) = merged[i];
        final (nx1, ny1, nx2, ny2) = merged[j];
        if (!(mx2 < nx1 || mx1 > nx2 || my2 < ny1 || my1 > ny2)) {
          merged[i] = (math.min(mx1, nx1), math.min(my1, ny1), math.max(mx2, nx2), math.max(my2, ny2));
          merged.removeAt(j);
          changed = true;
        }
      }
    }
  }
  return merged;
}

/// `inpaint_image`: cleans [mask]ed text from [image]. Uniform bubbles are
/// filled with their background colour; the rest goes to [inpainter], by
/// patches when that costs less than a full-page pass. Returns the cleaned
/// page (pixels outside the mask unchanged).
Future<RgbImage> inpaintPage(
  RgbImage image,
  GrayImage mask,
  InpaintConfig config,
  InpaintRegion inpainter, {
  List<TextBlock>? blocks,
  InpaintReport? report,
}) async {
  report ??= InpaintReport();
  if (!mask.data.any((v) => v != 0)) return image.clone();

  final (workingImage, workingMask, cleaned) = applyFastBubbleCleanup(image, mask, blocks, report: report);
  report.fastFilledBlocks = cleaned;
  if (!workingMask.data.any((v) => v != 0)) {
    report.mode = 'fast-fill-only';
    return workingImage;
  }
  final contours = findContours(workingMask);
  if (contours.isEmpty) return workingImage;

  final boxes = [for (final c in contours) boundingRect(c)];
  final merged = mergeOverlappingPaddedBoxes(boxes, workingImage.width, workingImage.height);
  if (merged.isEmpty) return workingImage;

  // Cost model of the original: patch pixels (min 128 px, multiple of 8,
  // plus a per-patch overhead) against one pass over the scaled page.
  final hImg = workingImage.height, wImg = workingImage.width;
  final maxSize = switch (config.strategy) {
    HdStrategy.resize => config.resizeLimit,
    HdStrategy.original => math.max(hImg, wImg),
    HdStrategy.crop => 1024,
  };
  final scale = math.min(1.0, maxSize / math.max(hImg, wImg));
  final fullPixels = math.max(1, pyRound(wImg * scale)) * math.max(1, pyRound(hImg * scale));
  var patchPixels = 0;
  for (final (x1, y1, x2, y2) in merged) {
    final w = math.max(0, x2 - x1), h = math.max(0, y2 - y1);
    patchPixels += math.max(128, (w / 8.0).ceil() * 8) * math.max(128, (h / 8.0).ceil() * 8);
  }
  final usePatches = patchPixels + (merged.length - 1) * 50000 < fullPixels;

  if (!usePatches) {
    report.mode = 'full';
    return await inpainter(workingImage, workingMask);
  }
  report.mode = 'patches';
  report.patches = merged.length;
  final out = workingImage.clone();
  for (final (x1, y1, x2, y2) in merged) {
    final box = BBox(x1, y1, x2, y2);
    final patch = await inpainter(workingImage.crop(box), workingMask.crop(box));
    for (var y = y1; y < y2; y++) {
      out.data.setRange(out.offset(x1, y), out.offset(x2, y), patch.data, patch.offset(0, y - y1));
    }
  }
  return out;
}

/// `_get_fast_fill_bounds`.
BBox? fastFillBounds(TextBlock block, int imageWidth, int imageHeight) {
  final bubble = block.bubbleXyxy;
  if (block.textClass == TextClass.bubble && bubble != null) {
    return adjustTextLineCoordinates(bubble, 10, 10, imageWidth, imageHeight);
  }
  return adjustTextLineCoordinates(block.xyxy, 10, 10, imageWidth, imageHeight);
}

GrayImage _sub(GrayImage m, BBox b) => m.crop(b);

void _putSub(GrayImage target, BBox b, GrayImage values) {
  for (var y = 0; y < values.height; y++) {
    target.data.setRange((b.y1 + y) * target.width + b.x1, (b.y1 + y) * target.width + b.x1 + values.width, values.data,
        y * values.width);
  }
}

int _count(GrayImage m) => m.data.where((v) => v != 0).length;

GrayImage _where(int w, int h, bool Function(int i) f) =>
    GrayImage(w, h, Uint8List.fromList([for (var i = 0; i < w * h; i++) f(i) ? 1 : 0]));

/// `_apply_fast_bubble_cleanup`: fills uniform bubbles; returns the image,
/// the mask that still needs the network, and how many blocks were filled.
(RgbImage, GrayImage, int) applyFastBubbleCleanup(
  RgbImage image,
  GrayImage mask,
  List<TextBlock>? blocks, {
  InpaintReport? report,
}) {
  final cleaned = image.clone();
  final residual = GrayImage(mask.width, mask.height, Uint8List.fromList(mask.data));
  if (blocks == null || blocks.isEmpty || !mask.data.any((v) => v != 0)) return (cleaned, residual, 0);

  var cleanedBlocks = 0;
  final cleanedBubbles = <TextBlock>[];
  for (final (idx, block) in blocks.indexed) {
    if (block.textClass != TextClass.bubble || block.bubbleXyxy == null) continue;
    final bounds = fastFillBounds(block, image.width, image.height);
    if (bounds == null || bounds.isEmpty) continue;
    final residualCrop = _sub(residual, bounds);
    if (!residualCrop.data.any((v) => v != 0)) continue;
    var cropMask = toMask255(residualCrop);

    var (uniform, reason) = isFastFillBubbleBackgroundUniform(image, block, bounds, cropMask);
    if (uniform) {
      final routing = _fastFillUniformityMask(image, block, bounds, cropMask);
      (uniform, reason) = isFastFillBubbleBackgroundUniform(image, block, bounds, routing);
    }
    if (!uniform) {
      report?.notes.add('block[$idx] routed to NN ($reason)');
      continue;
    }

    cropMask = clipMaskComponentsToBubble(cropMask, bounds, block.bubbleXyxy,
        inset: fastFillBubbleInset, image: image, seedBbox: block.xyxy);
    if (_count(cropMask) <= 0) continue;
    var (ok, why) = _fastFillBlock(cleaned, residual, block, bounds, cropMask);
    if (!ok) {
      BlockMask? fallback;
      try {
        fallback = buildBlockMaskData(image, block, requireTextOrTranslation: false, clipToBubble: true);
      } catch (_) {
        fallback = null;
      }
      if (fallback == null) {
        report?.notes.add('block[$idx] fast fill failed without fallback ($why)');
        continue;
      }
      final (fbOk, fbWhy) = _fastFillBlock(cleaned, residual, block, fallback.bounds, fallback.mask);
      if (!fbOk) {
        report?.notes.add('block[$idx] fast fill failed ($why; fallback $fbWhy)');
        continue;
      }
      why = 'fallback:$fbWhy';
      if (fallback.bounds != bounds) {
        final retry = _sub(residual, bounds);
        if (retry.data.any((v) => v != 0)) {
          final (rOk, rWhy) = _fastFillBlock(cleaned, residual, block, bounds, toMask255(retry));
          why = rOk ? '$why+retry:$rWhy' : '$why+retry_failed:$rWhy';
        }
      }
      ok = true;
    }
    cleanedBlocks++;
    cleanedBubbles.add(block);
    report?.notes.add('block[$idx] fast-filled ($why)');
  }

  if (cleanedBlocks > 0) {
    // Drop residual mask that spilled outside the cleaned bubbles' interiors.
    final w = mask.width, h = mask.height;
    final scope = Uint8List(w * h), allowed = Uint8List(w * h);
    for (final b in cleanedBubbles) {
      final bb = fastFillBounds(b, image.width, image.height);
      if (bb == null) continue;
      final clip = buildBubbleClipMask(bb.width, bb.height, bb, b.bubbleXyxy,
          inset: fastFillBubbleInset, image: image, seedBbox: b.xyxy);
      for (var y = bb.y1; y < bb.y2; y++) {
        for (var x = bb.x1; x < bb.x2; x++) {
          scope[y * w + x] = 1;
          if (clip != null && clip.data[(y - bb.y1) * bb.width + (x - bb.x1)] != 0) allowed[y * w + x] = 1;
        }
      }
    }
    for (var i = 0; i < w * h; i++) {
      if (residual.data[i] != 0 && scope[i] != 0 && allowed[i] == 0) residual.data[i] = 0;
    }
  }
  return (cleaned, residual, cleanedBlocks);
}

/// `_is_fast_fill_bubble_background_uniform`: flat fill only when the bubble
/// background has one colour everywhere (no artwork showing through).
(bool, String) isFastFillBubbleBackgroundUniform(RgbImage image, TextBlock block, BBox bounds, GrayImage cropMask) {
  final crop = image.crop(bounds);
  final cw = crop.width, ch = crop.height;
  if (cw == 0 || ch == 0) return (false, 'bubble-background-invalid');
  final bubble = buildBubbleClipMask(cw, ch, bounds, block.bubbleXyxy,
      inset: fastFillBubbleInset, image: image, seedBbox: block.xyxy);
  if (bubble == null) return (false, 'bubble-background-unavailable');

  final binary = toMask01(cropMask);
  final halo = imkDilate(binary, StructuringElement.rect(5, 5), iterations: 2);
  final sample = _where(cw, ch, (i) => bubble.data[i] != 0 && halo.data[i] == 0);
  final sampleCount = _count(sample);
  if (sampleCount < 64) return (false, 'bubble-background-too-small:$sampleCount');

  List<double> median(Iterable<int> indices) {
    final r = <int>[], g = <int>[], b = <int>[];
    for (final i in indices) {
      r.add(crop.data[i * 3]);
      g.add(crop.data[i * 3 + 1]);
      b.add(crop.data[i * 3 + 2]);
    }
    return [npMedian(r), npMedian(g), npMedian(b)];
  }

  final sampleIdx = [for (var i = 0; i < cw * ch; i++) if (sample.data[i] != 0) i];
  final med = median(sampleIdx);
  var close = 0;
  for (final i in sampleIdx) {
    var ok = true;
    for (var c = 0; c < 3; c++) {
      if ((crop.data[i * 3 + c] - med[c]).abs() > fastFillUniformColorTolerance) {
        ok = false;
        break;
      }
    }
    if (ok) close++;
  }
  final coverage = close / sampleCount;
  if (coverage < fastFillMinUniformCoverage) return (false, 'bubble-background-nonuniform:coverage=$coverage');

  var bx1 = cw, by1 = ch, bx2 = -1, by2 = -1;
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      if (bubble.data[y * cw + x] == 0) continue;
      if (x < bx1) bx1 = x;
      if (x > bx2) bx2 = x;
      if (y < by1) by1 = y;
      if (y > by2) by2 = y;
    }
  }
  if (bx2 >= 0) {
    by2 += 1;
    bx2 += 1;
    final minCount = math.max(64, pyRound(sampleCount * 0.015));
    for (var gy = 0; gy < 3; gy++) {
      final cy1 = by1 + pyRound(gy * (by2 - by1) / 3), cy2 = by1 + pyRound((gy + 1) * (by2 - by1) / 3);
      for (var gx = 0; gx < 3; gx++) {
        final cx1 = bx1 + pyRound(gx * (bx2 - bx1) / 3), cx2 = bx1 + pyRound((gx + 1) * (bx2 - bx1) / 3);
        final cell = <int>[
          for (var y = math.max(0, cy1); y < math.min(ch, cy2); y++)
            for (var x = math.max(0, cx1); x < math.min(cw, cx2); x++)
              if (sample.data[y * cw + x] != 0) y * cw + x,
        ];
        if (cell.length < minCount) continue;
        final cm = median(cell);
        final shift = [for (var c = 0; c < 3; c++) (cm[c] - med[c]).abs()].reduce(math.max);
        if (shift > fastFillUniformColorTolerance) {
          return (false, 'bubble-background-nonuniform:spatial-color-shift=$shift,cell=$gy:$gx');
        }
      }
    }
  }

  final maskedIdx = [for (var i = 0; i < cw * ch; i++) if (bubble.data[i] != 0 && binary.data[i] != 0) i];
  final bubbleCount = _count(bubble);
  final maskedCoverage = maskedIdx.length / math.max(1, bubbleCount);
  if (maskedIdx.length >= 64 && maskedCoverage >= 0.20) {
    final mm = median(maskedIdx);
    final shift = [for (var c = 0; c < 3; c++) (mm[c] - med[c]).abs()].reduce(math.max);
    if (shift > fastFillUniformColorTolerance) {
      return (false, 'bubble-background-nonuniform:expanded-mask-color-shift=$shift');
    }
  }
  return (true, 'bubble-background-uniform:coverage=$coverage,mask-coverage=$maskedCoverage');
}

/// `_get_fast_fill_uniformity_mask`: the block's own mask placed in [bounds].
GrayImage _fastFillUniformityMask(RgbImage image, TextBlock block, BBox bounds, GrayImage fallback) {
  BlockMask? bm;
  try {
    bm = buildBlockMaskData(image, block, requireTextOrTranslation: false, clipToBubble: true);
  } catch (_) {
    return fallback;
  }
  if (bm == null || !bm.mask.data.any((v) => v != 0)) return fallback;
  final b = bm.bounds;
  final ix1 = math.max(bounds.x1, b.x1), iy1 = math.max(bounds.y1, b.y1);
  final ix2 = math.min(bounds.x2, b.x2), iy2 = math.min(bounds.y2, b.y2);
  if (ix2 <= ix1 || iy2 <= iy1) return fallback;
  final routing = GrayImage.zeros(fallback.width, fallback.height);
  for (var y = iy1; y < iy2; y++) {
    for (var x = ix1; x < ix2; x++) {
      routing.data[(y - bounds.y1) * routing.width + (x - bounds.x1)] = bm.mask.data[(y - b.y1) * bm.mask.width + (x - b.x1)];
    }
  }
  return routing.data.any((v) => v != 0) ? routing : fallback;
}

/// `_fast_fill_block`: paints the masked text of one bubble with its
/// background colour (soft edge) and clears it from the residual mask.
(bool, String) _fastFillBlock(RgbImage cleaned, GrayImage residual, TextBlock block, BBox bounds, GrayImage cropMask) {
  final crop = cleaned.crop(bounds);
  final residualCrop = _sub(residual, bounds);
  final regions = _fastFillRegions(block, bounds, cropMask, residualCrop);
  if (regions == null) return (false, 'invalid-regions');
  final (masked, background) = regions;

  final (fill, colorReason) = _estimateFastFillColor(crop, masked, background);
  if (fill == null) return (false, colorReason);

  final w = crop.width, h = crop.height;
  final fillRegion = _associatedResidualComponents(residualCrop, masked);
  var applied = fillRegion;
  GrayImage? bubble;
  if (block.textClass == TextClass.bubble && block.bubbleXyxy != null) {
    bubble = buildBubbleClipMask(w, h, bounds, block.bubbleXyxy,
        inset: fastFillBubbleInset, image: cleaned, seedBbox: block.xyxy);
    if (bubble != null) {
      final labels = connectedComponentsWithStats(fillRegion, connectivity: 4).labels;
      final keep = <int>{
        for (var i = 0; i < w * h; i++)
          if (bubble.data[i] != 0 && labels[i] > 0) labels[i],
      };
      applied = _where(w, h, (i) => keep.contains(labels[i]) && bubble!.data[i] != 0);
    }
  }

  final blurred = pilGaussianBlurGray(toMask255(applied), 1.0);
  for (var i = 0; i < w * h; i++) {
    var soft = _fround(blurred.data[i] / 255.0);
    soft = soft.clamp(0.0, 1.0);
    if (bubble != null && bubble.data[i] == 0) soft = 0.0;
    final inv = _fround(1.0 - soft);
    for (var c = 0; c < 3; c++) {
      final v = _fround(_fround(crop.data[i * 3 + c] * inv) + _fround(fill[c] * soft));
      final r = npRint(v);
      crop.data[i * 3 + c] = r < 0 ? 0 : (r > 255 ? 255 : r.toInt());
    }
  }
  // Write back (numpy views).
  for (var y = 0; y < h; y++) {
    cleaned.data.setRange(cleaned.offset(bounds.x1, bounds.y1 + y), cleaned.offset(bounds.x1 + w, bounds.y1 + y), crop.data,
        crop.offset(0, y));
  }
  for (var i = 0; i < w * h; i++) {
    if (applied.data[i] != 0) residualCrop.data[i] = 0;
  }
  _putSub(residual, bounds, residualCrop);
  return (true, colorReason);
}

/// `_get_fast_fill_regions`: masked pixels and background sample pixels.
(GrayImage, GrayImage)? _fastFillRegions(TextBlock block, BBox bounds, GrayImage cropMask, GrayImage residualCrop) {
  if (block.textClass != TextClass.bubble) return null;
  final w = cropMask.width, h = cropMask.height;
  final masked = _where(w, h, (i) => cropMask.data[i] != 0 && residualCrop.data[i] != 0);
  if (_count(masked) == 0) return null;
  var background = _where(w, h, (i) => cropMask.data[i] == 0);

  final t = block.xyxy;
  final lx1 = (t.x1 - bounds.x1).clamp(0, w), ly1 = (t.y1 - bounds.y1).clamp(0, h);
  final lx2 = math.max(lx1, math.min(w, t.x2 - bounds.x1)), ly2 = math.max(ly1, math.min(h, t.y2 - bounds.y1));
  if (lx2 > lx1 && ly2 > ly1) {
    bool inBlock(int i) {
      final x = i % w, y = i ~/ w;
      return x >= lx1 && x < lx2 && y >= ly1 && y < ly2;
    }

    final maskedPixels = _count(masked);
    var maskedInText = 0;
    for (var i = 0; i < w * h; i++) {
      if (masked.data[i] != 0 && inBlock(i)) maskedInText++;
    }
    final ratio = maskedPixels > 0 ? maskedInText / maskedPixels : 0.0;
    if (maskedInText >= 8 && ratio >= 0.6) {
      final blockBackground = _where(w, h, (i) => background.data[i] != 0 && inBlock(i));
      if (_count(blockBackground) >= 32) background = blockBackground;
    }
  }

  // Leave out a thin halo so antialiased glyph edges do not vote.
  final halo = imkDilate(toMask01(cropMask), StructuringElement.rect(3, 3));
  final safe = _where(w, h, (i) => background.data[i] != 0 && halo.data[i] == 0);
  if (_count(safe) >= 32) background = safe;
  if (_count(background) < 32) return null;
  return (masked, background);
}

/// `_estimate_fast_fill_color`: the dominant (preferably bright) background
/// colour, or null when the background is not one clear colour.
(List<double>?, String) _estimateFastFillColor(RgbImage crop, GrayImage masked, GrayImage background) {
  final n = crop.width * crop.height;
  final bgIdx = [for (var i = 0; i < n; i++) if (background.data[i] != 0) i];
  if (bgIdx.isEmpty || _count(masked) == 0) return (null, 'empty-crop-or-regions');
  if (bgIdx.length < 64) return (null, 'background-too-small:${bgIdx.length}');
  var union = 0;
  for (var i = 0; i < n; i++) {
    if (masked.data[i] != 0 || background.data[i] != 0) union++;
  }
  final maskedRatio = _count(masked) / union;
  if (maskedRatio > 0.90) return (null, 'masked-ratio-too-high:$maskedRatio');

  // Quantise to 16 levels per channel; np.unique sorts the keys.
  final byKey = <int, List<int>>{};
  for (final i in bgIdx) {
    final o = i * 3;
    final key = ((crop.data[o] >> 4) << 8) | ((crop.data[o + 1] >> 4) << 4) | (crop.data[o + 2] >> 4);
    (byKey[key] ??= []).add(o);
  }
  final keys = byKey.keys.toList()..sort();
  final counts = [for (final k in keys) byKey[k]!.length];
  final minCluster = math.max(48, (bgIdx.length * 0.015).toInt());
  // np.argsort(counts)[::-1][:16] (ties: reversed index order).
  final order = List.generate(keys.length, (i) => i)
    ..sort((a, b) {
      final c = counts[a].compareTo(counts[b]);
      return c != 0 ? c : a.compareTo(b);
    });
  final top = order.reversed.take(16);

  final candidates = <({int count, double coverage, List<double> median, double brightness, double spread})>[];
  for (final k in top) {
    final count = counts[k];
    if (count < minCluster) continue;
    final offs = byKey[keys[k]]!;
    final median = <double>[], spread = <double>[];
    for (var c = 0; c < 3; c++) {
      final v = [for (final o in offs) crop.data[o + c]];
      median.add(npMedian(v));
      spread.add(npPercentile(v, 90) - npPercentile(v, 10));
    }
    final brightness = _fround(_fround(_fround(median[0] + median[1]) + median[2]) / 3);
    candidates.add((
      count: count,
      coverage: count / bgIdx.length,
      median: median,
      brightness: brightness,
      spread: spread.reduce(math.max),
    ));
  }
  if (candidates.isEmpty) return (null, 'no-candidates:min_cluster=$minCluster');

  // Stable sort by count, descending.
  final sorted = [...candidates.indexed]..sort((a, b) {
      final c = b.$2.count.compareTo(a.$2.count);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final cands = [for (final e in sorted) e.$2];
  final largest = cands.first;
  final bright = [
    for (final c in cands)
      if (c.brightness >= 150.0 && c.count >= math.max(minCluster, (largest.count * 0.12).toInt())) c,
  ];
  var selected = largest;
  if (bright.isNotEmpty) {
    selected = bright.first;
    for (final c in bright) {
      if (c.count > selected.count) selected = c;
    }
  }

  var valid = bgIdx;
  if (selected.brightness >= 80.0) {
    valid = [
      for (final i in bgIdx)
        if (0.299 * crop.data[i * 3 + 2] + 0.587 * crop.data[i * 3 + 1] + 0.114 * crop.data[i * 3] >= 50.0) i,
    ];
  }
  if (valid.isEmpty) valid = bgIdx;
  var close = 0;
  for (final i in valid) {
    var ok = true;
    for (var c = 0; c < 3; c++) {
      if ((crop.data[i * 3 + c] - selected.median[c]).abs() > 15) {
        ok = false;
        break;
      }
    }
    if (ok) close++;
  }
  final neighbourhood = close / valid.length;
  if (neighbourhood < 0.55) return (null, 'selected-too-low-coverage:coverage=$neighbourhood');
  if (selected.count < 96 && selected.coverage < 0.03) return (null, 'selected-too-small:count=${selected.count}');
  if (selected.spread > 48.0) return (null, 'selected-too-wide:spread=${selected.spread}');
  return (selected.median, 'ok:count=${selected.count},brightness=${selected.brightness}');
}

/// `_get_associated_residual_components`: residual components within 8 px
/// of the masked region.
GrayImage _associatedResidualComponents(GrayImage residualCrop, GrayImage masked) {
  final w = residualCrop.width, h = residualCrop.height;
  final binary = toMask01(residualCrop);
  if (!binary.data.any((v) => v != 0)) return masked;
  final cc = connectedComponentsWithStats(binary, connectivity: 8);
  if (cc.count <= 1) return binary;
  final near = imkDilate(masked, StructuringElement.rect(17, 17));
  final labels = <int>{
    for (var i = 0; i < w * h; i++)
      if (near.data[i] != 0 && cc.labels[i] > 0) cc.labels[i],
  };
  if (labels.isEmpty) return masked;
  return _where(w, h, (i) => labels.contains(cc.labels[i]));
}
