/// How the lettering of a block looks on the source page: letter size,
/// stroke weight, slant and outline. Measured when the block is read, so the
/// translation can be drawn the same way. Not in the original.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// Stroke width to letter height from which lettering counts as bold on a
/// page with too few blocks to compare.
const boldWeight = 0.19;

/// How much heavier than the page's usual lettering a bold block is.
const boldGain = 1.15;

/// Slant (horizontal shift per pixel of height) from which lettering counts
/// as italic.
const italicSlant = 0.12;

/// The look of a block's source lettering; sizes in source page pixels.
class SourceStyle {
  const SourceStyle({
    this.letterPx,
    this.strokePx,
    this.slant = 0,
    this.outlineColor,
    this.outlinePx = 0,
    this.inkWidthPx,
  });

  /// Median ink height of the letters of a line: the cap height of capitals,
  /// from ascenders to descenders otherwise. Null when not measured.
  final double? letterPx;

  /// Typical width of the strokes.
  final double? strokePx;

  /// How much vertical strokes lean right per pixel of height.
  final double slant;

  /// RGB colour of an outline around the letters; null: none.
  final int? outlineColor;

  /// Width of that outline.
  final double outlinePx;

  /// Widths of the inked parts of the lines, added up: with the letter
  /// height and the number of letters it tells narrow lettering from wide.
  final double? inkWidthPx;

  bool get hasOutline => outlineColor != null && outlinePx > 0;

  /// Stroke width to letter height; null when unknown.
  double? get weight => letterPx == null || strokePx == null || letterPx! <= 0 ? null : strokePx! / letterPx!;

  bool get italic => slant >= italicSlant;

  /// The same style on a page enlarged [f] times.
  SourceStyle scaled(double f) => SourceStyle(
    letterPx: letterPx == null ? null : letterPx! * f,
    strokePx: strokePx == null ? null : strokePx! * f,
    slant: slant,
    outlineColor: outlineColor,
    outlinePx: outlinePx * f,
    inkWidthPx: inkWidthPx == null ? null : inkWidthPx! * f,
  );

  Map<String, Object?> toJson() => {
    if (letterPx != null) 'letter_px': _round(letterPx!),
    if (strokePx != null) 'stroke_px': _round(strokePx!),
    if (slant != 0) 'slant': _round(slant),
    if (outlineColor != null) 'outline_color': '#${outlineColor!.toRadixString(16).padLeft(6, '0')}',
    if (outlinePx > 0) 'outline_px': _round(outlinePx),
    if (inkWidthPx != null) 'ink_width_px': _round(inkWidthPx!),
  };

