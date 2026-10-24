// Port of modules/detection/heuristic_lines/mask.py.
part of '../heuristic_lines.dart';

/// A boolean numpy mask: one byte per pixel, 0 or 1, row-major.
final class _Mask {
  _Mask(this.width, this.height, this.data);

  _Mask.zeros(this.width, this.height) : data = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List data;

  int get size => width * height;

  bool at(int x, int y) => data[y * width + x] != 0;

  int sum() {
    var s = 0;
    for (final v in data) {
      s += v;
    }
    return s;
  }

  bool any() {
    for (final v in data) {
      if (v != 0) return true;
    }
    return false;
  }

  _Mask copy() => _Mask(width, height, Uint8List.fromList(data));

  /// `mask[y1:y2, x1:x2]` as a copy (numpy slice semantics).
  _Mask slice(int y1, int y2, int x1, int x2) {
    final (sy1, sy2) = _slice(y1, y2, height);
    final (sx1, sx2) = _slice(x1, x2, width);
    final w = sx2 - sx1, h = sy2 - sy1;
    final out = _Mask.zeros(w, h);
    for (var y = 0; y < h; y++) {
      final src = (sy1 + y) * width + sx1;
      out.data.setRange(y * w, y * w + w, data, src);
    }
    return out;
  }

  /// A zero mask of the same shape with only columns `[x1, x2)` copied
  /// (`sub = np.zeros_like(mask); sub[:, x1:x2] = mask[:, x1:x2]`).
  _Mask columnsOnly(int x1, int x2) {
    final (sx1, sx2) = _slice(x1, x2, width);
    final out = _Mask.zeros(width, height);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      out.data.setRange(row + sx1, row + sx2, data, row + sx1);
    }
    return out;
  }

  /// `mask.sum(axis=1)`.
  List<int> rowSums() {
    final out = List<int>.filled(height, 0);
    for (var y = 0; y < height; y++) {
      var s = 0;
      final row = y * width;
      for (var x = 0; x < width; x++) {
        s += data[row + x];
      }
      out[y] = s;
    }
    return out;
  }

  /// `mask.sum(axis=0)`.
  List<int> colSums() {
    final out = List<int>.filled(width, 0);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        out[x] += data[row + x];
      }
    }
    return out;
  }

  ConnectedComponents components() => connectedComponentsWithStats(GrayImage(width, height, data), connectivity: 8);

  void orWith(_Mask other) {
    for (var i = 0; i < data.length; i++) {
      data[i] |= other.data[i];
    }
  }
}

/// `mask.astype(np.int32).cumsum(axis=0).cumsum(axis=1)`.
final class _Integral {
  _Integral(_Mask mask)
      : width = mask.width,
        height = mask.height,
        values = Int32List(mask.size) {
    for (var y = 0; y < height; y++) {
      var rowSum = 0;
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        rowSum += mask.data[i];
        values[i] = rowSum + (y > 0 ? values[i - width] : 0);
      }
    }
  }

  final int width;
  final int height;
  final Int32List values;

  /// `integral[y, x]` with numpy index semantics (negative indices wrap,
  /// out-of-range indices throw like numpy's IndexError).
  int at(int y, int x) => values[_index(y, height) * width + _index(x, width)];
}

int _sumBoxPixels(_Integral integral, int x1, int y1, int x2, int y2) {
  // Boxes clamped to the image size end one past the last pixel; sum like
  // the slice `mask[y1:y2 + 1, x1:x2 + 1]` (the original indexes past the
  // end and fails).
  x2 = math.min(x2, integral.width - 1);
  y2 = math.min(y2, integral.height - 1);
  if (x2 < x1 || y2 < y1) return 0;
  var total = integral.at(y2, x2);
  if (x1 > 0) total -= integral.at(y2, x1 - 1);
  if (y1 > 0) total -= integral.at(y1 - 1, x2);
  if (x1 > 0 && y1 > 0) total += integral.at(y1 - 1, x1 - 1);
  return total;
}

