/// Evening out what the network redrew over a flat background. Not in the
/// original.
library;

import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/morphology.dart';

/// Letters closer than this (px) form one spot with one background.
const _spotRadius = 6;

/// The least number of background pixels around a spot to judge it by.
const _minRing = 20;

/// Around a spot, this share of the pixels must be within [_ringTolerance]
/// of their median colour for the spot to have a flat background.
const _minFlatShare = 0.6;
const _ringTolerance = 4;

/// Networks miss a flat background by a level or two (LaMa gives 254–255 on
/// white paper): over a removed line of text the letters stay faintly
/// visible. For every spot of [mask] (non-zero = redrawn) whose surroundings
/// in [image] are mostly one colour, the redrawn pixels within [tolerance] of
/// that colour get it exactly; drawing the network brought back differs by
/// far more and stays. Changes [image] in place and returns the number of
/// pixels changed.
int snapToFlatBackground(RgbImage image, GrayImage mask, {int tolerance = 3}) {
  final w = image.width, h = image.height, n = w * h;
  final letters = GrayImage(w, h, Uint8List.fromList([for (final v in mask.data) v != 0 ? 1 : 0]));
  final spots = dilateBinary(letters, StructuringElement.rect(2 * _spotRadius + 1, 2 * _spotRadius + 1));
  // The pixel right next to a letter is often its anti-aliased edge.
  final near = dilateBinary(letters, StructuringElement.rect(3, 3));
  final components = connectedComponentsWithStats(spots, connectivity: 8);
  final label = components.labels, count = components.count;
  if (count <= 1) return 0;

  // Ring pixels (in the spot, away from the letters) grouped by spot.
  final starts = Int32List(count + 1);
  for (var i = 0; i < n; i++) {
    if (spots.data[i] != 0 && near.data[i] == 0) starts[label[i] + 1]++;
  }
  for (var l = 0; l < count; l++) {
    starts[l + 1] += starts[l];
  }
  final ring = Int32List(starts[count]);
  final fill = Int32List.fromList(starts.sublist(0, count));
  for (var i = 0; i < n; i++) {
    if (spots.data[i] != 0 && near.data[i] == 0) ring[fill[label[i]]++] = i;
  }

  // The background colour of each spot, or -1 when it is not flat.
  final background = Int32List(count)..fillRange(0, count, -1);
  final hist = Int32List(256);
  final px = image.data;
  for (var l = 1; l < count; l++) {
    final from = starts[l], to = starts[l + 1], k = to - from;
    if (k < _minRing) continue;
    final colour = List.filled(3, 0);
    for (var c = 0; c < 3; c++) {
      hist.fillRange(0, 256, 0);
      for (var j = from; j < to; j++) {
        hist[px[ring[j] * 3 + c]]++;
      }
      var seen = 0, v = 0;
      while ((seen += hist[v]) <= (k - 1) ~/ 2) {
        v++;
      }
      colour[c] = v;
    }
    var flat = 0;
    for (var j = from; j < to; j++) {
      final o = ring[j] * 3;
      if ((px[o] - colour[0]).abs() <= _ringTolerance &&
          (px[o + 1] - colour[1]).abs() <= _ringTolerance &&
          (px[o + 2] - colour[2]).abs() <= _ringTolerance) {
        flat++;
      }
    }
    if (flat >= k * _minFlatShare) background[l] = colour[0] << 16 | colour[1] << 8 | colour[2];
  }

  var changed = 0;
  for (var i = 0; i < n; i++) {
    if (letters.data[i] == 0) continue;
    final bg = background[label[i]];
    if (bg < 0) continue;
    final o = i * 3, r = bg >> 16, g = bg >> 8 & 0xff, b = bg & 0xff;
    if (px[o] == r && px[o + 1] == g && px[o + 2] == b) continue;
    if ((px[o] - r).abs() <= tolerance && (px[o + 1] - g).abs() <= tolerance && (px[o + 2] - b).abs() <= tolerance) {
      px[o] = r;
      px[o + 1] = g;
      px[o + 2] = b;
      changed++;
    }
  }
  return changed;
}
