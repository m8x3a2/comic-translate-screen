/// Pictures for the chat: each piece of text cut out of its page with its
/// label above it, put together on sheets (one picture is easier to send
/// than thirty), and pictures of whole pages with the labels on them.
library;

import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import '../render/upscale.dart';
import 'exchange_answer.dart';
import 'exchange_settings.dart';
import 'pixel_font.dart';

/// Lines of text thinner than this (pixels) are enlarged on the cut-outs.
const exchangeMinLinePx = 24.0;

/// Cut-outs lower than this (pixels) are enlarged.
const exchangeMinCropPx = 56;
const exchangeMaxEnlarge = 3.0;

const _labelScale = 4, _labelPad = 6, _border = 2, _gap = 18, _margin = 16;
const _labelBg = [255, 224, 0], _ink = [0, 0, 0], _frame = [150, 150, 150], _white = [255, 255, 255];
const _boxColor = [230, 30, 30];

/// [image] resized to [width]×[height] (area averaging when shrinking).
RgbImage resizeRgb(RgbImage image, int width, int height) {
  if (width == image.width && height == image.height) return image;
  final src = CvBridge.rgbToMat(image);
  try {
    final shrink = width < image.width;
    final dst = cv.resize(src, (
      math.max(1, width),
      math.max(1, height),
    ), interpolation: shrink ? cv.INTER_AREA : cv.INTER_LANCZOS4);
    try {
      return CvBridge.matToRgb(dst);
    } finally {
      dst.dispose();
    }
  } finally {
    src.dispose();
  }
}

/// The piece of [page] around [block] with a little room around the text,
/// enlarged when the letters are small.
RgbImage cropForExchange(RgbImage page, TextBlock block) {
  final box = block.xyxy;
  final pad = (0.15 * math.min(box.width, box.height)).round().clamp(6, 40);
  final area = box.inflate(pad, pad).clampTo(page.width, page.height);
  final crop = page.crop(area.isEmpty ? BBox(0, 0, page.width, page.height) : area);
  var f = 1.0;
  final line = block.linePx;
  if (line != null && line > 0 && line < exchangeMinLinePx) f = exchangeMinLinePx / line;
  if (crop.height < exchangeMinCropPx) f = math.max(f, exchangeMinCropPx / crop.height);
  f = math.min(f, exchangeMaxEnlarge);
  return f > 1.05 ? upscaleImage(crop, f) : crop;
}

/// [page] made smaller (longest side at most [maxPx]) with a red box and the
/// label of every piece on it.
RgbImage contextPicture(RgbImage page, List<(ExchangeLabel, BBox)> boxes, int maxPx) {
  final f = math.min(1.0, maxPx / math.max(page.width, page.height));
  final out = f < 1.0 ? resizeRgb(page, (page.width * f).round(), (page.height * f).round()) : page.clone();
  final scale = math.max(2, (math.max(out.width, out.height) / 500).round());
  final rects = [
    for (final (_, box) in boxes)
      BBox(
        (box.x1 * f).round(),
        (box.y1 * f).round(),
        (box.x1 * f).round() + math.max(4, (box.width * f).round()),
        (box.y1 * f).round() + math.max(4, (box.height * f).round()),
      ),
  ];
  for (final r in rects) {
    strokeRect(out, r.x1, r.y1, r.width, r.height, math.max(2, scale ~/ 2 + 1), _boxColor);
  }
  final placed = <BBox>[];
  for (final (i, (label, _)) in boxes.indexed) {
    final r = rects[i];
    final (tw, th) = pixelTextSize(label.code, scale);
    final lw = tw + 2 * scale, lh = th + 2 * scale;
    BBox at(int x, int y) => BBox(x, y, x + lw, y + lh);
    // Outside the box first (its text stays visible), inside only when
    // there is no room around it.
    final outside = [
      at(r.x1, r.y1 - lh),
      at(r.x1, r.y2),
      at(r.x2 - lw, r.y1 - lh),
      at(r.x2 - lw, r.y2),
      at(r.x1 - lw, r.y1),
      at(r.x2, r.y1),
    ].where((c) => c.x1 >= 0 && c.y1 >= 0 && c.x2 <= out.width && c.y2 <= out.height).toList();
    bool free(BBox c) => placed.every((o) => c.intersection(o) == null);
    bool clear(BBox c) =>
        free(c) &&
        [
          for (final (k, o) in rects.indexed)
            if (k != i) o,
        ].every((o) => c.intersection(o) == null);
    final spot = outside.where(clear).firstOrNull ?? outside.where(free).firstOrNull ?? at(r.x1, r.y1);
    placed.add(spot);
    fillRect(out, spot.x1, spot.y1, lw, lh, _labelBg);
    drawPixelText(out, label.code, spot.x1 + scale, spot.y1 + scale, scale, _ink);
  }
  return out;
}

/// One picture on a sheet: a cut-out with its label, or a whole page.
class SheetPiece {
  const SheetPiece(this.image, {this.label, this.page = 0, this.context = false});