  factory SourceStyle.fromJson(Map<String, Object?> j) {
    double? get(String key) => (j[key] as num?)?.toDouble();
    final color = j['outline_color'];
    return SourceStyle(
      letterPx: get('letter_px'),
      strokePx: get('stroke_px'),
      slant: get('slant') ?? 0,
      outlineColor: color is String ? int.tryParse(color.replaceFirst('#', ''), radix: 16) : null,
      outlinePx: get('outline_px') ?? 0,
      inkWidthPx: get('ink_width_px'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SourceStyle &&
      other.letterPx == letterPx &&
      other.strokePx == strokePx &&
      other.slant == slant &&
      other.outlineColor == outlineColor &&
      other.outlinePx == outlinePx &&
      other.inkWidthPx == inkWidthPx;

  @override
  int get hashCode => Object.hash(letterPx, strokePx, slant, outlineColor, outlinePx, inkWidthPx);
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;

/// The usual lettering of a page, to tell its bold blocks: comic lettering
/// is often heavy all over, so a block is bold when it is heavier than the
/// page's other blocks.
class PageLettering {
  const PageLettering(this.weight);

  /// Median stroke weight of the page's blocks; null with fewer than three.
  final double? weight;

  factory PageLettering.of(Iterable<TextBlock> blocks) {
    final weights = [for (final b in blocks) ?b.sourceStyle?.weight];
    return PageLettering(weights.length >= 3 ? npMedian(weights) : null);
  }

  bool isBold(SourceStyle style) {
    final w = style.weight;
    if (w == null) return false;
    return weight == null ? w >= boldWeight : w >= weight! * boldGain;
  }

  @override
  String toString() => weight == null ? '-' : _round(weight!).toString();
}

/// Whether [text] is written in capitals: at least three cased letters, at
/// least four in five of them upper case (OCR reads a few capitals as small
/// letters).
bool isMostlyUpperCase(String text) {
  var upper = 0, cased = 0;
  for (final r in text.runes) {
    final c = String.fromCharCode(r);
    final u = c.toUpperCase(), l = c.toLowerCase();
    if (u == l) continue;
    cased++;
    if (c == u) upper++;
  }
  return cased >= 3 && upper * 5 >= cased * 4;
}

/// The source style of [block] on [image], from its lines (the whole box when
/// it has none); null when nothing letter-like is found. Vertical blocks get
/// only an outline; only text outside speech bubbles gets one.
SourceStyle? measureSourceStyle(RgbImage image, TextBlock block) {
  final vertical = block.direction == TextDirection.vertical;
  final boxes = [
    for (final l in block.lines)
      if (l.axisBox.clampTo(image.width, image.height) case final b when b.width >= 4 && b.height >= 4) b,
  ];
  if (boxes.isEmpty) {
    final b = block.xyxy.clampTo(image.width, image.height);
    if (b.width < 4 || b.height < 4) return null;
    boxes.add(b);
  }
  final fill = block.fontColor;
  // Rows of capitals are all dense; in ordinary text the ascenders are
  // thinner than the small letters.
  final capitals = block.text.trim().isEmpty || isMostlyUpperCase(block.text);
  final heights = <double>[];
  final slants = <double>[];
  var inkWidth = 0;
  final lines = <_LineMask>[];
  var area = 0, edge = 0;
  for (final box in boxes) {
    final line = _LineMask.of(image, box, fill);
    if (line == null) continue;
    lines.add(line);
    area += line.area;
    edge += line.edge;
    if (!vertical) {
      if (line.letterHeight(dense: capitals ? 0.25 : 0.5) case final h?) heights.add(h);
      if (line.slant() case final s?) slants.add(s);
      inkWidth += line.inkWidth();
    }
  }
  if (area == 0) return null;
  final letterPx = heights.isEmpty ? null : npMedian(heights);
  final across = vertical
      ? npMedian([for (final l in lines) l.w])
      : (letterPx ?? npMedian([for (final l in lines) l.h]));
  // Strokes and slant of tiny letters are a pixel or two either way.
  final reliable = letterPx != null && letterPx >= minMeasuredLetterPx;
  // Text in a speech bubble has its background around it, not an outline
  // (a bubble's edge close to the letters would look like one).
  final ring = block.textClass != TextClass.bubble && across >= minMeasuredLetterPx
      ? _outline(image, lines, across)
      : null;
  return SourceStyle(
    letterPx: letterPx,
    // Each stroke shows two sides: its width is the area per side length.
    strokePx: reliable && edge > 0 ? 2 * area / edge : null,
    slant: reliable && slants.isNotEmpty ? npMedian(slants) : 0,
    outlineColor: ring?.$1,
    outlinePx: ring?.$2 ?? 0,
    inkWidthPx: vertical || inkWidth == 0 ? null : inkWidth.toDouble(),
  );
}

/// Letters smaller than this give no stroke weight or slant.
const minMeasuredLetterPx = 10.0;

double _luma(Uint8List d, int o) => 0.299 * d[o] + 0.587 * d[o + 1] + 0.114 * d[o + 2];

/// The letter pixels of one line box: the Otsu class on the side of the
/// text colour (the smaller class when it is unknown).
class _LineMask {
  _LineMask(this.box, this.mask, this.area, this.edge);

  final BBox box;

  /// 1 = letter, row by row over [box].
  final Uint8List mask;
  final int area;

  /// Letter pixels with a 4-neighbour outside the letters.
  final int edge;

  int get w => box.width;
  int get h => box.height;

  static _LineMask? of(RgbImage image, BBox box, List<int>? fill) {
    final w = box.width, h = box.height;
    final gray = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        gray[y * w + x] = _luma(image.data, image.offset(box.x1 + x, box.y1 + y)).round();
      }
    }
    // Letters are within [lo, hi]. Outlined letters have three tones
    // (letters, outline, background): while the letters' side still takes
    // much of the box, it is split again.
    var lo = 0, hi = 255;
    bool? darkLetters;
    final fillLuma = fill != null && fill.length >= 3 ? 0.299 * fill[0] + 0.587 * fill[1] + 0.114 * fill[2] : null;
    var area = 0;
    for (var round = 0; round < 3; round++) {
      final inside = Uint8List.fromList([
        for (final v in gray)
          if (v >= lo && v <= hi) v,
      ]);
      if (inside.length < 8) break;
      final t = mahotasOtsu(inside);
      var dark = 0;
      for (final v in inside) {
        if (v <= t) dark++;
      }
      darkLetters ??= fillLuma != null ? fillLuma <= t : dark * 2 <= inside.length;
      if (darkLetters) {
        hi = t;
        area = dark;
      } else {
        lo = t + 1;
        area = inside.length - dark;
      }
      if (area <= gray.length * 0.45) break;
    }
    final mask = Uint8List(w * h);
    area = 0;
    for (var i = 0; i < gray.length; i++) {
      if (gray[i] >= lo && gray[i] <= hi) {
        mask[i] = 1;
        area++;
      }
    }
    // A class that fills most of the box is the background, not letters.
    if (area == 0 || area > gray.length * 0.7) return null;
    var edge = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (mask[i] == 0) continue;
        if (x == 0 || mask[i - 1] == 0) edge++;
        if (x == w - 1 || mask[i + 1] == 0) edge++;
        if (y == 0 || mask[i - w] == 0) edge++;
        if (y == h - 1 || mask[i + w] == 0) edge++;
      }
    }
    return _LineMask(box, mask, area, edge);
  }

