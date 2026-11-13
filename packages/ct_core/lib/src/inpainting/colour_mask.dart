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

/// The largest colour distance (ΔE) of the pipette. A plain "within ΔE of the
/// colour" test reaches other colours as the tolerance grows: from red on the
/// owner's bunny photo the black and grey drawing is ≈75 away, so at 70+ the
/// drawing came in and at 90 the whole page. Beyond this the tolerance widens
/// only along the blend of the letter with its background (see
/// [maskByColours]).
const _maxDistance = 30.0;

/// Black ink of the drawing under coloured letters.
const _ink = (0.0, 0.0, 0.0);

/// How far from the background a blended pixel must still be (as the share
/// of the letter's colour in it) at [tolerance].
double _minShare(double tolerance) =>
    1 - 0.85 * ((tolerance - minPipetteTolerance) / (maxPipetteTolerance - minPipetteTolerance)).clamp(0, 1);

/// [base] (the mask before the pipette, the image's size or taller) with the
/// letters of [colours] in [image] added (255), grown by [grow] pixels, inside
/// [regions] (the whole image when null).
///
/// A pixel is a letter when it looks like a blend of a picked colour and the
/// region's background (its most common other colour): letter edges, soft
/// from anti-aliasing or a photo, are such blends. [tolerance] sets how faint
/// a blend still counts (from the solid colour only to faint edges) and how
/// far off the blend a pixel may be (ΔE, at most [_maxDistance], less for
/// fainter blends), so other colours of the drawing never come in.
///
/// With [wholePieces] only pieces of the colours lying whole inside a region
/// count: a piece that runs off the region's edge is the drawing around the
/// text, not a letter (black letters in a bubble on a black background, the
/// owner's breakfast page). Letters stay inside a text box grown a little,
/// on paper and over a drawing alike. (A first try, the bubble as the largest
/// patch of paper, lost the letters over the hatching on the bunny photo.)
GrayImage maskByColours(
  RgbImage image,
  GrayImage base,
  List<(int, int, int)> colours, {
  double tolerance = pipetteTolerance,
  List<BBox>? regions,
  int grow = 1,
  bool wholePieces = false,
}) {
  final w = image.width, h = math.min(image.height, base.height);
  final out = GrayImage(base.width, base.height, Uint8List.fromList(base.data));
  if (colours.isEmpty) return out;
  final distance = math.min(tolerance, _maxDistance);
  final minShare = _minShare(tolerance);
  for (final box in regions ?? [BBox(0, 0, w, h)]) {
    final x1 = math.max(0, box.x1), y1 = math.max(0, box.y1);
    final x2 = math.min(w, box.x2), y2 = math.min(h, box.y2);
    if (x2 <= x1 || y2 <= y1) continue;
    final bw = x2 - x1, bh = y2 - y1;
    final paper = _background(image, x1, y1, x2, y2, colours);
    final hit = GrayImage.zeros(bw, bh);
    var any = false;
    // Colours repeat a lot on a page: each is checked once.
    final cache = <int, bool>{};
    for (var y = y1; y < y2; y++) {
      for (var x = x1; x < x2; x++) {
        final i = (y * w + x) * 3;
        final key = (image.data[i] << 16) | (image.data[i + 1] << 8) | image.data[i + 2];
        final near = cache[key] ??= () {
          final p = (image.data[i], image.data[i + 1], image.data[i + 2]);
          for (final c in colours) {
            // A letter blends with the paper at its edges and with the
            // dark lines of the drawing where it lies over them.
            if (_isLetter(p, c, paper, minShare, distance) || _isLetter(p, c, _ink, minShare, distance)) return true;
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
    if (wholePieces) _dropEdgePieces(hit);
    final grown = grow > 0 ? imkDilate(hit, StructuringElement.rect(2 * grow + 1, 2 * grow + 1)) : hit;
    for (var y = 0; y < bh; y++) {
      for (var x = 0; x < bw; x++) {
        if (grown.data[y * bw + x] != 0) out.data[(y1 + y) * base.width + x1 + x] = 255;
      }
    }
  }
  return out;
}

/// Clears the 8-connected pieces of [hit] that touch its edge.
void _dropEdgePieces(GrayImage hit) {
  final w = hit.width, h = hit.height, d = hit.data;
  final queue = Int32List(w * h);
  var head = 0, tail = 0;
  void seed(int at) {
    if (d[at] == 0) return;
    d[at] = 0;
    queue[tail++] = at;
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (head < tail) {
    final at = queue[head++];
    final x = at % w, y = at ~/ w;
    for (var dy = -1; dy <= 1; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= h) continue;
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        if (nx >= 0 && nx < w) seed(ny * w + nx);
      }
    }
  }
}

/// Whether pixel [p] is a blend of letter colour [c] and background [paper]
/// with at least [minShare] of [c] in it, within [distance] ΔE (less for
/// fainter blends: near the background every colour is close to the blend).
/// Without a background only the colour itself counts.
bool _isLetter(
  (int, int, int) p,
  (int, int, int) c,
  (double, double, double)? paper,
  double minShare,
  double distance,
) {
  final (pr, pg, pb) = p;
  final (cr, cg, cb) = c;
  var share = 1.0;
  var (qr, qg, qb) = (cr.toDouble(), cg.toDouble(), cb.toDouble());
  if (paper != null) {
    final (br, bg, bb) = paper;
    final vr = cr - br, vg = cg - bg, vb = cb - bb;
    final len2 = vr * vr + vg * vg + vb * vb;
    // A colour too close to the background has no blend to follow.
    if (len2 >= 40 * 40) {
      share = (((pr - br) * vr + (pg - bg) * vg + (pb - bb) * vb) / len2).clamp(0.0, 1.0);
      if (share < minShare) return false;
      (qr, qg, qb) = (br + share * vr, bg + share * vg, bb + share * vb);
    }
  }
  final (l, a, b) = _lab(pr.toDouble(), pg.toDouble(), pb.toDouble());
  final (ql, qa, qb2) = _lab(qr, qg, qb);
  final d2 = (l - ql) * (l - ql) + (a - qa) * (a - qa) + (b - qb2) * (b - qb2);
  final limit = distance * share;
  return d2 <= limit * limit;
}

/// The background of the region: the mean of its most common colour (in
/// 16-level bins), leaving out pixels near [colours] (a region full of big
/// letters); null when no colour covers 2% of it.
(double, double, double)? _background(RgbImage image, int x1, int y1, int x2, int y2, List<(int, int, int)> colours) {
  // Sums in doubles: a 12-megapixel page of white overflows 32 bits.
  final count = Int32List(4096), sr = Float64List(4096), sg = Float64List(4096), sb = Float64List(4096);
  final d = image.data, w = image.width;
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      final i = (y * w + x) * 3;
      final r = d[i], g = d[i + 1], b = d[i + 2];
      var letter = false;
      for (final (cr, cg, cb) in colours) {
        if ((r - cr) * (r - cr) + (g - cg) * (g - cg) + (b - cb) * (b - cb) < 80 * 80) {
          letter = true;
          break;
        }
      }
      if (letter) continue;
      final k = (r >> 4) << 8 | (g >> 4) << 4 | b >> 4;
      count[k]++;
      sr[k] += r;
      sg[k] += g;
      sb[k] += b;
    }
  }
  var best = 0;
  for (var k = 1; k < 4096; k++) {
    if (count[k] > count[best]) best = k;
  }
  final n = count[best];
  if (n == 0 || n * 50 < (x2 - x1) * (y2 - y1)) return null;
  return (sr[best] / n, sg[best] / n, sb[best] / n);
}

/// sRGB → CIE L*a*b* (D65).
(double, double, double) _lab(double r8, double g8, double b8) {
  double lin(double c) {
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