/// `_mask_bounds`: inclusive `[x1, y1, x2, y2]` of the ink, or null.
List<int>? _maskBounds(_Mask mask) {
  if (mask.size == 0) return null;
  var x1 = mask.width, y1 = mask.height, x2 = -1, y2 = -1;
  for (var y = 0; y < mask.height; y++) {
    final row = y * mask.width;
    for (var x = 0; x < mask.width; x++) {
      if (mask.data[row + x] == 0) continue;
      if (x < x1) x1 = x;
      if (x > x2) x2 = x;
      if (y < y1) y1 = y;
      if (y > y2) y2 = y;
    }
  }
  if (x2 < 0) return null;
  return [x1, y1, x2, y2];
}

/// One entry of `_component_boxes`.
final class _Comp {
  _Comp(this.label, ComponentStats s, (double, double) centroid)
      : x1 = s.left.toDouble(),
        y1 = s.top.toDouble(),
        x2 = (s.left + s.width - 1).toDouble(),
        y2 = (s.top + s.height - 1).toDouble(),
        width = s.width.toDouble(),
        height = s.height.toDouble(),
        area = s.area.toDouble(),
        cx = centroid.$1,
        cy = centroid.$2;

  final int label;
  final double x1, y1, x2, y2, width, height, area, cx, cy;
}

List<_Comp> _componentBoxesFromCc(ConnectedComponents cc, {int minArea = 20}) => [
      for (var label = 1; label < cc.count; label++)
        if (cc.stats[label].area >= minArea) _Comp(label, cc.stats[label], cc.centroids[label]),
    ];

(double, double) _componentMedians(ConnectedComponents cc) {
  final valid = [for (var l = 1; l < cc.count; l++) if (cc.stats[l].area >= 8) cc.stats[l]];
  if (valid.isNotEmpty) {
    return (npMedian(valid.map((s) => s.width)), npMedian(valid.map((s) => s.height)));
  }
  return (12.0, 12.0);
}

final class _MaskStats {
  _MaskStats(this.mask)
      : totalPixels = mask.sum(),
        integral = _Integral(mask),
        cc = mask.components() {
    final (w, h) = _componentMedians(cc);
    medianW = w;
    medianH = h;
    componentBoxes = _componentBoxesFromCc(cc);
  }

  final _Mask mask;
  final int totalPixels;
  final _Integral integral;
  final ConnectedComponents cc;
  late final double medianW;
  late final double medianH;
  late final List<_Comp> componentBoxes;
}

_MaskStats _computeMaskStats(_Mask mask) => _MaskStats(mask);

_Mask? _prepareTextMask(RgbImage image) {
  final textMask = _textMask(image, inverse: false);
  if (textMask == null) return null;
  return _removeNonTextComponents(_removeEdgeComponents(textMask));
}

_Mask? _prepareInverseTextMask(RgbImage image) {
  final textMask = _textMask(image, inverse: true);
  if (textMask == null) return null;
  return _removeNonTextComponents(_removeEdgeComponents(textMask));
}

/// `_text_mask` (or `_inverse_text_mask` when [inverse]).
_Mask? _textMask(RgbImage image, {required bool inverse}) {
  if (image.width == 0 || image.height == 0) return null;
  final gray = pilToGray(image);
  final threshold = mahotasOtsu(gray.data);
  var fgPixels = 0;
  for (final v in gray.data) {
    if (v < threshold) fgPixels++;
  }
  final bgIsLight = fgPixels < gray.data.length * 0.5;
  final darkInk = bgIsLight != inverse;
  final out = _Mask.zeros(gray.width, gray.height);
  for (var i = 0; i < gray.data.length; i++) {
    final v = gray.data[i];
    out.data[i] = (darkInk ? v <= threshold : v >= threshold) ? 1 : 0;
  }
  return out;
}

void _clearLabel(_Mask mask, Int32List labels, int label) {
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] == label) mask.data[i] = 0;
  }
}