  /// Height of the band of rows dense with ink: rows with at least [dense]
  /// of the densest row's letter pixels, from the first to the last.
  double? letterHeight({required double dense}) {
    final rows = List.filled(h, 0);
    for (var y = 0; y < h; y++) {
      var n = 0;
      for (var x = 0; x < w; x++) {
        n += mask[y * w + x];
      }
      rows[y] = n;
    }
    final peak = rows.fold(0, math.max);
    if (peak < 2) return null;
    final first = rows.indexWhere((n) => n >= peak * dense), last = rows.lastIndexWhere((n) => n >= peak * dense);
    final band = last - first + 1;
    return band >= 3 ? band.toDouble() : null;
  }

  /// From the first to the last column with ink.
  int inkWidth() {
    var first = w, last = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (mask[y * w + x] == 1) {
          if (x < first) first = x;
          if (x > last) last = x;
        }
      }
    }
    return last < first ? 0 : last - first + 1;
  }

  /// The shear that makes the column profile sharpest: vertical strokes line
  /// up when the slant is undone.
  double? slant() {
    if (h < 6 || area < 20) return null;
    final ys = <int>[], xs = <int>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (mask[y * w + x] == 1) {
          ys.add(y);
          xs.add(x);
        }
      }
    }
    final pad = h;
    final cols = Int32List(w + 2 * pad + 1);
    double score(double s) {
      cols.fillRange(0, cols.length, 0);
      for (var i = 0; i < xs.length; i++) {
        // Undo a lean to the right: the higher the pixel, the further left.
        final x = (xs[i] + s * (ys[i] - h) + pad).round();
        if (x >= 0 && x < cols.length) cols[x]++;
      }
      var sum = 0.0;
      for (final c in cols) {
        sum += c * c;
      }
      return sum;
    }

    var best = 0.0, bestScore = score(0);
    for (var k = -20; k <= 20; k++) {
      final s = k * 0.025;
      if (k == 0) continue;
      final v = score(s);
      if (v > bestScore) {
        bestScore = v;
        best = s;
      }
    }
    return best;
  }
}

/// Colour distance under which pixels count as the same colour.
const _sameColor = 60.0;

