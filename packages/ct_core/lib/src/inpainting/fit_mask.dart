/// "Fit to letters" (new in this project): a piece of the mask painted
/// roughly over text shrinks to the letters inside it plus a small margin.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/morphology.dart';
import '../model/geometry.dart';

/// Default margin around the letters, in pixels.
const fitMaskMargin = 3;

/// Gray levels a pixel must differ from the background to count as ink when
/// the letters are found by contrast.
const _minContrast = 48;

/// Ink spots smaller than this (pixels) are noise, not letters.
const _minSpot = 4;

/// What [fitMaskToLetters] did.
class FitMaskResult {
  const FitMaskResult(this.mask, {required this.fitted, required this.empty});

  /// The whole mask with the pieces fitted.
  final GrayImage mask;

  /// Pieces shrunk to their letters.
  final int fitted;

  /// Pieces left as they were: no letters found in them.
  final int empty;
}

/// The pieces (8-connected parts) of [mask] at [seeds] — every piece when
/// [seeds] is empty — shrunk to the letters of [image] inside them, grown by
/// [margin] pixels. The letters are those of [letters] (a text masker's
/// map of the page) where it found enough of them in a piece; else what
/// stands out from the colour along the piece's edge (hand-drawn sounds, a
/// logo, letters the masker misses). Fitted pixels are 255 (letters for the
/// network); the rest of the mask keeps its values. A mask taller than the
/// image (webtoon) keeps its rows below the image as they are.
FitMaskResult fitMaskToLetters(
  RgbImage image,
  GrayImage mask,
  List<Point2> seeds, {
  GrayImage? letters,
  int margin = fitMaskMargin,
}) {
  final w = mask.width, mh = mask.height;
  final h = math.min(mh, image.height);
  final cc = connectedComponentsWithStats(mask, connectivity: 8);
  final labels = cc.labels;
  final chosen = <int>{};
  if (seeds.isEmpty) {
    for (var l = 1; l < cc.count; l++) {
      chosen.add(l);
    }
  } else {
    for (final s in seeds) {
      final x = s.x.floor(), y = s.y.floor();
      if (x < 0 || y < 0 || x >= w || y >= mh) continue;
      final l = labels[y * w + x];
      if (l > 0) chosen.add(l);
    }
  }
  final out = GrayImage(w, mh, Uint8List.fromList(mask.data));
  if (chosen.isEmpty) return FitMaskResult(out, fitted: 0, empty: 0);

  // Bounds of each chosen piece within the image.
  final x1 = <int, int>{}, y1 = <int, int>{}, x2 = <int, int>{}, y2 = <int, int>{};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final l = labels[y * w + x];
      if (l == 0 || !chosen.contains(l)) continue;
      if (!x1.containsKey(l)) {
        x1[l] = x;
        y1[l] = y;
        x2[l] = x + 1;
        y2[l] = y + 1;
      } else {
        if (x < x1[l]!) x1[l] = x;
        if (x + 1 > x2[l]!) x2[l] = x + 1;
        y2[l] = y + 1;
      }
    }
  }

  var fitted = 0, empty = 0;
  for (final l in chosen) {
    if (!x1.containsKey(l)) {
      empty++;
      continue;
    }
    final box = BBox(x1[l]!, y1[l]!, x2[l]!, y2[l]!);
    final ink = _inkOf(image, labels, w, l, box, letters);
    if (ink == null) {
      empty++;
      continue;
    }
    // The letters grown by the margin, in a crop with room for it.
    final cx1 = math.max(0, box.x1 - margin), cy1 = math.max(0, box.y1 - margin);
    final cx2 = math.min(w, box.x2 + margin), cy2 = math.min(h, box.y2 + margin);
    final cw = cx2 - cx1, ch = cy2 - cy1;
    final crop = GrayImage.zeros(cw, ch);
    for (var y = box.y1; y < box.y2; y++) {
      for (var x = box.x1; x < box.x2; x++) {
        if (ink[(y - box.y1) * box.width + x - box.x1] != 0) crop.data[(y - cy1) * cw + x - cx1] = 255;
      }
    }
    final grown = margin > 0 ? imkDilate(crop, StructuringElement.rect(2 * margin + 1, 2 * margin + 1)) : crop;
    for (var y = box.y1; y < box.y2; y++) {
      for (var x = box.x1; x < box.x2; x++) {
        if (labels[y * w + x] == l) out.data[y * w + x] = 0;
      }
    }
    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        if (grown.data[y * cw + x] != 0) out.data[(cy1 + y) * w + cx1 + x] = 255;
      }
    }
    fitted++;
  }
  return FitMaskResult(out, fitted: fitted, empty: empty);
}

