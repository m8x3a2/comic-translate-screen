// Port of modules/detection/heuristic_lines/geometry.py.
part of '../heuristic_lines.dart';

HLine _offsetLine(HLine line, int offsetX, int offsetY) {
  final p = line.points;
  if (p != null) return HLine.quad([for (final q in p) [q[0] + offsetX, q[1] + offsetY]]);
  final b = line.box!;
  return HLine.box([b[0] + offsetX, b[1] + offsetY, b[2] + offsetX, b[3] + offsetY]);
}

List<int> _toBox(BBox box) => [box.x1, box.y1, box.x2, box.y2];

List<int> _clampBox(List<num> box, int width, int height) {
  final x1 = math.max(0, math.min(width, pyRound(box[0])));
  final y1 = math.max(0, math.min(height, pyRound(box[1])));
  final x2 = math.max(0, math.min(width, pyRound(box[2])));
  final y2 = math.max(0, math.min(height, pyRound(box[3])));
  return [math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)];
}

List<int> _expandBox(List<int> box, int widthPercent, int heightPercent, int imageWidth, int imageHeight) {
  final width = box[2] - box[0];
  final height = box[3] - box[1];
  final dx = width * widthPercent / 100.0;
  final dy = height * heightPercent / 100.0;
  return _clampBox([box[0] - dx, box[1] - dy, box[2] + dx, box[3] + dy], imageWidth, imageHeight);
}

List<int>? _unionBox(List<HLine> lines) {
  if (lines.isEmpty) return null;
  return _unionOfBoxes([for (final line in lines) line.axisBox]);
}

List<int>? _unionOfBoxes(List<List<int>> boxes) {
  if (boxes.isEmpty) return null;
  return [
    _min(boxes.map((b) => b[0])).toInt(),
    _min(boxes.map((b) => b[1])).toInt(),
    _max(boxes.map((b) => b[2])).toInt(),
    _max(boxes.map((b) => b[3])).toInt(),
  ];
}

double _norm2(double x, double y) => math.sqrt(x * x + y * y);

List<List<int>> _padPolygonLine(List<List<int>> line, String direction, int width, int height) {
  final pts = [for (final p in line) [p[0].toDouble(), p[1].toDouble()]];
  final cx = (((pts[0][0] + pts[1][0]) + pts[2][0]) + pts[3][0]) / 4;
  final cy = (((pts[0][1] + pts[1][1]) + pts[2][1]) + pts[3][1]) / 4;
  final ex = [pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]];
  final ey = [pts[3][0] - pts[0][0], pts[3][1] - pts[0][1]];
  final edgeWidth = math.max(1.0, _norm2(ex[0], ex[1]));
  final edgeHeight = math.max(1.0, _norm2(ey[0], ey[1]));
  final lx = [ex[0] / edgeWidth, ex[1] / edgeWidth];
  final ly = [ey[0] / edgeHeight, ey[1] / edgeHeight];

  double xScale, yScale;
  if (direction == _horizontal) {
    xScale = (edgeWidth + math.max(2.0, edgeHeight * 0.20)) / edgeWidth;
    yScale = (edgeHeight + math.max(6.0, edgeHeight * 0.40)) / edgeHeight;
  } else {
    xScale = (edgeWidth + math.max(2.0, edgeWidth * 0.24)) / edgeWidth;
    yScale = (edgeHeight + math.max(2.0, edgeWidth * 0.20)) / edgeHeight;
  }

  final padded = <List<int>>[];
  for (final p in pts) {
    final dx = p[0] - cx, dy = p[1] - cy;
    final dotX = dx * lx[0] + dy * lx[1];
    final dotY = dx * ly[0] + dy * ly[1];
    final px = cx + lx[0] * dotX * xScale + ly[0] * dotY * yScale;
    final py = cy + lx[1] * dotX * xScale + ly[1] * dotY * yScale;
    padded.add([
      math.max(0, math.min(width, pyRound(px))),
      math.max(0, math.min(height, pyRound(py))),
    ]);
  }
  return padded;
}

List<HLine> _padLineBoxes(List<HLine> lines, String direction, int width, int height) {
  final padded = <HLine>[];
  for (final line in lines) {
    final p = line.points;
    if (p != null) {
      padded.add(HLine.quad(_padPolygonLine(p, direction, width, height)));
      continue;
    }
    final [x1, y1, x2, y2] = line.box!;
    final lineWidth = math.max(1, x2 - x1 + 1);
    final lineHeight = math.max(1, y2 - y1 + 1);
    int dx, dy;
    if (direction == _horizontal) {
      dx = math.max(1, pyRound(lineHeight * 0.10));
      dy = math.max(3, pyRound(lineHeight * 0.20));
    } else {
      dx = math.max(1, pyRound(lineWidth * 0.12));
      dy = math.max(1, pyRound(lineWidth * 0.10));
    }
    padded.add(HLine.box(_clampBox([x1 - dx, y1 - dy, x2 + dx, y2 + dy], width, height)));
  }
  return padded;
}
