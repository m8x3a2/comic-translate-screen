// Port of modules/detection/heuristic_lines/clustering.py.
part of '../heuristic_lines.dart';

List<HLine> _detectLinesFromMask(_Mask textMask, String direction) {
  final height = textMask.height, width = textMask.width;
  final toleranceX = math.max(1, _int(height * 0.02));
  final toleranceY = math.max(1, _int(width * 0.02));

  final spans = <List<int>>[];
  if (direction == _horizontal) {
    final ySum = textMask.rowSums();
    var startY = -1;
    for (var y = 0; y < height; y++) {
      if (ySum[y] > toleranceY) {
        if (startY == -1) startY = y;
      } else if (startY != -1) {
        spans.add([0, startY, width, y]);
        startY = -1;
      }
    }
    if (startY != -1) spans.add([0, startY, width, height]);
  } else {
    final xSum = textMask.colSums();
    var startX = -1;
    for (var x = 0; x < width; x++) {
      if (xSum[x] > toleranceX) {
        if (startX == -1) startX = x;
      } else if (startX != -1) {
        spans.add([startX, 0, x, height]);
        startX = -1;
      }
    }
    if (startX != -1) spans.add([startX, 0, width, height]);
  }

  final boxes = <HLine>[];
  for (final [sx1, sy1, sx2, sy2] in spans) {
    final bounds = _maskBounds(textMask.slice(sy1, sy2, sx1, sx2));
    if (bounds == null) continue;

    if (direction == _horizontal) {
      boxes.addAll(_splitHorizontalSpan(textMask, sx1, sy1, sx2, sy2));
    } else {
      final minX = sx1 + bounds[0];
      final maxX = sx1 + bounds[2];
      final minY = sy1 + bounds[1];
      final maxY = sy1 + bounds[3];
      if (maxX - minX < 4 && maxY - minY < 4) continue;
      boxes.add(HLine.box([minX, minY, maxX, maxY]));
    }
  }

  if (boxes.isEmpty) return [HLine.box([0, 0, width, height])];
  return boxes;
}

/// Runs of consecutive indices whose value is `<= threshold`.
List<List<int>> _valleyRuns(List<int> ySum, double threshold) {
  final runs = <List<int>>[];
  var current = <int>[];
  for (var y = 0; y < ySum.length; y++) {
    if (ySum[y] <= threshold) {
      current.add(y);
    } else if (current.isNotEmpty) {
      runs.add(current);
      current = [];
    }
  }
  if (current.isNotEmpty) runs.add(current);
  return runs;
}

int _runArgmin(List<int> ySum, List<int> run) {
  var minY = run.first;
  var minVal = ySum[minY];
  for (final y in run) {
    if (ySum[y] < minVal) {
      minVal = ySum[y];
      minY = y;
    }
  }
  return minY;
}

double _peak(List<int> values, int start, int end) {
  var m = values[start];
  for (var i = start + 1; i < end; i++) {
    if (values[i] > m) m = values[i];
  }
  return m.toDouble();
}

List<int> _findHorizontalValleySplits(_Mask region) {
  final h = region.height, w = region.width;
  if (h < 36) return _findCompactHorizontalValleySplits(region);

  final ySum = region.rowSums();
  final maxPeak = _max(ySum).toInt();
  if (maxPeak <= 0) return [];

  final valleyThresh = math.max(4.0, math.min(0.12 * maxPeak, 0.08 * w));
  final splits = <int>[];
  for (final run in _valleyRuns(ySum, valleyThresh)) {
    if (run.first <= 3 || run.last >= h - 4) continue;

    // At least two consecutive near-empty rows, unless the valley is a strong
    // local minimum between text rows (dense handwritten captions).
    var nearZeroStreak = 0;
    for (final y in run) {
      if (ySum[y] <= 1) {
        nearZeroStreak++;
        if (nearZeroStreak >= 2) break;
      } else {
        nearZeroStreak = 0;
      }
    }
    if (nearZeroStreak < 2 && !_isSoftHorizontalValley(ySum, run, maxPeak, w)) continue;
    splits.add(_runArgmin(ySum, run));
  }
  return splits;
}

