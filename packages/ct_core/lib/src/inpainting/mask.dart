/// Text-removal mask: port of `generate_mask` and its helpers from
/// `modules/utils/image_utils.py` and `detect_content_mask_in_bbox` from
/// `modules/detection/utils/content.py`.
///
/// Masks are [GrayImage]s with 0 for "keep" and non-zero for "remove"
/// (255, or 1 for boolean intermediates).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/morphology.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// `adjust_text_line_coordinates`: grows a box by a percentage of its size
/// (half on each side), clamped to the image.
BBox adjustTextLineCoordinates(BBox box, int widthPercent, int heightPercent, int imageWidth, int imageHeight) {
  final dx = (box.width * widthPercent / 100 / 2).truncate();
  final dy = (box.height * heightPercent / 100 / 2).truncate();
  return BBox(
    math.max(box.x1 - dx, 0),
    math.max(box.y1 - dy, 0),
    math.min(box.x2 + dx, imageWidth),
    math.min(box.y2 + dy, imageHeight),
  );
}

/// `detect_content_mask_in_bbox`: dark and light ink components of [image]
/// (Otsu threshold), without border-touching and background-sized blobs.
GrayImage detectContentMaskInBbox(RgbImage image, {int minArea = 10, int margin = 1}) {
  final w = image.width, h = image.height;
  if (w == 0 || h == 0) return GrayImage.zeros(w, h);
  final gray = pilToGray(image);
  final t = mahotasOtsu(gray.data);
  var minV = 255, maxV = 0;
  for (final v in gray.data) {
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  GrayImage binary(bool Function(int) f) => GrayImage(w, h, Uint8List.fromList([for (final v in gray.data) f(v) ? 1 : 0]));
  var black = binary((v) => v < t);
  var white = binary((v) => v > t);
  if (!black.data.contains(1)) black = binary((v) => v == minV);
  if (!white.data.contains(1)) white = binary((v) => v == maxV);
  final mb = _maskFromComponentStats(black, minArea: minArea, margin: margin);
  final mw = _maskFromComponentStats(white, minArea: minArea, margin: margin);
  return GrayImage(w, h, Uint8List.fromList([for (var i = 0; i < w * h; i++) mb[i] || mw[i] ? 255 : 0]));
}

List<bool> _maskFromComponentStats(GrayImage binary, {required int minArea, required int margin}) {
  final w = binary.width, h = binary.height;
  final cc = connectedComponentsWithStats(binary, connectivity: 8);
  final keep = List<bool>.filled(cc.count, false);
  if (cc.count <= 1) return List.filled(w * h, false);
  final maxArea = (0.50 * h * w).toInt();
  for (var l = 1; l < cc.count; l++) {
    final s = cc.stats[l];
    final areaOk = s.area > minArea;
    final small = s.area >= 4 && s.width <= 6 && s.height <= 6;
    final inside = s.left >= margin && s.top >= margin && s.left + s.width <= w - margin && s.top + s.height <= h - margin;
    var k = (areaOk || small) && inside;
    if (h * w > 150) k = k && s.area < maxArea;
    keep[l] = k;
  }
  return [for (final l in cc.labels) keep[l]];
}

/// `_resolve_block_crop_bounds`: the region examined for a block (the text
/// box grown by 10%, widened to the bubble for text in bubbles).
BBox resolveBlockCropBounds(int imageWidth, int imageHeight, TextBlock block, int defaultPadding) {
  final c = adjustTextLineCoordinates(block.xyxy, 10, 10, imageWidth, imageHeight);
  final bubble = block.bubbleXyxy;
  if (block.textClass != TextClass.bubble || bubble == null) return c;
  final margin = math.max(4, math.min(defaultPadding + 3, 12));
  final insetY = math.max(2, math.min(defaultPadding + 1, 8));
  return BBox(
    math.min(c.x1, math.max(0, bubble.x1 - margin)),
    math.min(c.y1, math.max(0, bubble.y1 + insetY)),
    math.max(c.x2, math.min(imageWidth, bubble.x2 + margin)),
    math.max(c.y2, math.min(imageHeight, bubble.y2 - insetY)),
  );
}

/// `_select_text_like_components`: components anchored in the text box plus
/// glyph-like neighbours in the same row or column; sparse long components
/// (bubble outlines) are dropped. Returns 0/255.
GrayImage selectTextLikeComponents(
  GrayImage cropMask,
  (int, int, int, int) textBounds, {
  required int searchPadding,
  int corePadding = 2,
}) {
  final w = cropMask.width, h = cropMask.height;
  final binary = toMask01(cropMask);
  final cc = connectedComponentsWithStats(binary, connectivity: 4);
  if (cc.count <= 1) return GrayImage.zeros(w, h);

  final (tx1, ty1, tx2, ty2) = textBounds;
  final sx1 = math.max(0, tx1 - searchPadding), sy1 = math.max(0, ty1 - searchPadding);
  final sx2 = math.min(w, tx2 + searchPadding), sy2 = math.min(h, ty2 + searchPadding);
  if (sx2 <= sx1 || sy2 <= sy1) return GrayImage.zeros(w, h);

  final candidateSet = <int>{};
  for (var y = sy1; y < sy2; y++) {
    for (var x = sx1; x < sx2; x++) {
      final l = cc.labels[y * w + x];
      if (l > 0) candidateSet.add(l);
    }
  }
  final candidates = candidateSet.toList()..sort();
  if (candidates.isEmpty) return GrayImage.zeros(w, h);

  final coreCounts = List<int>.filled(cc.count, 0);
  final cx1 = math.max(0, tx1 - corePadding), cy1 = math.max(0, ty1 - corePadding);
  final cx2 = math.min(w, tx2 + corePadding), cy2 = math.min(h, ty2 + corePadding);
  for (var y = cy1; y < cy2; y++) {
    for (var x = cx1; x < cx2; x++) {
      coreCounts[cc.labels[y * w + x]]++;
    }
  }

  final textWidth = math.max(1, tx2 - tx1), textHeight = math.max(1, ty2 - ty1);
  final outlineThreshold = math.max(24, pyRound(0.30 * math.max(textWidth, textHeight)));
  bool isOutline(int l) {
    final s = cc.stats[l];
    final density = s.area / math.max(1, s.width * s.height);
    return density < 0.08 && math.max(s.width, s.height) > outlineThreshold;
  }

  final anchors = <int>[
    for (final l in candidates)
      if (coreCounts[l] / math.max(1, cc.stats[l].area) >= 0.20 && !isOutline(l)) l,
  ];
  if (anchors.isEmpty) return GrayImage.zeros(w, h);

  final keep = {...anchors};
  for (final l in candidates) {
    if (keep.contains(l) || isOutline(l)) continue;
    final s = cc.stats[l];
    final x = s.left, y = s.top, cw = s.width, ch = s.height, area = math.max(1, s.area);
    final x2 = x + cw, y2 = y + ch;
    for (final a in anchors) {
      final t = cc.stats[a];
      final ax = t.left, ay = t.top, aw = t.width, ah = t.height, aArea = math.max(1, t.area);
      final ax2 = ax + aw, ay2 = ay + ah;
      final areaSim = math.min(area, aArea) / math.max(area, aArea);
      final heightSim = math.min(ch, ah) / math.max(ch, ah);
      final widthSim = math.min(cw, aw) / math.max(cw, aw);
      final rowOverlap = math.max(0, math.min(y2, ay2) - math.max(y, ay));
      final colOverlap = math.max(0, math.min(x2, ax2) - math.max(x, ax));
      final hGap = math.max(0, math.max(x, ax) - math.min(x2, ax2));
      final vGap = math.max(0, math.max(y, ay) - math.min(y2, ay2));
      final sameRow = rowOverlap >= 0.50 * math.min(ch, ah) &&
          heightSim >= 0.45 &&
          hGap <= math.max(18, pyRound(0.80 * math.max(ch, ah)));
      final sameCol = colOverlap >= 0.50 * math.min(cw, aw) &&
          widthSim >= 0.45 &&
          vGap <= math.max(18, pyRound(0.80 * math.max(cw, aw)));
      if (areaSim >= 0.18 && (sameRow || sameCol)) {
        keep.add(l);
        break;
      }
    }
  }
  return GrayImage(w, h, Uint8List.fromList([for (final l in cc.labels) keep.contains(l) ? 255 : 0]));
}

/// `build_bubble_clip_mask`: where text may be removed inside a speech
/// bubble, as a 0/1 mask of size [maskWidth]×[maskHeight] placed at
/// [bounds]. The bubble interior is segmented by flood-filling its
/// background colour from the text; an inset ellipse is the fallback.
GrayImage? buildBubbleClipMask(
  int maskWidth,
  int maskHeight,
  BBox bounds,
  BBox? bubble, {
  required int inset,
  RgbImage? image,
  BBox? seedBbox,
}) {
  if (bubble == null) return null;
  final x1 = bounds.x1, y1 = bounds.y1, x2 = bounds.x2, y2 = bounds.y2;
  final bx1 = bubble.x1, by1 = bubble.y1, bx2 = bubble.x2, by2 = bubble.y2;
  final bx1r = bx1 + inset - x1, by1r = by1 + inset - y1, bx2r = bx2 - inset - x1, by2r = by2 - inset - y1;
  final width = maskWidth, height = maskHeight;

  GrayImage ellipse() {
    final ecx = (bx1r + bx2r) / 2.0, ecy = (by1r + by2r) / 2.0;
    final rx = math.max(1.0, (bx2r - bx1r) / 2.0), ry = math.max(1.0, (by2r - by1r) / 2.0);
    final out = GrayImage.zeros(width, height);
    for (var y = 0; y < height; y++) {
      final dy = (y - ecy) / ry;
      for (var x = 0; x < width; x++) {
        final dx = (x - ecx) / rx;
        if (dx * dx + dy * dy <= 1.0) out.data[y * width + x] = 1;
      }
    }
    return out;
  }

  if (image != null) {
    try {
      final segmented = _segmentBubble(image, width, height, x1, y1, x2, y2, bx1, by1, bx2, by2, inset, seedBbox, ellipse);
      if (segmented != null) return segmented;
    } catch (_) {
      // The original falls back to the ellipse on any error.
    }
  }
  return ellipse();
}

GrayImage? _segmentBubble(
  RgbImage image,
  int width,
  int height,
  int x1,
  int y1,
  int x2,
  int y2,
  int bx1,
  int by1,
  int bx2,
  int by2,
  int inset,
  BBox? seedBbox,
  GrayImage Function() ellipse,
) {
  final imgH = image.height, imgW = image.width;
  const margin = 5;
  final cy1 = math.max(0, by1 - margin), cy2 = math.min(imgH, by2 + margin);
  final cx1 = math.max(0, bx1 - margin), cx2 = math.min(imgW, bx2 + margin);
  final cw = math.max(0, cx2 - cx1), ch = math.max(0, cy2 - cy1);

  // The original weights channel 2 as red (BGR order) although images are RGB.
  final gray = Uint8List(cw * ch);
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      final o = image.offset(cx1 + x, cy1 + y);
      final d = image.data;
      gray[y * cw + x] = (0.299 * d[o + 2] + 0.587 * d[o + 1] + 0.114 * d[o]).toInt();
    }
  }

  int sx1, sy1, sx2, sy2;
  if (seedBbox != null) {
    (sx1, sy1, sx2, sy2) = (seedBbox.x1, seedBbox.y1, seedBbox.x2, seedBbox.y2);
  } else {
    sx1 = (bx1 + bx2) ~/ 2 - 5;
    sx2 = (bx1 + bx2) ~/ 2 + 5;
    sy1 = (by1 + by2) ~/ 2 - 5;
    sy2 = (by1 + by2) ~/ 2 + 5;
  }
  final (ry1, ry2) = _slice(math.max(0, sy1 - cy1), math.min(ch, sy2 - cy1), ch);
  final (rx1, rx2) = _slice(math.max(0, sx1 - cx1), math.min(cw, sx2 - cx1), cw);
  if (ry2 <= ry1 || rx2 <= rx1) return null;

  final hist = List<int>.filled(16, 0);
  for (var y = ry1; y < ry2; y++) {
    for (var x = rx1; x < rx2; x++) {
      hist[gray[y * cw + x] >> 4]++;
    }
  }
  var maxBin = 0;
  for (var i = 1; i < 16; i++) {
    if (hist[i] > hist[maxBin]) maxBin = i;
  }
  final bgVal = maxBin * 16 + 8.0;
  final bg = GrayImage(cw, ch, Uint8List.fromList([for (final g in gray) (g - bgVal).abs() <= 20 ? 1 : 0]));
  final labels = connectedComponentsWithStats(bg, connectivity: 4).labels;

  final seedLabels = <int>{};
  for (var y = ry1; y < ry2; y++) {
    for (var x = rx1; x < rx2; x++) {
      final i = y * cw + x;
      if (bg.data[i] != 0 && labels[i] > 0) seedLabels.add(labels[i]);
    }
  }
  if (seedLabels.isEmpty) return null;
  var bubbleMask = GrayImage(cw, ch, Uint8List.fromList([for (final l in labels) seedLabels.contains(l) ? 1 : 0]));

  // Share of the bubble box border covered by the segmentation: above half,
  // the fill leaked outside the bubble.
  final bY1 = by1 - cy1, bY2 = by2 - cy1, bX1 = bx1 - cx1, bX2 = bx2 - cx1;
  final border = <int>[];
  int at(int x, int y) => bubbleMask.data[y * cw + x];
  if (0 <= bY1 && bY1 < ch) {
    for (var x = math.max(0, bX1); x < math.min(cw, bX2); x++) {
      border.add(at(x, bY1));
    }
  }
  if (0 <= bY2 - 1 && bY2 - 1 < ch) {
    for (var x = math.max(0, bX1); x < math.min(cw, bX2); x++) {
      border.add(at(x, bY2 - 1));
    }
  }
  if (0 <= bX1 && bX1 < cw) {
    for (var y = math.max(0, bY1); y < math.min(ch, bY2); y++) {
      border.add(at(bX1, y));
    }
  }
  if (0 <= bX2 - 1 && bX2 - 1 < cw) {
    for (var y = math.max(0, bY1); y < math.min(ch, bY2); y++) {
      border.add(at(bX2 - 1, y));
    }
  }
  final touchRatio = border.isEmpty ? 0.0 : border.fold<int>(0, (a, b) => a + b) / border.length;
  if (touchRatio >= 0.5) return null;

  bubbleMask = closeHoles(bubbleMask);
  final segInset = math.min(2, inset);
  if (segInset > 0) {
    bubbleMask = toMask01(imkErode(toMask255(bubbleMask), StructuringElement.cross(3, 3), iterations: segInset));
  }

  final finalClip = GrayImage.zeros(width, height);
  final oy1 = math.max(y1, cy1), oy2 = math.min(y2, cy2), ox1 = math.max(x1, cx1), ox2 = math.min(x2, cx2);
  if (oy2 > oy1 && ox2 > ox1) {
    for (var y = oy1; y < oy2; y++) {
      for (var x = ox1; x < ox2; x++) {
        final fy = y - y1, fx = x - x1;
        if (fy < 0 || fy >= height || fx < 0 || fx >= width) continue;
        finalClip.data[fy * width + fx] = bubbleMask.data[(y - cy1) * cw + (x - cx1)];
      }
    }
  }

  if (seedBbox != null) {
    // Translucent bubbles can hold several tonal regions; recover the inset
    // ellipse only around the detected text.
    const seedPadding = 2;
    final ex1 = math.max(0, sx1 - seedPadding - x1), ey1 = math.max(0, sy1 - seedPadding - y1);
    final ex2 = math.min(width, sx2 + seedPadding - x1), ey2 = math.min(height, sy2 + seedPadding - y1);
    if (ex2 > ex1 && ey2 > ey1) {
      final el = ellipse();
      for (var y = ey1; y < ey2; y++) {
        for (var x = ex1; x < ex2; x++) {
          final i = y * width + x;
          if (el.data[i] != 0) finalClip.data[i] = 1;
        }
      }
    }
  }
  return finalClip;
}