_Mask _removeEdgeComponents(_Mask textMask) {
  final cc = textMask.components();
  if (cc.count <= 1) return textMask;

  final height = textMask.height, width = textMask.width;
  final cleaned = textMask.copy();
  final originalPixels = textMask.sum();
  final (medianW, medianH) = _componentMedians(cc);
  final removedLabels = <int>[];

  for (var label = 1; label < cc.count; label++) {
    final s = cc.stats[label];
    final x1 = s.left, y1 = s.top, compWidth = s.width, compHeight = s.height, area = s.area;
    final x2 = x1 + compWidth - 1;
    final y2 = y1 + compHeight - 1;

    final touchesLeft = x1 <= 5;
    final touchesRight = x2 >= width - 6;
    final touchesTop = y1 <= 5;
    final touchesBottom = y2 >= height - 6;
    if (!(touchesLeft || touchesRight || touchesTop || touchesBottom)) continue;

    // Components touching the left or right edge are bubble or panel borders.
    if (touchesLeft || touchesRight) {
      _clearLabel(cleaned, cc.labels, label);
      removedLabels.add(label);
      continue;
    }

    final minCharHeight = math.max(4, pyRound(medianH * 0.5));
    final isTooSmallNoise = area < 8 || compHeight < minCharHeight;

    var isSmallCropRelative = compWidth < width * 0.35 && compHeight < height * 0.35;
    if (height < 30 && compWidth < width * 0.35 && compHeight < height * 0.45) isSmallCropRelative = true;

    final isSmallMedianRelative =
        compWidth <= math.max(3.5 * medianW, 24.0) && compHeight <= math.max(3.5 * medianH, 24.0);

    final isMergedHorizontalLine = compHeight <= math.max(1.8 * medianH, 12.0) &&
        compWidth <= _max([8.0 * medianW, width * 0.85, 80.0]);

    final isCharacter = (isSmallCropRelative || isSmallMedianRelative || isMergedHorizontalLine) && !isTooSmallNoise;
    if (!isCharacter) {
      _clearLabel(cleaned, cc.labels, label);
      removedLabels.add(label);
    }
  }

  if (cleaned.sum() < math.max(8, originalPixels * 0.25) && !_hasEnoughTextAfterEdgeCleanup(cleaned)) {
    return textMask;
  }
  return _restoreLeadingTextFromEdgeComponents(textMask, cleaned, cc.labels, removedLabels, medianW, medianH);
}

bool _hasEnoughTextAfterEdgeCleanup(_Mask cleanedMask) {
  if (cleanedMask.sum() < 200) return false;

  final cc = cleanedMask.components();
  var textLike = 0;
  for (var label = 1; label < cc.count; label++) {
    final s = cc.stats[label];
    if (s.area < 8) continue;
    if (s.width < 2 || s.height < 2) continue;
    textLike++;
  }
  return textLike >= 4;
}

_Mask _restoreLeadingTextFromEdgeComponents(
  _Mask originalMask,
  _Mask cleanedMask,
  Int32List labels,
  List<int> removedLabels,
  double medianW,
  double medianH,
) {
  if (removedLabels.isEmpty || !cleanedMask.any()) return cleanedMask;

  final height = cleanedMask.height, width = cleanedMask.width;
  final rowSpans = _horizontalInkSpans(cleanedMask);
  if (rowSpans.isEmpty) return cleanedMask;
  if (rowSpans.length > 4 || height > math.max(100, pyRound(medianH * 8.0))) return cleanedMask;

  final restored = cleanedMask.copy();
  final removed = removedLabels.toSet();
  for (final (sy1, sy2) in rowSpans) {
    final bandY1 = math.max<int>(0, sy1 - math.max(2, pyRound(medianH * 0.25)));
    final bandY2 = math.min<int>(height, sy2 + math.max(2, pyRound(medianH * 0.25)));
    final cleanedBand = cleanedMask.slice(bandY1, bandY2, 0, width);
    final textX1 = _bandTextMinX(cleanedBand);
    if (textX1 == null) continue;
    if (textX1 <= math.max(2, pyRound(medianW * 0.5))) continue;

    var sideMask = _Mask.zeros(width, height);
    final (by1, by2) = _slice(bandY1, bandY2, height);
    final (_, bx2) = _slice(0, textX1, width);
    for (var y = by1; y < by2; y++) {
      for (var x = 0; x < bx2; x++) {
        final i = y * width + x;
        if (removed.contains(labels[i])) sideMask.data[i] = 1;
      }
    }

    sideMask = _removeLongEdgeStrokes(sideMask, bandY1, bandY2);
    if (!sideMask.any()) continue;

    final candidate = _leadingTextCandidate(sideMask, textX1, medianW, medianH);
    if (candidate != null) restored.orWith(candidate);
  }
  return restored;
}

