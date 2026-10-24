// The row-and-column dilation and erosion against a cell-by-cell reference.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// mahotas semantics visited cell by cell (the former implementation).
GrayImage reference(GrayImage a, StructuringElement se, {required bool dilate, required bool binary}) {
  final w = a.width, h = a.height;
  final out = GrayImage.zeros(w, h);
  final offs = se.offsets.toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = dilate ? 0 : 256;
      for (final (dy, dx) in offs) {
        final yy = dilate ? y - dy : y + dy, xx = dilate ? x - dx : x + dx;
        if (yy < 0 || yy >= h || xx < 0 || xx >= w) continue;
        final v = a.data[yy * w + xx];
        if (dilate) {
          final s = binary ? (v != 0 ? 1 : 0) : (v == 0 ? 0 : (v == 255 ? 255 : v + 1));
          if (s > m) m = s;
        } else {
          final s = binary ? (v != 0 ? 1 : 0) : v;
          if (s < m) m = s;
        }
      }
      out.data[y * w + x] = dilate ? m : (binary ? (m == 0 ? 0 : 1) : (m == 256 || m == 0 ? 0 : m - 1));
    }
  }
  return out;
}

void main() {
  final rnd = math.Random(7);
  final elements = <String, StructuringElement>{
    'rect 3x3': StructuringElement.rect(3, 3),
    'rect 5x5': StructuringElement.rect(5, 5),
    'rect 17x17': StructuringElement.rect(17, 17),
    'rect 2x4': StructuringElement.rect(2, 4),
    'rect 1x6': StructuringElement.rect(1, 6),
    'cross 3x3': StructuringElement.cross(3, 3),
    'cross 4x5': StructuringElement.cross(4, 5),
    'diagonal': StructuringElement(3, 3, [true, false, false, false, true, false, false, false, true]),
  };
  final sizes = [(1, 1), (1, 9), (7, 1), (13, 11), (40, 23)];
  for (final MapEntry(key: name, value: se) in elements.entries) {
    test(name, () {
      for (final (w, h) in sizes) {
        for (final sparse in [true, false]) {
          final data = Uint8List.fromList([
            for (var i = 0; i < w * h; i++)
              sparse ? (rnd.nextInt(6) == 0 ? [1, 128, 254, 255][rnd.nextInt(4)] : 0) : rnd.nextInt(256),
          ]);
          final a = GrayImage(w, h, data);
          final what = '$name on ${w}x$h${sparse ? ' sparse' : ''}';
          expect(
            dilateGray(a, se).data,
            reference(a, se, dilate: true, binary: false).data,
            reason: 'dilateGray $what',
          );
          expect(erodeGray(a, se).data, reference(a, se, dilate: false, binary: false).data, reason: 'erodeGray $what');
          expect(
            dilateBinary(a, se).data,
            reference(a, se, dilate: true, binary: true).data,
            reason: 'dilateBinary $what',
          );
          expect(
            erodeBinary(a, se).data,
            reference(a, se, dilate: false, binary: true).data,
            reason: 'erodeBinary $what',
          );
        }
      }
    });
  }
}
