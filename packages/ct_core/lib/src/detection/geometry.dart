/// Box geometry used by detection. Port of
/// `modules/detection/utils/geometry.py` and `filter_and_fix_bboxes` from
/// `modules/detection/utils/content.py`.
library;

import 'dart:math' as math;

import '../model/geometry.dart';

/// `calculate_iou`.
double calculateIou(BBox a, BBox b) {
  final x1 = math.max(a.x1, b.x1);
  final y1 = math.max(a.y1, b.y1);
  final x2 = math.min(a.x2, b.x2);
  final y2 = math.min(a.y2, b.y2);
  final inter = math.max(0, x2 - x1) * math.max(0, y2 - y1);
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  final union = areaA + areaB - inter;
  return union != 0 ? inter / union : 0;
}

/// `do_rectangles_overlap`.
bool doRectanglesOverlap(BBox a, BBox b, {double iouThreshold = 0.2}) => calculateIou(a, b) >= iouThreshold;

/// `does_rectangle_fit`: [smaller] lies entirely inside [bigger].
bool doesRectangleFit(BBox bigger, BBox smaller) {
  final left1 = math.min(bigger.x1, bigger.x2), top1 = math.min(bigger.y1, bigger.y2);
  final right1 = math.max(bigger.x1, bigger.x2), bottom1 = math.max(bigger.y1, bigger.y2);
  final left2 = math.min(smaller.x1, smaller.x2), top2 = math.min(smaller.y1, smaller.y2);
  final right2 = math.max(smaller.x1, smaller.x2), bottom2 = math.max(smaller.y1, smaller.y2);
  return left1 <= left2 && right1 >= right2 && top1 <= top2 && bottom1 >= bottom2;
}

/// `is_mostly_contained`.
bool isMostlyContained(BBox outer, BBox inner, double threshold) {
  final innerArea = (inner.x2 - inner.x1) * (inner.y2 - inner.y1);
  final outerArea = (outer.x2 - outer.x1) * (outer.y2 - outer.y1);
  if (outerArea < innerArea || innerArea == 0) return false;
  final inter = math.max(0, math.min(inner.x2, outer.x2) - math.max(inner.x1, outer.x1)) *
      math.max(0, math.min(inner.y2, outer.y2) - math.max(inner.y1, outer.y1));
  return inter / innerArea >= threshold;
}

/// `merge_boxes`.
BBox mergeBoxes(BBox a, BBox b) =>
    BBox(math.min(a.x1, b.x1), math.min(a.y1, b.y1), math.max(a.x2, b.x2), math.max(a.y2, b.y2));

/// `merge_overlapping_boxes`: merges boxes mostly contained in each other and
/// drops duplicates/overlaps on the fly.
List<BBox> mergeOverlappingBoxes(
  List<BBox> boxes, {
  double containmentThreshold = 0.3,
  double overlapThreshold = 0.5,
}) {
  var accepted = <BBox>[];
  for (var i = 0; i < boxes.length; i++) {
    var merged = boxes[i];
    for (var j = 0; j < boxes.length; j++) {
      if (i == j) continue;
      final other = boxes[j];
      if (isMostlyContained(merged, other, containmentThreshold) ||
          isMostlyContained(other, merged, containmentThreshold)) {
        merged = mergeBoxes(merged, other);
      }
    }
    var conflict = false;
    for (final acc in accepted) {
      if (merged == acc || doRectanglesOverlap(merged, acc, iouThreshold: overlapThreshold)) {
        conflict = true;
        break;
      }
    }
    if (conflict) continue;
    final m = merged;
    accepted = [
      for (final acc in accepted)
        if (!(acc == m || doRectanglesOverlap(m, acc, iouThreshold: overlapThreshold))) acc,
    ];
    accepted.add(merged);
  }
  return accepted;
}

/// `filter_and_fix_bboxes`: clamps to the image (when its size is given) and
/// drops boxes with non-positive area or width/height ≤ the tolerances.
List<BBox> filterAndFixBboxes(
  List<BBox> boxes, {
  int? imageHeight,
  int? imageWidth,
  int widthTolerance = 5,
  int heightTolerance = 5,
}) {
  final out = <BBox>[];
  for (final b in boxes) {
    var x1 = b.x1, y1 = b.y1, x2 = b.x2, y2 = b.y2;
    if (imageWidth != null) {
      x1 = math.max(0, math.min(x1, imageWidth));
      x2 = math.max(0, math.min(x2, imageWidth));
    }
    if (imageHeight != null) {
      y1 = math.max(0, math.min(y1, imageHeight));
      y2 = math.max(0, math.min(y2, imageHeight));
    }
    final w = x2 - x1, h = y2 - y1;
    if (w <= 0 || h <= 0) continue;
    if (w <= widthTolerance || h <= heightTolerance) continue;
    out.add(BBox(x1, y1, x2, y2));
  }
  return out;
}

/// Stable sort (Dart's `List.sort` is not stable; Python's `sorted` is).
List<T> stableSortedBy<T>(Iterable<T> items, Comparable Function(T) key) {
  final indexed = [for (final (i, item) in items.indexed) (i, item, key(item))];
  indexed.sort((a, b) {
    final c = a.$3.compareTo(b.$3);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
