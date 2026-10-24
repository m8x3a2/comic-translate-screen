/// Port of `modules/detection/heuristic_lines` from the original: splits
/// detected text blocks into lines (or vertical columns) and infers the text
/// direction from a binarised crop of each block.
///
/// The port is deliberately literal — same thresholds, iteration order,
/// stable sorts and Python rounding — so that it produces the original's
/// lines exactly; parity tests compare it with the original's output. The
/// parts mirror the original's modules one to one.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

part 'heuristic_lines/clustering.dart';
part 'heuristic_lines/column_routing.dart';
part 'heuristic_lines/core.dart';
part 'heuristic_lines/direction.dart';
part 'heuristic_lines/geometry.dart';
part 'heuristic_lines/horizontal.dart';
part 'heuristic_lines/mask.dart';
part 'heuristic_lines/scoring.dart';
part 'heuristic_lines/skew.dart';
part 'heuristic_lines/vertical.dart';

/// A text line as the original keeps it: an inclusive box `[x1, y1, x2, y2]`
/// or, for skewed text, a quadrilateral of four integer `[x, y]` points.
final class HLine {
  HLine.box(List<int> box) : box = List.unmodifiable(box), points = null;

  HLine.quad(List<List<int>> points)
    : points = List.unmodifiable([for (final p in points) List<int>.unmodifiable(p)]),
      box = null;

  factory HLine.fromJson(Object? json) {
    final l = json as List;
    if (l.isNotEmpty && l.first is List) {
      return HLine.quad([for (final p in l) (p as List).cast<num>().map((v) => v.toInt()).toList()]);
    }
    return HLine.box(l.cast<num>().map((v) => v.toInt()).toList());
  }

  final List<int>? box;
  final List<List<int>>? points;

  bool get isPolygon => points != null;

  /// `_line_axis_box`: a fresh `[x1, y1, x2, y2]` list.
  List<int> get axisBox {
    final b = box;
    if (b != null) return List.of(b);
    final p = points!;
    var x1 = p[0][0], y1 = p[0][1], x2 = x1, y2 = y1;
    for (final q in p) {
      x1 = math.min(x1, q[0]);
      y1 = math.min(y1, q[1]);
      x2 = math.max(x2, q[0]);
      y2 = math.max(y2, q[1]);
    }
    return [x1, y1, x2, y2];
  }

  /// Python `line == [x1, y1, x2, y2]` (never true for a quadrilateral).
  bool equalsBox(List<int> other) => box != null && _listEq(box!, other);

  TextLine toTextLine() {
    final b = box;
    if (b != null) return TextLine.box(BBox(b[0], b[1], b[2], b[3]));
    return TextLine.polygon([for (final p in points!) Point2(p[0].toDouble(), p[1].toDouble())]);
  }

  Object toJson() => box ?? points!;