  final RgbImage image;

  /// Null for a picture of the whole page.
  final ExchangeLabel? label;
  final int page;
  final bool context;
}

class ExchangeSheet {
  const ExchangeSheet(this.image, this.labels);

  final RgbImage image;

  /// The pieces on it, in order.
  final List<ExchangeLabel> labels;
}

/// Puts [pieces] (cut-outs in order, with whole pages before the cut-outs of
/// their page) on sheets of at most [maxPx]×[maxPx]. [groups]: the user's
/// own grouping (indexes into the cut-outs, see [parseSheetGroups]); the
/// rest follows [grouping].
List<ExchangeSheet> buildSheets(
  List<SheetPiece> pieces, {
  SheetGrouping grouping = SheetGrouping.size,
  int perSheet = 8,
  int maxPx = 1600,
  bool sheetPerPage = false,
  List<List<int>> groups = const [],
}) {
  final cuts = [
    for (final (i, p) in pieces.indexed)
      if (!p.context) i,
  ];
  // Groups of cut-outs (indexes into [cuts]).
  final named = {for (final g in groups) ...g};
  final chunks = <List<int>>[...groups];
  var run = <int>[];
  void flush() {
    if (run.isNotEmpty) chunks.add(run);
    run = [];
  }

  for (var k = 0; k < cuts.length; k++) {
    if (named.contains(k)) {
      flush();
      continue;
    }
    final newPage = run.isNotEmpty && pieces[cuts[run.last]].page != pieces[cuts[k]].page;
    if ((sheetPerPage && newPage) || (grouping == SheetGrouping.count && run.length >= perSheet)) flush();
    run.add(k);
  }
  flush();
  chunks.sort((a, b) => a.first - b.first);

  // Whole pages go with the chunk that has their first cut-out.
  final pagesDone = <int>{};
  final sheets = <ExchangeSheet>[];
  for (final chunk in chunks) {
    final tiles = <SheetPiece>[];
    for (final k in chunk) {
      final piece = pieces[cuts[k]];
      if (pagesDone.add(piece.page)) {
        tiles.addAll(pieces.where((p) => p.context && p.page == piece.page));
      }
      tiles.add(piece);
    }
    sheets.addAll(_pack(tiles, maxPx));
  }
  return sheets;
}

/// Rows of tiles, left to right; a new sheet when the next row would not
/// fit.
List<ExchangeSheet> _pack(List<SheetPiece> pieces, int maxPx) {
  final tiles = [for (final p in pieces) _tile(p, maxPx - 2 * _margin)];
  final sheets = <ExchangeSheet>[];
  var start = 0;
  while (start < tiles.length) {
    final placed = <(int, int, int)>[]; // tile, x, y
    var x = _margin, y = _margin, rowH = 0, usedW = 0, bottom = 0;
    var i = start;
    for (; i < tiles.length; i++) {
      final t = tiles[i];
      if (x > _margin && x + t.width + _margin > maxPx) {
        x = _margin;
        y += rowH + _gap;
        rowH = 0;
      }
      if (y + t.height + _margin > maxPx && placed.isNotEmpty) break;
      placed.add((i, x, y));
      x += t.width + _gap;
      rowH = math.max(rowH, t.height);
      usedW = math.max(usedW, x - _gap);
      bottom = math.max(bottom, y + t.height);
    }
    final height = bottom + _margin;
    final sheet = RgbImage.filled(usedW + _margin, height, 255, 255, 255);
    for (final (k, tx, ty) in placed) {
      blit(sheet, tiles[k], tx, ty);
    }
    sheets.add(ExchangeSheet(sheet, [for (final (k, _, _) in placed) ?pieces[k].label]));
    start = i;
  }
  return sheets;
}

/// A cut-out framed with its label above it, at most [limit] pixels on each
/// side.
RgbImage _tile(SheetPiece piece, int limit) {
  final label = piece.label?.toString();
  final (lw, lh) = label == null ? (0, 0) : pixelTextSize(label, _labelScale);
  final bar = label == null ? 0 : lh + 2 * _labelPad;
  var img = piece.image;
  final room = limit - 2 * _border;
  final f = math.min(1.0, math.min(room / img.width, (room - bar) / img.height));
  if (f < 1.0) img = resizeRgb(img, math.max(1, (img.width * f).floor()), math.max(1, (img.height * f).floor()));
  final w = math.max(img.width, lw + 2 * _labelPad) + 2 * _border;
  final h = bar + img.height + 2 * _border;
  final tile = RgbImage.filled(w, h, _white[0], _white[1], _white[2]);
  if (label != null) {
    fillRect(tile, 0, 0, lw + 2 * _labelPad, bar, _labelBg);
    drawPixelText(tile, label, _labelPad, _labelPad, _labelScale, _ink);
  }
  strokeRect(tile, 0, bar, w, h - bar, _border, _frame);
  blit(tile, img, _border, bar + _border);
  return tile;
}
