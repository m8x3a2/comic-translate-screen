import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('ink in the bottom right corner of a crop does not break the line splitter', () {
    // An almost empty crop (e.g. a cleaned bubble read again): the only ink
    // touches the right and bottom edges, so a line box ends one past them.
    const w = 57, h = 25;
    final data = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 255);
    for (var y = 21; y < h; y++) {
      for (var x = 48; x < w; x++) {
        data.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, 0);
      }
    }
    expect(() => detectLinesAndDirectionInCrop(RgbImage(w, h, data)), returnsNormally);
  });
}
