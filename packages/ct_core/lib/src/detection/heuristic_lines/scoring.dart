// Port of modules/detection/heuristic_lines/scoring.py.
part of '../heuristic_lines.dart';

double _scoreLineCandidate(List<HLine> lines, String direction, _Mask textMask, [_MaskStats? maskStats]) {
  if (lines.isEmpty) return -1000000.0;

  final totalTextPixels = maskStats?.totalPixels ?? textMask.sum();
  if (totalTextPixels <= 0) return -1000000.0;

  var coveredPixels = 0;
  var totalArea = 0.0;
  final shapeScores = <double>[];
  for (final line in lines) {
    final (linePixels, lineArea, lineWidth, lineHeight) = _lineCoverageMetrics(line, textMask, maskStats);
    if (lineArea <= 0) continue;
    coveredPixels += linePixels;
    totalArea += lineArea;
    final ratio = direction == _horizontal ? lineWidth / lineHeight : lineHeight / lineWidth;
    shapeScores.add(pyTanh(math.log(math.max(ratio, 1e-6))));
  }
  if (totalArea <= 0 || shapeScores.isEmpty) return -1000000.0;

  final coverage = coveredPixels / totalTextPixels;
  final density = coveredPixels / totalArea;
  final shapeScore = npMean(shapeScores);
  final fragmentationPenalty = 0.08 * math.max(0, lines.length - 1);
  return coverage * 1.4 + density * 0.8 + shapeScore * 1.2 - fragmentationPenalty;
}

(int, double, double, double) _lineCoverageMetrics(HLine line, _Mask textMask, [_MaskStats? maskStats]) {
  final p = line.points;
  if (p != null) {
    final p0x = p[0][0].toDouble(), p0y = p[0][1].toDouble();
    final exX = p[1][0] - p0x, exY = p[1][1] - p0y;
    final eyX = p[3][0] - p0x, eyY = p[3][1] - p0y;
    final lineWidth = math.max(1.0, _norm2(exX, exY));
    final lineHeight = math.max(1.0, _norm2(eyX, eyY));
    final [x1, y1, x2, y2] = _clampBox(line.axisBox, textMask.width, textMask.height);
    if (x2 < x1 || y2 < y1) return (0, 0.0, lineWidth, lineHeight);

    final region = textMask.slice(y1, y2 + 1, x1, x2 + 1);
    final uxX = exX / lineWidth, uxY = exY / lineWidth;
    final uyX = eyX / lineHeight, uyY = eyY / lineHeight;
    var any = false;
    var inside = 0;
    for (var y = 0; y < region.height; y++) {
      for (var x = 0; x < region.width; x++) {
        if (region.data[y * region.width + x] == 0) continue;
        any = true;
        final dx = (x + x1) - p0x, dy = (y + y1) - p0y;
        final localX = dx * uxX + dy * uxY;
        final localY = dx * uyX + dy * uyY;
        if (localX >= -0.5 && localX <= lineWidth + 0.5 && localY >= -0.5 && localY <= lineHeight + 0.5) inside++;
      }
    }
    if (!any) return (0, lineWidth * lineHeight, lineWidth, lineHeight);
    return (inside, lineWidth * lineHeight, lineWidth, lineHeight);
  }

  final [x1, y1, x2, y2] = _clampBox(line.axisBox, textMask.width, textMask.height);
  if (x2 < x1 || y2 < y1) return (0, 0.0, 1.0, 1.0);

  final lineWidth = math.max(1, x2 - x1 + 1).toDouble();
  final lineHeight = math.max(1, y2 - y1 + 1).toDouble();
  final pixels = maskStats != null
      ? _sumBoxPixels(maskStats.integral, x1, y1, x2, y2)
      : textMask.slice(y1, y2 + 1, x1, x2 + 1).sum();
  return (pixels, lineWidth * lineHeight, lineWidth, lineHeight);
}

