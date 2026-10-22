/// Model-independent parts of the PP-OCR text line detector (DB): preparing
/// the page, turning the probability map into line boxes, and gathering the
/// lines into blocks.
///
/// Ports of `modules/ocr/ppocr/{preprocessing,postprocessing}.py` (det part)
/// and `modules/detection/ppocr_lines.py`, with the geometry helpers of
/// `imkit` they use. The original runs this detector only to split blocks
/// found by RT-DETR into lines; here it also finds the text of screenshots,
/// sites and games on its own ([groupLinesIntoBlocks] is new).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/contours.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// `resize_keep_stride`: the size the detector sees, sides multiples of 32.
/// With `limit_type="min"` the smaller side is brought up to [limitSideLen].
(int, int) detInputSize(int width, int height, {int limitSideLen = 960, bool limitMin = true}) {
  double ratio;
  if (limitMin) {
    ratio = math.min(height, width) < limitSideLen ? limitSideLen / (height < width ? height : width) : 1.0;
  } else {
    ratio = math.max(height, width) > limitSideLen ? limitSideLen / (height > width ? height : width) : 1.0;
  }
  final nh = math.max(32, pyRound(height * ratio / 32) * 32);
  final nw = math.max(32, pyRound(width * ratio / 32) * 32);
  return (nw, nh);
}

/// `det_preprocess`: resized (Lanczos), BGR, scaled to [-1, 1], NCHW.
({Float32List data, int width, int height}) detPreprocess(RgbImage image, {int limitSideLen = 960}) {
  final (w, h) = detInputSize(image.width, image.height, limitSideLen: limitSideLen);
  final resized = w == image.width && h == image.height ? image : pilResize(image, w, h, filter: PilFilter.lanczos);
  final plane = w * h;
  final data = Float32List(3 * plane);
  final src = resized.data;
  for (var i = 0; i < plane; i++) {
    // BGR order, (x / 255 - 0.5) / 0.5 in float32 like numpy.
    for (var c = 0; c < 3; c++) {
      final v = _fround(_fround(_fround(src[i * 3 + 2 - c] / 255.0) - 0.5) / 0.5);
      data[c * plane + i] = v;
    }
  }
  return (data: data, width: w, height: h);
}

final _f32 = Float32List(1);

/// Rounds to float32 (numpy float32 arithmetic).
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// A quadrilateral (top-left, top-right, bottom-right, bottom-left).
typedef Quad = List<Point2>;

/// `DBPostProcessor` with the settings of `PPOCRLineDetector`.
class DbPostProcessor {
  const DbPostProcessor({this.thresh = 0.3, this.boxThresh = 0.5, this.maxCandidates = 1000, this.unclipRatio = 2.0});

  final double thresh;
  final double boxThresh;
  final int maxCandidates;
  final double unclipRatio;

  /// Line quadrilaterals in page pixels ([destWidth]×[destHeight]) from the
  /// probability map [prob] ([width]×[height]).
  List<Quad> call(Float32List prob, int width, int height, int destWidth, int destHeight) {
    final bitmap = GrayImage(width, height, Uint8List(width * height));
    for (var i = 0; i < prob.length; i++) {
      if (prob[i] > thresh) bitmap.data[i] = 255;
    }
    final contours = findContours(bitmap, threshold: 127);
    final boxes = <Quad>[];
    final n = math.min(contours.length, maxCandidates);
    for (var i = 0; i < n; i++) {
      final contour = [for (final (x, y) in contours[i]) Point2(x.toDouble(), y.toDouble())];
      var (box, sside) = minBox(contour);
      if (sside < 3) continue;
      final score = scoreFast(prob, width, height, box);
      if (score < boxThresh) continue;
      (box, sside) = minBox(unclip(box, unclipRatio));
      if (sside < 5) continue;
      boxes.add([
        for (final p in box)
          Point2(
            (pyRound(p.x / width * destWidth)).clamp(0, destWidth).toDouble(),
            (pyRound(p.y / height * destHeight)).clamp(0, destHeight).toDouble(),
          ),
      ]);
    }
    return _filter(boxes, destHeight, destWidth);
  }

