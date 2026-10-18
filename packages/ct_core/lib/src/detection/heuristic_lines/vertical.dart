// Port of modules/detection/heuristic_lines/vertical.py.
part of '../heuristic_lines.dart';

List<HLine> _alignVerticalLinesToDetectorBlock(List<HLine> lines, List<int> blockBox) {
  if (lines.isEmpty) return lines;
  final blockTop = blockBox[1], blockBottom = blockBox[3];
  return [
    for (final line in lines)
      () {
        final box = line.axisBox;
        if (box[1] < blockTop) box[1] = blockTop;
        if (box[3] > blockBottom) box[3] = blockBottom;
        return HLine.box(box);
      }(),
  ];
}

/// Row groups `(start_y, end_y, pixels)` of a box, split at gaps longer
/// than [gapLimit] rows (`y` in mask coordinates).
List<(int, int, int)> _rowGroups(List<int> rowPixels, int y1, int gapLimit) {
  final activeRows = _activeIndices(rowPixels);
  if (activeRows.isEmpty) return [];
  final groups = <(int, int, int)>[];
  var groupStart = activeRows.first;
  var previous = activeRows.first;
  for (final row in activeRows.skip(1)) {
    if (row - previous > gapLimit) {
      groups.add((y1 + groupStart, y1 + previous, _sumRange(rowPixels, groupStart, previous + 1)));
      groupStart = row;
    }
    previous = row;
  }
  groups.add((y1 + groupStart, y1 + previous, _sumRange(rowPixels, groupStart, previous + 1)));
  return groups;
}

List<HLine> _trimDisconnectedVerticalLineTails(List<HLine> lines, _Mask textMask, _MaskStats maskStats) {
  if (lines.isEmpty) return lines;

  final height = textMask.height, width = textMask.width;
  final medianH = math.max(1.0, maskStats.medianH);
  final gapLimit = math.max(24, pyRound(medianH * 1.5));
  final tailGapLimit = math.max(72, pyRound(medianH * 3.0));
  final minTrim = math.max(18, pyRound(medianH * 0.85));

  final trimmed = <HLine>[];
  for (final line in lines) {
    var [x1, y1, x2, y2] = line.axisBox;
    x1 = math.max(0, math.min(width - 1, x1));
    x2 = math.max(0, math.min(width - 1, x2));
    y1 = math.max(0, math.min(height - 1, y1));
    y2 = math.max(0, math.min(height - 1, y2));
    if (x2 < x1 || y2 < y1) {
      trimmed.add(line);
      continue;
    }

    final rowPixels = textMask.slice(y1, y2 + 1, x1, x2 + 1).rowSums();
    if (_activeIndices(rowPixels).length <= 1) {
      trimmed.add(line);
      continue;
    }
    final groups = _rowGroups(rowPixels, y1, gapLimit);
    if (groups.length <= 1) {
      trimmed.add(line);
      continue;
    }

    final mainIndex = _argmax([for (final g in groups) g.$3]);
    final mainPixels = math.max(1, groups[mainIndex].$3);
    var selectedEnd = groups[mainIndex].$2;
    var cutTail = false;
    var cutGap = 0;
    for (final (groupStartY, groupEndY, groupPixels) in groups.skip(mainIndex + 1)) {
      final gap = groupStartY - selectedEnd - 1;
      final groupHeight = groupEndY - groupStartY + 1;
      final weakTail = groupPixels <= mainPixels * 0.75;
      final tinyTail = groupPixels <= mainPixels * 0.20 || groupHeight <= math.max(8.0, medianH * 0.75);
      if (gap >= tailGapLimit && (weakTail || tinyTail)) {
        cutTail = true;
        cutGap = gap;
        break;
      }
      selectedEnd = groupEndY;
    }

    if (cutTail) {
      final lineWidth = math.max(1, x2 - x1 + 1);
      final slackLimit = math.max(18.0, _min([96.0, medianH * 2.5, lineWidth * 1.75, cutGap * 0.35]).toDouble());
      selectedEnd = math.min(y2, selectedEnd + pyRound(math.min(math.max(0, cutGap - 1), slackLimit)));
    }

    final keptHeight = selectedEnd - y1 + 1;
    final originalHeight = y2 - y1 + 1;
    final mainHeight = groups[mainIndex].$2 - groups[mainIndex].$1 + 1;
    if (!cutTail ||
        y2 - selectedEnd < minTrim ||
        mainHeight < math.max(36.0, medianH * 1.75) ||
        keptHeight < originalHeight * 0.55) {
      trimmed.add(line);
      continue;
    }

    final bounds = _maskBounds(textMask.slice(y1, selectedEnd + 1, x1, x2 + 1));
    if (bounds == null) {
      trimmed.add(HLine.box([x1, y1, x2, selectedEnd]));
      continue;
    }
    trimmed.add(HLine.box([x1 + bounds[0], y1, x1 + bounds[2], y1 + bounds[3]]));
  }
  return trimmed;
}

