// Port of modules/detection/heuristic_lines/skew.py.
part of '../heuristic_lines.dart';

List<HLine> _filterNoiseLines(List<HLine> lines, String direction) {
  final filtered = <HLine>[];
  for (final line in lines) {
    final [x1, y1, x2, y2] = line.axisBox;
    final w = math.max(1, x2 - x1 + 1);
    final h = math.max(1, y2 - y1 + 1);

    double hPerp, wPerp;
    final p = line.points;
    if (p != null) {
      hPerp = _norm2((p[3][0] - p[0][0]).toDouble(), (p[3][1] - p[0][1]).toDouble());
      wPerp = _norm2((p[1][0] - p[0][0]).toDouble(), (p[1][1] - p[0][1]).toDouble());
    } else {
      hPerp = h.toDouble();
      wPerp = w.toDouble();
    }

    if (direction == _horizontal) {
      if (hPerp < 5 && wPerp < 36) continue;
      if (hPerp < 3) continue;
    } else {
      if (wPerp < 5 && hPerp < 36) continue;
      if (wPerp < 3) continue;
    }
    filtered.add(line);
  }
  return filtered;
}

/// Ink pixel coordinates in `np.where` order, shifted to the mask centre.
final class _InkPoints {
  _InkPoints(_Mask mask)
      : centerX = (mask.width - 1) / 2.0,
        centerY = (mask.height - 1) / 2.0 {
    final n = mask.sum();
    xs = Float64List(n);
    ys = Float64List(n);
    var k = 0;
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        if (mask.data[y * mask.width + x] == 0) continue;
        xs[k] = x - centerX;
        ys[k] = y - centerY;
        k++;
      }
    }
  }

  final double centerX;
  final double centerY;
  late final Float64List xs;
  late final Float64List ys;

  int get length => xs.length;
}

List<HLine> _detectHorizontalLinesSkewAware(_Mask textMask) {
  var baseLines = _filterNoiseLines(_detectLinesFromMask(textMask, _horizontal), _horizontal);
  baseLines = _mergeAlignedHorizontalFragments(baseLines);
  if (baseLines.isEmpty) baseLines = [HLine.box([0, 0, textMask.width, textMask.height])];

  var bestLines = baseLines;
  final baseScore = _scoreLineCandidate(bestLines, _horizontal, textMask);
  var bestScore = baseScore;

  final ink = _InkPoints(textMask);
  if (ink.length == 0) return bestLines;

  final maxCandidates = math.max(baseLines.length + 2, (baseLines.length * 1.6).ceil());

  // Pass 1: coarse search over widely separated angles.
  const coarseAngles = [-33, -24, -15, -6, 6, 15, 24, 33];
  var bestCoarseAngle = 0;
  var bestCoarseScore = -1000000.0;
  for (final angle in coarseAngles) {
    final candidate = _filterNoiseLines(_detectHorizontalLinesAtAngle(textMask, angle, ink), _horizontal);
    if (candidate.isEmpty) continue;
    if (candidate.length > maxCandidates) continue;
    if (!_isLineLikeHorizontalQuadSet(candidate)) continue;
    final score = _scoreLineCandidate(candidate, _horizontal, textMask);
    if (score > bestCoarseScore) {
      bestCoarseScore = score;
      bestCoarseAngle = angle;
    }
  }

  // No skewed angle comes close to the unrotated baseline: the text is level.
  if (bestCoarseScore < baseScore - 0.15 && baseScore >= 1.4) return bestLines;

  // Pass 2: fine search around the best coarse angle.
  final fine = <int>{
    if (bestCoarseAngle != 0) ...[bestCoarseAngle - 3, bestCoarseAngle, bestCoarseAngle + 3],
    -3,
    3,
  }.where((a) => -36 <= a && a <= 36 && a != 0).toList()
    ..sort();

  for (final angle in fine) {
    final candidate = _filterNoiseLines(_detectHorizontalLinesAtAngle(textMask, angle, ink), _horizontal);
    if (candidate.isEmpty) continue;
    if (candidate.length > maxCandidates) continue;
    if (!_isLineLikeHorizontalQuadSet(candidate)) continue;
    final score = _scoreLineCandidate(candidate, _horizontal, textMask);
    if (baseLines.length >= 2 &&
        candidate.length < baseLines.length - 1 &&
        score < baseScore + 0.35 &&
        !_hasReasonableReducedSkewThickness(baseLines, candidate)) {
      continue;
    }
    if (baseLines.length >= 2 &&
        candidate.length < baseLines.length &&
        _looksLikeDistinctHorizontalRows(baseLines) &&
        score < baseScore + 0.12) {
      continue;
    }
    final angleBonus = math.min(0.12, angle.abs() * 0.006);
    final lineCountPenalty = 0.04 * math.max(0, candidate.length - baseLines.length);
    final adjustedScore = score + angleBonus - lineCountPenalty;
    if (score >= baseScore - 0.12 && adjustedScore > bestScore + 0.02) {
      bestScore = adjustedScore;
      bestLines = candidate;
    }
  }

  return _recoverMultilineBaseRows(baseLines, bestLines, textMask) ?? bestLines;
}