  List<Quad> _filter(List<Quad> boxes, int h, int w) {
    final out = <Quad>[];
    for (final b0 in boxes) {
      final b = [
        for (final p in orderClockwise(b0)) Point2(p.x.clamp(0, w - 1).toDouble(), p.y.clamp(0, h - 1).toDouble()),
      ];
      final rw = _dist(b[0], b[1]).toInt();
      final rh = _dist(b[0], b[3]).toInt();
      if (rw <= 3 || rh <= 3) continue;
      out.add(b);
    }
    return out;
  }
}

double _dist(Point2 a, Point2 b) => math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

/// `_min_box`: the minimum-area rectangle around [points] as an ordered
/// quad (float32 corners), and its shorter side.
(Quad, double) minBox(List<Point2> points) {
  final rect = minAreaRect(points);
  final pts = boxPoints(rect);
  // sorted by x (stable), then each pair by y.
  final byX = [...pts]..sort((a, b) => a.x.compareTo(b.x));
  final left = [byX[0], byX[1]], right = [byX[2], byX[3]];
  final (tl, bl) = left[1].y < left[0].y ? (left[1], left[0]) : (left[0], left[1]);
  final (tr, br) = right[1].y < right[0].y ? (right[1], right[0]) : (right[0], right[1]);
  return ([tl, tr, br, bl], math.min(rect.width, rect.height));
}

/// `_order_clockwise` of `DBPostProcessor`.
Quad orderClockwise(Quad pts) => minBoxOrder(pts);

Quad minBoxOrder(List<Point2> pts) {
  final byX = [...pts]..sort((a, b) => a.x.compareTo(b.x));
  final left = [byX[0], byX[1]], right = [byX[2], byX[3]];
  final (tl, bl) = left[1].y < left[0].y ? (left[1], left[0]) : (left[0], left[1]);
  final (tr, br) = right[1].y < right[0].y ? (right[1], right[0]) : (right[0], right[1]);
  return [tl, tr, br, bl];
}

/// `_score_fast`: mean probability inside [box].
double scoreFast(Float32List prob, int w, int h, Quad box) {
  final xs = [for (final p in box) p.x], ys = [for (final p in box) p.y];
  final xmin = xs.reduce(math.min).floor().clamp(0, w - 1);
  final xmax = xs.reduce(math.max).ceil().clamp(0, w - 1);
  final ymin = ys.reduce(math.min).floor().clamp(0, h - 1);
  final ymax = ys.reduce(math.max).ceil().clamp(0, h - 1);
  final mw = xmax - xmin + 1, mh = ymax - ymin + 1;
  final mask = Uint8List(mw * mh);
  // float32 → int32 like `astype(np.int32)` (truncation).
  fillPolygon(mask, mw, mh, [for (final p in box) ((p.x - xmin).toInt(), (p.y - ymin).toInt())]);
  var sum = 0.0;
  var count = 0;
  for (var y = 0; y < mh; y++) {
    for (var x = 0; x < mw; x++) {
      if (mask[y * mw + x] == 0) continue;
      sum += prob[(y + ymin) * w + x + xmin];
      count++;
    }
  }
  return count == 0 ? 0 : sum / count;
}

/// `_unclip`: [box] grown outwards by area × ratio / perimeter (the
/// original offsets the polygon with round joins; for a rectangle the
/// smallest rectangle around that is the rectangle grown by the distance
/// on every side).
List<Point2> unclip(Quad box, double ratio) {
  var area = 0.0, length = 0.0;
  for (var i = 0; i < box.length; i++) {
    final a = box[i], b = box[(i + 1) % box.length];
    area += a.x * b.y - b.x * a.y;
    length += _dist(a, b);
  }
  area = area.abs() / 2;
  final d = area * ratio / (length + 1e-6);
  // Corners moved outwards along both edge normals.
  final cx = box.fold(0.0, (s, p) => s + p.x) / box.length;
  final cy = box.fold(0.0, (s, p) => s + p.y) / box.length;
  final out = <Point2>[];
  for (var i = 0; i < box.length; i++) {
    final p = box[i], prev = box[(i + box.length - 1) % box.length], next = box[(i + 1) % box.length];
    Point2 normal(Point2 a, Point2 b) {
      final len = math.max(1e-9, _dist(a, b));
      var nx = (b.y - a.y) / len, ny = -(b.x - a.x) / len;
      // Outwards: away from the centre.
      final mx = (a.x + b.x) / 2 - cx, my = (a.y + b.y) / 2 - cy;
      if (nx * mx + ny * my < 0) (nx, ny) = (-nx, -ny);
      return Point2(nx, ny);
    }

    final n1 = normal(prev, p), n2 = normal(p, next);
    out
      ..add(Point2(p.x + n1.x * d, p.y + n1.y * d))
      ..add(Point2(p.x + n2.x * d, p.y + n2.y * d))
      ..add(Point2(p.x + (n1.x + n2.x) * d, p.y + (n1.y + n2.y) * d));
  }
  return out;
}

