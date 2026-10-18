/// Ports of the mahotas/imkit morphology the original mask code uses.
///
/// mahotas behaviour (checked against mahotas 1.4 by the parity tests):
/// - structuring elements are centred at `(h ~/ 2, w ~/ 2)`; only symmetric
///   elements (rectangles, crosses) are used here;
/// - dilation treats pixels outside the image as background;
/// - erosion ignores pixels outside the image;
/// - on `uint8` images both are greyscale: dilation gives `max + 1`
///   (0 stays 0), erosion gives `min - 1` (saturating at 0).
library;

import 'dart:typed_data';

import '../image/raster.dart';
import 'mahotas.dart';

/// A structuring element: `true` cells take part.
class StructuringElement {
  StructuringElement(this.height, this.width, this.cells) : assert(cells.length == height * width);

  /// `np.ones((h, w))` / `MORPH_RECT`.
  factory StructuringElement.rect(int height, int width) =>
      StructuringElement(height, width, List.filled(height * width, true));

  /// `MORPH_CROSS`: the middle row and column.
  factory StructuringElement.cross(int height, int width) => StructuringElement(height, width, [
        for (var y = 0; y < height; y++)
          for (var x = 0; x < width; x++) y == height ~/ 2 || x == width ~/ 2,
      ]);

  final int height;
  final int width;
  final List<bool> cells;

  Iterable<(int, int)> get offsets sync* {
    final cy = height ~/ 2, cx = width ~/ 2;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (cells[y * width + x]) yield (y - cy, x - cx);
      }
    }
  }
}

/// `mahotas.dilate` on a boolean image (values 0/non-zero → 0/1).
GrayImage dilateBinary(GrayImage a, StructuringElement se) {
  final w = a.width, h = a.height;
  final out = GrayImage.zeros(w, h);
  final offs = se.offsets.toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (final (dy, dx) in offs) {
        final yy = y - dy, xx = x - dx;
        if (yy < 0 || yy >= h || xx < 0 || xx >= w) continue;
        if (a.data[yy * w + xx] != 0) {
          out.data[y * w + x] = 1;
          break;
        }
      }
    }
  }
  return out;
}

/// `mahotas.erode` on a boolean image; pixels outside the image do not
/// erode.
GrayImage erodeBinary(GrayImage a, StructuringElement se) {
  final w = a.width, h = a.height;
  final out = GrayImage.zeros(w, h);
  final offs = se.offsets.toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var keep = true;
      for (final (dy, dx) in offs) {
        final yy = y + dy, xx = x + dx;
        if (yy < 0 || yy >= h || xx < 0 || xx >= w) continue;
        if (a.data[yy * w + xx] == 0) {
          keep = false;
          break;
        }
      }
      if (keep) out.data[y * w + x] = 1;
    }
  }
  return out;
}

/// `mahotas.dilate` on a `uint8` image.
GrayImage dilateGray(GrayImage a, StructuringElement se) {
  final w = a.width, h = a.height;
  final out = GrayImage.zeros(w, h);
  final offs = se.offsets.toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = 0;
      for (final (dy, dx) in offs) {
        final yy = y - dy, xx = x - dx;
        if (yy < 0 || yy >= h || xx < 0 || xx >= w) continue;
        final v = a.data[yy * w + xx];
        if (v == 0) continue;
        final s = v == 255 ? 255 : v + 1;
        if (s > m) m = s;
      }
      out.data[y * w + x] = m;
    }
  }
  return out;
}

/// `mahotas.erode` on a `uint8` image.
GrayImage erodeGray(GrayImage a, StructuringElement se) {
  final w = a.width, h = a.height;
  final out = GrayImage.zeros(w, h);
  final offs = se.offsets.toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = 256;
      for (final (dy, dx) in offs) {
        final yy = y + dy, xx = x + dx;
        if (yy < 0 || yy >= h || xx < 0 || xx >= w) continue;
        final v = a.data[yy * w + xx];
        if (v < m) m = v;
      }
      out.data[y * w + x] = m == 256 ? 0 : (m == 0 ? 0 : m - 1);
    }
  }
  return out;
}

/// `imkit.dilate(mask, kernel, iterations)`: mahotas dilation (boolean when
/// [binaryInput], else greyscale), returned as 0/255.
GrayImage imkDilate(GrayImage mask, StructuringElement se, {int iterations = 1, bool binaryInput = false}) {
  var out = mask;
  for (var i = 0; i < iterations; i++) {
    out = binaryInput ? dilateBinary(out, se) : dilateGray(out, se);
  }
  return toMask255(out);
}

/// `imkit.erode(mask, kernel, iterations)` on a `uint8` mask, as 0/255.
GrayImage imkErode(GrayImage mask, StructuringElement se, {int iterations = 1}) {
  var out = mask;
  for (var i = 0; i < iterations; i++) {
    out = erodeGray(out, se);
  }
  return toMask255(out);
}

/// `mahotas.close` on a `uint8` image (greyscale: values may become 254).
GrayImage closeGray(GrayImage a, StructuringElement se) => erodeGray(dilateGray(a, se), se);

/// `(a > 0) * 255`.
GrayImage toMask255(GrayImage a) => GrayImage(a.width, a.height, Uint8List.fromList([for (final v in a.data) v > 0 ? 255 : 0]));

/// `(a > 0)` as 0/1.
GrayImage toMask01(GrayImage a) => GrayImage(a.width, a.height, Uint8List.fromList([for (final v in a.data) v > 0 ? 1 : 0]));

/// `mahotas.close_holes(mask > 0)`: background regions (4-connected) that do
/// not touch the border are filled. Returns 0/1.
GrayImage closeHoles(GrayImage mask) {
  final w = mask.width, h = mask.height;
  final background = GrayImage(w, h, Uint8List.fromList([for (final v in mask.data) v > 0 ? 0 : 1]));
  final cc = connectedComponentsWithStats(background, connectivity: 4);
  final touches = List<bool>.filled(cc.count, false);
  for (var x = 0; x < w; x++) {
    touches[cc.labels[x]] = true;
    touches[cc.labels[(h - 1) * w + x]] = true;
  }
  for (var y = 0; y < h; y++) {
    touches[cc.labels[y * w]] = true;
    touches[cc.labels[y * w + w - 1]] = true;
  }
  final out = GrayImage.zeros(w, h);
  for (var i = 0; i < w * h; i++) {
    final l = cc.labels[i];
    out.data[i] = mask.data[i] > 0 || (l > 0 && !touches[l]) ? 1 : 0;
  }
  return out;
}
