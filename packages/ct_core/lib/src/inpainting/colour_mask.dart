/// The mask pipette (new in this project, the owner's idea): letters of the
/// colours the user clicked, inside the text boxes.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/morphology.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// Default colour tolerance (CIE76 ΔE). The top of the range is wide on
/// purpose (the owner's wish): to clean a page well the mask sometimes has to
/// take the soft edges of the letters too.
const pipetteTolerance = 20.0;
const minPipetteTolerance = 4.0;
const maxPipetteTolerance = 100.0;

/// The colour at ([x], [y]) of [image]: the median of the 3×3 pixels around
/// it (a click on a thin stroke of a letter often lands on its edge).
(int, int, int) sampleColour(RgbImage image, int x, int y) {
  final r = <int>[], g = <int>[], b = <int>[];
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final px = (x + dx).clamp(0, image.width - 1), py = (y + dy).clamp(0, image.height - 1);
      final i = (py * image.width + px) * 3;
      r.add(image.data[i]);
      g.add(image.data[i + 1]);
      b.add(image.data[i + 2]);
    }
  }
  int median(List<int> v) => (v..sort())[v.length ~/ 2];
  return (median(r), median(g), median(b));
}

/// Where the text of [blocks] is on a [width]×[height] page: the bubble, or
/// the text box grown a little (the region [generateMask] looks at).
List<BBox> textRegions(List<TextBlock> blocks, int width, int height) => [
  for (final b in blocks)
    if (_region(b, width, height) case final r? when !r.isEmpty) r,
];

BBox? _region(TextBlock b, int w, int h) {
  final t = b.xyxy;
  final bubble = b.textClass == TextClass.bubble ? b.bubbleXyxy : null;
  final dx = t.width ~/ 20 + 6, dy = t.height ~/ 20 + 6;
  final r = bubble ?? BBox(t.x1 - dx, t.y1 - dy, t.x2 + dx, t.y2 + dy);
  return BBox(math.max(0, r.x1), math.max(0, r.y1), math.min(w, r.x2), math.min(h, r.y2));
}

/// [base] (the mask before the pipette, the image's size or taller) with the
/// pixels of [image] within [tolerance] (ΔE) of any of [colours] added as
/// letters (255), grown by [grow] pixels, inside [regions] (the whole image
/// when null).
GrayImage maskByColours(
  RgbImage image,
  GrayImage base,
  List<(int, int, int)> colours, {
  double tolerance = pipetteTolerance,
  List<BBox>? regions,
  int grow = 1,
}) {
  final w = image.width, h = math.min(image.height, base.height);
  final out = GrayImage(base.width, base.height, Uint8List.fromList(base.data));
  if (colours.isEmpty) return out;
  final targets = [for (final (r, g, b) in colours) _lab(r, g, b)];
  final limit = tolerance * tolerance;
  for (final box in regions ?? [BBox(0, 0, w, h)]) {
    final x1 = math.max(0, box.x1), y1 = math.max(0, box.y1);
    final x2 = math.min(w, box.x2), y2 = math.min(h, box.y2);
    if (x2 <= x1 || y2 <= y1) continue;
    final bw = x2 - x1, bh = y2 - y1;
    final hit = GrayImage.zeros(bw, bh);
    var any = false;
    // Colours repeat a lot on a page: each is converted once.
    final cache = <int, bool>{};
    for (var y = y1; y < y2; y++) {
      for (var x = x1; x < x2; x++) {
        final i = (y * w + x) * 3;
        final key = (image.data[i] << 16) | (image.data[i + 1] << 8) | image.data[i + 2];
        final near = cache[key] ??= () {
          final (l, a, bb) = _lab(image.data[i], image.data[i + 1], image.data[i + 2]);
          for (final (tl, ta, tb) in targets) {
            final d = (l - tl) * (l - tl) + (a - ta) * (a - ta) + (bb - tb) * (bb - tb);
            if (d <= limit) return true;
          }
          return false;
        }();
        if (near) {
          hit.data[(y - y1) * bw + x - x1] = 255;
          any = true;
        }
      }
    }
    if (!any) continue;
    final grown = grow > 0 ? imkDilate(hit, StructuringElement.rect(2 * grow + 1, 2 * grow + 1)) : hit;
    for (var y = 0; y < bh; y++) {
      for (var x = 0; x < bw; x++) {
        if (grown.data[y * bw + x] != 0) out.data[(y1 + y) * base.width + x1 + x] = 255;
      }
    }
  }
  return out;
}

/// sRGB → CIE L*a*b* (D65).
(double, double, double) _lab(int r8, int g8, int b8) {
  double lin(int c) {
    final v = c / 255;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin(r8), g = lin(g8), b = lin(b8);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}