List<HLine>? _recoverMultilineBaseRows(List<HLine> baseLines, List<HLine> candidateLines, _Mask textMask) {
  if (candidateLines.length != 1 || baseLines.length < 3) return null;
  if (!candidateLines[0].isPolygon) return null;
  if (baseLines.any((l) => l.isPolygon)) return null;

  final height = textMask.height, width = textMask.width;
  final candidateBox = candidateLines[0].axisBox;
  final candidateHeight = math.max(1, candidateBox[3] - candidateBox[1] + 1);
  final candidateWidth = math.max(1, candidateBox[2] - candidateBox[0] + 1);
  if (candidateWidth < width * 0.65 || candidateHeight < height * 0.50) return null;

  final baseBoxes = [for (final l in baseLines) l.axisBox];
  final medianWidth = npMedian(baseBoxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final medianHeight = npMedian(baseBoxes.map((b) => math.max(1, b[3] - b[1] + 1)));
  if (medianHeight <= 0.0) return null;

  final rows = <List<List<int>>>[];
  final rowGap = math.max(8.0, medianHeight * 0.90);
  for (final box in _sorted(baseBoxes, (b) => [(b[1] + b[3]) / 2.0, b[0]])) {
    final centerY = (box[1] + box[3]) / 2.0;
    List<List<int>>? matchedRow;
    for (final row in rows) {
      final rowBox = _unionOfBoxes(row);
      if (rowBox == null) continue;
      final rowCenterY = (rowBox[1] + rowBox[3]) / 2.0;
      final rowHeight = math.max(1, rowBox[3] - rowBox[1] + 1);
      if ((centerY - rowCenterY).abs() <= math.max(rowGap, rowHeight * 0.45)) {
        matchedRow = row;
        break;
      }
    }
    if (matchedRow == null) {
      rows.add([box]);
    } else {
      matchedRow.add(box);
    }
  }

  final recoveredRows = <List<int>>[];
  for (final row in rows) {
    final rowBox = _unionOfBoxes(row);
    if (rowBox == null) continue;
    final rowWidth = math.max(1, rowBox[2] - rowBox[0] + 1);
    final rowHeight = math.max(1, rowBox[3] - rowBox[1] + 1);
    if (rowWidth >= _max([width * 0.28, rowHeight * 2.2, medianWidth * 0.60])) recoveredRows.add(rowBox);
  }

  if (recoveredRows.length < 3) return null;
  final centersY = _sorted([for (final b in recoveredRows) (b[1] + b[3]) / 2.0], (v) => [v]);
  if (centersY.length >= 2 && npMedian(_diff(centersY)) < math.max(6.0, medianHeight * 0.45)) return null;
  if (candidateHeight < medianHeight * 2.4 || candidateWidth < medianWidth * 0.95) return null;
  return [for (final b in recoveredRows) HLine.box(b)];
}

List<HLine> _mergeAlignedHorizontalFragments(List<HLine> lines) {
  if (lines.length <= 1 || lines.any((l) => l.isPolygon)) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  final medianHeight = npMedian(boxes.map((b) => math.max(1, b[3] - b[1] + 1)));
  final rows = <List<List<int>>>[];

  for (final box in _sorted(boxes, (b) => [(b[1] + b[3]) / 2.0, b[0]])) {
    final centerY = (box[1] + box[3]) / 2.0;
    List<List<int>>? matchedRow;
    for (final row in rows) {
      final rowBox = _unionOfBoxes(row);
      if (rowBox == null) continue;
      final rowCenterY = (rowBox[1] + rowBox[3]) / 2.0;
      final verticalOverlap = math.min(rowBox[3], box[3]) - math.max(rowBox[1], box[1]) + 1;
      final minHeight = math.min(rowBox[3] - rowBox[1] + 1, box[3] - box[1] + 1);
      if (verticalOverlap >= minHeight * 0.45 || (centerY - rowCenterY).abs() <= math.max(5.0, medianHeight * 0.45)) {
        matchedRow = row;
        break;
      }
    }
    if (matchedRow == null) {
      rows.add([box]);
    } else {
      matchedRow.add(box);
    }
  }

  final mergedBoxes = <List<int>>[];
  final gapLimit = math.max(14.0, medianHeight * 1.55);
  for (var row in rows) {
    row = _sorted(row, (b) => [b[0]]);
    var current = List.of(row[0]);
    for (final box in row.skip(1)) {
      final gap = box[0] - current[2] - 1;
      final verticalOverlap = math.min(current[3], box[3]) - math.max(current[1], box[1]) + 1;
      final currentHeight = current[3] - current[1] + 1;
      final boxHeight = box[3] - box[1] + 1;
      final minHeight = math.min(currentHeight, boxHeight);
      final heightRatio = math.max(currentHeight, boxHeight) / math.max(1, minHeight);
      if (gap <= gapLimit && verticalOverlap >= minHeight * 0.35 && heightRatio <= 1.8) {
        current = [
          math.min(current[0], box[0]),
          math.min(current[1], box[1]),
          math.max(current[2], box[2]),
          math.max(current[3], box[3]),
        ];
      } else {
        mergedBoxes.add(current);
        current = List.of(box);
      }
    }
    mergedBoxes.add(current);
  }

  if (mergedBoxes.length >= lines.length) return lines;
  return [for (final b in _sorted(mergedBoxes, (b) => [b[1], b[0]])) HLine.box(b)];
}

List<HLine> _detectHorizontalLinesAtAngle(_Mask textMask, num angleDegrees, _InkPoints ink) {
  final height = textMask.height, width = textMask.width;
  if (ink.length == 0) return [HLine.box([0, 0, width, height])];

  final angle = angleDegrees * (math.pi / 180.0);
  final sinA = math.sin(angle);
  final cosA = math.cos(angle);
  final n = ink.length;
  final projectedY = Float64List(n);
  var minP = double.infinity, maxP = -double.infinity;
  for (var i = 0; i < n; i++) {
    final v = -sinA * ink.xs[i] + cosA * ink.ys[i];
    projectedY[i] = v;
    if (v < minP) minP = v;
    if (v > maxP) maxP = v;
  }

  final minProjection = minP.floor();
  final maxProjection = maxP.ceil();
  final bins = Int32List(n);
  var maxBin = 0;
  for (var i = 0; i < n; i++) {
    final b = pyRound(projectedY[i] - minProjection);
    bins[i] = b;
    if (b > maxBin) maxBin = b;
  }
  final counts = List<int>.filled(math.max(maxBin + 1, maxProjection - minProjection + 2), 0);
  for (final b in bins) {
    counts[b]++;
  }
  final tolerance = math.max(1, _int(width * 0.02));

  final spans = <(int, int)>[];
  var start = -1;
  for (var index = 0; index < counts.length; index++) {
    if (counts[index] > tolerance) {
      if (start == -1) start = index;
    } else if (start != -1) {
      spans.add((start, index));
      start = -1;
    }
  }
  if (start != -1) spans.add((start, counts.length));

  // Spans are disjoint; map every bin to its span once.
  final spanOfBin = Int32List(counts.length)..fillRange(0, counts.length, -1);
  for (final (s, (a, b)) in spans.indexed) {
    spanOfBin.fillRange(a, b, s);
  }
  final minX = List<double>.filled(spans.length, double.infinity);
  final maxX = List<double>.filled(spans.length, -double.infinity);
  final minY = List<double>.filled(spans.length, double.infinity);
  final maxY = List<double>.filled(spans.length, -double.infinity);
  final hasInk = List<bool>.filled(spans.length, false);
  for (var i = 0; i < n; i++) {
    final s = spanOfBin[bins[i]];
    if (s < 0) continue;
    hasInk[s] = true;
    final px = cosA * ink.xs[i] + sinA * ink.ys[i];
    final py = projectedY[i];
    if (px < minX[s]) minX[s] = px;
    if (px > maxX[s]) maxX[s] = px;
    if (py < minY[s]) minY[s] = py;
    if (py > maxY[s]) maxY[s] = py;
  }

  final boxes = <HLine>[];
  for (var s = 0; s < spans.length; s++) {
    if (!hasInk[s]) continue;
    if (maxX[s] - minX[s] < 4 && maxY[s] - minY[s] < 4) continue;
    boxes.add(_quadFromRotatedRect(minX[s], minY[s], maxX[s], maxY[s], ink.centerX, ink.centerY, sinA, cosA, width, height));
  }
  return boxes.isNotEmpty ? boxes : [HLine.box([0, 0, width, height])];
}

HLine _quadFromRotatedRect(
  double minX,
  double minY,
  double maxX,
  double maxY,
  double centerX,
  double centerY,
  double sinA,
  double cosA,
  int imageWidth,
  int imageHeight,
) {
  final corners = [(minX, minY), (maxX, minY), (maxX, maxY), (minX, maxY)];
  return HLine.quad([
    for (final (px, py) in corners)
      [
        math.max(0, math.min(imageWidth, pyRound(centerX + cosA * px - sinA * py))),
        math.max(0, math.min(imageHeight, pyRound(centerY + sinA * px + cosA * py))),
      ],
  ]);
}

bool _isLineLikeHorizontalQuadSet(List<HLine> lines) {
  for (final line in lines) {
    final p = line.points;
    if (p == null) return false;
    final edgeWidth = math.max(1.0, _norm2((p[1][0] - p[0][0]).toDouble(), (p[1][1] - p[0][1]).toDouble()));
    final edgeHeight = math.max(1.0, _norm2((p[3][0] - p[0][0]).toDouble(), (p[3][1] - p[0][1]).toDouble()));
    if (edgeWidth / edgeHeight < 3.2) return false;
  }
  return true;
}

bool _hasReasonableReducedSkewThickness(List<HLine> baseLines, List<HLine> candidateLines) {
  if (baseLines.isEmpty) return false;
  final medianBaseHeight = npMedian(baseLines.map((l) {
    final b = l.axisBox;
    return math.max(1, b[3] - b[1] + 1);
  }));
  final candidateHeights = <double>[];
  for (final line in candidateLines) {
    final p = line.points;
    if (p == null) return false;
    candidateHeights.add(math.max(1.0, _norm2((p[3][0] - p[0][0]).toDouble(), (p[3][1] - p[0][1]).toDouble())));
  }
  return candidateHeights.isNotEmpty && _max(candidateHeights) <= medianBaseHeight * 2.6;
}

bool _looksLikeDistinctHorizontalRows(List<HLine> lines) {
  final boxes = [for (final l in lines) l.axisBox];
  if (boxes.length < 2) return false;
  final heights = [for (final b in boxes) math.max(1, b[3] - b[1] + 1)];
  final centersY = _sorted([for (final b in boxes) (b[1] + b[3]) / 2.0], (v) => [v]);
  final medianHeight = npMedian(heights);
  final medianGap = npMedian(_diff(centersY));
  return medianGap >= math.max(8.0, medianHeight * 1.20);
}
