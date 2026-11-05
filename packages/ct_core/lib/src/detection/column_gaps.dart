/// Columns inside one block (new): a list of names and their descriptions,
/// the stats of a game character. The detectors find one block for both
/// columns, and the line finder joins a name and its description into one
/// line; the reader then mixes them or loses words.
///
/// A block is split where an empty stripe crosses it from top to bottom, at
/// least [columnGapLetters] letter heights wide (a space between words is
/// about half a letter). One wide gap in one line is not enough: the stripe
/// must separate text in two rows of the block, or another block of the
/// page must have a stripe at the same place.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import 'foreground_color.dart';
import 'ppocr_det.dart';
import 'text_blocks.dart';

/// The least width of a stripe between columns, in letter heights.
const columnGapLetters = 1.5;

/// Empty rows this many letter heights tall separate two parts of a column.
const _rowGapLetters = 2.0;

/// A pixel differing from the block's background by more than this (in any
/// channel) is ink.
const _inkDifference = 60;

/// The ink of one block.
class _Ink {
  _Ink(this.box, this.ink, this.letter, this.stripes);

  /// The block's box on the page (clamped).
  final BBox box;

  /// 1 = ink, row-major over [box].
  final Uint8List ink;

  /// Median letter height (px).
  final double letter;

  /// Empty stripes from top to bottom, x from–to on the page.
  final List<(int, int)> stripes;

  int get w => box.width;
  int get h => box.height;

  /// Rows of the block with ink on both sides of [stripe]: how many bands of
  /// such rows at least half a letter tall.
  int rowsAcross((int, int) stripe) {
    final (s1, s2) = stripe;
    var bands = 0, run = 0;
    for (var y = 0; y < h; y++) {
      var left = false, right = false;
      for (var x = 0; x < w && !(left && right); x++) {
        if (ink[y * w + x] == 0) continue;
        final px = box.x1 + x;
        if (px < s1) left = true;
        if (px >= s2) right = true;
      }
      if (left && right) {
        run++;
        if (run == math.max(1, (letter / 2).round())) bands++;
      } else {
        run = 0;
      }
    }
    return bands;
  }