/// numpy basic slicing of an axis of length [n] (negative bounds count from
/// the end).
(int, int) _slice(int start, int stop, int n) {
  if (start < 0) start = math.max(0, start + n);
  if (stop < 0) stop = math.max(0, stop + n);
  start = math.min(start, n);
  stop = math.min(stop, n);
  return (start, math.max(start, stop));
}

/// `clip_mask_components_to_bubble`: keeps the mask components touching the
/// bubble interior, clipped to it, optionally dilated inside it. 0/255.
GrayImage clipMaskComponentsToBubble(
  GrayImage mask,
  BBox bounds,
  BBox? bubble, {
  required int inset,
  RgbImage? image,
  BBox? seedBbox,
  int dilateKernelSize = 0,
  int dilateIterations = 1,
}) {
  final w = mask.width, h = mask.height;
  final clip = buildBubbleClipMask(w, h, bounds, bubble, inset: inset, image: image, seedBbox: seedBbox);
  if (clip == null) {
    if (dilateKernelSize > 0) {
      return imkDilate(mask, StructuringElement.rect(dilateKernelSize, dilateKernelSize), iterations: dilateIterations);
    }
    return mask;
  }
  final labels = connectedComponentsWithStats(toMask01(mask), connectivity: 4).labels;
  final keepLabels = <int>{
    for (var i = 0; i < w * h; i++)
      if (clip.data[i] != 0 && labels[i] > 0) labels[i],
  };
  if (keepLabels.isEmpty) return GrayImage.zeros(w, h);
  final kept = GrayImage(w, h, Uint8List.fromList([
    for (var i = 0; i < w * h; i++) keepLabels.contains(labels[i]) && clip.data[i] != 0 ? 255 : 0,
  ]));
  if (dilateKernelSize <= 0) return kept;
  final dilated = imkDilate(kept, StructuringElement.rect(dilateKernelSize, dilateKernelSize), iterations: dilateIterations);
  return GrayImage(w, h, Uint8List.fromList([
    for (var i = 0; i < w * h; i++) (clip.data[i] != 0 && dilated.data[i] != 0) || kept.data[i] != 0 ? 255 : 0,
  ]));
}

