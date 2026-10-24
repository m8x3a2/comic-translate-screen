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

  bool get _isRect => !cells.contains(false);

  bool get _isCross {
    final cy = height ~/ 2, cx = width ~/ 2;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (cells[y * width + x] != (y == cy || x == cx)) return false;
      }
    }
    return true;
  }
}

/// Max (or min) of [src] over the window `[x + lo, x + hi]` of each row,
/// limited to the image (pixels outside do not take part).
/// The window holds 0 (`lo <= 0 <= hi`): the pixel itself, then each shift.
Uint8List _rowExtreme(Uint8List src, int w, int h, int lo, int hi, bool max) {
  final out = Uint8List.fromList(src);
  for (var d = lo; d <= hi; d++) {
    if (d == 0) continue;
    final x1 = d < 0 ? -d : 0, x2 = d > 0 ? w - d : w;
    for (var row = 0; row < w * h; row += w) {
      if (max) {
        for (var i = row + x1; i < row + x2; i++) {
          final v = src[i + d];
          if (v > out[i]) out[i] = v;
        }
      } else {
        for (var i = row + x1; i < row + x2; i++) {
          final v = src[i + d];
          if (v < out[i]) out[i] = v;
        }
      }
    }
  }
  return out;
}

/// Max or min over the 3×3 cross (the pixel and its 4 neighbours) in one
/// pass.
Uint8List _cross3(Uint8List src, int w, int h, bool max) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      final i = row + x;
      var m = src[i];
      if (max) {
        if (x > 0 && src[i - 1] > m) m = src[i - 1];
        if (x < w - 1 && src[i + 1] > m) m = src[i + 1];
        if (y > 0 && src[i - w] > m) m = src[i - w];
        if (y < h - 1 && src[i + w] > m) m = src[i + w];
      } else {
        if (x > 0 && src[i - 1] < m) m = src[i - 1];
        if (x < w - 1 && src[i + 1] < m) m = src[i + 1];
        if (y > 0 && src[i - w] < m) m = src[i - w];
        if (y < h - 1 && src[i + w] < m) m = src[i + w];
      }
      out[i] = m;
    }
  }
  return out;
}

/// The same over the window `[y + lo, y + hi]` of each column.
Uint8List _colExtreme(Uint8List src, int w, int h, int lo, int hi, bool max) {
  final out = Uint8List.fromList(src);
  for (var d = lo; d <= hi; d++) {
    if (d == 0) continue;
    final y1 = d < 0 ? -d : 0, y2 = d > 0 ? h - d : h;
    if (y2 <= y1) continue;
    final shift = d * w;
    if (max) {
      for (var i = y1 * w; i < y2 * w; i++) {
        final v = src[i + shift];
        if (v > out[i]) out[i] = v;
      }
    } else {
      for (var i = y1 * w; i < y2 * w; i++) {
        final v = src[i + shift];
        if (v < out[i]) out[i] = v;
      }
    }
  }
  return out;
}

/// Max (dilation) or min (erosion) of [a] over [se] for rectangles and
/// crosses, row and column apart: the same values as visiting every cell
/// (whose windows are taken mirrored for dilation), much faster for large
/// elements. Null for other shapes.
Uint8List? _separableExtreme(GrayImage a, StructuringElement se, {required bool dilate}) {
  final w = a.width, h = a.height;
  if (w == 0 || h == 0) return null;
  final rect = se._isRect;
  if (!rect && !se._isCross) return null;
  final cy = se.height ~/ 2, cx = se.width ~/ 2;
  // Dilation visits `y - dy` for dy in [-cy, height - 1 - cy], erosion `y + dy`.
  final loY = dilate ? -(se.height - 1 - cy) : -cy, hiY = dilate ? cy : se.height - 1 - cy;
  final loX = dilate ? -(se.width - 1 - cx) : -cx, hiX = dilate ? cx : se.width - 1 - cx;
  if (rect) return _colExtreme(_rowExtreme(a.data, w, h, loX, hiX, dilate), w, h, loY, hiY, dilate);
  if (se.height == 3 && se.width == 3) return _cross3(a.data, w, h, dilate);
  final row = _rowExtreme(a.data, w, h, loX, hiX, dilate), col = _colExtreme(a.data, w, h, loY, hiY, dilate);
  for (var i = 0; i < w * h; i++) {
    if (dilate ? col[i] > row[i] : col[i] < row[i]) row[i] = col[i];
  }
  return row;
}