/// An outline around the letters of [lines] (their RGB colour and width),
/// told from the background by colour rings around the letters: an outline
/// is a uniform ring of its own colour that ends a few pixels out, where the
/// background begins; a bubble's background stays uniform all the way out.
/// [across] is the letter height (column width of vertical text).
(int, double)? _outline(RgbImage image, List<_LineMask> lines, double across) {
  if (lines.isEmpty) return null;
  final reach = math.max(6, (math.max(across, 8) * 0.45).round());
  final outer = lines
      .map((l) => l.box)
      .reduce((a, b) => a.union(b))
      .inflate(reach, reach)
      .clampTo(image.width, image.height);
  final w = outer.width, h = outer.height;
  if (w < 4 || h < 4) return null;
  // City-block distance to the nearest letter pixel, capped at reach + 1.
  final cap = reach + 1;
  final dist = Int32List(w * h)..fillRange(0, w * h, cap);
  for (final line in lines) {
    final box = line.box;
    for (var y = 0; y < line.h; y++) {
      for (var x = 0; x < line.w; x++) {
        if (line.mask[y * line.w + x] == 1) dist[(y + box.y1 - outer.y1) * w + x + box.x1 - outer.x1] = 0;
      }
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      var d = dist[i];
      if (x > 0) d = math.min(d, dist[i - 1] + 1);
      if (y > 0) d = math.min(d, dist[i - w] + 1);
      dist[i] = d;
    }
  }
  for (var y = h - 1; y >= 0; y--) {
    for (var x = w - 1; x >= 0; x--) {
      final i = y * w + x;
      var d = dist[i];
      if (x < w - 1) d = math.min(d, dist[i + 1] + 1);
      if (y < h - 1) d = math.min(d, dist[i + w] + 1);
      dist[i] = d;
    }
  }
  final rings = [for (var d = 0; d <= reach; d++) <int>[]];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = dist[y * w + x];
      if (d <= reach) rings[d].add(image.offset(outer.x1 + x, outer.y1 + y));
    }
  }
  final data = image.data;
  // Median colour of a ring and the share of its pixels close to it.
  (List<double>, double)? stats(List<int> px) {
    if (px.length < 12) return null;
    final c = [
      for (var k = 0; k < 3; k++) npMedian([for (final o in px) data[o + k]]),
    ];
    var same = 0;
    for (final o in px) {
      if (_dist3(data, o, c) <= _sameColor) same++;
    }
    return (c, same / px.length);
  }

  final fill = stats(rings[0]);
  if (fill == null || reach < 4) return null;
  // Ring 1 is blended with the letters: ring 2 decides the colour.
  final first = stats(rings[2]);
  if (first == null || first.$2 < 0.75 || _dist(first.$1, fill.$1) < 90) return null;
  var width = 2;
  while (width < reach) {
    final r = stats(rings[width + 1]);
    if (r == null || r.$2 < 0.85 || _dist(r.$1, first.$1) > _sameColor) break;
    width++;
  }
  // The same colour all the way out is the background, not an outline.
  if (width >= reach - 1) return null;
  final color = first.$1.map((v) => v.round().clamp(0, 255)).toList();
  return ((color[0] << 16) | (color[1] << 8) | color[2], width.toDouble());
}

double _dist(List<double> a, List<double> b) {
  final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
  return math.sqrt(dr * dr + dg * dg + db * db);
}

double _dist3(Uint8List d, int o, List<double> c) {
  final dr = d[o] - c[0], dg = d[o + 1] - c[1], db = d[o + 2] - c[2];
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// What tells one font from another in measured lettering: stroke weight,
/// slant and width per character (to the letter height). For suggesting a
/// font like the source's.
class LetteringShape {
  const LetteringShape(this.weight, this.slant, this.width);

  final double weight;
  final double slant;
  final double width;

  /// The shape of [style] measured on [text] drawn in [lines] lines (the
  /// spaces where lines break take no width); null when unmeasured.
  static LetteringShape? of(SourceStyle style, String text, {int lines = 1}) {
    final weight = style.weight, letter = style.letterPx, ink = style.inkWidthPx;
    final chars = text.trim().length - (lines - 1);
    if (weight == null || letter == null || ink == null || chars < 3 || letter <= 0) return null;
    return LetteringShape(weight, style.slant, ink / (letter * chars));
  }

  /// The usual shape of [blocks] (medians), from blocks with measured
  /// lettering and text; null when there are none.
  static LetteringShape? ofPage(Iterable<TextBlock> blocks) {
    final shapes = [
      for (final b in blocks)
        if (b.sourceStyle case final s?) ?of(s, b.text, lines: math.max(1, b.lines.length)),
    ];
    if (shapes.isEmpty) return null;
    return LetteringShape(
      npMedian([for (final s in shapes) s.weight]),
      npMedian([for (final s in shapes) s.slant]),
      npMedian([for (final s in shapes) s.width]),
    );
  }

  /// How far [other] is from this shape: 1 is a clear difference in one of
  /// weight (15 %), slant (0.08) or width (12 %).
  double distance(LetteringShape other) =>
      (math.log(other.weight / weight)).abs() / 0.15 +
      (other.slant - slant).abs() / 0.08 +
      (math.log(other.width / width)).abs() / 0.12;

  @override
  String toString() => 'weight ${_round(weight)}, slant ${_round(slant)}, width ${_round(width)}';
}
