// Port of modules/detection/heuristic_lines/core.py.
part of '../heuristic_lines.dart';

(List<HLine>, String) _detectLinesAndDirectionInCrop(RgbImage image, String sourceLanguage) {
  final height = image.height, width = image.width;
  if (width <= 1 || height <= 1) {
    final box = [0, 0, math.max(0, width), math.max(0, height)];
    return ([HLine.box(box)], _fallbackDirection(box, sourceLanguage));
  }

  var textMask = _prepareTextMask(image);
  if (textMask == null || !textMask.any()) {
    final box = [0, 0, width, height];
    return ([HLine.box(box)], _fallbackDirection(box, sourceLanguage));
  }
  final maskStats = _computeMaskStats(textMask);

  final horizontalLines = _detectHorizontalLinesSkewAware(textMask);
  var verticalLines = _filterNoiseLines(_detectLinesFromMask(textMask, _vertical), _vertical);
  final rawVerticalLines = [for (final l in verticalLines) l.axisBox];
  final componentVerticalLines =
      _detectSparseVerticalComponentColumns(textMask, componentBoxes: maskStats.componentBoxes);

  final horizontalScore = _scoreLineCandidate(horizontalLines, _horizontal, textMask, maskStats);
  final verticalScore = _scoreLineCandidate(verticalLines, _vertical, textMask, maskStats);
  final hasStructuredVerticalColumns = _looksLikeStructuredVerticalColumns(textMask, componentVerticalLines);

  String direction;
  if (_isLargeGlyphHorizontal(textMask, horizontalLines, verticalLines, maskStats)) {
    direction = _horizontal;
  } else if (_isMultilineHorizontalText(horizontalLines, verticalLines)) {
    direction = _horizontal;
  } else if (hasStructuredVerticalColumns &&
      _structuredColumnsShouldOverrideHorizontal(
        textMask,
        horizontalLines,
        verticalLines,
        componentVerticalLines,
        horizontalScore,
        verticalScore,
      )) {
    if (_shouldUseComponentVerticalColumns(textMask, verticalLines, componentVerticalLines)) {
      verticalLines = componentVerticalLines;
    }
    direction = _vertical;
  } else if (_isFragmentedRotatedHorizontalText(textMask, horizontalLines, verticalLines)) {
    direction = _horizontal;
  } else if (_isSparseHorizontalOverfit(
    textMask,
    horizontalLines,
    verticalLines,
    horizontalScore,
    verticalScore,
    maskStats,
  )) {
    if (componentVerticalLines.isNotEmpty) verticalLines = componentVerticalLines;
    direction = _vertical;
  } else if ((horizontalScore - verticalScore).abs() < 0.2) {
    final union = _unionBox([...horizontalLines, ...verticalLines]) ?? [0, 0, width, height];
    direction = _fallbackDirection(union, sourceLanguage);
  } else {
    direction = verticalScore > horizontalScore ? _vertical : _horizontal;
  }

  var maskWasSplit = false;
  List<HLine> lines;
  if (direction == _horizontal) {
    if (horizontalLines.any((l) => l.isPolygon)) {
      lines = horizontalLines;
    } else {
      final subMasks = _splitMaskByTallVerticalColumns(textMask);
      if (subMasks.length > 1) {
        final full = [0, 0, width, height];
        lines = [
          for (final subMask in subMasks)
            for (final l in _detectHorizontalLinesSkewAware(subMask))
              if (!l.equalsBox(full)) l,
        ];
        maskWasSplit = true;
      } else {
        lines = horizontalLines;
      }
    }
    lines = _trimMarginalVerticalNoiseFromHorizontalLines(
      lines,
      textMask,
      verticalLines,
      componentBoxes: maskStats.componentBoxes,
      integralImage: maskStats.integral,
    );
    lines = _collapseEdgeSpanningHorizontalFragments(lines, textMask, verticalLines);
    (lines, textMask) = _replaceLowDensityLineWithInverseMask(image, lines, textMask);
    lines = _mergeSmallHorizontalFragments(lines);
    lines = _filterMarginalHorizontalArtifacts(lines, textMask);
  } else {
    if (_shouldUseComponentVerticalColumns(textMask, verticalLines, componentVerticalLines) ||
        _shouldAddOneComponentVerticalColumn(
          textMask,
          verticalLines,
          componentVerticalLines,
          horizontalScore,
          verticalScore,
        )) {
      verticalLines = componentVerticalLines;
    }
    lines = _trimDisconnectedVerticalLineTails(verticalLines, textMask, maskStats);
    lines = _dropNestedVerticalLineDuplicates(lines);
  }

  if (lines.isEmpty) lines = [HLine.box([0, 0, width, height])];
  lines = _padLineBoxes(lines, direction, width, height);
  if (direction == _vertical) {
    lines = _widenSkinnyVerticalLinesBySpacing(lines, width, maskStats);
    lines = _splitTallVerticalLinesOnValleys(lines, textMask, maskStats);
    lines = _mergeFragmentedTopEdgeVerticalLines(lines, textMask, maskStats);
    lines = _repairFragmentedVerticalBlocksWithRawSupport(lines, rawVerticalLines, textMask, maskStats);
  }

  // Drop wrong-direction noise (e.g. vertical strokes in a horizontal block).
  if (!maskWasSplit) {
    try {
      final finalStats = identical(textMask, maskStats.mask) ? maskStats : _computeMaskStats(textMask);
      final medianW = finalStats.medianW;
      final medianH = finalStats.medianH;
      final filtered = <HLine>[];
      for (final line in lines) {
        final [x1, y1, x2, y2] = line.axisBox;
        final lineW = math.max(1, x2 - x1 + 1);
        final lineH = math.max(1, y2 - y1 + 1);
        if (direction == _horizontal) {
          if (lineH > lineW && lineH > 2.0 * medianH) continue;
        } else {
          if (lineW > lineH && lineW > 2.0 * medianW) continue;
        }
        filtered.add(line);
      }
      if (filtered.isNotEmpty) lines = filtered;
    } catch (_) {
      // The original prints the error and keeps the unfiltered lines.
    }
  }

  return (lines, direction);
}