/// `mahotas.dilate` on a boolean image (values 0/non-zero → 0/1).
GrayImage dilateBinary(GrayImage a, StructuringElement se) {
  final w = a.width, h = a.height;
  final fast = _separableExtreme(a, se, dilate: true);
  if (fast != null) {
    for (var i = 0; i < fast.length; i++) {
      fast[i] = fast[i] != 0 ? 1 : 0;
    }
    return GrayImage(w, h, fast);
  }
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
  final fast = _separableExtreme(a, se, dilate: false);
  if (fast != null) {
    for (var i = 0; i < fast.length; i++) {
      fast[i] = fast[i] != 0 ? 1 : 0;
    }
    return GrayImage(w, h, fast);
  }
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
  final fast = _separableExtreme(a, se, dilate: true);
  if (fast != null) {
    // max(v + 1) = max(v) + 1: the step is monotonic.
    for (var i = 0; i < fast.length; i++) {
      final v = fast[i];
      if (v != 0 && v != 255) fast[i] = v + 1;
    }
    return GrayImage(w, h, fast);
  }
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
  final fast = _separableExtreme(a, se, dilate: false);
  if (fast != null) {
    for (var i = 0; i < fast.length; i++) {
      if (fast[i] != 0) fast[i]--;
    }
    return GrayImage(w, h, fast);
  }
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
GrayImage toMask255(GrayImage a) => _binarize(a, 255);

/// `(a > 0)` as 0/1.
GrayImage toMask01(GrayImage a) => _binarize(a, 1);

GrayImage _binarize(GrayImage a, int on) {
  final src = a.data, out = Uint8List(src.length);
  for (var i = 0; i < src.length; i++) {
    if (src[i] != 0) out[i] = on;
  }
  return GrayImage(a.width, a.height, out);
}

/// `mahotas.close_holes(mask > 0)`: background regions (4-connected) that do
/// not touch the border are filled. Returns 0/1.
GrayImage closeHoles(GrayImage mask) {
  final w = mask.width, h = mask.height;
  if (w == 0 || h == 0) return GrayImage.zeros(w, h);
  final background = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    if (mask.data[i] == 0) background[i] = 1;
  }
  // The background reached from the border stays; the rest is a hole.
  final outside = Uint8List(w * h);
  final stack = <int>[];
  void seed(int i) {
    if (background[i] != 0 && outside[i] == 0) {
      outside[i] = 1;
      stack.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  flood4(stack, outside, background, w);
  final out = GrayImage.zeros(w, h);
  for (var i = 0; i < w * h; i++) {
    out.data[i] = outside[i] == 0 ? 1 : 0;
  }
  return out;
}

/// Marks in [filled] every pixel of [open] (a [width]-wide image) that is
/// 4-connected to the pixels on [stack], which are marked already.
void flood4(List<int> stack, Uint8List filled, Uint8List open, int width) {
  final n = open.length, w = width;
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w;
    if (x > 0 && open[i - 1] != 0 && filled[i - 1] == 0) {
      filled[i - 1] = 1;
      stack.add(i - 1);
    }
    if (x < w - 1 && open[i + 1] != 0 && filled[i + 1] == 0) {
      filled[i + 1] = 1;
      stack.add(i + 1);
    }
    if (i >= w && open[i - w] != 0 && filled[i - w] == 0) {
      filled[i - w] = 1;
      stack.add(i - w);
    }
    if (i + w < n && open[i + w] != 0 && filled[i + w] == 0) {
      filled[i + w] = 1;
      stack.add(i + w);
    }
  }
}