bool _isLargeGlyphHorizontal(
  _Mask textMask,
  List<HLine> horizontalLines,
  List<HLine> verticalLines, [
  _MaskStats? maskStats,
]) {
  final union = _unionBox([...horizontalLines, ...verticalLines]);
  if (union == null) return false;

  final width = math.max(1, union[2] - union[0] + 1);
  final height = math.max(1, union[3] - union[1] + 1);
  if (width < height * 0.9 || horizontalLines.length > 2 || verticalLines.length > 4) return false;

  var components = maskStats?.componentBoxes ?? _componentBoxes(textMask);
  if (components.isNotEmpty) {
    final maxArea = _max(components.map((c) => c.area.toInt()));
    components = [
      for (final c in components)
        if (c.area.toInt() >= math.max(20, maxArea * 0.15)) c,
    ];
  }
  if (components.isEmpty || components.length > 6) return false;

  final centersY = [for (final c in components) c.cy];
  final medianHeight = npMedian(components.map((c) => c.height.toInt()));
  return _max(centersY) - _min(centersY) <= math.max(12.0, medianHeight * 0.8);
}

bool _isMultilineHorizontalText(List<HLine> horizontalLines, List<HLine> verticalLines) {
  if (horizontalLines.length < 3 || verticalLines.length != 1) return false;

  final boxes = [for (final l in horizontalLines) l.axisBox];
  final widths = [for (final b in boxes) (b[2] - b[0] + 1).toDouble()];
  final heights = [for (final b in boxes) (b[3] - b[1] + 1).toDouble()];

  var rowLikeCount = 0;
  for (var i = 0; i < widths.length; i++) {
    if (widths[i] / math.max(1.0, heights[i]) >= 1.8) rowLikeCount++;
  }
  if (rowLikeCount < math.max(3, (horizontalLines.length * 0.65).ceil())) return false;

  final union = _unionBox(horizontalLines);
  if (union == null) return false;

  final medianHeight = npMedian(heights);
  final medianWidth = npMedian(widths);
  final unionWidth = math.max(1, union[2] - union[0] + 1);
  final unionHeight = math.max(1, union[3] - union[1] + 1);
  if (unionHeight < medianHeight * 3.0 || medianWidth < math.max(16.0, unionWidth * 0.35)) return false;

  final centersY = _sorted([for (final b in boxes) (b[1] + b[3]) / 2.0], (v) => [v]);
  if (centersY.length >= 2 && npMedian(_diff(centersY)) < medianHeight * 0.75) return false;

  final verticalBox = verticalLines[0].axisBox;
  final verticalWidth = math.max(1, verticalBox[2] - verticalBox[0] + 1);
  final verticalHeight = math.max(1, verticalBox[3] - verticalBox[1] + 1);
  return verticalHeight > verticalWidth * 1.2;
}

bool _isFragmentedRotatedHorizontalText(_Mask textMask, List<HLine> horizontalLines, List<HLine> verticalLines) {
  if (horizontalLines.length < 5 || verticalLines.length < 2) return false;

  final height = textMask.height, width = textMask.width;
  final verticalBoxes = [for (final l in verticalLines) l.axisBox];
  final broadVerticals = [
    for (final b in verticalBoxes)
      if ((b[2] - b[0] + 1) >= width * 0.55 && (b[3] - b[1] + 1) >= height * 0.65) b,
  ];
  if (broadVerticals.length != 1) return false;

  final broadBox = broadVerticals[0];
  final broadWidth = math.max(1, broadBox[2] - broadBox[0] + 1);
  for (final box in verticalBoxes) {
    if (_listEq(box, broadBox)) continue;
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    if (boxWidth > math.max(14, pyRound(broadWidth * 0.14))) return false;
  }

  var rowLikeCount = 0;
  for (final l in horizontalLines) {
    final box = l.axisBox;
    final lineWidth = math.max(1, box[2] - box[0] + 1);
    final lineHeight = math.max(1, box[3] - box[1] + 1);
    if (lineWidth >= lineHeight * 1.8 && lineWidth >= width * 0.25) rowLikeCount++;
  }
  if (rowLikeCount < 4) return false;

  final components = _componentBoxes(textMask);
  if (components.length < 8) return false;

  final medianHeight = npMedian(components.map((c) => c.height));
  final medianWidth = npMedian(components.map((c) => c.width));
  var substantialRows = 0;
  for (final row in _clusterComponentsByY(components, medianHeight)) {
    final box = _componentsToBox(row);
    if (box == null) continue;
    final rowWidth = math.max(1, box[2] - box[0] + 1);
    if (row.length >= 2 && rowWidth >= math.max(width * 0.25, medianWidth * 4.0)) substantialRows++;
  }
  return substantialRows >= 4;
}