List<int> _findCompactHorizontalValleySplits(_Mask region) {
  final h = region.height, w = region.width;
  if (h < 10) return [];

  final ySum = region.rowSums();
  final maxPeak = _max(ySum).toInt();
  if (maxPeak < math.max(12, pyRound(w * 0.18))) return [];

  final valleyThresh = math.max(1.0, math.min(3.0, 0.10 * maxPeak));
  final splits = <int>[];
  for (final run in _valleyRuns(ySum, valleyThresh)) {
    if (run.length < 2 || run.first <= 1 || run.last >= h - 2) continue;
    final leftPeak = run.first > 0 ? _peak(ySum, 0, run.first) : 0.0;
    final rightPeak = run.last + 1 < ySum.length ? _peak(ySum, run.last + 1, ySum.length) : 0.0;
    if (math.min(leftPeak, rightPeak) < math.max(10.0, 0.35 * maxPeak)) continue;
    splits.add(_runArgmin(ySum, run));
  }
  return splits;
}

bool _isSoftHorizontalValley(List<int> ySum, List<int> run, int maxPeak, int width) {
  if (run.length < 3 || maxPeak <= 0) return false;

  final minVal = _min(run.map((y) => ySum[y])).toDouble();
  final softThresh = math.max(8.0, math.min(0.06 * maxPeak, 0.04 * width));
  if (minVal > softThresh) return false;

  final leftPeak = run.first > 0 ? _peak(ySum, 0, run.first) : 0.0;
  final rightPeak = run.last + 1 < ySum.length ? _peak(ySum, run.last + 1, ySum.length) : 0.0;
  final sidePeakThresh = math.max(12.0, 0.18 * maxPeak);
  if (leftPeak < sidePeakThresh || rightPeak < sidePeakThresh) return false;
  return minVal <= math.min(leftPeak, rightPeak) * 0.35;
}

List<HLine> _splitHorizontalSpan(_Mask textMask, int sx1, int sy1, int sx2, int sy2) {
  final region = textMask.slice(sy1, sy2, sx1, sx2);
  final bounds = _maskBounds(region);
  if (bounds == null) return [];

  final splits = _findHorizontalValleySplits(region);
  if (splits.isNotEmpty) {
    final subBoxes = <HLine>[];
    var lastY = 0;
    for (final splitY in splits) {
      subBoxes.addAll(_splitHorizontalSpan(textMask, sx1, sy1 + lastY, sx2, sy1 + splitY));
      lastY = splitY + 1;
    }
    subBoxes.addAll(_splitHorizontalSpan(textMask, sx1, sy1 + lastY, sx2, sy2));
    return subBoxes;
  }

  final componentRows = _splitTallHorizontalSpan(region, sx1, sy1);
  if (componentRows != null) return componentRows;

  final minY = sy1 + bounds[1];
  final maxY = sy1 + bounds[3];
  final lineHeight = math.max(1, maxY - minY + 1);
  final gapLimit = math.max(10, _int(lineHeight * 2.8));

  final colSums = region.colSums();
  final boxes = <HLine>[];
  int? startX;
  int? lastInkX;
  var gap = 0;
  final minWidthThreshold = math.max(24, _int(region.width * 0.10));

  for (var localX = 0; localX < colSums.length; localX++) {
    if (colSums[localX] > 0) {
      startX ??= localX;
      lastInkX = localX;
      gap = 0;
      continue;
    }
    if (startX != null) {
      gap++;
      if (gap > gapLimit && lastInkX != null) {
        final w = lastInkX + 1 - startX;
        if (w >= minWidthThreshold || boxes.isEmpty) {
          final box = _refineSubspanBox(region, sx1, sy1, startX, lastInkX + 1);
          if (box != null) boxes.add(box);
        }
        startX = null;
        lastInkX = null;
        gap = 0;
      }
    }
  }

  if (startX != null && lastInkX != null) {
    final w = lastInkX + 1 - startX;
    if (w >= minWidthThreshold || boxes.isEmpty) {
      final box = _refineSubspanBox(region, sx1, sy1, startX, lastInkX + 1);
      if (box != null) boxes.add(box);
    }
  }
  return boxes;
}