/// A rotated rectangle of `cv2.minAreaRect`.
class RotatedRect {
  const RotatedRect(this.cx, this.cy, this.width, this.height, this.angle);

  final double cx, cy, width, height;

  /// Degrees.
  final double angle;
}

/// `_monotone_chain`: convex hull, counter-clockwise, no repeated point.
List<Point2> convexHull(List<Point2> points) {
  if (points.length <= 1) return [...points];
  final pts = [...points]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  double cross(Point2 o, Point2 a, Point2 b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final lower = <Point2>[];
  for (final p in pts) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <Point2>[];
  for (final p in pts.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  return [...lower.sublist(0, lower.length - 1), ...upper.sublist(0, upper.length - 1)];
}

/// `imkit.min_area_rect` (OpenCV conventions).
RotatedRect minAreaRect(List<Point2> points) {
  if (points.isEmpty) throw ArgumentError('no points');
  final hull = convexHull(points);
  final m = hull.length;
  if (m == 1) return RotatedRect(hull[0].x, hull[0].y, 0, 0, 0);
  if (m == 2) {
    final dx = hull[1].x - hull[0].x, dy = hull[1].y - hull[0].y;
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (dx.abs() < 1e-10) {
      angle = dy > 0 ? -90.0 : 90.0;
    } else if (dy.abs() < 1e-10) {
      angle = dx > 0 ? 180.0 : 0.0;
    } else {
      angle -= 180.0;
    }
    return RotatedRect(
      (hull[0].x + hull[1].x) / 2,
      (hull[0].y + hull[1].y) / 2,
      math.sqrt(dx * dx + dy * dy),
      0,
      angle,
    );
  }
  var best = double.infinity;
  RotatedRect? out;
  for (var i = 0; i < m; i++) {
    final a = hull[i], b = hull[(i + 1) % m];
    final ex = b.x - a.x, ey = b.y - a.y;
    final len = math.sqrt(ex * ex + ey * ey);
    if (len <= 1e-12) continue;
    final ux = ex / len, uy = ey / len;
    final vx = -uy, vy = ux;
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (final p in hull) {
      final px = p.x * ux + p.y * uy, py = p.x * vx + p.y * vy;
      minX = math.min(minX, px);
      maxX = math.max(maxX, px);
      minY = math.min(minY, py);
      maxY = math.max(maxY, py);
    }
    final w = maxX - minX, h = maxY - minY;
    // `np.argmin`: the first of equal areas.
    if (w * h >= best) continue;
    best = w * h;
    final cxr = (minX + maxX) / 2, cyr = (minY + maxY) / 2;
    final cx = cxr * ux + cyr * vx, cy = cxr * uy + cyr * vy;
    var angle = math.atan2(uy, ux) * 180 / math.pi;
    while (angle < -180) {
      angle += 360;
    }
    while (angle >= 180) {
      angle -= 360;
    }
    final horizontal = angle.abs() < 1e-6 || (angle.abs() - 180).abs() < 1e-6;
    final vertical = (angle.abs() - 90).abs() < 1e-6;
    if (horizontal) {
      out = RotatedRect(cx, cy, h, w, 90);
    } else if (vertical) {
      out = RotatedRect(cx, cy, w, h, 90);
    } else if (angle < 0) {
      out = RotatedRect(cx, cy, h, w, angle + 90);
    } else {
      out = RotatedRect(cx, cy, w, h, angle);
    }
  }
  return out ?? RotatedRect(hull[0].x, hull[0].y, 0, 0, 0);
}

/// `imkit.box_points`: the corners of [r] (float32).
List<Point2> boxPoints(RotatedRect r) {
  final t = r.angle * math.pi / 180;
  final c = math.cos(t), s = math.sin(t);
  final hw = r.width / 2, hh = r.height / 2;
  return [
    for (final (x, y) in [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)])
      Point2(_fround(x * c - y * s + r.cx), _fround(x * s + y * c + r.cy)),
  ];
}

/// Fills the polygon [points] (x, y) into [mask] ([w]×[h]) with 1, as
/// `mahotas.polygon.fill_polygon` does (scan lines, crossings truncated,
/// both ends filled; checked against mahotas on 3 000 random quads).
void fillPolygon(Uint8List mask, int w, int h, List<(int, int)> points) {
  if (points.isEmpty) return;
  final ys = [for (final (_, y) in points) y];
  final n = points.length;
  for (var y = ys.reduce(math.min); y <= ys.reduce(math.max); y++) {
    if (y < 0 || y >= h) continue;
    final nodes = <int>[];
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final (xi, yi) = points[i];
      final (xj, yj) = points[j];
      if ((yi < y && yj >= y) || (yj < y && yi >= y)) {
        nodes.add((xi + (y - yi) / (yj - yi) * (xj - xi)).toInt());
      }
    }
    nodes.sort();
    for (var k = 0; k + 1 < nodes.length; k += 2) {
      var a = nodes[k], b = nodes[k + 1];
      if (a >= w) break;
      if (b < 0) continue;
      a = math.max(a, 0);
      b = math.min(b, w - 1);
      for (var x = a; x <= b; x++) {
        mask[y * w + x] = 1;
      }
    }
  }
}

