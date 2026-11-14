/// Touch-ups painted by hand over the cleaned page (new in this project, the
/// owner's step 7): a brush with a colour, an eraser that takes the brush
/// back off, a brush that brings back the original picture, and a fill of
/// one click. They lie over the cleaned page as a layer of their own, under
/// the translation; [bakePaints] draws them into the picture for export.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../model/geometry.dart';

enum PaintKind {
  /// Paints [PaintOp.color].
  brush,

  /// Takes the touch-ups back off: the cleaned page shows again.
  erase,

  /// Brings back the original page (before cleaning).
  original,

  /// Fills [PaintOp.runs] with [PaintOp.color].
  fill,
}

/// One stroke or fill, in page pixels.
class PaintOp {
  const PaintOp({
    required this.kind,
    this.points = const [],
    this.width = 1,
    this.color = 0xFFFFFFFF,
    this.runs = const [],
  });

  final PaintKind kind;

  /// The stroke's path (strokes only).
  final List<Point2> points;

  /// Brush diameter in page pixels (strokes only).
  final double width;

  /// ARGB colour of the brush and the fill (always opaque).
  final int color;

  /// The fill's pixels: rows as `y, x1, x2` triples, `x2` exclusive.
  final List<int> runs;

  bool get isStroke => kind != PaintKind.fill;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (isStroke) 'points': [for (final p in points) p.toJson()],
    if (isStroke) 'width': width,
    if (kind == PaintKind.brush || kind == PaintKind.fill) 'color': color,
    if (kind == PaintKind.fill) 'runs': runs,
  };

  factory PaintOp.fromJson(Map<String, Object?> j) => PaintOp(
    kind: PaintKind.values.asNameMap()[j['kind']] ?? PaintKind.brush,
    points: [for (final p in (j['points'] as List? ?? const [])) Point2.fromJson(p)],
    width: (j['width'] as num?)?.toDouble() ?? 1,
    color: (j['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
    runs: [for (final v in (j['runs'] as List? ?? const [])) (v as num).toInt()],
  );
}

/// Touch-ups from the JSON list [json] (unknown entries are skipped).
List<PaintOp> paintOpsFromJson(Object? json) => [
  if (json is List)
    for (final j in json)
      if (j is Map) PaintOp.fromJson(j.cast<String, Object?>()),
];

/// Some of [ops] bring back the original page.
bool paintsUseOriginal(List<PaintOp> ops) => ops.any((o) => o.kind == PaintKind.original);

/// [base] (the cleaned page) with [ops] drawn over it in order. [original]
/// (the page before cleaning, of the same size) is needed when the ops
/// bring it back; without it those strokes do nothing. Strokes have soft
/// (anti-aliased) edges like the ones drawn on screen.
RgbImage bakePaints(RgbImage base, List<PaintOp> ops, {RgbImage? original}) {
  final out = base.clone();
  if (ops.isEmpty) return out;
  final w = out.width, h = out.height;
  final data = out.data;
  final orig = original != null && original.width == w && original.height == h ? original.data : null;
  for (final op in ops) {
    if (op.kind == PaintKind.fill) {
      final r = (op.color >> 16) & 0xFF, g = (op.color >> 8) & 0xFF, b = op.color & 0xFF;
      for (var k = 0; k + 2 < op.runs.length; k += 3) {
        final y = op.runs[k];
        if (y < 0 || y >= h) continue;
        final x1 = op.runs[k + 1].clamp(0, w), x2 = op.runs[k + 2].clamp(0, w);
        for (var i = (y * w + x1) * 3, end = (y * w + x2) * 3; i < end; i += 3) {
          data[i] = r;
          data[i + 1] = g;
          data[i + 2] = b;
        }
      }
      continue;
    }
    if (op.kind == PaintKind.original && orig == null) continue;
    final cover = _strokeCoverage(op.points, op.width / 2, w, h);
    if (cover == null) continue;
    final (box, alpha) = cover;
    final cr = (op.color >> 16) & 0xFF, cg = (op.color >> 8) & 0xFF, cb = op.color & 0xFF;
    for (var y = box.y1; y < box.y2; y++) {
      for (var x = box.x1; x < box.x2; x++) {
        final a = alpha[(y - box.y1) * box.width + (x - box.x1)];
        if (a == 0) continue;
        final i = (y * w + x) * 3;
        int tr, tg, tb;
        switch (op.kind) {
          case PaintKind.brush:
            (tr, tg, tb) = (cr, cg, cb);
          case PaintKind.erase:
            (tr, tg, tb) = (base.data[i], base.data[i + 1], base.data[i + 2]);
          case PaintKind.original:
            (tr, tg, tb) = (orig![i], orig[i + 1], orig[i + 2]);
          case PaintKind.fill:
            continue;
        }
        if (a == 255) {
          data[i] = tr;
          data[i + 1] = tg;
          data[i + 2] = tb;
        } else {
          data[i] = (data[i] * (255 - a) + tr * a + 127) ~/ 255;
          data[i + 1] = (data[i + 1] * (255 - a) + tg * a + 127) ~/ 255;
          data[i + 2] = (data[i + 2] * (255 - a) + tb * a + 127) ~/ 255;
        }
      }
    }
  }
  return out;
}

/// How much a round-capped stroke along [points] of [radius] covers each
/// pixel (0–255) within its bounding box on a [w]×[h] page; null when it
/// misses the page. Pixel centres are at +0.5, as on screen.
(BBox, Uint8List)? _strokeCoverage(List<Point2> points, double radius, int w, int h) {
  if (points.isEmpty || radius <= 0) return null;
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final box = BBox(
    (minX - radius - 1).floor(),
    (minY - radius - 1).floor(),
    (maxX + radius + 2).ceil(),
    (maxY + radius + 2).ceil(),
  ).clampTo(w, h);
  if (box.isEmpty) return null;
  final alpha = Uint8List(box.width * box.height);
  void segment(Point2 a, Point2 b) {
    final x1 = math.max(box.x1, (math.min(a.x, b.x) - radius - 1).floor());
    final x2 = math.min(box.x2, (math.max(a.x, b.x) + radius + 2).ceil());
    final y1 = math.max(box.y1, (math.min(a.y, b.y) - radius - 1).floor());
    final y2 = math.min(box.y2, (math.max(a.y, b.y) + radius + 2).ceil());
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    for (var y = y1; y < y2; y++) {
      final py = y + 0.5;
      for (var x = x1; x < x2; x++) {
        final px = x + 0.5;
        var t = len2 == 0 ? 0.0 : ((px - a.x) * dx + (py - a.y) * dy) / len2;
        t = t.clamp(0.0, 1.0);
        final ex = a.x + t * dx - px, ey = a.y + t * dy - py;
        final d = math.sqrt(ex * ex + ey * ey);
        final c = (radius + 0.5 - d).clamp(0.0, 1.0);
        if (c <= 0) continue;
        final v = (c * 255).round();
        final k = (y - box.y1) * box.width + (x - box.x1);
        if (v > alpha[k]) alpha[k] = v;
      }
    }
  }

  if (points.length == 1) {
    segment(points.single, points.single);
  } else {
    for (var i = 1; i < points.length; i++) {
      segment(points[i - 1], points[i]);
    }
  }
  return (box, alpha);
}

/// The fill of one click at ([x], [y]) on [image]: the pixels joined to it
/// whose colour differs from the clicked one by at most [tolerance] in each
/// channel, as `y, x1, x2` runs (see [PaintOp.runs]). With [closeSpots], the
/// spots enclosed by the fill (leftover letters, smudges) are filled too
/// when each is smaller than [spotShare] of the fill, so that a click on
/// the white gutter does not fill whole panels. Empty outside the image.
List<int> floodFillRuns(
  RgbImage image,
  int x,
  int y, {
  int tolerance = 40,
  bool closeSpots = true,
  double spotShare = 0.5,
}) {
  final w = image.width, h = image.height;
  if (x < 0 || y < 0 || x >= w || y >= h) return const [];
  final d = image.data;
  final s = (y * w + x) * 3;
  final sr = d[s], sg = d[s + 1], sb = d[s + 2];
  bool like(int i) {
    final j = i * 3;
    return (d[j] - sr).abs() <= tolerance && (d[j + 1] - sg).abs() <= tolerance && (d[j + 2] - sb).abs() <= tolerance;
  }

  final region = Uint8List(w * h);
  var area = 0;
  var minX = x, maxX = x, minY = y, maxY = y;
  // Scanline fill (4-connected).
  final stack = <int>[y * w + x];
  while (stack.isNotEmpty) {
    final start = stack.removeLast();
    if (region[start] != 0) continue;
    final row = start ~/ w;
    var l = start % w, r = l;
    final base = row * w;
    while (l > 0 && region[base + l - 1] == 0 && like(base + l - 1)) {
      l--;
    }
    while (r + 1 < w && region[base + r + 1] == 0 && like(base + r + 1)) {
      r++;
    }
    for (var i = l; i <= r; i++) {
      region[base + i] = 1;
    }
    area += r - l + 1;
    minX = math.min(minX, l);
    maxX = math.max(maxX, r);
    minY = math.min(minY, row);
    maxY = math.max(maxY, row);
    for (final ny in [row - 1, row + 1]) {
      if (ny < 0 || ny >= h) continue;
      final nb = ny * w;
      var inRun = false;
      for (var i = l; i <= r; i++) {
        final ok = region[nb + i] == 0 && like(nb + i);
        if (ok && !inRun) stack.add(nb + i);
        inRun = ok;
      }
    }
  }

  if (closeSpots) {
    // Spots: pieces of what is not filled, inside the fill's box, that do
    // not reach the box's edge (8-connected, so a diagonal gap leads out).
    final bw = maxX - minX + 1, bh = maxY - minY + 1;
    final seen = Uint8List(bw * bh);
    final piece = <int>[];
    final queue = <int>[];
    final limit = area * spotShare;
    for (var by = 0; by < bh; by++) {
      for (var bx = 0; bx < bw; bx++) {
        final k = by * bw + bx;
        if (seen[k] != 0 || region[(by + minY) * w + bx + minX] != 0) continue;
        piece.clear();
        queue
          ..clear()
          ..add(k);
        seen[k] = 1;
        var edge = false;
        while (queue.isNotEmpty) {
          final c = queue.removeLast();
          piece.add(c);
          final cx = c % bw, cy = c ~/ bw;
          if (cx == 0 || cy == 0 || cx == bw - 1 || cy == bh - 1) edge = true;
          for (var oy = -1; oy <= 1; oy++) {
            for (var ox = -1; ox <= 1; ox++) {
              final nx = cx + ox, ny = cy + oy;
              if (nx < 0 || ny < 0 || nx >= bw || ny >= bh) continue;
              final n = ny * bw + nx;
              if (seen[n] != 0 || region[(ny + minY) * w + nx + minX] != 0) continue;
              seen[n] = 1;
              queue.add(n);
            }
          }
        }
        if (edge || piece.length > limit) continue;
        for (final c in piece) {
          region[(c ~/ bw + minY) * w + c % bw + minX] = 1;
        }
      }
    }
  }

  final runs = <int>[];
  for (var ry = minY; ry <= maxY; ry++) {
    final base = ry * w;
    var rx = minX;
    while (rx <= maxX) {
      if (region[base + rx] == 0) {
        rx++;
        continue;
      }
      final start = rx;
      while (rx <= maxX && region[base + rx] != 0) {
        rx++;
      }
      runs.addAll([ry, start, rx]);
    }
  }
  return runs;
}

/// The pixels inside the closed outline [points] (a lasso, a polygon, a
/// rectangle or an ellipse made into points) on a [width]×[height] page, as
/// `y, x1, x2` runs (see [PaintOp.runs]): those whose centre is inside
/// (even–odd rule). Empty for fewer than three points.
List<int> polygonRuns(List<Point2> points, int width, int height) {
  if (points.length < 3) return const [];
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  final y1 = math.max(0, (minY - 0.5).ceil()), y2 = math.min(height - 1, (maxY - 0.5).floor());
  final runs = <int>[];
  final xs = <double>[];
  for (var y = y1; y <= y2; y++) {
    final cy = y + 0.5;
    xs.clear();
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      if ((a.y <= cy && b.y > cy) || (b.y <= cy && a.y > cy)) {
        xs.add(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x));
      }
    }
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final from = math.max(0, (xs[k] - 0.5).ceil()), to = math.min(width, (xs[k + 1] - 0.5).ceil());
      if (to > from) runs.addAll([y, from, to]);
    }
  }
  return runs;
}

/// The outline of the ellipse inside [a]–[b] (opposite corners) as points.
List<Point2> ellipsePoints(Point2 a, Point2 b, {int count = 72}) {
  final cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2, rx = (a.x - b.x).abs() / 2, ry = (a.y - b.y).abs() / 2;
  return [
    for (var i = 0; i < count; i++)
      Point2(cx + rx * math.cos(2 * math.pi * i / count), cy + ry * math.sin(2 * math.pi * i / count)),
  ];
}

/// The outline of the rectangle with opposite corners [a] and [b].
List<Point2> rectanglePoints(Point2 a, Point2 b) => [a, Point2(b.x, a.y), b, Point2(a.x, b.y)];