bool _isSparseHorizontalOverfit(
  _Mask textMask,
  List<HLine> horizontalLines,
  List<HLine> verticalLines,
  double horizontalScore,
  double verticalScore, [
  _MaskStats? maskStats,
]) {
  if (horizontalLines.length < 5 || verticalLines.length < horizontalLines.length) return false;

  final totalPixels = maskStats?.totalPixels ?? textMask.sum();
  final maskDensity = totalPixels / math.max(1, textMask.height * textMask.width);
  if (maskDensity >= 0.06 || verticalScore < horizontalScore - 0.12) return false;

  final densities = <double>[];
  for (final line in horizontalLines) {
    final (pixels, area, _, _) = _lineCoverageMetrics(line, textMask, maskStats);
    if (area > 0) densities.add(pixels / area);
  }
  return densities.isNotEmpty && npMedian(densities) < 0.09;
}

List<HLine> _detectSparseVerticalComponentColumns(_Mask textMask, {List<_Comp>? componentBoxes}) {
  final components = componentBoxes ?? _componentBoxes(textMask);
  if (components.length < 2) return [];

  final seeds = _verticalColumnSeedComponents(components, textMask.height, textMask.width);
  if (seeds.length < 2) return [];

  final medianWidth = npMedian(seeds.map((c) => c.width));
  final medianHeight = npMedian(seeds.map((c) => c.height));
  final centerGap = math.max(18.0, _min([42.0, medianWidth * 2.0, medianHeight * 1.2]).toDouble());
  final edgeGap = math.max(4.0, _min([10.0, medianWidth * 0.35, medianHeight * 0.35]).toDouble());

  final columns = <List<_Comp>>[];
  final columnBoxes = <List<double>>[];
  for (final component in _sorted(seeds, (c) => [c.cx])) {
    if (columns.isEmpty) {
      columns.add([component]);
      columnBoxes.add([component.x1, component.y1, component.x2, component.y2]);
      continue;
    }

    final currentBox = columnBoxes.last;
    final columnCenter = (currentBox[0] + currentBox[2]) / 2.0;
    final gap = component.x1 - currentBox[2] - 1.0;
    final centerDistance = (component.cx - columnCenter).abs();
    final currentWidth = math.max(1.0, currentBox[2] - currentBox[0] + 1.0);
    final componentWidth = math.max(1.0, component.width);
    final skinnyFragmentMerge = gap <= edgeGap &&
        currentWidth <= math.max(8.0, medianWidth * 1.25) &&
        componentWidth <= math.max(8.0, medianWidth * 1.25);
    final shouldMerge = centerDistance <= centerGap || skinnyFragmentMerge;
    if (!shouldMerge) {
      columns.add([component]);
      columnBoxes.add([component.x1, component.y1, component.x2, component.y2]);
    } else {
      columns.last.add(component);
      currentBox[0] = math.min(currentBox[0], component.x1);
      currentBox[1] = math.min(currentBox[1], component.y1);
      currentBox[2] = math.max(currentBox[2], component.x2);
      currentBox[3] = math.max(currentBox[3], component.y2);
    }
  }

  var boxes = [for (final column in columns) _componentsToBox(column)].whereType<List<int>>().toList();
  boxes = _mergeAdjacentVerticalColumnBoxes(boxes, medianWidth, medianHeight);
  return [for (final b in _filterVerticalColumnArtifacts(textMask, boxes, medianWidth, medianHeight)) HLine.box(b)];
}

