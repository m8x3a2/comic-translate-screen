/// Slicing of very tall pages (webtoons) for detection. Port of
/// `modules/detection/utils/slicer.py`.
library;

import 'dart:math' as math;

import '../image/raster.dart';
import '../model/geometry.dart';

class SliceParams {
  const SliceParams(this.sliceWidth, this.sliceHeight, this.effectiveSliceHeight, this.numSlices);

  final int sliceWidth;
  final int sliceHeight;
  final int effectiveSliceHeight;
  final int numSlices;

  List<int> toList() => [sliceWidth, sliceHeight, effectiveSliceHeight, numSlices];
}

/// Detections of one image: speech bubbles and text regions.
typedef BubbleTextBoxes = ({List<BBox> bubbles, List<BBox> texts});

class ImageSlicer {
  const ImageSlicer({
    this.heightToWidthRatioThreshold = 3.5,
    this.targetSliceRatio = 3.0,
    this.overlapHeightRatio = 0.2,
    this.minSliceHeightRatio = 0.7,
    this.mergeIouThreshold = 0.2,
    this.duplicateIouThreshold = 0.5,
    this.mergeYDistanceThreshold = 0.1,
    this.containmentThreshold = 0.85,
  });

  final double heightToWidthRatioThreshold;
  final double targetSliceRatio;
  final double overlapHeightRatio;
  final double minSliceHeightRatio;
  final double mergeIouThreshold;
  final double duplicateIouThreshold;
  final double mergeYDistanceThreshold;
  final double containmentThreshold;

  bool shouldSlice(int width, int height) => height / width > heightToWidthRatioThreshold;

  SliceParams calculateSliceParams(int width, int height) {
    final sliceWidth = width;
    final sliceHeight = (sliceWidth * targetSliceRatio).toInt();
    final effective = (sliceHeight * (1 - overlapHeightRatio)).toInt();
    var numSlices = (height / effective).ceil();
    final lastStart = (numSlices - 1) * effective;
    final lastHeight = height - lastStart;
    if (lastHeight / sliceHeight < minSliceHeightRatio && numSlices > 1) numSlices -= 1;
    return SliceParams(sliceWidth, sliceHeight, effective, numSlices);
  }

  /// `get_slice`: (start_y, end_y) of slice [n].
  (int, int) sliceRange(int height, int n, int effective, int sliceHeight) {
    final startY = n * effective;
    final endY = n == (height / effective).ceil() - 1 ? height : math.min(startY + sliceHeight, height);
    return (startY, endY);
  }

  /// `box_contained`: (contained, ratio, which: 1 = a contains b, 2 = b contains a).
  (bool, double, int) _boxContained(List<double> a, List<double> b) {
    final area1 = (a[2] - a[0]) * (a[3] - a[1]);
    final area2 = (b[2] - b[0]) * (b[3] - b[1]);
    final ix1 = math.max(a[0], b[0]), iy1 = math.max(a[1], b[1]);
    final ix2 = math.min(a[2], b[2]), iy2 = math.min(a[3], b[3]);
    if (ix2 <= ix1 || iy2 <= iy1) return (false, 0, 0);
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final ratio = inter / math.min(area1, area2);
    if (ratio >= containmentThreshold) return (true, ratio, area1 > area2 ? 1 : 2);
    return (false, ratio, 0);
  }

  /// `calculate_iou` on float boxes.
  static double _iou(List<double> a, List<double> b) {
    final inter = math.max(0.0, math.min(a[2], b[2]) - math.max(a[0], b[0])) *
        math.max(0.0, math.min(a[3], b[3]) - math.max(a[1], b[1]));
    final union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter;
    return union != 0 ? inter / union : 0;
  }