int? _bandTextMinX(_Mask bandMask) {
  final stats = _computeMaskStats(bandMask);
  int? minX;
  for (var label = 1; label < stats.cc.count; label++) {
    final s = stats.cc.stats[label];
    if (s.area < 8 || s.width < 3 || s.height < 3) continue;
    minX = minX == null ? s.left : math.min(minX, s.left);
  }
  return minX;
}

List<(int, int)> _horizontalInkSpans(_Mask mask) {
  final ySum = mask.rowSums();
  final tolerance = math.max(1, _int(mask.width * 0.02));
  final spans = <(int, int)>[];
  var start = -1;
  for (var y = 0; y < mask.height; y++) {
    if (ySum[y] > tolerance) {
      if (start == -1) start = y;
    } else if (start != -1) {
      spans.add((start, y));
      start = -1;
    }
  }
  if (start != -1) spans.add((start, mask.height));
  return spans;
}

_Mask _removeLongEdgeStrokes(_Mask mask, int bandY1, int bandY2) {
  final cleaned = mask.copy();
  final bandHeight = math.max(1, bandY2 - bandY1);
  final bounds = _maskBounds(cleaned);
  final activeWidth = bounds != null ? bounds[2] - bounds[0] + 1 : cleaned.width;
  final rowSum = cleaned.rowSums();
  final colSum = cleaned.colSums();
  final rowLimit = math.max(20, _int(activeWidth * 0.30));
  final colLimit = math.max(30, _int(bandHeight * 1.25));
  for (var y = 0; y < cleaned.height; y++) {
    for (var x = 0; x < cleaned.width; x++) {
      if (rowSum[y] >= rowLimit || colSum[x] >= colLimit) cleaned.data[y * cleaned.width + x] = 0;
    }
  }
  if (cleaned.sum() < math.max(8, _int(mask.sum() * 0.20))) return mask;
  return cleaned;
}

_Mask? _leadingTextCandidate(_Mask sideMask, int textX1, double medianW, double medianH) {
  final sideStats = _computeMaskStats(sideMask);
  if (sideStats.cc.count <= 1) return null;

  var kept = _Mask.zeros(sideMask.width, sideMask.height);
  for (var label = 1; label < sideStats.cc.count; label++) {
    final s = sideStats.cc.stats[label];
    final x2 = s.left + s.width - 1;
    if (s.area < 8) continue;
    if (x2 >= textX1) continue;
    if (s.height < math.max(3, pyRound(medianH * 0.25))) continue;
    if (s.height > math.max(18, pyRound(medianH * 2.2))) continue;
    if (s.width > math.max(40, pyRound(medianW * 5.0))) continue;
    for (var i = 0; i < kept.data.length; i++) {
      if (sideStats.cc.labels[i] == label) kept.data[i] = 1;
    }
  }
  if (!kept.any()) return null;

  final selected = _selectRightmostLeadingTextCluster(kept, textX1, medianW, medianH);
  if (selected == null) return null;
  kept = selected;

  final bounds = _maskBounds(kept);
  if (bounds == null) return null;
  final gapToText = textX1 - bounds[2] - 1;
  final candidateWidth = bounds[2] - bounds[0] + 1;
  if (gapToText > math.max(12, pyRound(medianW * 2.5))) return null;
  if (candidateWidth > math.max(90, pyRound(medianW * 7.0))) return null;
  return kept;
}

