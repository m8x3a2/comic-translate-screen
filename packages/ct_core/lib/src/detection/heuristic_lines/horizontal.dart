// Port of modules/detection/heuristic_lines/horizontal.py.
part of '../heuristic_lines.dart';

List<HLine> _collapseEdgeSpanningHorizontalFragments(List<HLine> lines, _Mask textMask, List<HLine> verticalLines) {
  if (lines.length <= 1) return lines;
  if (lines.length > 4 || verticalLines.length < 2) return lines;

  final height = textMask.height, width = textMask.width;
  if (width <= 0 || height <= 0) return lines;

  final boxes = [for (final l in lines) l.axisBox];
  final edgeMargin = math.max(2, pyRound(height * 0.04));
  final minEdgeWidth = math.max(12, pyRound(width * 0.25));

  bool isWideTopEdge(List<int> b) => b[1] <= edgeMargin && (b[2] - b[0] + 1) >= minEdgeWidth;
  bool isWideBottomEdge(List<int> b) => b[3] >= height - 1 - edgeMargin && (b[2] - b[0] + 1) >= minEdgeWidth;

  if (!boxes.any(isWideTopEdge) || !boxes.any(isWideBottomEdge)) return lines;

  final heights = [for (final b in boxes) b[3] - b[1] + 1];
  final medianH = heights.isNotEmpty ? npMedian(heights) : 0.0;
  final ratio = height > 0 ? medianH / height : 0.0;

  // Lines that are thin relative to the crop are border noise: collapse them.
  // Otherwise keep them when they are vertically separated rows.
  if (ratio >= 0.25) {
    final sortedBoxes = _sorted(boxes, (b) => [(b[1] + b[3]) / 2.0]);
    for (var i = 0; i < sortedBoxes.length - 1; i++) {
      final b1 = sortedBoxes[i], b2 = sortedBoxes[i + 1];
      final h1 = b1[3] - b1[1] + 1;
      final h2 = b2[3] - b2[1] + 1;
      final overlap = math.min(b1[3], b2[3]) - math.max(b1[1], b2[1]) + 1;
      final minH = math.min(h1, h2);
      if (minH > 0 && overlap / minH < 0.40) return lines;
    }
  }

  final union = _unionBox(lines);
  if (union == null) return lines;
  final unionWidth = math.max(1, union[2] - union[0] + 1);
  final unionHeight = math.max(1, union[3] - union[1] + 1);
  if (unionWidth < width * 0.55 || unionHeight < height * 0.70) return lines;
  return [HLine.box(union)];
}

(List<HLine>, _Mask) _replaceLowDensityLineWithInverseMask(RgbImage image, List<HLine> lines, _Mask textMask) {
  if (lines.length != 1) return (lines, textMask);

  final height = textMask.height, width = textMask.width;
  final box = lines[0].axisBox;
  final lineWidth = math.max(1, box[2] - box[0] + 1);
  final lineHeight = math.max(1, box[3] - box[1] + 1);
  final currentDensity = _lineBoxDensity(textMask, box);

  _Mask? inverseMask;
  if (lineWidth >= width * 0.55 && lineHeight >= height * 0.60 && currentDensity < 0.08) {
    inverseMask = _prepareInverseTextMask(image);
    if (inverseMask != null && inverseMask.any()) {
      final expandedTitleLine = _largeInverseComponentTitleLine(inverseMask, box);
      if (expandedTitleLine != null) return ([HLine.box(expandedTitleLine)], inverseMask);
    }
  }

  if (lineWidth < width * 0.65 || lineHeight < height * 0.65) return (lines, textMask);
  if (currentDensity >= 0.08) return (lines, textMask);

  inverseMask ??= _prepareInverseTextMask(image);
  if (inverseMask == null || !inverseMask.any()) return (lines, textMask);

  var inverseLines = _detectHorizontalLinesSkewAware(inverseMask);
  final inverseVerticalLines = _filterNoiseLines(_detectLinesFromMask(inverseMask, _vertical), _vertical);
  inverseLines = _trimMarginalVerticalNoiseFromHorizontalLines(inverseLines, inverseMask, inverseVerticalLines);
  if (inverseLines.length != 1) return (lines, textMask);

  final inverseBox = inverseLines[0].axisBox;
  final inverseHeight = math.max(1, inverseBox[3] - inverseBox[1] + 1);
  final inverseDensity = _lineBoxDensity(inverseMask, inverseBox);
  if (inverseHeight >= lineHeight * 0.80) return (lines, textMask);
  if (inverseDensity < math.max(0.12, currentDensity * 2.0)) return (lines, textMask);
  return (inverseLines, inverseMask);
}

List<int>? _largeInverseComponentTitleLine(_Mask inverseMask, List<int> currentBox) {
  final height = inverseMask.height, width = inverseMask.width;
  final cc = inverseMask.components();
  if (cc.count <= 1) return null;

  final minArea = math.max(900, pyRound(inverseMask.size * 0.0018));
  final minWidth = math.max(35, pyRound(width * 0.025));
  final minHeight = math.max(35, pyRound(height * 0.10));
  final selected = <List<int>>[];
  for (var label = 1; label < cc.count; label++) {
    final s = cc.stats[label];
    if (s.area < minArea) continue;
    if (s.width < minWidth && s.height < minHeight) continue;
    final x2 = s.left + s.width - 1;
    final y2 = s.top + s.height - 1;
    final density = s.area / math.max(1, s.width * s.height);
    // Top-edge hatching can survive inverse cleanup in title banners.
    if (s.top <= pyRound(height * 0.06) && s.height >= pyRound(height * 0.28) && density < 0.36) continue;
    selected.add([s.left, s.top, x2, y2]);
  }
  if (selected.length < 4) return null;

  final union = _unionOfBoxes(selected);
  if (union == null) return null;
  final unionWidth = math.max(1, union[2] - union[0] + 1);
  final unionHeight = math.max(1, union[3] - union[1] + 1);
  final currentWidth = math.max(1, currentBox[2] - currentBox[0] + 1);
  if (unionWidth < math.max(width * 0.55, currentWidth * 1.15)) return null;
  if (unionHeight < height * 0.35) return null;
  if (union[1] <= 4 && union[3] >= height - 5) return null;
  return union;
}

double _lineBoxDensity(_Mask textMask, List<int> box) {
  final height = textMask.height, width = textMask.width;
  final x1 = math.max(0, math.min(width - 1, box[0]));
  final y1 = math.max(0, math.min(height - 1, box[1]));
  final x2 = math.max(0, math.min(width - 1, box[2]));
  final y2 = math.max(0, math.min(height - 1, box[3]));
  if (x2 < x1 || y2 < y1) return 0.0;
  final area = math.max(1, (x2 - x1 + 1) * (y2 - y1 + 1));
  return textMask.slice(y1, y2 + 1, x1, x2 + 1).sum() / area;
}