List<HLine> _trimMarginalVerticalNoiseFromHorizontalLines(
  List<HLine> lines,
  _Mask textMask,
  List<HLine> verticalLines, {
  List<_Comp>? componentBoxes,
  _Integral? integralImage,
}) {
  if (lines.length < 2 || verticalLines.length < 2) return lines;
  if (lines.any((l) => l.isPolygon)) return lines;

  final verticalBoxes = [for (final l in verticalLines) l.axisBox];
  final integral = integralImage ?? _Integral(textMask);
  final verticalPixels = <int>[];
  for (final box in verticalBoxes) {
    final x1 = math.max(0, box[0]);
    final y1 = math.max(0, box[1]);
    final x2 = math.min(textMask.width - 1, box[2]);
    final y2 = math.min(textMask.height - 1, box[3]);
    if (x2 < x1 || y2 < y1) {
      verticalPixels.add(0);
      continue;
    }
    verticalPixels.add(_sumBoxPixels(integral, x1, y1, x2, y2));
  }
  if (verticalPixels.isEmpty) return lines;

  final mainIndex = _argmax(verticalPixels);
  final mainBox = verticalBoxes[mainIndex];
  final mainPixels = math.max(1, verticalPixels[mainIndex]);
  final mainWidth = math.max(1, mainBox[2] - mainBox[0] + 1);
  final mainHeight = math.max(1, mainBox[3] - mainBox[1] + 1);

  final components = componentBoxes ?? _componentBoxes(textMask);
  final medianHeight = components.isNotEmpty ? npMedian(components.map((c) => c.height)) : 12.0;

  final marginalColumns = <(String, List<int>)>[];
  for (final (index, box) in verticalBoxes.indexed) {
    if (index == mainIndex) continue;
    final width = math.max(1, box[2] - box[0] + 1);
    final height = math.max(1, box[3] - box[1] + 1);
    final gapLeft = mainBox[0] - box[2] - 1;
    final gapRight = box[0] - mainBox[2] - 1;
    final side = gapLeft >= 0
        ? 'left'
        : gapRight >= 0
            ? 'right'
            : '';
    if (side.isEmpty) continue;
    if (math.max(gapLeft, gapRight) < math.max(6.0, medianHeight * 0.25)) continue;
    if (width > math.max(mainWidth * 0.65, medianHeight * 4.0)) continue;
    if (height < math.max(medianHeight * 2.5, mainHeight * 0.35)) continue;
    if (verticalPixels[index] > mainPixels * 0.35) continue;
    final startsLater = box[1] > mainBox[1] + medianHeight;
    if (!startsLater) continue;
    marginalColumns.add((side, box));
  }
  if (marginalColumns.isEmpty) return lines;

  final trimmed = <HLine>[];
  for (final line in lines) {
    var refined = line.axisBox;
    for (final (side, column) in marginalColumns) {
      final lineHeight = math.max(1, refined[3] - refined[1] + 1);
      final overlapY = math.max(0, math.min(refined[3], column[3]) - math.max(refined[1], column[1]) + 1);
      if (overlapY < math.max(2, pyRound(lineHeight * 0.25))) continue;
      if (_hasInterveningTextInk(textMask, integral, refined, mainBox, column, side)) continue;

      if (side == 'left' && refined[0] <= column[2] && refined[2] >= mainBox[0]) {
        final candidate = _refineBoxInRange(textMask, mainBox[0], refined[1], refined[2], refined[3]);
        if (candidate != null) refined = candidate;
      } else if (side == 'right' && refined[2] >= column[0] && refined[0] <= mainBox[2]) {
        final candidate = _refineBoxInRange(textMask, refined[0], refined[1], mainBox[2], refined[3]);
        if (candidate != null) refined = candidate;
      }
    }
    trimmed.add(HLine.box(refined));
  }
  return trimmed;
}

bool _hasInterveningTextInk(
  _Mask textMask,
  _Integral integral,
  List<int> lineBox,
  List<int> mainBox,
  List<int> column,
  String side,
) {
  int x1, x2;
  if (side == 'left') {
    x1 = column[2] + 1;
    x2 = mainBox[0] - 1;
  } else if (side == 'right') {
    x1 = mainBox[2] + 1;
    x2 = column[0] - 1;
  } else {
    return false;
  }

  final height = textMask.height, width = textMask.width;
  final y1 = math.max(0, math.min(height - 1, lineBox[1]));
  final y2 = math.max(0, math.min(height - 1, lineBox[3]));
  x1 = math.max(0, math.min(width - 1, x1));
  x2 = math.max(0, math.min(width - 1, x2));
  if (x2 < x1 || y2 < y1) return false;

  final lineHeight = math.max(1, y2 - y1 + 1);
  final bridgePixels = _sumBoxPixels(integral, x1, y1, x2, y2);
  if (bridgePixels < math.max(12, pyRound(lineHeight * 0.75))) return false;

  final bridge = textMask.slice(y1, y2 + 1, x1, x2 + 1);
  final bridgeWidth = math.max(1, x2 - x1 + 1);
  final inkColumns = bridge.colSums().where((v) => v > 0).length;
  return inkColumns >= math.max(3, math.min(12, pyRound(bridgeWidth * 0.08)));
}