List<_Comp> _verticalColumnSeedComponents(List<_Comp> components, int height, int width) {
  if (components.isEmpty) return [];

  final medianArea = npMedian(components.map((c) => c.area));
  final medianWidth = npMedian(components.map((c) => c.width));
  final medianHeight = npMedian(components.map((c) => c.height));

  final seeds = <_Comp>[];
  for (final component in components) {
    final compWidth = math.max(1.0, component.width);
    final compHeight = math.max(1.0, component.height);
    final area = component.area;
    final density = area / math.max(1.0, compWidth * compHeight);

    if (area < math.max(12.0, medianArea * 0.20)) continue;
    if (compWidth < 2.0 || compHeight < 2.0) continue;

    // Outline blobs and panel strokes can bridge separate vertical columns:
    // useful ink, but bad seeds.
    final isOversizedBridge = compWidth >= _max([72.0, medianWidth * 5.0, width * 0.16]) &&
        compHeight >= _max([72.0, medianHeight * 3.0, height * 0.12]);
    final isWideRowBridge = compWidth >= math.max(42.0, medianWidth * 1.7) &&
        compWidth >= compHeight * 1.45 &&
        compHeight <= math.max(64.0, medianHeight * 2.2);
    final isSkinnyBackgroundStroke = compWidth <= math.max(3.0, medianWidth * 0.45) &&
        compHeight >= math.max(80.0, medianHeight * 8.0) &&
        density <= 0.45;
    if (isOversizedBridge || isWideRowBridge || isSkinnyBackgroundStroke) continue;
    seeds.add(component);
  }
  return seeds;
}

List<List<int>> _mergeAdjacentVerticalColumnBoxes(List<List<int>> boxes, double medianWidth, double medianHeight) {
  if (boxes.length <= 1) return boxes;

  final gapLimit = math.max(5.0, _min([14.0, medianWidth * 0.85, medianHeight * 0.55]).toDouble());
  final merged = <List<int>>[];
  for (final box in _sorted(boxes, (b) => [b[0]])) {
    if (merged.isEmpty) {
      merged.add(List.of(box));
      continue;
    }
    final previous = merged.last;
    final gap = box[0] - previous[2] - 1;
    final overlapY = math.min(previous[3], box[3]) - math.max(previous[1], box[1]) + 1;
    final minHeight = math.min(previous[3] - previous[1] + 1, box[3] - box[1] + 1);
    final enoughYOverlap = minHeight > 0 && overlapY >= minHeight * 0.35;
    final previousWidth = math.max(1, previous[2] - previous[0] + 1);
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    final narrowFragmentLimit = math.max(8.0, medianWidth * 1.35);
    final mergesStrokeFragments = previousWidth <= narrowFragmentLimit && boxWidth <= narrowFragmentLimit;
    if (gap <= gapLimit && enoughYOverlap && mergesStrokeFragments) {
      previous[0] = math.min(previous[0], box[0]);
      previous[1] = math.min(previous[1], box[1]);
      previous[2] = math.max(previous[2], box[2]);
      previous[3] = math.max(previous[3], box[3]);
    } else {
      merged.add(List.of(box));
    }
  }
  return merged;
}

