/// Port of imkit's contour tracing (`imkit/analysis.py`: `find_contours`,
/// `bounding_rect`), which the original uses instead of OpenCV.
library;

import 'dart:typed_data';

import '../image/raster.dart';

// Neighbour order of imkit: N, NE, E, SE, S, SW, W, NW.
const _di = [-1, -1, 0, 1, 1, 1, 0, -1];
const _dj = [0, 1, 1, 1, 0, -1, -1, -1];

/// `find_contours(img, threshold)`: outer borders of the foreground
/// (`value > threshold`) in imkit's order; each contour is a list of `(x, y)`
/// points.
List<List<(int, int)>> findContours(GrayImage image, {int threshold = 0}) {
  final h0 = image.height, w0 = image.width;
  final w = w0 + 2, h = h0 + 2;
  final m = Uint8List(w * h);
  for (var y = 0; y < h0; y++) {
    for (var x = 0; x < w0; x++) {
      if (image.data[y * w0 + x] > threshold) m[(y + 1) * w + x + 1] = 1;
    }
  }

  // Start candidates: foreground pixels whose left neighbour is background,
  // in raster order (computed before tracing, as numpy does).
  final starts = <int>[];
  for (var y = 1; y <= h0; y++) {
    for (var x = 1; x <= w0; x++) {
      final p = y * w + x;
      if (m[p] != 0 && m[p - 1] == 0) starts.add(p);
    }
  }

  final contours = <List<(int, int)>>[];
  for (final pos in starts) {
    if (m[pos] != 1) continue; // already consumed by an earlier trace
    contours.add(_trace(m, w, pos));
  }
  return contours;
}

List<(int, int)> _trace(Uint8List mv, int w, int startPos, {int maxSteps = 2000000}) {
  final off = [-w, -w + 1, 1, w + 1, w, w - 1, -1, -w - 1];
  final startI = startPos ~/ w, startJ = startPos % w;
  if (mv[startPos - 1] == 0) mv[startPos] = 2;

  int? scan(int p, int bIdx) {
    final s = (bIdx + 1) & 7;
    for (var k = 0; k < 8; k++) {
      final q = (s + k) & 7;
      if (mv[p + off[q]] != 0) return q;
    }
    return null;
  }

  final first = scan(startPos, 6);
  if (first == null) return [(startJ - 1, startI - 1)];

  final codes = <int>[first];
  var pos = startPos + off[first];
  final firstNext = pos;
  var bIdx = (first + 4) & 7;
  var steps = 1;
  while (true) {
    if (steps > maxSteps) break;
    if (mv[pos - 1] == 0) mv[pos] = 2;
    final q = scan(pos, bIdx);
    if (q == null) break;
    final next = pos + off[q];
    if (pos == startPos && next == firstNext) break;
    codes.add(q);
    pos = next;
    bIdx = (q + 4) & 7;
    steps++;
  }

  final out = <(int, int)>[(startJ - 1, startI - 1)];
  var x = startJ - 1, y = startI - 1;
  for (final c in codes) {
    x += _dj[c];
    y += _di[c];
    out.add((x, y));
  }
  return out;
}

/// `bounding_rect(contour)`: `(x, y, w, h)` with cv2's +1 width/height.
(int, int, int, int) boundingRect(List<(int, int)> contour) {
  var x1 = contour.first.$1, y1 = contour.first.$2, x2 = x1, y2 = y1;
  for (final (x, y) in contour) {
    if (x < x1) x1 = x;
    if (y < y1) y1 = y;
    if (x > x2) x2 = x;
    if (y > y2) y2 = y;
  }
  return (x1, y1, x2 - x1 + 1, y2 - y1 + 1);
}