/// One block's part of the mask (`build_block_mask_data`).
class BlockMask {
  BlockMask(this.mask, this.bounds);

  final GrayImage mask;
  final BBox bounds;
}

/// `build_block_mask_data`.
BlockMask? buildBlockMaskData(
  RgbImage image,
  TextBlock block, {
  int defaultPadding = 5,
  bool requireTextOrTranslation = true,
  bool clipToBubble = false,
}) {
  if (requireTextOrTranslation && block.text.isEmpty && block.translation.isEmpty) return null;
  final bounds = resolveBlockCropBounds(image.width, image.height, block, defaultPadding);
  if (bounds.isEmpty) return null;
  final crop = image.crop(bounds);

  var cropMask = detectContentMaskInBbox(crop);
  if (!cropMask.data.any((v) => v != 0)) return null;
  cropMask = closeGray(cropMask, StructuringElement.rect(3, 3));

  final bubbleClip = clipToBubble && block.textClass == TextClass.bubble && block.bubbleXyxy != null;
  final t = block.xyxy;
  final textBounds = (t.x1 - bounds.x1, t.y1 - bounds.y1, t.x2 - bounds.x1, t.y2 - bounds.y1);
  if (bubbleClip) {
    cropMask = selectTextLikeComponents(cropMask, textBounds, searchPadding: math.max(16, math.min(defaultPadding + 23, 32)));
  }
  final kernel = defaultPadding;
  const iterations = 3;
  GrayImage dilated;
  if (bubbleClip) {
    dilated = clipMaskComponentsToBubble(
      cropMask,
      bounds,
      block.bubbleXyxy,
      inset: math.max(1, kernel),
      image: image,
      seedBbox: block.xyxy,
      dilateKernelSize: kernel,
      dilateIterations: iterations,
    );
  } else {
    dilated = imkDilate(cropMask, StructuringElement.rect(kernel, kernel), iterations: iterations);
  }

  if (bubbleClip) {
    // Keep the detector envelope plus a narrow halo around admitted glyphs.
    const finalPadding = 2;
    final mw = dilated.width, mh = dilated.height;
    final ex1 = math.max(0, textBounds.$1 - finalPadding), ey1 = math.max(0, textBounds.$2 - finalPadding);
    final ex2 = math.min(mw, textBounds.$3 + finalPadding), ey2 = math.min(mh, textBounds.$4 + finalPadding);
    final halo = imkDilate(toMask01(cropMask), StructuringElement.rect(5, 5));
    final out = Uint8List(mw * mh);
    for (var y = 0; y < mh; y++) {
      for (var x = 0; x < mw; x++) {
        final i = y * mw + x;
        final inEnvelope = (x >= ex1 && x < ex2 && y >= ey1 && y < ey2) || halo.data[i] != 0;
        out[i] = inEnvelope ? dilated.data[i] : 0;
      }
    }
    dilated = GrayImage(mw, mh, out);
  }
  return BlockMask(dilated, bounds);
}

/// `generate_mask`: the union of every block's mask (0/255).
GrayImage generateMask(RgbImage image, List<TextBlock> blocks, {int defaultPadding = 5}) {
  final mask = GrayImage.zeros(image.width, image.height);
  for (final b in blocks) {
    final entry = buildBlockMaskData(image, b, defaultPadding: defaultPadding, clipToBubble: true);
    if (entry == null) continue;
    final bb = entry.bounds;
    for (var y = 0; y < entry.mask.height; y++) {
      for (var x = 0; x < entry.mask.width; x++) {
        final v = entry.mask.data[y * entry.mask.width + x];
        if (v == 0) continue;
        final i = (bb.y1 + y) * image.width + bb.x1 + x;
        mask.data[i] |= v;
      }
    }
  }
  return mask;
}