  @override
  bool operator ==(Object other) {
    if (other is! HLine) return false;
    if (box != null) return other.box != null && _listEq(box!, other.box!);
    final a = points!, b = other.points;
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_listEq(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => box != null ? Object.hashAll(box!) : Object.hashAll([for (final p in points!) Object.hashAll(p)]);

  @override
  String toString() => 'HLine(${toJson()})';
}

/// Lines and direction (`'horizontal'` or `'vertical'`) of the text in
/// [image], a crop around one block (`_detect_lines_and_direction_in_crop`).
(List<HLine>, String) detectLinesAndDirectionInCrop(RgbImage image, [String sourceLanguage = '']) =>
    _detectLinesAndDirectionInCrop(image, sourceLanguage);

/// How far past a block the line splitter looks (per cent of the block's
/// width and height, as in the original).
const heuristicCropPercent = 4;

/// Fills `lines` and `direction` of every block
/// (`annotate_blocks_with_heuristic_lines`). [sourceLanguage] overrides each
/// block's own `sourceLang`.
///
/// Like the original, an internal failure aborts the remaining blocks by
/// throwing; blocks processed before it keep their lines.
List<TextBlock> annotateBlocksWithHeuristicLines(RgbImage image, List<TextBlock> blocks, {String? sourceLanguage}) {
  if (image.width == 0 || image.height == 0 || blocks.isEmpty) return blocks;

  final height = image.height, width = image.width;
  for (final block in blocks) {
    final lang = sourceLanguage ?? block.sourceLang;
    final blockBox = _toBox(block.xyxy);
    final cropBox = _clampBox(
      _expandBox(blockBox, heuristicCropPercent, heuristicCropPercent, width, height),
      width,
      height,
    );
    final [x1, y1, x2, y2] = cropBox;
    if (x2 <= x1 || y2 <= y1) {
      block.lines = [HLine.box(cropBox).toTextLine()];
      block.direction = TextDirection.parse(_fallbackDirection(cropBox, lang));
      continue;
    }

    final crop = image.crop(BBox(x1, y1, x2, y2));
    final (lines, direction) = _detectLinesAndDirectionInCrop(crop, lang);
    var imageLines = [for (final line in lines) _offsetLine(line, x1, y1)];
    if (direction == _vertical) {
      imageLines = _alignVerticalLinesToDetectorBlock(imageLines, blockBox);
    }

    block.lines = [for (final line in _sortLines(imageLines, direction)) line.toTextLine()];
    block.direction = TextDirection.parse(direction);
  }
  return blocks;
}

const _horizontal = 'horizontal';
const _vertical = 'vertical';

// ------------------------------------------------------------- helpers ---

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Python comparison of numbers (no `-0.0 < 0.0` like `num.compareTo`).
int _cmp(num a, num b) => a < b ? -1 : (a > b ? 1 : 0);

/// Python tuple comparison.
int _cmpTuple(List<num> a, List<num> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = _cmp(a[i], b[i]);
    if (c != 0) return c;
  }
  return _cmp(a.length, b.length);
}

/// Python `sorted(items, key=...)`: stable.
List<T> _sorted<T>(Iterable<T> items, List<num> Function(T) key) {
  final keyed = [for (final (i, item) in items.indexed) (i, item, key(item))];
  keyed.sort((a, b) {
    final c = _cmpTuple(a.$3, b.$3);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in keyed) e.$2];
}

/// First index of the maximum (`np.argmax`, `max(range(n), key=...)`).
int _argmax(List<num> values) {
  var best = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] > values[best]) best = i;
  }
  return best;
}

/// Python `max(values)`: the first maximal element.
num _max(Iterable<num> values) {
  final it = values.iterator..moveNext();
  var best = it.current;
  while (it.moveNext()) {
    if (it.current > best) best = it.current;
  }
  return best;
}

/// Python `min(values)`: the first minimal element.
num _min(Iterable<num> values) {
  final it = values.iterator..moveNext();
  var best = it.current;
  while (it.moveNext()) {
    if (it.current < best) best = it.current;
  }
  return best;
}

/// Python `int(x)` for the non-negative values used here (truncation).
int _int(num x) => x.toInt();

/// numpy basic slicing of an axis of length [n].
(int, int) _slice(int start, int stop, int n) {
  if (start < 0) start = math.max(0, start + n);
  if (stop < 0) stop = math.max(0, stop + n);
  start = math.min(start, n);
  stop = math.min(stop, n);
  if (stop < start) stop = start;
  return (start, stop);
}

/// numpy integer indexing of an axis of length [n].
int _index(int i, int n) {
  if (i < -n || i >= n) throw RangeError('index $i is out of bounds for axis with size $n');
  return i < 0 ? i + n : i;
}

/// `np.flatnonzero(values > 0)`.
List<int> _activeIndices(List<int> values) => [
  for (var i = 0; i < values.length; i++)
    if (values[i] > 0) i,
];

/// `int(values[a:b].sum())`.
int _sumRange(List<int> values, int a, int b) {
  var s = 0;
  for (var i = a; i < b; i++) {
    s += values[i];
  }
  return s;
}

/// `np.diff` of sorted values.
List<double> _diff(List<double> values) => [for (var i = 1; i < values.length; i++) values[i] - values[i - 1]];