// `ppocr_lines.py`: line boxes from the quads, merged into whole lines.

/// `_axis_box`.
BBox axisBox(Quad q) => BBox(
  pyRound(q.map((p) => p.x).reduce(math.min)),
  pyRound(q.map((p) => p.y).reduce(math.min)),
  pyRound(q.map((p) => p.x).reduce(math.max)),
  pyRound(q.map((p) => p.y).reduce(math.max)),
);

/// `_merge_line_boxes`: pieces of one line put together. Pieces side by side
/// are merged across a gap of up to 8 % of the page or two line heights;
/// with [maxGap] (line heights, new) only up to that: two columns of text
/// often stand closer than that.
List<BBox> mergeLineBoxes(List<BBox> lines, int width, int height, {double? maxGap}) {
  final sorted = [...lines]..sort((a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1));
  final groups = <BBox>[];
  for (final line in sorted) {
    final i = groups.indexWhere((g) => _shouldMerge(g, line, width, maxGap));
    if (i < 0) {
      groups.add(line);
    } else {
      final g = groups[i];
      groups[i] = BBox(
        math.min(g.x1, line.x1),
        math.min(g.y1, line.y1),
        math.max(g.x2, line.x2),
        math.max(g.y2, line.y2),
      );
    }
  }
  final out = [
    for (final g in groups)
      if (_clamp(g, width, height) case final b when b.x2 - b.x1 > 3 && b.y2 - b.y1 > 3) b,
  ]..sort((a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1));
  return out;
}

BBox _clamp(BBox b, int w, int h) {
  final x1 = b.x1.clamp(0, w), y1 = b.y1.clamp(0, h), x2 = b.x2.clamp(0, w), y2 = b.y2.clamp(0, h);
  return BBox(math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2));
}

