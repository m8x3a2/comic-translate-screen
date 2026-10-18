// Port of modules/detection/heuristic_lines/column_routing.py.
part of '../heuristic_lines.dart';

bool _shouldUseComponentVerticalColumns(_Mask textMask, List<HLine> verticalLines, List<HLine> componentLines) {
  if (_looksLikeSingleComponentVerticalColumn(textMask, verticalLines, componentLines)) return true;
  if (!_looksLikeStructuredVerticalColumns(textMask, componentLines)) return false;

  final height = textMask.height, width = textMask.width;
  final rawBoxes = [for (final l in verticalLines) l.axisBox];
  final componentBoxes = [for (final l in componentLines) l.axisBox];
  if (rawBoxes.isEmpty || componentBoxes.isEmpty) return false;

  final hasMergedRawColumn = rawBoxes.any((b) => (b[2] - b[0] + 1) >= width * 0.45);
  final nRaw = verticalLines.length, nComp = componentLines.length;
  if (nRaw <= 2 && nComp > nRaw && nComp <= 6) {
    if (!hasMergedRawColumn) return false;
    if (nComp < 4 && _componentColumnsHaveStrongOverlap(componentBoxes)) return false;
    return true;
  }

  if (nComp < nRaw) return _hasSkinnyRawVerticalArtifacts(rawBoxes);
  if (nComp == nRaw) return false;
  if (nComp > nRaw) {
    if (nComp > math.min(6, nRaw + 1)) return false;
    if (!hasMergedRawColumn) return false;
  }
  if (nComp <= nRaw || nComp > 6) return false;
  if (!hasMergedRawColumn) return false;

  var verticalishComponents = 0;
  for (final b in componentBoxes) {
    final boxWidth = math.max(1, b[2] - b[0] + 1);
    final boxHeight = math.max(1, b[3] - b[1] + 1);
    if (boxHeight >= math.max(height * 0.25, boxWidth * 1.8)) verticalishComponents++;
  }
  return verticalishComponents >= math.max(2, componentBoxes.length - 1);
}

bool _hasSkinnyRawVerticalArtifacts(List<List<int>> rawBoxes) {
  if (rawBoxes.length < 2) return false;
  final widths = [for (final b in rawBoxes) math.max(1, b[2] - b[0] + 1).toDouble()];
  final heights = [for (final b in rawBoxes) math.max(1, b[3] - b[1] + 1).toDouble()];
  final skinnyLimit = math.max(4.0, npMedian(widths) * 0.25);
  final tallLimit = math.max(40.0, npMedian(heights) * 0.25);
  for (var i = 0; i < widths.length; i++) {
    if (widths[i] <= skinnyLimit && heights[i] >= tallLimit) return true;
  }
  return false;
}

bool _shouldAddOneComponentVerticalColumn(
  _Mask textMask,
  List<HLine> verticalLines,
  List<HLine> componentLines,
  double horizontalScore,
  double verticalScore,
) {
  if (componentLines.length != verticalLines.length + 1) return false;
  if (componentLines.length > 5) return false;
  if (horizontalScore >= 0.0 || verticalScore < horizontalScore + 1.5) return false;
  if (!_looksLikeStructuredVerticalColumns(textMask, componentLines)) return false;
  return !_componentColumnsHaveStrongOverlap([for (final l in componentLines) l.axisBox]);
}

bool _componentColumnsHaveStrongOverlap(List<List<int>> componentBoxes) {
  if (componentBoxes.length < 2) return false;
  final boxes = _sorted(componentBoxes, (b) => [b[0]]);
  for (var i = 0; i + 1 < boxes.length; i++) {
    final left = boxes[i], right = boxes[i + 1];
    final overlap = math.min(left[2], right[2]) - math.max(left[0], right[0]) + 1;
    if (overlap <= 0) continue;
    final minWidth = math.min(left[2] - left[0] + 1, right[2] - right[0] + 1);
    if (overlap >= minWidth * 0.55) return true;
  }
  return false;
}

bool _looksLikeSingleComponentVerticalColumn(_Mask textMask, List<HLine> verticalLines, List<HLine> componentLines) {
  if (componentLines.length != 1 || verticalLines.length <= 1) return false;

  final componentBox = componentLines[0].axisBox;
  final componentWidth = math.max(1, componentBox[2] - componentBox[0] + 1);
  final componentHeight = math.max(1, componentBox[3] - componentBox[1] + 1);
  if (componentHeight < math.max(textMask.height * 0.35, componentWidth * 3.0)) return false;

  final rawUnion = _unionBox(verticalLines);
  if (rawUnion == null) return false;

  final rawWidth = math.max(1, rawUnion[2] - rawUnion[0] + 1);
  final rawHeight = math.max(1, rawUnion[3] - rawUnion[1] + 1);
  final rawBoxes = _sorted([for (final l in verticalLines) l.axisBox], (b) => [b[0]]);
  final medianRawWidth = npMedian(rawBoxes.map((b) => math.max(1, b[2] - b[0] + 1)));
  var maxGap = 0;
  for (var i = 0; i + 1 < rawBoxes.length; i++) {
    maxGap = math.max(maxGap, rawBoxes[i + 1][0] - rawBoxes[i][2] - 1);
  }
  if (maxGap > math.max(6.0, medianRawWidth * 0.35)) return false;

  final overlapX = math.min(componentBox[2], rawUnion[2]) - math.max(componentBox[0], rawUnion[0]) + 1;
  final overlapY = math.min(componentBox[3], rawUnion[3]) - math.max(componentBox[1], rawUnion[1]) + 1;
  return overlapX >= rawWidth * 0.70 && overlapY >= rawHeight * 0.85;
}

bool _structuredColumnsShouldOverrideHorizontal(
  _Mask textMask,
  List<HLine> horizontalLines,
  List<HLine> verticalLines,
  List<HLine> componentLines,
  double horizontalScore,
  double verticalScore,
) {
  if (componentLines.length < 2) return false;

  final height = textMask.height, width = textMask.width;
  final componentBoxes = [for (final l in componentLines) l.axisBox];

  if (horizontalScore > 1.25 && verticalScore < horizontalScore + 1.0) return false;
  if (verticalScore >= horizontalScore + 0.50) return true;

  var tallColumns = 0;
  for (final b in componentBoxes) {
    final h = math.max(1, b[3] - b[1] + 1).toDouble();
    final w = math.max(1, b[2] - b[0] + 1).toDouble();
    if (h >= math.max(height * 0.28, w * 2.0)) tallColumns++;
  }
  if (tallColumns < math.max(2, componentBoxes.length - 1)) return false;

  final hasBroadRawColumn = verticalLines.any((l) {
    final b = l.axisBox;
    return (b[2] - b[0] + 1) >= width * 0.45 && (b[3] - b[1] + 1) >= height * 0.55;
  });
  if (!hasBroadRawColumn && verticalLines.length < math.max(2, componentLines.length ~/ 2)) return false;

  if (horizontalLines.length >= componentLines.length * 2) return true;
  return verticalScore >= horizontalScore + 0.50;
}
