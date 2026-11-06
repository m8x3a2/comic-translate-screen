/// Columns inside one block (new): a list of names and their descriptions,
/// the stats of a game character, a schedule. The detectors find one block
/// for both columns, and the line finder joins a name and its description
/// into one line; the reader then mixes them or loses words.
///
/// A block is split where an empty stripe crosses it from top to bottom, at
/// least [columnGapLetters] letter heights wide (a space between words is
/// about half a letter). One wide gap in one line is not enough: the stripe
/// must separate text in two rows, or another block of the page must have a
/// stripe at the same place. A title over both columns blocks the stripe:
/// without one, the block is cut at its widest empty band of rows and each
/// part is looked at again; nothing is cut when no part has columns.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import 'foreground_color.dart';
import 'text_blocks.dart';

/// The least width of a stripe between columns, in letter heights.
const columnGapLetters = 1.5;

/// Empty rows this many letter heights tall (and much taller than between
/// the lines) separate two parts of a column.
const _rowGapLetters = 1.0;

/// The least empty band of rows a block without a stripe is cut at, in
/// letter heights.
const _cutLetters = 0.5;

/// How many times a block without a stripe is cut across in search of one
/// (a title above the columns, a note below them).
const _maxCuts = 3;

/// A pixel differing from the block's background by more than this (in any
/// channel) is ink.
const _inkDifference = 60;

/// The least number of letters on each side of a stripe.
const _minLetters = 3;

/// A stripe without two rows of text across it must be met in this many
/// other blocks: at the same place, with letters of about the same size.
const _minOtherBlocks = 2;

/// The ink of one block.
class _Ink {
  _Ink(this.box, this.ink, this.letter, this.letters);

  /// The block's box on the page (clamped).
  final BBox box;

  /// 1 = ink, row-major over [box].
  final Uint8List ink;

  /// Median letter height (px).
  final double letter;

  /// The letters (ink spots, specks left out) as page boxes.
  final List<BBox> letters;

  int get w => box.width;
  int get h => box.height;

  /// Empty stripes across the page rows [y1, y2) (x from–to on the page),
  /// wide enough, with text on both sides.
  List<(int, int)> stripes(int y1, int y2) {
    final columnInk = Int32List(w);
    for (var y = y1 - box.y1; y < y2 - box.y1; y++) {
      for (var x = 0; x < w; x++) {
        columnInk[x] += ink[y * w + x];
      }
    }
    var first = 0, last = w - 1;
    while (first < w && columnInk[first] == 0) {
      first++;
    }
    while (last >= 0 && columnInk[last] == 0) {
      last--;
    }
    final rows = [
      for (final l in letters)
        if (l.y1 >= y1 && l.y2 <= y2) l,
    ];
    int lettersIn(int x1, int x2) => rows.where((l) => l.x1 >= box.x1 + x1 && l.x2 <= box.x1 + x2).length;
    // Empty runs between letters and words (one stray pixel in a column is
    // allowed). Stripes stand apart from them: wide enough, and 1.8 times as
    // wide as the widest run that is not a stripe; else they are spacing
    // (wide words over a drawing whose specks pass for letters).
    final runs = <(int, int)>[];
    var start = -1;
    for (var x = first; x <= last + 1; x++) {
      final empty = x <= last && columnInk[x] <= 1;
      if (empty && start < 0) start = x;
      if (!empty && start >= 0) {
        if (x - start >= 2) runs.add((start, x));
        start = -1;
      }
    }
    final widths = [for (final (a, b) in runs) b - a]..sort((a, b) => b - a);
    final base = math.max(8, columnGapLetters * letter);
    double? least;
    for (var k = 0; k < widths.length && widths[k] >= base; k++) {
      if (widths[k] >= 1.8 * (k + 1 < widths.length ? widths[k + 1] : 0)) {
        least = widths[k].toDouble();
        break;
      }
    }
    if (least == null) return const [];
    final out = <(int, int)>[];
    for (final (start, x) in runs) {
      if (x - start >= least &&
          start - first >= 2 * letter &&
          last + 1 - x >= 2 * letter &&
          lettersIn(first, start) >= _minLetters &&
          lettersIn(x, last + 1) >= _minLetters) {
        out.add((box.x1 + start, box.x1 + x));
      }
    }
    return out;
  }