_Mask? _selectRightmostLeadingTextCluster(_Mask mask, int textX1, double medianW, double medianH) {
  final stats = _computeMaskStats(mask);
  if (stats.cc.count <= 1) return null;

  final components = <({int label, int x1, int y1, int x2, int y2})>[];
  for (var label = 1; label < stats.cc.count; label++) {
    final s = stats.cc.stats[label];
    final x2 = s.left + s.width - 1;
    final y2 = s.top + s.height - 1;
    if (s.area < 8 || x2 >= textX1) continue;
    components.add((label: label, x1: s.left, y1: s.top, x2: x2, y2: y2));
  }
  if (components.isEmpty) return null;

  final sortedComponents = _sorted(components, (c) => [c.x1]);
  final groups = [
    [sortedComponents.first],
  ];
  final groupMaxX2s = [sortedComponents.first.x2];
  final maxGap = math.max(4, pyRound(medianW * 0.75));
  for (final component in sortedComponents.skip(1)) {
    final currentX2 = groupMaxX2s.last;
    if (component.x1 - currentX2 - 1 <= maxGap) {
      groups.last.add(component);
      groupMaxX2s[groupMaxX2s.length - 1] = math.max(groupMaxX2s.last, component.x2);
    } else {
      groups.add([component]);
      groupMaxX2s.add(component.x2);
    }
  }

  List<({int label, int x1, int y1, int x2, int y2})>? bestGroup;
  var bestX2 = -1;
  for (final group in groups) {
    final groupX1 = _min(group.map((c) => c.x1)).toInt();
    final groupX2 = _max(group.map((c) => c.x2)).toInt();
    final groupY1 = _min(group.map((c) => c.y1)).toInt();
    final groupY2 = _max(group.map((c) => c.y2)).toInt();
    final groupWidth = groupX2 - groupX1 + 1;
    final groupHeight = groupY2 - groupY1 + 1;
    final gapToText = textX1 - groupX2 - 1;
    if (gapToText > math.max(12, pyRound(medianW * 2.5))) continue;
    if (groupWidth < math.max(10, pyRound(medianW * 0.60))) continue;
    if (groupHeight < math.max(4, pyRound(medianH * 0.25))) continue;
    if (groupX2 > bestX2) {
      bestX2 = groupX2;
      bestGroup = group;
    }
  }
  if (bestGroup == null) return null;

  final labels = {for (final c in bestGroup) c.label};
  final selected = _Mask.zeros(mask.width, mask.height);
  for (var i = 0; i < selected.data.length; i++) {
    if (labels.contains(stats.cc.labels[i])) selected.data[i] = 1;
  }
  return selected;
}

_Mask _removeNonTextComponents(_Mask textMask) {
  final cc = textMask.components();
  if (cc.count <= 1) return textMask;

  final height = textMask.height, width = textMask.width;
  final cleaned = textMask.copy();
  final originalPixels = textMask.sum();
  for (var label = 1; label < cc.count; label++) {
    final s = cc.stats[label];
    final density = s.area / math.max(1, s.width * s.height);
    if (s.width >= width * 0.55 && s.height >= height * 0.35 && density < 0.08) {
      _clearLabel(cleaned, cc.labels, label);
    }
  }
  if (cleaned.sum() < math.max(8, originalPixels * 0.20)) return textMask;
  return cleaned;
}

int _checkAlignment(List<HLine> linesA, List<HLine> linesB) {
  var alignedCount = 0;
  for (final la in linesA) {
    final [_, lay1, _, lay2] = la.axisBox;
    final laH = lay2 - lay1 + 1;

    var bestOverlap = 0;
    var bestLbH = 1;
    double? bestLbCenterY;
    for (final lb in linesB) {
      final [_, lby1, _, lby2] = lb.axisBox;
      final lbH = lby2 - lby1 + 1;
      final overlap = math.max(0, math.min(lay2, lby2) - math.max<int>(lay1, lby1) + 1);
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestLbH = lbH;
        bestLbCenterY = (lby1 + lby2) / 2.0;
      }
    }

    if (bestOverlap > 0) {
      final maxH = math.max(laH, bestLbH);
      if (bestOverlap >= 0.50 * maxH) {
        alignedCount++;
        continue;
      }
    }

    if (bestLbCenterY == null) {
      for (final lb in linesB) {
        final [_, lby1, _, lby2] = lb.axisBox;
        final lbCenterY = (lby1 + lby2) / 2.0;
        final distance = ((lay1 + lay2) / 2.0 - lbCenterY).abs();
        if (bestLbCenterY == null || distance < ((lay1 + lay2) / 2.0 - bestLbCenterY).abs()) {
          bestLbCenterY = lbCenterY;
          bestLbH = lby2 - lby1 + 1;
        }
      }
    }
    if (bestLbCenterY == null) continue;

    final laCenterY = (lay1 + lay2) / 2.0;
    final maxH = math.max(laH, bestLbH);
    if ((laCenterY - bestLbCenterY).abs() <= math.max(4.0, maxH * 0.45)) alignedCount++;
  }
  return alignedCount;
}

