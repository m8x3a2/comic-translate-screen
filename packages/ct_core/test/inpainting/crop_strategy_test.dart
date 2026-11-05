import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// A mask with one spot per "letter": [rows] lines of [perRow] 8×14 spots
/// starting at ([x0], [y0]).
GrayImage _letters(int w, int h, {required int x0, required int y0, int rows = 1, int perRow = 1}) {
  final mask = GrayImage.zeros(w, h);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < perRow; c++) {
      for (var y = y0 + r * 24; y < y0 + r * 24 + 14; y++) {
        for (var x = x0 + c * 12; x < x0 + c * 12 + 8; x++) {
          mask.data[y * w + x] = 255;
        }
      }
    }
  }
  return mask;
}

/// Calls of the network made by [InpaintModel] with the crop strategy.
List<(int, int)> _runs(RgbImage image, GrayImage mask) {
  final runs = <(int, int)>[];
  final model = InpaintModel((img, m) {
    runs.add((img.width, img.height));
    return RgbImage(
      img.width,
      img.height,
      Uint8List(img.width * img.height * 3)..fillRange(0, img.width * img.height * 3, 7),
    );
  });
  final result = model.call(image, mask, const InpaintConfig(strategy: HdStrategy.crop));
  for (var i = 0; i < mask.data.length; i++) {
    expect(result.data[i * 3], mask.data[i] == 255 ? 7 : 200, reason: 'pixel $i');
  }
  return runs;
}

RgbImage _page(int w, int h) => RgbImage(w, h, Uint8List(w * h * 3)..fillRange(0, w * h * 3, 200));

void main() {
  test('one spot: the crop of the original', () {
    expect(cropWindows([(1000, 1000, 1008, 1014)], 2000, 3000, 512), [(488, 488, 1520, 1526)]);
    // At the edge the crop is shifted inwards.
    expect(cropWindows([(0, 0, 8, 14)], 2000, 3000, 512), [(0, 0, 1032, 1038)]);
  });

  test('a page of letters gives a few crops, every letter keeps its context', () {
    // 20 lines of 60 letters: 1200 spots.
    final mask = _letters(2000, 3000, x0: 200, y0: 300, rows: 20, perRow: 60);
    final boxes = boxesFromMask(mask);
    expect(boxes, hasLength(1200));
    final windows = cropWindows(boxes, 2000, 3000, 512);
    expect(windows.length, lessThanOrEqualTo(4));
    for (final (x1, y1, x2, y2) in boxes) {
      // At least 256 px around the letter, cut by the page edge.
      final inside = windows.where(
        (w) =>
            w.$1 <= (x1 - 256).clamp(0, 2000) &&
            w.$2 <= (y1 - 256).clamp(0, 3000) &&
            w.$3 >= (x2 + 256).clamp(0, 2000) &&
            w.$4 >= (y2 + 256).clamp(0, 3000),
      );
      expect(inside, isNotEmpty, reason: 'box ($x1, $y1)');
    }
  });

  test('distant letters stay separate crops', () {
    final mask = _letters(2000, 3000, x0: 100, y0: 100, perRow: 3);
    for (var y = 2800; y < 2814; y++) {
      for (var x = 1800; x < 1808; x++) {
        mask.data[y * 2000 + x] = 255;
      }
    }
    final runs = _runs(_page(2000, 3000), mask);
    expect(runs, hasLength(2));
  });

  test('text all over a big page: crops of at most 1536 px', () {
    final mask = _letters(2000, 3000, x0: 50, y0: 50, rows: 120, perRow: 160);
    final runs = _runs(_page(2000, 3000), mask);
    expect(runs.length, lessThanOrEqualTo(12));
    for (final (w, h) in runs) {
      expect(w, lessThanOrEqualTo(fastCropSide));
      expect(h, lessThanOrEqualTo(fastCropSide));
    }
  });

  test('crops larger than a small page together: one pass over the page', () {
    final mask = _letters(1400, 1400, x0: 50, y0: 50, rows: 50, perRow: 100);
    final runs = _runs(_page(1400, 1400), mask);
    expect(runs, [(1400, 1400)]);
  });
}