List<List<int>> _filterVerticalColumnArtifacts(
  _Mask textMask,
  List<List<int>> boxes,
  double medianWidth,
  double medianHeight,
) {
  if (boxes.isEmpty) return [];

  final height = textMask.height, width = textMask.width;
  final integral = _Integral(textMask);
  final filtered = <List<int>>[];
  for (final box in boxes) {
    final x1 = math.max(0, math.min(width - 1, box[0]));
    final x2 = math.max(0, math.min(width - 1, box[2]));
    final y1 = math.max(0, math.min(height - 1, box[1]));
    final y2 = math.max(0, math.min(height - 1, box[3]));
    if (x2 < x1 || y2 < y1) continue;

    final boxWidth = x2 - x1 + 1;
    final boxHeight = y2 - y1 + 1;
    final pixels = _sumBoxPixels(integral, x1, y1, x2, y2);
    final density = pixels / math.max(1, boxWidth * boxHeight);

    if (boxHeight < math.max(24.0, medianHeight * 1.8) && boxWidth < math.max(24.0, medianWidth * 2.2)) continue;
    if (boxWidth <= math.max(4.0, medianWidth * 0.55) &&
        boxHeight >= math.max(80.0, medianHeight * 7.0) &&
        density <= 0.36) {
      continue;
    }
    if (boxWidth >= width * 0.42 && density < 0.08) continue;
    filtered.add([x1, y1, x2, y2]);
  }
  if (filtered.length <= 1) return filtered;
  return _dropNestedVerticalColumns(filtered);
}

List<List<int>> _dropNestedVerticalColumns(List<List<int>> boxes) {
  final kept = <List<int>>[];
  for (final (index, box) in boxes.indexed) {
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    final boxHeight = math.max(1, box[3] - box[1] + 1);
    var nested = false;
    for (final (otherIndex, other) in boxes.indexed) {
      if (index == otherIndex) continue;
      final otherWidth = math.max(1, other[2] - other[0] + 1);
      final otherHeight = math.max(1, other[3] - other[1] + 1);
      if (otherWidth < boxWidth || otherHeight < boxHeight) continue;
      final overlapX = math.min(box[2], other[2]) - math.max(box[0], other[0]) + 1;
      final overlapY = math.min(box[3], other[3]) - math.max(box[1], other[1]) + 1;
      if (overlapX >= boxWidth * 0.85 && overlapY >= boxHeight * 0.85) {
        nested = true;
        break;
      }
    }
    if (!nested) kept.add(box);
  }
  return kept;
}

bool _looksLikeStructuredVerticalColumns(_Mask textMask, List<HLine> lines) {
  if (lines.length < 2) return false;

  final height = textMask.height;
  final boxes = _sorted([for (final l in lines) l.axisBox], (b) => [b[0]]);
  final widths = [for (final b in boxes) math.max(1, b[2] - b[0] + 1).toDouble()];
  final heights = [for (final b in boxes) math.max(1, b[3] - b[1] + 1).toDouble()];

  var verticalish = 0;
  var substantial = 0;
  for (var i = 0; i < boxes.length; i++) {
    if (heights[i] >= math.max(24.0, widths[i] * 1.45)) verticalish++;
    if (heights[i] >= math.max(height * 0.16, 36.0)) substantial++;
  }
  if (verticalish < math.max(2, (boxes.length * 0.65).ceil())) return false;
  if (substantial < 2) return false;

  final centersX = _sorted([for (final b in boxes) (b[0] + b[2]) / 2.0], (v) => [v]);
  if (centersX.length >= 2) {
    final medianWidth = npMedian(widths);
    final minCenterGap = _min(_diff(centersX));
    if (minCenterGap < math.max(5.0, medianWidth * 0.30)) return false;
  }

  var overlapPairs = 0;
  for (var i = 0; i + 1 < boxes.length; i++) {
    final left = boxes[i], right = boxes[i + 1];
    final overlap = math.min(left[2], right[2]) - math.max(left[0], right[0]) + 1;
    if (overlap <= 0) continue;
    final minWidth = math.min(left[2] - left[0] + 1, right[2] - right[0] + 1);
    if (overlap >= minWidth * 0.55) overlapPairs++;
  }
  if (overlapPairs > math.max(0, boxes.length ~/ 3)) return false;

  final union = _unionOfBoxes(boxes)!;
  final unionWidth = math.max(1, union[2] - union[0] + 1);
  final unionHeight = math.max(1, union[3] - union[1] + 1);
  if (unionHeight < math.max(48.0, height * 0.30)) return false;
  if (unionWidth < math.max(16.0, npMedian(widths) * 1.2)) return false;
  return true;
}