  /// Rows [y1, y2) with ink on both sides of [stripe]: how many bands of
  /// such rows at least half a letter tall.
  int rowsAcross((int, int) stripe, int y1, int y2) {
    final (s1, s2) = stripe;
    var bands = 0, run = 0;
    for (var y = y1 - box.y1; y < y2 - box.y1; y++) {
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

  /// The widest band of empty rows inside the page rows [y1, y2) with ink
  /// above and below, at least [_cutLetters] letters tall, or null.
  (int, int)? widestEmptyRows(int y1, int y2) {
    (int, int)? best;
    var start = -1, seenInk = false;
    for (var y = y1 - box.y1; y < y2 - box.y1; y++) {
      var empty = true;
      for (var x = 0; x < w && empty; x++) {
        if (ink[y * w + x] != 0) empty = false;
      }
      if (empty) {
        if (seenInk && start < 0) start = y;
      } else {
        if (start >= 0 && y - start >= _cutLetters * letter && (best == null || y - start > best.$2 - best.$1)) {
          best = (box.y1 + start, box.y1 + y);
        }
        start = -1;
        seenInk = true;
      }
    }
    return best;
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

/// Looks at the ink of [block]; null for vertical lines of a line finder,
/// tiny or letterless blocks. The direction the line heuristics gave a
/// comic block is not trusted: two columns of English made it "vertical".
/// Vertical Japanese columns stand much closer than a stripe.
_Ink? _look(RgbImage image, TextBlock block) {
  if (block.fixedLines && block.direction == TextDirection.vertical) return null;
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

  // Letters: the ink spots (dots and specks left out). imkit's sizes are one
  // more than the extent.
  final spots = connectedComponentsWithStats(GrayImage(w, h, ink), connectivity: 8);
  final found = [
    for (final s in spots.stats.skip(1))
      if (s.area >= 4 && s.height - 1 >= 3) s,
  ];
  if (found.length < 3) return null;
  // The letter height: the median of the spots at least a third as tall as
  // the tall ones, so that the specks of a drawing under the text (hundreds,
  // a few pixels each) do not make it tiny.
  final heights = [for (final s in found) (s.height - 1).toDouble()];
  final tall = npPercentile(heights, 90);
  final letter = npPercentile([
    for (final v in heights)
      if (v >= tall / 3) v,
  ], 50);
  return _Ink(box, ink, letter, [
    for (final s in found)
      BBox(box.x1 + s.left, box.y1 + s.top, box.x1 + s.left + s.width - 1, box.y1 + s.top + s.height - 1),
  ]);
}

/// Splits the blocks of [blocks] that hold columns (see the library
/// comment); the others are kept as they are, in the same order. Blocks with
/// fixed lines (from a line finder) get their lines cut at the parts and
/// grouped again; the others are cut into the parts, and get new lines from
/// [annotateLines].
List<TextBlock> splitColumnBlocks(RgbImage image, List<TextBlock> blocks, {LineAnnotator? annotateLines}) {
  final looks = [for (final b in blocks) _look(image, b)];
  // The stripes across whole blocks, to find the same place in others.
  final all = [
    for (final (i, l) in looks.indexed)
      if (l != null)
        for (final s in l.stripes(l.box.y1, l.box.y2)) (i, s, l.letter),
  ];

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
    final parts = look == null
        ? null
        : _parts(
            look,
            look.box.y1,
            look.box.y2,
            (s, y1, y2) => look.rowsAcross(s, y1, y2) >= 2 || metElsewhere(i, s, look.letter) >= _minOtherBlocks,
          );
    final split = parts == null ? const <TextBlock>[] : _blocks(image, block, look!, parts, annotateLines);
    out.addAll(split.length > 1 ? split : [block]);
  }
  return out;
}

/// The parts of the page rows [y1, y2) of [look]: columns at the stripes
/// [confirmed] there, else the rows cut at their widest empty band and each
/// half looked at again, [depth] times at most. Null when nothing is cut.
List<BBox>? _parts(
  _Ink look,
  int y1,
  int y2,
  bool Function((int, int) stripe, int y1, int y2) confirmed, {
  int depth = _maxCuts,
}) {
  final stripes = [
    for (final s in look.stripes(y1, y2))
      if (confirmed(s, y1, y2)) s,
  ];
  if (stripes.isNotEmpty) {
    if (_columns(look, stripes, y1, y2) case final columns?) return columns;
  }
  if (depth == 0) return null;
  final gap = look.widestEmptyRows(y1, y2);
  if (gap == null) return null;
  final top = _parts(look, y1, gap.$1, confirmed, depth: depth - 1);
  final bottom = _parts(look, gap.$2, y2, confirmed, depth: depth - 1);
  if (top == null && bottom == null) return null;
  return [
    ...top ?? [?look.inkBox(look.box.x1, look.box.x2, y1, gap.$1)],
    ...bottom ?? [?look.inkBox(look.box.x1, look.box.x2, gap.$2, y2)],
  ];
}

/// The rows [y1, y2) of [look] cut into columns at [stripes], and the
/// columns at tall empty bands (a name, then the next name far below).
/// Null unless two columns at least are two letters wide (a row of colons
/// is no column).
List<BBox>? _columns(_Ink look, List<(int, int)> stripes, int y1, int y2) {
  final ranges = <(int, int)>[];
  var x = look.box.x1;
  for (final (s1, s2) in stripes) {
    ranges.add((x, s1));
    x = s2;
  }
  ranges.add((x, look.box.x2));

  // The empty bands of rows in each column: (first row, height).
  final columns = <(BBox, List<(int, int)>)>[];
  for (final (c1, c2) in ranges) {
    final column = look.inkBox(c1, c2, y1, y2);
    if (column == null) continue;
    final gaps = <(int, int)>[];
    var empty = 0;
    for (var y = column.y1; y < column.y2; y++) {
      if (look.inkBox(column.x1, column.x2, y, y + 1) != null) {
        if (empty > 0) gaps.add((y - empty, empty));
        empty = 0;
      } else {
        empty++;
      }
    }
    columns.add((column, gaps));
  }
  if (columns.where((c) => c.$1.width >= 2 * look.letter).length < 2) return null;
  // A column is cut where the gap is much taller than between its lines
  // (widely spaced lines of a phone screen stay together).
  final all = [
    for (final (_, gaps) in columns)
      for (final (_, height) in gaps) height,
  ];
  final lineGap = all.isEmpty ? 0.0 : npPercentile(all, 25);
  final least = math.max(_rowGapLetters * look.letter, 1.8 * lineGap);
  final parts = <BBox>[];
  for (final (column, gaps) in columns) {
    var top = column.y1;
    for (final (start, height) in gaps) {
      if (height < least) continue;
      if (look.inkBox(column.x1, column.x2, top, start) case final part?) parts.add(part);
      top = start + height;
    }
    if (look.inkBox(column.x1, column.x2, top, column.y2) case final part?) parts.add(part);
  }
  return parts;
}

/// The blocks [block] becomes with [parts].
List<TextBlock> _blocks(RgbImage image, TextBlock block, _Ink look, List<BBox> parts, LineAnnotator? annotateLines) {
  if (block.fixedLines && block.lines.isNotEmpty) {
    // Each part takes the lines whose middle row is in it, cut to it; a line
    // in no part becomes a block of its own.
    final byPart = [for (final _ in parts) <BBox>[]];
    final alone = <BBox>[];
    for (final line in block.lines.map((l) => l.axisBox)) {
      final middle = (line.y1 + line.y2) ~/ 2;
      var placed = false;
      for (final (k, part) in parts.indexed) {
        if (middle < part.y1 || middle >= part.y2) continue;
        if (_trimLine(look, line, part.x1, part.x2) case final piece?) {
          byPart[k].add(piece);
          placed = true;
        }
      }
      if (!placed) alone.add(line);
    }
    TextBlock blockOf(List<BBox> lines) {
      lines.sort((a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1));
      return TextBlock(
        xyxy: lines.reduce((a, b) => a.union(b)),
        bubbleXyxy: block.bubbleXyxy,
        textClass: block.textClass,
        lines: [for (final l in lines) TextLine.box(l)],
        fontColor: block.fontColor,
        direction: TextDirection.horizontal,
      )..fixedLines = true;
    }

    return [
      for (final lines in byPart)
        if (lines.isNotEmpty) blockOf(lines),
      for (final line in alone) blockOf([line]),
    ];
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
  final x1 = math.max(line.x1, c1 - 1), x2 = math.min(line.x2, c2 + 1);
  if (x2 <= x1) return null;
  final ink = look.inkBox(x1, x2, line.y1, line.y2);
  if (ink == null || ink.width < look.letter) return null;
  final pad = math.max(1, (look.letter / 4).round());
  return BBox(math.max(line.x1, ink.x1 - pad), line.y1, math.min(line.x2, ink.x2 + pad), line.y2);
}

/// [box] with a margin of a quarter letter, as detected boxes have.
BBox _pad(BBox box, double letter, RgbImage image) {
  final m = math.max(2, (letter / 4).round());
  return BBox(box.x1 - m, box.y1 - m, box.x2 + m, box.y2 + m).clampTo(image.width, image.height);
}