bool _shouldMerge(BBox a, BBox b, int imageWidth, double? maxGap) {
  final wa = a.x2 - a.x1, ha = a.y2 - a.y1, wb = b.x2 - b.x1, hb = b.y2 - b.y1;
  final aVertical = ha > wa * 1.25, bVertical = hb > wb * 1.25;
  final aHorizontal = wa > ha * 1.25, bHorizontal = wb > hb * 1.25;

  final overlapY = math.max(0, math.min(a.y2, b.y2) - math.max(a.y1, b.y1));
  final minHeight = math.max(1, math.min(ha, hb));
  final centerDelta = (((a.y1 + a.y2) / 2) - ((b.y1 + b.y2) / 2)).abs();
  final gapX = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2));
  final sameHorizontal = overlapY / minHeight >= 0.55 || centerDelta <= minHeight * 0.35;
  final horizontalMerge =
      sameHorizontal && gapX <= (maxGap == null ? math.max(imageWidth * 0.08, minHeight * 2) : minHeight * maxGap);
  if (!aVertical && !bVertical && (aHorizontal || bHorizontal || horizontalMerge)) return horizontalMerge;

  final overlapX = math.max(0, math.min(a.x2, b.x2) - math.max(a.x1, b.x1));
  final minWidth = math.max(1, math.min(wa, wb));
  final xCenterDelta = (((a.x1 + a.x2) / 2) - ((b.x1 + b.x2) / 2)).abs();
  final gapY = math.max(0, math.max(a.y1, b.y1) - math.min(a.y2, b.y2));
  final sameVertical = overlapX / minWidth >= 0.55 || xCenterDelta <= minWidth * 0.35;
  final verticalMerge = sameVertical && gapY <= math.max(minWidth * 2, 8);
  if (!aHorizontal && !bHorizontal) return verticalMerge;
  return false;
}

/// Lines of one paragraph or label put into one block (new): lines of
/// similar height, one under the other with a gap of at most [maxGap] line
/// heights, overlapping sideways or aligned by their left edges or centres.
/// Vertical lines (CJK columns) stay blocks of their own.
List<TextBlock> groupLinesIntoBlocks(List<BBox> lines, {double maxGap = 0.9}) {
  final n = lines.length;
  final parent = List<int>.generate(n, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      i = parent[i] = parent[parent[i]];
    }
    return i;
  }

  bool horizontal(BBox b) => b.width >= b.height;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final a = lines[i], b = lines[j];
      if (!horizontal(a) || !horizontal(b)) continue;
      final ha = a.height, hb = b.height;
      if (math.max(ha, hb) > 1.6 * math.max(1, math.min(ha, hb))) continue;
      final h = (ha + hb) / 2;
      final (top, bottom) = a.y1 <= b.y1 ? (a, b) : (b, a);
      final gap = bottom.y1 - top.y2;
      if (gap > maxGap * h || gap < -0.5 * h) continue;
      final overlap = math.min(a.x2, b.x2) - math.max(a.x1, b.x1);
      final aligned =
          overlap >= 0.3 * math.min(a.width, b.width) ||
          (a.x1 - b.x1).abs() <= h ||
          ((a.x1 + a.x2) / 2 - (b.x1 + b.x2) / 2).abs() <= h;
      if (aligned) parent[find(i)] = find(j);
    }
  }
  final groups = <int, List<BBox>>{};
  for (var i = 0; i < n; i++) {
    groups.putIfAbsent(find(i), () => []).add(lines[i]);
  }
  final blocks = <TextBlock>[];
  for (final g in groups.values) {
    g.sort((a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1));
    final box = BBox(
      g.map((b) => b.x1).reduce(math.min),
      g.map((b) => b.y1).reduce(math.min),
      g.map((b) => b.x2).reduce(math.max),
      g.map((b) => b.y2).reduce(math.max),
    );
    final vertical = g.length == 1 && g.single.height > g.single.width * 1.25;
    blocks.add(
      TextBlock(
        xyxy: box,
        textClass: TextClass.free,
        lines: [for (final b in g) TextLine.box(b)],
        direction: vertical ? TextDirection.vertical : TextDirection.horizontal,
      )..fixedLines = true,
    );
  }
  // Reading order: rows from the top (blocks overlapping a row's band by
  // half their height belong to it), each row from the left.
  blocks.sort((a, b) => a.xyxy.y1.compareTo(b.xyxy.y1));
  final rows = <(int, int, List<TextBlock>)>[];
  for (final b in blocks) {
    final box = b.xyxy;
    final i = rows.indexWhere((r) => math.min(r.$2, box.y2) - math.max(r.$1, box.y1) >= box.height / 2);
    if (i < 0) {
      rows.add((box.y1, box.y2, [b]));
    } else {
      final (top, bottom, members) = rows[i];
      rows[i] = (top, math.max(bottom, box.y2), members..add(b));
    }
  }
  return [for (final (_, _, members) in rows) ...members..sort((a, b) => a.xyxy.x1.compareTo(b.xyxy.x1))];
}