  /// `merge_overlapping_boxes` (slice-seam merging and de-duplication).
  List<BBox> mergeOverlappingBoxes(List<BBox> boxes, {required int imageHeight}) {
    if (boxes.isEmpty) return const [];
    final list = [for (final b in boxes) b.toList().map((v) => v.toDouble()).toList()];
    final yThreshold = mergeYDistanceThreshold * imageHeight;
    var i = 0;
    while (i < list.length - 1) {
      var j = i + 1;
      while (j < list.length) {
        final b1 = list[i], b2 = list[j];
        final iou = _iou(b1, b2);
        final w1 = b1[2] - b1[0], h1 = b1[3] - b1[1];
        final w2 = b2[2] - b2[0], h2 = b2[3] - b2[1];
        final a1 = w1 * h1, a2 = w2 * h2;

        final (contained, _, which) = _boxContained(b1, b2);
        if (contained) {
          if (which == 1) {
            list.removeAt(j);
          } else {
            list[i] = b2;
            list.removeAt(j);
          }
          continue;
        }

        if (iou >= duplicateIouThreshold) {
          if (a2 > a1) list[i] = b2;
          list.removeAt(j);
          continue;
        }

        final yDist = math.min((b1[1] - b2[3]).abs(), (b1[3] - b2[1]).abs());
        final localY = math.min(yThreshold, math.max(h1, h2) * 0.1);
        final xOverlap = math.max(0.0, math.min(b1[2], b2[2]) - math.max(b1[0], b2[0]));
        final minW = math.min(w1, w2);
        final xOverlapRatio = minW > 0 ? xOverlap / minW : 0.0;
        final maxA = math.max(a1, a2);
        final sizeRatio = maxA > 0 ? math.min(a1, a2) / maxA : 0.0;
        final maxW = math.max(w1, w2);

        if (yDist < localY &&
            xOverlapRatio > mergeIouThreshold &&
            sizeRatio > 0.3 &&
            (b1[0] - b2[0]).abs() < 0.5 * maxW &&
            (b1[2] - b2[2]).abs() < 0.5 * maxW) {
          final merged = [
            math.min(b1[0], b2[0]),
            math.min(b1[1], b2[1]),
            math.max(b1[2], b2[2]),
            math.max(b1[3], b2[3]),
          ];
          final mergedArea = (merged[2] - merged[0]) * (merged[3] - merged[1]);
          if (mergedArea > 3 * maxA) {
            j += 1;
            continue;
          }
          list[i] = merged;
          list.removeAt(j);
        } else {
          j += 1;
        }
      }
      i += 1;
    }
    return [for (final b in list) BBox(b[0].toInt(), b[1].toInt(), b[2].toInt(), b[3].toInt())];
  }

  /// `process_slices_for_detection` for detectors returning (bubbles, texts).
  Future<BubbleTextBoxes> processSlicesForDetection(
    RgbImage image,
    Future<BubbleTextBoxes> Function(RgbImage slice) detect,
  ) async {
    if (!shouldSlice(image.width, image.height)) return detect(image);

    final params = calculateSliceParams(image.width, image.height);
    // The original recomputes these here, ignoring the last-slice merge done
    // by calculate_slice_params; kept for parity.
    final numSlices = (image.height / params.effectiveSliceHeight).ceil();
    final sliceHeight = (image.width * targetSliceRatio).toInt();

    final bubbles = <BBox>[];
    final texts = <BBox>[];
    for (var n = 0; n < numSlices; n++) {
      final (startY, endY) = sliceRange(image.height, n, params.effectiveSliceHeight, sliceHeight);
      final slice = image.crop(BBox(0, startY, image.width, endY));
      final result = await detect(slice);
      bubbles.addAll(result.bubbles.map((b) => b.translate(0, startY)));
      texts.addAll(result.texts.map((b) => b.translate(0, startY)));
    }
    return (
      bubbles: bubbles.isEmpty ? const <BBox>[] : mergeOverlappingBoxes(bubbles, imageHeight: image.height),
      texts: texts.isEmpty ? const <BBox>[] : mergeOverlappingBoxes(texts, imageHeight: image.height),
    );
  }
}