  /// The ink box (page pixels) of the columns [x1, x2) and rows [y1, y2) of
  /// the page, or null without ink there.
  BBox? inkBox(int x1, int x2, int y1, int y2) {
    final cx1 = math.max(0, x1 - box.x1), cx2 = math.min(w, x2 - box.x1);
    final cy1 = math.max(0, y1 - box.y1), cy2 = math.min(h, y2 - box.y1);
    var minX = cx2, maxX = -1, minY = cy2, maxY = -1;
    for (var y = cy1; y < cy2; y++) {
      for (var x = cx1; x < cx2; x++) {
        if (ink[y * w + x] == 0) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return null;
    return BBox(box.x1 + minX, box.y1 + minY, box.x1 + maxX + 1, box.y1 + maxY + 1);
  }
}

/// Looks at the ink of [block]; null for vertical, tiny or letterless blocks.
_Ink? _look(RgbImage image, TextBlock block) {
  if (block.direction == TextDirection.vertical) return null;
  final box = block.xyxy.clampTo(image.width, image.height);
  final w = box.width, h = box.height;
  if (w < 24 || h < 6) return null;

  // Background: the median colour of the block's edge.
  final edge = <List<int>>[[], [], []];
  void addEdge(int x, int y) {
    final o = image.offset(box.x1 + x, box.y1 + y);
    for (var c = 0; c < 3; c++) {
      edge[c].add(image.data[o + c]);
    }
  }

  for (var x = 0; x < w; x++) {
    addEdge(x, 0);
    addEdge(x, h - 1);
  }
  for (var y = 1; y < h - 1; y++) {
    addEdge(0, y);
    addEdge(w - 1, y);
  }
  final bg = [for (final values in edge) npPercentile(values, 50)];

  final ink = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    var o = image.offset(box.x1, box.y1 + y);
    for (var x = 0; x < w; x++, o += 3) {
      final d = image.data;
      if ((d[o] - bg[0]).abs() > _inkDifference ||
          (d[o + 1] - bg[1]).abs() > _inkDifference ||
          (d[o + 2] - bg[2]).abs() > _inkDifference) {
        ink[y * w + x] = 1;
      }
    }
  }

  // Letter height: the median height of the ink spots (dots and specks
  // left out). imkit's heights are one more than the extent.
  final spots = connectedComponentsWithStats(GrayImage(w, h, ink), connectivity: 8);
  final heights = [
    for (final s in spots.stats.skip(1))
      if (s.area >= 4 && s.height - 1 >= 3) (s.height - 1).toDouble(),
  ];
  if (heights.length < 3) return null;
  final letter = npPercentile(heights, 50);

  // Empty columns (one stray pixel allowed) between the first and the last
  // inked one.
  final columnInk = Int32List(w);
  for (var i = 0; i < w * h; i++) {
    if (ink[i] != 0) columnInk[i % w]++;
  }
  var first = 0, last = w - 1;
  while (first < w && columnInk[first] == 0) {
    first++;
  }
  while (last >= 0 && columnInk[last] == 0) {
    last--;
  }
  // A column holds at least [_minLetters] letters and is two letters wide:
  // a wide gap after one word of three letters is spacing, not columns.
  final letters = [
    for (final s in spots.stats.skip(1))
      if (s.area >= 4 && s.height - 1 >= 3) (s.left, s.left + s.width - 2),
  ];
  int lettersIn(int x1, int x2) => letters.where((l) => l.$1 >= x1 && l.$2 < x2).length;
  final least = math.max(8, columnGapLetters * letter);
  final stripes = <(int, int)>[];
  var start = -1;
  for (var x = first; x <= last; x++) {
    final empty = columnInk[x] <= 1;
    if (empty && start < 0) start = x;
    if (!empty && start >= 0) {
      if (x - start >= least &&
          start - first >= 2 * letter &&
          last + 1 - x >= 2 * letter &&
          lettersIn(first, start) >= _minLetters &&
          lettersIn(x, last + 1) >= _minLetters) {
        stripes.add((box.x1 + start, box.x1 + x));
      }
      start = -1;
    }
  }
  return _Ink(box, ink, letter, stripes);
}

/// The least number of letters on each side of a stripe.
const _minLetters = 3;

/// A stripe of a block with one row of text must be met in this many other
/// blocks: at the same place, with letters of about the same size.
const _minOtherBlocks = 2;

/// Splits the blocks of [blocks] that hold columns (see the library
/// comment); the others are kept as they are, in the same order. Blocks with
/// fixed lines (from a line finder) get their lines cut at the stripes and
/// grouped again; the others are cut into columns and the columns at tall
/// empty bands, and get new lines from [annotateLines].
List<TextBlock> splitColumnBlocks(RgbImage image, List<TextBlock> blocks, {LineAnnotator? annotateLines}) {
  final looks = [for (final b in blocks) _look(image, b)];
  final all = [
    for (final (i, l) in looks.indexed)
      if (l != null)
        for (final s in l.stripes) (i, s, l.letter),
  ];
  if (all.isEmpty) return blocks;

  // Stripes of other blocks at the same place: overlapping by half the
  // narrower one, letters within half again of each other's size.
  int metElsewhere(int i, (int, int) s, double letter) => {
    for (final (j, o, l) in all)
      if (j != i &&
          math.min(o.$2, s.$2) - math.max(o.$1, s.$1) >= math.min(o.$2 - o.$1, s.$2 - s.$1) / 2 &&
          math.max(l, letter) <= 1.5 * math.min(l, letter))
        j,
  }.length;

  final out = <TextBlock>[];
  for (final (i, block) in blocks.indexed) {
    final look = looks[i];
    final stripes = [
      for (final s in look?.stripes ?? const <(int, int)>[])
        if (look!.rowsAcross(s) >= 2 || metElsewhere(i, s, look.letter) >= _minOtherBlocks) s,
    ];
    if (stripes.isEmpty) {
      out.add(block);
      continue;
    }
    final parts = _split(image, block, look!, stripes, annotateLines);
    out.addAll(parts.length > 1 ? parts : [block]);
  }
  return out;
}

List<TextBlock> _split(
  RgbImage image,
  TextBlock block,
  _Ink look,
  List<(int, int)> stripes,
  LineAnnotator? annotateLines,
) {
  final box = look.box;
  final columns = <(int, int)>[];
  var x = box.x1;
  for (final (s1, s2) in stripes) {
    columns.add((x, s1));
    x = s2;
  }
  columns.add((x, box.x2));

  if (block.fixedLines && block.lines.isNotEmpty) {
    final pieces = <BBox>[
      for (final line in block.lines)
        for (final (c1, c2) in columns) ?_trimLine(look, line.axisBox, c1, c2),
    ];
    return [
      for (final b in groupLinesIntoBlocks(pieces))
        b
          ..textClass = block.textClass
          ..bubbleXyxy = block.bubbleXyxy
          ..fontColor = block.fontColor,
    ];
  }

  final parts = <BBox>[];
  for (final (c1, c2) in columns) {
    final column = look.inkBox(c1, c2, box.y1, box.y2);
    if (column == null) continue;
    // Tall empty bands split a column: a name, then the next name far below.
    final rowInk = List.filled(column.height, false);
    for (var y = column.y1; y < column.y2; y++) {
      rowInk[y - column.y1] = look.inkBox(column.x1, column.x2, y, y + 1) != null;
    }
    var top = column.y1, empty = 0;
    for (var y = column.y1; y < column.y2; y++) {
      if (rowInk[y - column.y1]) {
        if (empty >= _rowGapLetters * look.letter && y - empty > top) {
          if (look.inkBox(column.x1, column.x2, top, y - empty) case final part?) parts.add(part);
          top = y;
        }
        empty = 0;
      } else {
        empty++;
      }
    }
    if (look.inkBox(column.x1, column.x2, top, column.y2) case final part?) parts.add(part);
  }
  final split = [
    for (final p in parts)
      TextBlock(
        xyxy: _pad(p, look.letter, image),
        bubbleXyxy: block.bubbleXyxy,
        textClass: block.textClass,
        fontColor: extractForegroundColor(image.crop(p)),
        direction: block.direction,
      ),
  ];
  if (annotateLines != null) {
    try {
      annotateLines(image, split);
    } on Object {
      // Read whole, as blocks without lines are.
    }
    // The line splitter looks a little beyond the block, where the next
    // column's letters now are.
    for (final b in split) {
      b.lines = [
        for (final l in b.lines)
          if (l.axisBox case final a when a.x1 < b.xyxy.x1 || a.x2 > b.xyxy.x2)
            TextLine.box(BBox(math.max(a.x1, b.xyxy.x1), a.y1, math.min(a.x2, b.xyxy.x2), a.y2))
          else
            l,
      ];
    }
  }
  return split;
}

/// [line] cut to the columns [c1, c2) and trimmed to its ink there.
BBox? _trimLine(_Ink look, BBox line, int c1, int c2) {
  final x1 = math.max(line.x1, c1), x2 = math.min(line.x2, c2);
  if (x2 <= x1) return null;
  final ink = look.inkBox(x1, x2, line.y1, line.y2);
  if (ink == null || ink.width < look.letter) return null;
  final pad = math.max(1, (look.letter / 4).round());
  return BBox(math.max(x1, ink.x1 - pad), line.y1, math.min(x2, ink.x2 + pad), line.y2);
}

/// [box] with a margin of a quarter letter, as detected boxes have.
BBox _pad(BBox box, double letter, RgbImage image) {
  final m = math.max(2, (letter / 4).round());
  return BBox(box.x1 - m, box.y1 - m, box.x2 + m, box.y2 + m).clampTo(image.width, image.height);
}