List<HLine> _dropNestedVerticalLineDuplicates(List<HLine> lines) {
  if (lines.length <= 1) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  final keep = <HLine>[];
  for (final (index, box) in boxes.indexed) {
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    final boxHeight = math.max(1, box[3] - box[1] + 1);
    var nestedDuplicate = false;
    for (final (otherIndex, other) in boxes.indexed) {
      if (index == otherIndex) continue;
      final otherWidth = math.max(1, other[2] - other[0] + 1);
      final otherHeight = math.max(1, other[3] - other[1] + 1);
      if (otherWidth < boxWidth * 1.75 || otherHeight < boxHeight * 1.10) continue;
      final overlapX = math.min(box[2], other[2]) - math.max(box[0], other[0]) + 1;
      final overlapY = math.min(box[3], other[3]) - math.max(box[1], other[1]) + 1;
      if (overlapX >= boxWidth * 0.70 && overlapY >= boxHeight * 0.85) {
        nestedDuplicate = true;
        break;
      }
    }
    if (!nestedDuplicate) keep.add(lines[index]);
  }
  return keep;
}

List<HLine> _widenSkinnyVerticalLinesBySpacing(List<HLine> lines, int width, _MaskStats maskStats) {
  if (lines.length < 2 || lines.length > 6) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  final medianLineWidth = npMedian(boxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final medianH = math.max(1.0, maskStats.medianH);
  final indexedBoxes = _sorted(boxes.indexed, (e) => [(e.$2[0] + e.$2[2]) / 2.0]);
  final centers = [for (final b in boxes) (b[0] + b[2]) / 2.0];

  final widened = List.of(lines);
  for (final (sortedIndex, (lineIndex, box)) in indexedBoxes.indexed) {
    final [x1, y1, x2, y2] = box;
    final lineWidth = math.max(1, x2 - x1 + 1);
    final lineHeight = math.max(1, y2 - y1 + 1);
    if (lineWidth > 44) continue;
    if (lineWidth >= medianLineWidth * 0.82) continue;
    if (lineHeight < _max([180.0, medianH * 12.0, lineWidth * 8.0])) continue;

    final center = centers[lineIndex];
    final desiredWidth = math.min(lineWidth + 40.0, _max([48.0, medianLineWidth * 1.45, lineWidth * 1.60]).toDouble());
    final desiredLeft = (center - desiredWidth / 2.0).floor();
    final desiredRight = (center + desiredWidth / 2.0).ceil();

    var leftLimit = 0;
    if (sortedIndex > 0) {
      final prevIndex = indexedBoxes[sortedIndex - 1].$1;
      leftLimit = ((centers[prevIndex] + center) / 2.0).floor() + 1;
    }
    var rightLimit = width - 1;
    if (sortedIndex + 1 < indexedBoxes.length) {
      final nextIndex = indexedBoxes[sortedIndex + 1].$1;
      rightLimit = ((center + centers[nextIndex]) / 2.0).ceil() - 1;
    }

    final newX1 = math.min(x1, _max([0, leftLimit, desiredLeft]).toInt());
    final newX2 = math.max(x2, _min([width - 1, rightLimit, desiredRight]).toInt());
    if (newX2 <= newX1) continue;
    widened[lineIndex] = HLine.box([newX1, y1, newX2, y2]);
  }
  return widened;
}

/// `np.convolve(values, np.ones(window) / window, mode="same")`.
List<double> _movingAverageSame(List<double> values, int window) {
  final kernel = 1 / window;
  final n = values.length, m = window;
  final longer = math.max(n, m), shorter = math.min(n, m);
  // Full convolution index k = j + (shorter - 1 - shorter ~/ 2).
  final offset = shorter - 1 - shorter ~/ 2;
  return [
    for (var j = 0; j < longer; j++)
      () {
        final k = j + offset;
        var s = 0.0;
        for (var i = math.max(0, k - m + 1); i <= math.min(k, n - 1); i++) {
          s += values[i] * kernel;
        }
        return s;
      }(),
  ];
}

List<HLine> _splitTallVerticalLinesOnValleys(List<HLine> lines, _Mask textMask, _MaskStats maskStats) {
  if (lines.length > 4) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  if (boxes.isEmpty) return lines;
  final medianWidth = npMedian(boxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final medianH = math.max(1.0, maskStats.medianH);
  final splitLines = <HLine>[];
  for (final box in boxes) {
    final [x1, y1, x2, y2] = box;
    final boxWidth = math.max(1, x2 - x1 + 1);
    final boxHeight = math.max(1, y2 - y1 + 1);
    if (boxWidth < math.max(56.0, medianWidth * 1.25)) {
      splitLines.add(HLine.box(box));
      continue;
    }
    if (boxHeight < _max([420.0, medianH * 18.0, boxWidth * 4.0])) {
      splitLines.add(HLine.box(box));
      continue;
    }

    final region = textMask.slice(y1, y2 + 1, x1, x2 + 1);
    final rowPixels = [for (final v in region.rowSums()) v.toDouble()];
    if (rowPixels.length < 80 || _max(rowPixels) <= 0) {
      splitLines.add(HLine.box(box));
      continue;
    }

    var window = math.max(9, pyRound(medianH * 0.75));
    if (window.isEven) window++;
    final smoothRows = _movingAverageSame(rowPixels, window);
    final smoothMax = _max(smoothRows).toDouble();
    final valleyThreshold = math.max(1.0, smoothMax * 0.20);
    final edgeMargin = math.max(20, pyRound(boxHeight * 0.08));

    final lowRows = [
      for (var i = 0; i < smoothRows.length; i++)
        if (smoothRows[i] <= valleyThreshold) i,
    ];
    var valleyRuns = <(int, int, double)>[];
    if (lowRows.isNotEmpty) {
      var runStart = lowRows.first;
      var previous = lowRows.first;
      for (final row in lowRows.skip(1)) {
        if (row - previous > 1) {
          valleyRuns.add((runStart, previous, npMean(smoothRows.sublist(runStart, previous + 1))));
          runStart = row;
        }
        previous = row;
      }
      valleyRuns.add((runStart, previous, npMean(smoothRows.sublist(runStart, previous + 1))));
    }

    final minValleyLen = math.max(12, pyRound(medianH * 0.6));
    valleyRuns = [
      for (final run in valleyRuns)
        if (run.$1 >= edgeMargin && run.$2 <= rowPixels.length - 1 - edgeMargin && (run.$2 - run.$1 + 1) >= minValleyLen)
          run,
    ];
    if (valleyRuns.isEmpty) {
      splitLines.add(HLine.box(box));
      continue;
    }

    (List<int>, List<int>)? bestSplit;
    List<double>? bestScore;
    for (final (runStart, runEnd, meanValley) in valleyRuns) {
      final splitRow = pyRound((runStart + runEnd) / 2.0);
      final upperRegion = region.slice(0, splitRow, 0, region.width);
      final lowerRegion = region.slice(splitRow + 1, region.height, 0, region.width);
      final upperBounds = upperRegion.size > 0 ? _maskBounds(upperRegion) : null;
      final lowerBounds = lowerRegion.size > 0 ? _maskBounds(lowerRegion) : null;
      if (upperBounds == null || lowerBounds == null) continue;

      final upperBox = [x1 + upperBounds[0], y1 + upperBounds[1], x1 + upperBounds[2], y1 + upperBounds[3]];
      final lowerBox = [
        x1 + lowerBounds[0],
        y1 + splitRow + 1 + lowerBounds[1],
        x1 + lowerBounds[2],
        y1 + splitRow + 1 + lowerBounds[3],
      ];
      final upperHeight = math.max(1, upperBox[3] - upperBox[1] + 1);
      final lowerHeight = math.max(1, lowerBox[3] - lowerBox[1] + 1);
      final minSideHeight = _max([100.0, boxWidth * 1.2, medianH * 4.0]);
      if (upperHeight < minSideHeight || lowerHeight < minSideHeight) continue;

      final upperPeak = runStart > 0 ? _max(smoothRows.sublist(0, runStart)).toDouble() : 0.0;
      final lowerPeak = runEnd + 1 < smoothRows.length ? _max(smoothRows.sublist(runEnd + 1)).toDouble() : 0.0;
      if (upperPeak < smoothMax * 0.35 || lowerPeak < smoothMax * 0.35) continue;

      final balance = math.min(upperHeight, lowerHeight) / math.max(upperHeight, lowerHeight);
      final score = [balance, -meanValley, math.min(upperPeak, lowerPeak), -(runEnd - runStart + 1).toDouble()];
      if (bestScore == null || _cmpTuple(score, bestScore) > 0) {
        bestScore = score;
        bestSplit = (upperBox, lowerBox);
      }
    }

    if (bestSplit == null) {
      splitLines.add(HLine.box(box));
      continue;
    }
    splitLines
      ..add(HLine.box(bestSplit.$1))
      ..add(HLine.box(bestSplit.$2));
  }
  return splitLines;
}

List<HLine> _mergeFragmentedTopEdgeVerticalLines(List<HLine> lines, _Mask textMask, _MaskStats maskStats) {
  if (lines.length < 6 || lines.length > 12) return lines;

  final height = textMask.height;
  final boxes = _sorted([for (final l in lines) l.axisBox], (b) => [b[0]]);
  final medianWidth = npMedian(boxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  final topLimit = math.max(6, pyRound(height * 0.05));
  final merged = <HLine>[];
  var index = 0;
  while (index < boxes.length) {
    final current = boxes[index];
    if (index + 1 < boxes.length) {
      final pair = _mergeTopAlignedVerticalPair(current, boxes[index + 1], textMask, medianWidth, topLimit);
      if (pair != null) {
        merged.add(HLine.box(pair));
        index += 2;
        continue;
      }
      final fragment =
          _mergeTopEdgeFragmentIntoNeighbor(current, boxes[index + 1], textMask, medianWidth, topLimit, height);
      if (fragment != null) {
        merged.add(HLine.box(fragment));
        index += 2;
        continue;
      }
    }
    merged.add(HLine.box(current));
    index++;
  }
  return merged;
}

List<HLine> _repairFragmentedVerticalBlocksWithRawSupport(
  List<HLine> lines,
  List<List<int>> rawVerticalLines,
  _Mask textMask,
  _MaskStats maskStats,
) {
  if (lines.length < 5 || lines.length > 10) return lines;
  if (rawVerticalLines.length < lines.length + 4) return lines;

  final height = textMask.height, width = textMask.width;
  final topLimit = math.max(6, pyRound(height * 0.05));
  final boxes = _sorted([for (final l in lines) l.axisBox], (b) => [b[0]]);
  final topCount = boxes.where((b) => b[1] <= topLimit).length;
  if (topCount < math.max(3, boxes.length ~/ 2)) return lines;

  final medianH = math.max(1.0, maskStats.medianH);
  final gapLimit = math.max(24, pyRound(medianH * 1.5));
  final grownBoxes = <List<int>>[];
  for (final box in boxes) {
    final lowerDominant = _lowerDominantVerticalGroupBox(box, textMask, gapLimit, topLimit, medianH);
    if (lowerDominant != null) {
      grownBoxes.add(_padLineBoxes([HLine.box(lowerDominant)], _vertical, width, height)[0].axisBox);
    } else {
      grownBoxes.add(box);
    }
  }

  final nonTopBottoms = [for (final b in grownBoxes) if (b[1] > topLimit) b[3]];
  final bottomCap = nonTopBottoms.isNotEmpty ? _max(nonTopBottoms).toInt() : null;
  final adjustedBoxes = <List<int>>[];
  for (final box in grownBoxes) {
    final aligned = _alignedRawVerticalSupportBoxes(box, rawVerticalLines);
    if (aligned.isEmpty) {
      adjustedBoxes.add(box);
      continue;
    }
    final rawTop = _min(aligned.map((b) => b[1])).toInt();
    final rawBottom = _max(aligned.map((b) => b[3])).toInt();
    final topExtensionLimit = math.max(20, pyRound(medianH * 2.0));
    final bottomExtensionLimit = math.max(80, pyRound(medianH * 6.0));
    if (box[1] > topLimit && rawTop + topExtensionLimit < box[1]) {
      adjustedBoxes.add([box[0], rawTop, box[2], box[3]]);
      continue;
    }
    if (box[1] <= topLimit &&
        bottomCap != null &&
        box[3] < bottomCap - bottomExtensionLimit &&
        rawBottom > box[3] + bottomExtensionLimit) {
      adjustedBoxes.add([box[0], box[1], box[2], math.min(rawBottom, bottomCap)]);
      continue;
    }
    adjustedBoxes.add(box);
  }

  final kept = <HLine>[];
  for (final (index, box) in adjustedBoxes.indexed) {
    final boxWidth = math.max(1, box[2] - box[0] + 1);
    final boxHeight = math.max(1, box[3] - box[1] + 1);
    final aligned = _alignedRawVerticalSupportBoxes(box, rawVerticalLines);
    final rawBottom = aligned.isEmpty ? box[3] : _max(aligned.map((b) => b[3])).toInt();
    var shouldDrop = false;
    if (box[1] <= topLimit &&
        boxHeight <= math.max(300.0, height * 0.24) &&
        rawBottom <= box[3] + math.max(24, pyRound(medianH * 2.0)) &&
        index + 1 < adjustedBoxes.length) {
      final nextBox = adjustedBoxes[index + 1];
      final nextHeight = math.max(1, nextBox[3] - nextBox[1] + 1);
      final gapX = nextBox[0] - box[2] - 1;
      if (gapX <= math.max(14, pyRound(boxWidth * 0.25)) && nextHeight >= boxHeight * 2.8) shouldDrop = true;
    }
    if (!shouldDrop) kept.add(HLine.box(box));
  }
  return kept;
}

List<int>? _lowerDominantVerticalGroupBox(List<int> box, _Mask textMask, int gapLimit, int topLimit, double medianH) {
  if (box[1] <= topLimit) return null;

  final groups = _rowGroupsInVerticalBox(textMask, box, gapLimit);
  if (groups.length < 2) return null;

  final firstGroup = groups.first;
  final lastGroup = groups.last;
  final gapY = lastGroup.$1 - firstGroup.$2 - 1;
  if (gapY < math.max(72, pyRound(medianH * 3.0))) return null;
  if (lastGroup.$3 < firstGroup.$3 * 1.8) return null;

  final bounds = _maskBounds(textMask.slice(lastGroup.$1, lastGroup.$2 + 1, box[0], box[2] + 1));
  if (bounds == null) return null;
  return [box[0] + bounds[0], lastGroup.$1 + bounds[1], box[0] + bounds[2], lastGroup.$1 + bounds[3]];
}

List<List<int>> _alignedRawVerticalSupportBoxes(List<int> box, List<List<int>> rawVerticalLines) {
  final aligned = <List<int>>[];
  final boxWidth = math.max(1, box[2] - box[0] + 1);
  final boxCenter = (box[0] + box[2]) / 2.0;
  for (final raw in rawVerticalLines) {
    final rawWidth = math.max(1, raw[2] - raw[0] + 1);
    final overlapX = math.min(box[2], raw[2]) - math.max(box[0], raw[0]) + 1;
    final rawCenter = (raw[0] + raw[2]) / 2.0;
    if (overlapX >= math.min(boxWidth, rawWidth) * 0.35 || (rawCenter - boxCenter).abs() <= math.max(10.0, boxWidth * 0.30)) {
      aligned.add(raw);
    }
  }
  return aligned;
}

List<(int, int, int)> _rowGroupsInVerticalBox(_Mask textMask, List<int> box, int gapLimit) {
  final [x1, y1, x2, y2] = box;
  final rowPixels = textMask.slice(y1, y2 + 1, x1, x2 + 1).rowSums();
  return _rowGroups(rowPixels, y1, gapLimit);
}

List<int>? _mergeTopAlignedVerticalPair(
  List<int> current,
  List<int> candidate,
  _Mask textMask,
  double medianWidth,
  int topLimit,
) {
  final currentWidth = math.max(1, current[2] - current[0] + 1);
  final candidateWidth = math.max(1, candidate[2] - candidate[0] + 1);
  final currentHeight = math.max(1, current[3] - current[1] + 1);
  final candidateHeight = math.max(1, candidate[3] - candidate[1] + 1);
  final gap = candidate[0] - current[2] - 1;
  final overlapX = math.min(current[2], candidate[2]) - math.max(current[0], candidate[0]) + 1;

  final bothTopAligned = current[1] <= topLimit && candidate[1] <= topLimit;
  final similarHeight =
      math.min(currentHeight, candidateHeight) >= math.max(currentHeight, candidateHeight) * 0.45;
  final touching = gap <= math.max(2, pyRound(medianWidth * 0.10)) || overlapX > 0;
  final moderateWidth = math.max(currentWidth, candidateWidth) <= math.max(90.0, medianWidth * 4.5);
  final substantialPair = overlapX > 0 || math.min(currentWidth, candidateWidth) >= medianWidth * 1.4;
  if (!(bothTopAligned && similarHeight && touching && moderateWidth && substantialPair)) return null;
  return _mergedVerticalPairBounds(current, candidate, textMask);
}

List<int>? _mergeTopEdgeFragmentIntoNeighbor(
  List<int> current,
  List<int> candidate,
  _Mask textMask,
  double medianWidth,
  int topLimit,
  int height,
) {
  final currentWidth = math.max(1, current[2] - current[0] + 1);
  final currentHeight = math.max(1, current[3] - current[1] + 1);
  final candidateHeight = math.max(1, candidate[3] - candidate[1] + 1);
  final gap = candidate[0] - current[2] - 1;

  final isSmallTopFragment = current[1] <= topLimit &&
      currentWidth <= math.max(24.0, medianWidth * 0.8) &&
      currentHeight <= math.max(height * 0.30, 260.0);
  final isTallNeighbor = candidateHeight >= math.max(currentHeight * 2.0, height * 0.45);
  if (!(isSmallTopFragment && isTallNeighbor)) return null;
  if (gap > math.max(14, pyRound(medianWidth * 0.8))) return null;
  return _mergedVerticalPairBounds(current, candidate, textMask);
}

List<int>? _mergedVerticalPairBounds(List<int> left, List<int> right, _Mask textMask) {
  final x1 = math.min(left[0], right[0]);
  final y1 = math.min(left[1], right[1]);
  final x2 = math.max(left[2], right[2]);
  final y2 = math.max(left[3], right[3]);
  final bounds = _maskBounds(textMask.slice(y1, y2 + 1, x1, x2 + 1));
  if (bounds == null) return null;
  return [x1 + bounds[0], y1 + bounds[1], x1 + bounds[2], y1 + bounds[3]];
}