List<HLine> _mergeSmallHorizontalFragments(List<HLine> lines) {
  if (lines.length <= 1) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  final medianWidth = npMedian(boxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final medianHeight = npMedian(boxes.map((b) => math.max(1, b[3] - b[1] + 1)));

  final consumed = <int>{};
  for (var index = 0; index < boxes.length; index++) {
    if (consumed.contains(index)) continue;
    final box = boxes[index];
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    final boxHeight = math.max(1, box[3] - box[1] + 1);
    final isSmallFragment =
        boxHeight <= math.max(8.0, medianHeight * 0.45) && boxWidth <= math.max(36.0, medianWidth * 0.35);
    if (!isSmallFragment) continue;

    final centerX = (box[0] + box[2]) / 2.0;
    int? bestTarget;
    double? bestGap;
    for (var targetIndex = 0; targetIndex < boxes.length; targetIndex++) {
      if (targetIndex == index || consumed.contains(targetIndex)) continue;
      final target = boxes[targetIndex];
      final targetWidth = math.max(1, target[2] - target[0] + 1);
      final targetHeight = math.max(1, target[3] - target[1] + 1);
      if (targetWidth < boxWidth * 2.0 && targetHeight < boxHeight * 2.0) continue;

      final verticalOverlap = math.min(box[3], target[3]) - math.max(box[1], target[1]) + 1;
      final minH = math.min(boxHeight, targetHeight);
      final verticalGap = math.max(0, math.max(box[1], target[1]) - math.min(box[3], target[3]) - 1);
      final gapLimit = math.max(8.0, medianHeight * 0.45);
      final hasOverlap = minH > 0 && verticalOverlap / minH >= 0.20;
      final hasSmallGap = verticalGap <= gapLimit && boxHeight < targetHeight * 0.60;
      if (!hasOverlap && !hasSmallGap) continue;

      final horizontalOverlap = math.min(box[2], target[2]) - math.max(box[0], target[0]) + 1;
      final centerInTarget = target[0] - medianHeight <= centerX && centerX <= target[2] + medianHeight;
      final enoughOverlap = horizontalOverlap >= math.min(boxWidth * 0.35, 8.0);
      if (!centerInTarget && !enoughOverlap) continue;

      if (bestGap == null || verticalGap < bestGap) {
        bestGap = verticalGap.toDouble();
        bestTarget = targetIndex;
      }
    }
    if (bestTarget == null) continue;

    final target = boxes[bestTarget];
    boxes[bestTarget] = [
      math.min(target[0], box[0]),
      math.min(target[1], box[1]),
      math.max(target[2], box[2]),
      math.max(target[3], box[3]),
    ];
    consumed.add(index);
  }

  return [
    for (final (index, line) in lines.indexed)
      if (!consumed.contains(index))
        _listEq(boxes[index], line.axisBox) ? line : HLine.box(boxes[index]),
  ];
}

List<HLine> _filterMarginalHorizontalArtifacts(List<HLine> lines, _Mask textMask) {
  if (lines.length <= 1) return lines;
  if (lines.any((l) => l.isPolygon)) return lines;

  final width = textMask.width;
  final boxes = [for (final l in lines) l.axisBox];
  final medianWidth = npMedian(boxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final medianHeight = npMedian(boxes.map((b) => math.max(1, b[3] - b[1] + 1)));

  final edgeMargin = math.max(4, pyRound(width * 0.03));
  final maxArtifactWidth = math.max(40.0, medianWidth * 0.18);
  final maxArtifactHeight = math.max(12.0, medianHeight * 0.80);
  final kept = <HLine>[];
  for (final (index, box) in boxes.indexed) {
    final lineWidth = math.max(1, box[2] - box[0] + 1);
    final lineHeight = math.max(1, box[3] - box[1] + 1);
    final touchesEdge = box[0] <= edgeMargin || box[2] >= width - 1 - edgeMargin;
    if (!touchesEdge || lineWidth > maxArtifactWidth || lineHeight > maxArtifactHeight) {
      kept.add(HLine.box(box));
      continue;
    }

    var overlapsOtherText = false;
    for (final (otherIndex, other) in boxes.indexed) {
      if (otherIndex == index) continue;
      final otherWidth = math.max(1, other[2] - other[0] + 1);
      if (otherWidth <= lineWidth) continue;
      final horizontalOverlap = math.min(box[2], other[2]) - math.max(box[0], other[0]) + 1;
      final horizontalGap = math.max(0, math.max(box[0], other[0]) - math.min(box[2], other[2]) - 1);
      final verticalOverlap = math.min(box[3], other[3]) - math.max(box[1], other[1]) + 1;
      final minHeight = math.min(lineHeight, math.max(1, other[3] - other[1] + 1));
      final meaningfulOverlap = horizontalOverlap >= math.max(8.0, lineWidth * 0.35);
      final sameRowNeighbor = horizontalOverlap <= 0 &&
          horizontalGap <= math.max(8.0, medianHeight * 0.35) &&
          verticalOverlap >= math.max(2.0, minHeight * 0.25);
      if (meaningfulOverlap || sameRowNeighbor) {
        overlapsOtherText = true;
        break;
      }
    }
    if (overlapsOtherText) kept.add(HLine.box(box));
  }
  return kept.isNotEmpty ? kept : lines;
}

List<int>? _refineBoxInRange(_Mask textMask, int x1, int y1, int x2, int y2) {
  final h = textMask.height, w = textMask.width;
  x1 = math.max(0, math.min(w - 1, x1));
  x2 = math.max(0, math.min(w - 1, x2));
  y1 = math.max(0, math.min(h - 1, y1));
  y2 = math.max(0, math.min(h - 1, y2));
  if (x2 < x1 || y2 < y1) return null;

  final bounds = _maskBounds(textMask.slice(y1, y2 + 1, x1, x2 + 1));
  if (bounds == null) return null;
  return [x1 + bounds[0], y1 + bounds[1], x1 + bounds[2], y1 + bounds[3]];
}

List<HLine>? _splitTallHorizontalSpan(_Mask region, int offsetX, int offsetY) {
  final components = _componentBoxes(region);
  if (components.length < 4) return null;

  final medianHeight = npMedian(components.map((c) => c.height));
  final bounds = _maskBounds(region);
  if (bounds == null) return null;
  final inkHeight = bounds[3] - bounds[1] + 1;
  if (inkHeight < math.max(36, pyRound(medianHeight * 1.75))) return null;
  final centersX = [for (final c in components) c.cx];
  final centersY = [for (final c in components) c.cy];
  if (centersX.length >= 4 && npStd(centersX) > 1.0 && npStd(centersY) > 1.0) {
    if (npCorrcoef(centersX, centersY).abs() > 0.88) return null;
  }

  final rows = _clusterComponentsByY(components, medianHeight);
  if (rows.length <= 1) return null;
  if (rows.where((row) => row.length >= 3).length < 2) return null;

  final rowBands = _componentRowBands(rows, region.height);
  var localBoxes = <List<int>>[];
  for (var i = 0; i < rows.length && i < rowBands.length; i++) {
    final (bandY1, bandY2) = rowBands[i];
    for (final group in _splitComponentRowByX(rows[i], region.width, medianHeight)) {
      final box = _componentsToBandBox(group, region, bandY1, bandY2);
      if (box != null) localBoxes.add(box);
    }
  }

  localBoxes = _mergeLeftMarginalBoxes(localBoxes, region.width, medianHeight);
  if (localBoxes.length <= 1) return null;
  return [
    for (final b in localBoxes) HLine.box([b[0] + offsetX, b[1] + offsetY, b[2] + offsetX, b[3] + offsetY]),
  ];
}

List<(int, int)> _componentRowBands(List<List<_Comp>> rows, int regionHeight) {
  if (rows.isEmpty) return [];
  if (rows.length == 1) return [(0, regionHeight)];

  final centers = [for (final row in rows) npMean(row.map((c) => c.cy))];
  final boundaries = [0];
  for (var index = 0; index < rows.length - 1; index++) {
    var boundary = pyRound((centers[index] + centers[index + 1]) / 2.0);
    boundary = math.max(boundaries.last + 1, math.min(regionHeight - 1, boundary));
    boundaries.add(boundary);
  }
  boundaries.add(regionHeight);
  return [for (var i = 0; i < boundaries.length - 1; i++) (boundaries[i], boundaries[i + 1])];
}

List<_Comp> _componentBoxes(_Mask region) => _componentBoxesFromCc(region.components());

List<List<_Comp>> _clusterComponentsByY(List<_Comp> components, double medianHeight) {
  final rows = <List<_Comp>>[];
  final rowGap = math.max(8.0, medianHeight * 0.75);
  final rowCenterSums = <double>[];
  final rowCounts = <int>[];
  for (final component in _sorted(components, (c) => [c.cy])) {
    if (rows.isEmpty) {
      rows.add([component]);
      rowCenterSums.add(component.cy);
      rowCounts.add(1);
      continue;
    }
    final rowCenter = rowCenterSums.last / rowCounts.last;
    if (component.cy - rowCenter > rowGap) {
      rows.add([component]);
      rowCenterSums.add(component.cy);
      rowCounts.add(1);
    } else {
      rows.last.add(component);
      rowCenterSums[rowCenterSums.length - 1] += component.cy;
      rowCounts[rowCounts.length - 1] += 1;
    }
  }
  return rows;
}

List<List<_Comp>> _splitComponentRowByX(List<_Comp> row, int spanWidth, double medianHeight) {
  row = _sorted(row, (c) => [c.x1]);
  if (row.length <= 1) return [row];

  var currentMaxX = row[0].x2;
  for (var index = 1; index < row.length; index++) {
    final gap = row[index].x1 - currentMaxX - 1;
    final left = row.sublist(0, index);
    final right = row.sublist(index);
    if (_isMarginalComponentSplit(left, right, gap, spanWidth, medianHeight)) {
      return [left, ..._splitComponentRowByX(right, spanWidth, medianHeight)];
    }
    currentMaxX = math.max(currentMaxX, row[index].x2);
  }

  final groups = [
    [row[0]],
  ];
  currentMaxX = row[0].x2;
  final groupBoxes = [
    [row[0].x1, row[0].y1, row[0].x2, row[0].y2],
  ];
  final gapLimit = math.max(12.0, medianHeight * 0.85);
  for (final component in row.skip(1)) {
    final gap = component.x1 - currentMaxX - 1;
    final previousBox = groupBoxes.last;
    if (gap > gapLimit && !_isTrailingPunctuationComponentBox(previousBox, component, gap, medianHeight)) {
      groups.add([component]);
      groupBoxes.add([component.x1, component.y1, component.x2, component.y2]);
    } else {
      groups.last.add(component);
      previousBox[0] = math.min(previousBox[0], component.x1);
      previousBox[1] = math.min(previousBox[1], component.y1);
      previousBox[2] = math.max(previousBox[2], component.x2);
      previousBox[3] = math.max(previousBox[3], component.y2);
    }
    currentMaxX = math.max(currentMaxX, component.x2);
  }
  return groups;
}

bool _isTrailingPunctuationComponentBox(List<double> previousBox, _Comp component, double gap, double medianHeight) {
  final previousWidth = math.max(1.0, previousBox[2] - previousBox[0] + 1);
  final componentWidth = math.max(1.0, component.width);
  final componentHeight = math.max(1.0, component.height);
  final previousCenterY = (previousBox[1] + previousBox[3]) / 2.0;
  final componentCenterY = (component.y1 + component.y2) / 2.0;

  if (gap > math.max(48.0, medianHeight * 3.0)) return false;
  if (componentWidth > math.max(8.0, medianHeight * 0.60)) return false;
  if (componentHeight > math.max(14.0, medianHeight * 0.95)) return false;
  if (previousWidth < math.max(36.0, medianHeight * 3.0)) return false;
  return (previousCenterY - componentCenterY).abs() <= math.max(10.0, medianHeight * 0.90);
}

bool _isMarginalComponentSplit(
  List<_Comp> left,
  List<_Comp> right,
  double gap,
  int spanWidth,
  double medianHeight,
) {
  if (gap < math.max(4.0, medianHeight * 0.2) || right.length < 3) return false;

  final leftBox = _componentsToBox(left);
  final rightBox = _componentsToBox(right);
  if (leftBox == null || rightBox == null) return false;

  final leftWidth = math.max(1, leftBox[2] - leftBox[0] + 1);
  final rightWidth = math.max(1, rightBox[2] - rightBox[0] + 1);
  final leftHeight = math.max(1, leftBox[3] - leftBox[1] + 1);
  final leftCenterY = (leftBox[1] + leftBox[3]) / 2.0;
  final rightCenterY = (rightBox[1] + rightBox[3]) / 2.0;

  final nearLeftEdge = leftBox[0] <= spanWidth * 0.28 && leftBox[2] <= spanWidth * 0.42;
  final rightIsMainText = rightWidth >= math.max(leftWidth * 1.35, medianHeight * 4.0);
  final leftIsSideNote =
      leftHeight >= medianHeight * 1.25 || (leftCenterY - rightCenterY).abs() >= medianHeight * 0.35;
  return nearLeftEdge && rightIsMainText && leftIsSideNote;
}

List<int>? _componentsToBox(List<_Comp> components) {
  if (components.isEmpty) return null;
  return [
    _min(components.map((c) => c.x1)).floor(),
    _min(components.map((c) => c.y1)).floor(),
    _max(components.map((c) => c.x2)).ceil(),
    _max(components.map((c) => c.y2)).ceil(),
  ];
}

List<int>? _componentsToBandBox(List<_Comp> components, _Mask region, int bandY1, int bandY2) {
  final box = _componentsToBox(components);
  if (box == null) return null;

  final x1 = math.max(0, math.min(region.width - 1, box[0]));
  final x2 = math.max(0, math.min(region.width - 1, box[2]));
  final y1 = math.max(0, math.min(region.height, bandY1));
  final y2 = math.max(0, math.min(region.height, bandY2));
  if (x2 < x1 || y2 <= y1) return box;

  final bounds = _maskBounds(region.slice(y1, y2, x1, x2 + 1));
  if (bounds == null) return box;
  return [x1 + bounds[0], y1 + bounds[1], x1 + bounds[2], y1 + bounds[3]];
}

List<List<int>> _mergeLeftMarginalBoxes(List<List<int>> boxes, int spanWidth, double medianHeight) {
  if (boxes.length <= 2) return boxes;

  var leftBoxes = [
    for (final b in boxes)
      if (b[0] <= spanWidth * 0.28 && b[2] <= spanWidth * 0.42 && (b[2] - b[0] + 1) <= spanWidth * 0.32) b,
  ];
  if (leftBoxes.length < 2) return boxes;

  leftBoxes = _sorted(leftBoxes, (b) => [b[1], b[0]]);
  final mergedLeft = <List<int>>[];
  final consumed = <int>{};
  for (var index = 0; index < leftBoxes.length; index++) {
    if (consumed.contains(index)) continue;
    var merged = List.of(leftBoxes[index]);
    consumed.add(index);
    for (var otherIndex = index + 1; otherIndex < leftBoxes.length; otherIndex++) {
      final other = leftBoxes[otherIndex];
      final verticalGap = math.max(0, math.max(merged[1], other[1]) - math.min(merged[3], other[3]));
      final horizontalGap = math.max(0, math.max(merged[0], other[0]) - math.min(merged[2], other[2]));
      final union = [
        math.min(merged[0], other[0]),
        math.min(merged[1], other[1]),
        math.max(merged[2], other[2]),
        math.max(merged[3], other[3]),
      ];
      if (verticalGap <= medianHeight * 0.8 &&
          horizontalGap <= medianHeight * 1.2 &&
          (union[3] - union[1] + 1) <= medianHeight * 4.8) {
        merged = union;
        consumed.add(otherIndex);
      }
    }
    mergedLeft.add(merged);
  }

  bool isLeft(List<int> b) => leftBoxes.any((l) => _listEq(l, b));
  return [
    for (final b in boxes)
      if (!isLeft(b)) b,
    ...mergedLeft,
  ];
}

HLine? _refineSubspanBox(_Mask region, int offsetX, int offsetY, int localX1, int localX2) {
  final bounds = _maskBounds(region.slice(0, region.height, localX1, localX2));
  if (bounds == null) return null;

  final minX = offsetX + localX1 + bounds[0];
  final maxX = offsetX + localX1 + bounds[2];
  final minY = offsetY + bounds[1];
  final maxY = offsetY + bounds[3];
  if (maxX - minX < 4 && maxY - minY < 4) return null;
  return HLine.box([minX, minY, maxX, maxY]);
}