/// The letter pixels of piece [label] inside [box], as 0/1 of the box's
/// size, or null when there are none.
Uint8List? _inkOf(RgbImage image, Int32List labels, int w, int label, BBox box, GrayImage? letters) {
  final bw = box.width, bh = box.height;
  final ink = Uint8List(bw * bh);
  var area = 0;
  bool inPiece(int x, int y) => x >= 0 && y >= 0 && x < w && y < image.height && labels[y * w + x] == label;

  // The masker's letters, when it found enough in the piece.
  var found = 0;
  for (var y = box.y1; y < box.y2; y++) {
    for (var x = box.x1; x < box.x2; x++) {
      if (labels[y * w + x] != label) continue;
      area++;
      if (letters != null && y < letters.height && x < letters.width && letters.data[y * letters.width + x] != 0) {
        ink[(y - box.y1) * bw + x - box.x1] = 1;
        found++;
      }
    }
  }
  if (found >= math.max(12, area ~/ 100)) return _withoutSpecks(ink, bw, bh);

  // Else by contrast with the colour along the piece's edge.
  ink.fillRange(0, ink.length, 0);
  final data = image.data;
  int gray(int x, int y) {
    final i = (y * image.width + x) * 3;
    return (data[i] * 299 + data[i + 1] * 587 + data[i + 2] * 114) ~/ 1000;
  }

  final edge = <int>[];
  for (var y = box.y1; y < box.y2; y++) {
    for (var x = box.x1; x < box.x2; x++) {
      if (labels[y * w + x] != label) continue;
      if (!inPiece(x - 1, y) || !inPiece(x + 1, y) || !inPiece(x, y - 1) || !inPiece(x, y + 1)) edge.add(gray(x, y));
    }
  }
  if (edge.isEmpty) return null;
  edge.sort();
  final background = edge[edge.length ~/ 2];
  final diffs = Uint8List(area);
  var k = 0;
  for (var y = box.y1; y < box.y2; y++) {
    for (var x = box.x1; x < box.x2; x++) {
      if (labels[y * w + x] == label) diffs[k++] = (gray(x, y) - background).abs();
    }
  }
  final threshold = math.max(_minContrast, mahotasOtsu(diffs));
  var any = false;
  for (var y = box.y1; y < box.y2; y++) {
    for (var x = box.x1; x < box.x2; x++) {
      if (labels[y * w + x] == label && (gray(x, y) - background).abs() >= threshold) {
        ink[(y - box.y1) * bw + x - box.x1] = 1;
        any = true;
      }
    }
  }
  return any ? _withoutSpecks(ink, bw, bh) : null;
}

/// [ink] without spots smaller than [_minSpot]; null when nothing is left.
Uint8List? _withoutSpecks(Uint8List ink, int w, int h) {
  final cc = connectedComponentsWithStats(GrayImage(w, h, ink), connectivity: 8);
  final keep = List<bool>.generate(cc.count, (l) => l > 0 && cc.stats[l].area >= _minSpot);
  var any = false;
  for (var i = 0; i < ink.length; i++) {
    final on = keep[cc.labels[i]];
    ink[i] = on ? 1 : 0;
    if (on) any = true;
  }
  return any ? ink : null;
}