List<(int, int)> _inkColumns(List<int> xSum, int tolerance) {
  final columns = <(int, int)>[];
  var startX = -1;
  for (var x = 0; x < xSum.length; x++) {
    if (xSum[x] > tolerance) {
      if (startX == -1) startX = x;
    } else if (startX != -1) {
      columns.add((startX, x));
      startX = -1;
    }
  }
  if (startX != -1) columns.add((startX, xSum.length));
  return columns;
}

int _columnPixels(List<int> xSum, int x1, int x2) => _sumRange(xSum, x1, x2);

List<_Mask> _splitMaskByTallVerticalColumns(_Mask mask) {
  final h = mask.height, w = mask.width;
  final xSum = mask.colSums();
  final toleranceX = math.max(1, _int(h * 0.02));

  final rawColumns = _inkColumns(xSum, toleranceX);
  final minPixels = math.max(12, _int(mask.sum() * 0.005));
  final columns = [
    for (final (cx1, cx2) in rawColumns)
      if (_columnPixels(xSum, cx1, cx2) >= minPixels) (cx1, cx2),
  ];
  if (columns.length <= 1) return [mask];

  final columnPixels = [for (final (cx1, cx2) in columns) _columnPixels(xSum, cx1, cx2)];
  final totalPixels = columnPixels.fold(0, (a, b) => a + b);
  if (totalPixels == 0) return [mask];

  final maxIdx = _argmax(columnPixels);
  final maxRatio = columnPixels[maxIdx] / totalPixels;
  if (maxRatio < 0.60) return [mask];

  final cc = mask.components();
  final validHeights = [
    for (var l = 1; l < cc.count; l++)
      if (cc.stats[l].area >= 8) cc.stats[l].height,
  ];
  final medianH = validHeights.isNotEmpty ? npMedian(validHeights) : 12.0;

  final targetIdxs = <int>[];
  for (final (idx, (cx1, cx2)) in columns.indexed) {
    if (idx == maxIdx) continue;
    if (columnPixels[idx] / totalPixels >= 0.05) {
      var minY = -1, maxY = -1;
      for (var y = 0; y < h; y++) {
        for (var x = cx1; x < cx2; x++) {
          if (mask.at(x, y)) {
            if (minY < 0) minY = y;
            maxY = y;
            break;
          }
        }
      }
      if (minY >= 0 && maxY - minY + 1 >= 2.5 * medianH) targetIdxs.add(idx);
    }
  }
  if (targetIdxs.isEmpty) return [mask];

  final (domX1, domX2) = columns[maxIdx];
  final domMask = mask.columnsOnly(domX1, domX2);
  final full = [0, 0, w, h];
  final domLines = [
    for (final l in _filterNoiseLines(_detectLinesFromMask(domMask, _horizontal), _horizontal))
      if (!l.equalsBox(full)) l,
  ];

  for (final idx in targetIdxs) {
    final (cx1, cx2) = columns[idx];
    final subMask = mask.columnsOnly(cx1, cx2);
    final subLines = [
      for (final l in _filterNoiseLines(_detectLinesFromMask(subMask, _horizontal), _horizontal))
        if (!l.equalsBox(full)) l,
    ];
    if (subLines.isEmpty) continue;
    if (_checkAlignment(subLines, domLines) >= 0.50 * subLines.length) return [mask];
  }

  return [for (final (cx1, cx2) in columns) mask.columnsOnly(cx1, cx2)];
}
