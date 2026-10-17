import 'dart:math' as math;

/// A point with double coordinates (image pixels).
class Point2 {
  const Point2(this.x, this.y);

  final double x;
  final double y;

  List<num> toJson() => [_num(x), _num(y)];

  factory Point2.fromJson(Object? json) {
    final l = json as List;
    return Point2((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }

  @override
  bool operator ==(Object other) => other is Point2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${_num(x)}, ${_num(y)})';
}

/// Axis-aligned box in integer pixel coordinates, `x2`/`y2` exclusive —
/// the `xyxy` arrays of the original code.
class BBox {
  const BBox(this.x1, this.y1, this.x2, this.y2);

  factory BBox.fromXywh(int x, int y, int w, int h) => BBox(x, y, x + w, y + h);

  /// Accepts `[x1, y1, x2, y2]` with ints or doubles (doubles are truncated,
  /// like `map(int, box)` in the original).
  factory BBox.fromList(List<num> v) =>
      BBox(v[0].toInt(), v[1].toInt(), v[2].toInt(), v[3].toInt());

  factory BBox.fromJson(Object? json) => BBox.fromList((json as List).cast<num>());

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  int get width => x2 - x1;
  int get height => y2 - y1;
  int get area => math.max(0, width) * math.max(0, height);
  bool get isEmpty => width <= 0 || height <= 0;
  Point2 get center => Point2((x1 + x2) / 2, (y1 + y2) / 2);

  List<int> toList() => [x1, y1, x2, y2];
  List<int> toJson() => toList();

  /// `[x, y, w, h]` (the `xywh` property of the original TextBlock).
  List<int> get xywh => [x1, y1, width, height];

  BBox clampTo(int width, int height) => BBox(
        x1.clamp(0, width),
        y1.clamp(0, height),
        x2.clamp(0, width),
        y2.clamp(0, height),
      );

  BBox? intersection(BBox o) {
    final r = BBox(math.max(x1, o.x1), math.max(y1, o.y1), math.min(x2, o.x2), math.min(y2, o.y2));
    return r.isEmpty ? null : r;
  }

  BBox union(BBox o) =>
      BBox(math.min(x1, o.x1), math.min(y1, o.y1), math.max(x2, o.x2), math.max(y2, o.y2));

  BBox translate(int dx, int dy) => BBox(x1 + dx, y1 + dy, x2 + dx, y2 + dy);

  BBox inflate(int dx, int dy) => BBox(x1 - dx, y1 - dy, x2 + dx, y2 + dy);

  bool containsBox(BBox o) => o.x1 >= x1 && o.y1 >= y1 && o.x2 <= x2 && o.y2 <= y2;

  /// Intersection over union, 0 when disjoint.
  double iou(BBox o) {
    final inter = intersection(o);
    if (inter == null) return 0;
    final u = area + o.area - inter.area;
    return u <= 0 ? 0 : inter.area / u;
  }

  @override
  bool operator ==(Object other) =>
      other is BBox && other.x1 == x1 && other.y1 == y1 && other.x2 == x2 && other.y2 == y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);

  @override
  String toString() => 'BBox($x1, $y1, $x2, $y2)';
}

/// A detected text line: either an axis-aligned box or a quadrilateral for
/// skewed text. The original stores these as `[x1, y1, x2, y2]` or
/// `[[x, y] × 4]`; JSON keeps the same shapes.
class TextLine {
  const TextLine.box(BBox this.box) : polygon = null;
  const TextLine.polygon(List<Point2> this.polygon) : box = null;

  factory TextLine.fromJson(Object? json) {
    final l = json as List;
    if (l.isNotEmpty && l.first is List) {
      return TextLine.polygon([for (final p in l) Point2.fromJson(p)]);
    }
    return TextLine.box(BBox.fromList(l.cast<num>()));
  }

  final BBox? box;
  final List<Point2>? polygon;

  bool get isPolygon => polygon != null;

  /// Bounding box of the line.
  BBox get axisBox {
    if (box != null) return box!;
    final pts = polygon!;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    return BBox(minX.floor(), minY.floor(), maxX.ceil(), maxY.ceil());
  }

  Object toJson() => box != null ? box!.toJson() : [for (final p in polygon!) p.toJson()];

  @override
  bool operator ==(Object other) {
    if (other is! TextLine) return false;
    if (box != null) return other.box == box;
    final a = polygon!, b = other.polygon;
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => box?.hashCode ?? Object.hashAll(polygon!);
}

num _num(double v) => v == v.roundToDouble() ? v.toInt() : v;
