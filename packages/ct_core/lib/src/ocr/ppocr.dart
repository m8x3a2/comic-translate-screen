/// Model-independent parts of the PP-OCR pipeline: cropping text lines,
/// preparing them for the recognizer and decoding its output.
///
/// Ports of `modules/ocr/ppocr/{engine,preprocessing,postprocessing}.py`.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/linalg.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/language.dart';
import '../model/text_block.dart';

/// Recognizer input height and minimum width (`rec_img_shape`).
const ppocrRecHeight = 48;
const ppocrRecMinWidth = 320;

final _f32 = Float32List(1);

/// Rounds to float32 (numpy float32 arithmetic).
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// `np.rot90(image)`: counter-clockwise.
RgbImage rot90(RgbImage src) {
  final w = src.height, h = src.width;
  final out = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = (x * src.width + (src.width - 1 - y)) * 3;
      final d = (y * w + x) * 3;
      out[d] = src.data[s];
      out[d + 1] = src.data[s + 1];
      out[d + 2] = src.data[s + 2];
    }
  }
  return RgbImage(w, h, out);
}

/// `_should_rotate_line_crops`: vertical blocks taller than wide are read
/// column by column, each column rotated to horizontal.
bool shouldRotateLineCrops(TextBlock block) {
  if (block.direction != TextDirection.vertical) return false;
  final width = math.max(1.0, block.xyxy.width.toDouble());
  final height = math.max(1.0, block.xyxy.height.toDouble());
  // A square-ish block is usually one or two tall glyphs, not vertical text.
  return height > width * 1.15;
}

/// `_crop_line`: the pixels of one line (box or quadrilateral), or null when
/// it is empty or degenerate.
RgbImage? cropLine(RgbImage image, TextLine line, {bool rotateVertical = false}) {
  final polygon = line.polygon;
  if (polygon != null) {
    if (polygon.length < 4) return null;
    return cropQuad(image, polygon);
  }
  final b = line.box!;
  return cropBox(image, b.x1, b.y1, b.x2, b.y2, rotateVertical: rotateVertical);
}

RgbImage? cropBox(RgbImage image, int x1, int y1, int x2, int y2, {bool rotateVertical = false}) {
  x1 = x1.clamp(0, image.width);
  x2 = x2.clamp(0, image.width);
  y1 = y1.clamp(0, image.height);
  y2 = y2.clamp(0, image.height);
  if (x2 <= x1 || y2 <= y1) return null;
  final crop = image.crop(BBox(x1, y1, x2, y2));
  return rotateVertical ? rot90(crop) : crop;
}

/// `crop_quad`: perspective crop of a quadrilateral (points in order
/// top-left, top-right, bottom-right, bottom-left). Tall results (h/w >= 1.5)
/// are rotated counter-clockwise. Null for degenerate quads.
RgbImage? cropQuad(RgbImage image, List<Point2> quad) {
  if (quad.length != 4) return null;
  final pts = [for (final p in quad) (_fround(p.x), _fround(p.y))];
  if (pts.any((p) => !p.$1.isFinite || !p.$2.isFinite)) return null;
  if (pts.toSet().length != 4) return null;

  var twiceArea = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = pts[i], b = pts[(i + 1) % 4];
    twiceArea += a.$1 * b.$2 - a.$2 * b.$1;
  }
  if ((0.5 * twiceArea).abs() < 1e-3) return null;

  double dist(int i, int j) {
    final dx = _fround(pts[i].$1 - pts[j].$1), dy = _fround(pts[i].$2 - pts[j].$2);
    return _fround(math.sqrt(_fround(_fround(dx * dx) + _fround(dy * dy))));
  }

  final w = math.max(dist(0, 1), dist(2, 3)).ceil();
  final h = math.max(dist(0, 3), dist(1, 2)).ceil();
  if (w < 1 || h < 1) return null;
  final dst = [(0.0, 0.0), (w.toDouble(), 0.0), (w.toDouble(), h.toDouble()), (0.0, h.toDouble())];

  final List<double> coeffs;
  try {
    final m = _perspectiveTransform(pts, dst);
    final inv = invert(m);
    final flat = [for (final row in inv) ...row];
    coeffs = [for (var i = 0; i < 8; i++) flat[i] / flat[8]];
  } on StateError {
    return null;
  }
  final crop = pilPerspectiveBicubic(image, w, h, coeffs);
  return h / w >= 1.5 ? rot90(crop) : crop;
}

/// `imkit.get_perspective_transform`: the 3×3 homography mapping [src] to
/// [dst] (8×8 linear system, last element 1).
List<List<double>> _perspectiveTransform(List<(double, double)> src, List<(double, double)> dst) {
  final a = List.generate(8, (_) => List<double>.filled(8, 0));
  final b = List<double>.filled(8, 0);
  for (var i = 0; i < 4; i++) {
    final (xs, ys) = src[i];
    final (xd, yd) = dst[i];
    final e = a[2 * i], o = a[2 * i + 1];
    e[0] = xs;
    e[1] = ys;
    e[2] = 1;
    e[6] = _fround(-xs * xd);
    e[7] = _fround(-ys * xd);
    o[3] = xs;
    o[4] = ys;
    o[5] = 1;
    o[6] = _fround(-xs * yd);
    o[7] = _fround(-ys * yd);
    b[2 * i] = xd;
    b[2 * i + 1] = yd;
  }
  final h = solveLinear(a, b);
  return [
    [h[0], h[1], h[2]],
    [h[3], h[4], h[5]],
    [h[6], h[7], 1.0],
  ];
}

/// `_rec_target_width`: padded recognizer width for a crop.
int recTargetWidth(RgbImage crop) {
  final ratio = crop.width / math.max(1, crop.height).toDouble();
  return math.max(ppocrRecMinWidth, (ppocrRecHeight * ratio).ceil());
}

/// `(v / 255 - 0.5) / 0.5` in float32 for every byte value.
final Float32List _normLut = Float32List.fromList([
  for (var v = 0; v < 256; v++) _fround(_fround(_fround(v / 255.0) - 0.5) / 0.5),
]);

/// `rec_resize_norm`: resizes [crop] to height 48 (Lanczos), converts to BGR,
/// normalises to [-1, 1] and right-pads with zeros to the bucket width.
/// Returns CHW float32 values of shape `(3, 48, targetWidth)`.
({Float32List data, int width}) recResizeNorm(RgbImage crop, double maxWhRatio) {
  const h = ppocrRecHeight;
  final ratio = crop.width / crop.height.toDouble();
  final targetW = (h * maxWhRatio).toInt();
  final resizedW = math.min(targetW, (h * ratio).ceil());
  final resized = pilResize(crop, resizedW, h, filter: PilFilter.lanczos);

  final out = Float32List(3 * h * targetW);
  final plane = h * targetW;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < resizedW; x++) {
      final s = (y * resizedW + x) * 3;
      final d = y * targetW + x;
      out[d] = _normLut[resized.data[s + 2]]; // B
      out[plane + d] = _normLut[resized.data[s + 1]]; // G
      out[2 * plane + d] = _normLut[resized.data[s]]; // R
    }
  }
  return (data: out, width: targetW);
}

/// `CTCLabelDecoder`: greedy CTC decoding with a Paddle-style dictionary.
class CtcDecoder {
  CtcDecoder(List<String> chars) : dictChars = List.unmodifiable(chars);

  /// Reads a dictionary file the way Python's text mode does (one entry per
  /// line, universal newlines).
  factory CtcDecoder.fromDictionary(String text) => CtcDecoder(const LineSplitter().convert(text));

  final List<String> dictChars;

  List<String> _vocab(int numClasses) {
    final n = dictChars.length;
    if (numClasses == n + 2) return ['', ...dictChars, ' '];
    if (numClasses == n + 1) return ['', ...dictChars];
    if (numClasses == n) return ['', ...dictChars]; // a blank column is prepended
    if (numClasses >= n + 2) return ['', ...dictChars, ' ', ...List.filled(numClasses - (n + 2), '')];
    return ['', ...dictChars.take(math.max(0, numClasses - 1))];
  }

  /// Decodes logits of shape `(N, T, C)` (probabilities or raw scores).
  List<({String text, double confidence})> decode(Float32List logits, int n, int t, int c, {double probThreshold = 0.0}) {
    var classes = c;
    var probs = logits;
    if (c == dictChars.length) {
      // Prepend a zero "blank" column.
      classes = c + 1;
      probs = Float32List(n * t * classes);
      for (var r = 0; r < n * t; r++) {
        probs.setRange(r * classes + 1, (r + 1) * classes, logits, r * c);
      }
    }
    final vocab = _vocab(c);

    var maxV = -double.infinity, minV = double.infinity;
    for (final v in probs) {
      if (v > maxV) maxV = v;
      if (v < minV) minV = v;
    }
    if (maxV > 1.0 || minV < 0.0) probs = _softmax(probs, classes);

    final results = <({String text, double confidence})>[];
    for (var b = 0; b < n; b++) {
      final chars = StringBuffer();
      final scores = <double>[];
      var last = -1;
      for (var step = 0; step < t; step++) {
        final row = (b * t + step) * classes;
        var best = 0;
        for (var k = 1; k < classes; k++) {
          if (probs[row + k] > probs[row + best]) best = k;
        }
        if (best != 0 && best != last) {
          final p = probs[row + best];
          final ch = best < vocab.length ? vocab[best] : '';
          if (p >= probThreshold && ch.isNotEmpty && !ch.codeUnits.any((u) => u < 32)) {
            chars.write(ch);
            scores.add(p);
          }
        }
        last = best;
      }
      results.add((text: chars.toString(), confidence: scores.isEmpty ? 0.0 : npMean(scores)));
    }
    return results;
  }

  static Float32List _softmax(Float32List x, int classes) {
    final out = Float32List(x.length);
    for (var r = 0; r < x.length; r += classes) {
      var m = -double.infinity;
      for (var k = 0; k < classes; k++) {
        m = math.max(m, x[r + k]);
      }
      var sum = 0.0;
      for (var k = 0; k < classes; k++) {
        out[r + k] = math.exp(x[r + k] - m);
        sum += out[r + k];
      }
      for (var k = 0; k < classes; k++) {
        out[r + k] = out[r + k] / sum;
      }
    }
    return out;
  }
}

/// Line crops of one block for the recognizer (`process_image` with text
/// lines): the lines that produced a non-empty crop, and the crops.
({List<TextLine> lines, List<RgbImage> crops}) blockLineCrops(RgbImage image, TextBlock block) {
  var lines = block.lines.isNotEmpty ? block.lines : [TextLine.box(block.xyxy)];
  final rotateVertical = shouldRotateLineCrops(block);
  if (block.direction == TextDirection.vertical && !rotateVertical) lines = [TextLine.box(block.xyxy)];
  final keptLines = <TextLine>[];
  final crops = <RgbImage>[];
  for (final line in lines) {
    final crop = cropLine(image, line, rotateVertical: rotateVertical);
    if (crop == null || crop.width == 0 || crop.height == 0) continue;
    keptLines.add(line);
    crops.add(crop);
  }
  return (lines: keptLines, crops: crops);
}

/// Stores recognized line texts in [block] (`texts`, `text`,
/// `skipped_small_texts`), joining without spaces for languages that do not
/// use them.
void assignBlockTexts(TextBlock block, List<TextLine> lines, List<String> rawTexts) {
  final texts = [for (final t in rawTexts) t.trim()];
  final (kept, skipped) = splitJapaneseSmallLineTexts(block, lines, texts);
  block.texts = kept;
  block.skippedSmallTexts = skipped;
  block.text = isNoSpaceLanguageCode(block.sourceLang) ? kept.join() : kept.join(' ');
}

/// `is_no_space_lang`.
bool isNoSpaceLanguageCode(String code) {
  if (code.isEmpty) return false;
  final c = code.toLowerCase();
  if (c.contains('zh') || c.contains('ja') || c.contains('th')) return true;
  return Languages.all.any((l) => l.noSpace && l.code.toLowerCase() == c);
}

/// `_split_japanese_small_line_texts`: for Japanese, drops furigana-like
/// lines that are much thinner and smaller than the others.
(List<String>, List<Map<String, Object?>>) splitJapaneseSmallLineTexts(
  TextBlock block,
  List<TextLine> lines,
  List<String> texts,
) {
  final cleaned = [for (final t in texts) if (t.trim().isNotEmpty) t.trim()];
  final japanese = block.sourceLang.trim().toLowerCase().startsWith('ja') || block.script == 'Japanese';
  if (!japanese) return (cleaned, const []);
  if (lines.length < 2 || lines.length != texts.length) return (cleaned, const []);

  final infos = <Map<String, Object?>>[];
  for (var i = 0; i < lines.length; i++) {
    final b = _ocrLineAxisBox(lines[i]);
    final width = math.max(1.0, (b.$3 - b.$1).toDouble());
    final height = math.max(1.0, (b.$4 - b.$2).toDouble());
    infos.add({
      'line_index': i,
      'line': lines[i].toJson(),
      'text': texts[i].trim(),
      'width': width,
      'height': height,
      'area': width * height,
    });
  }

  final vertical = block.direction == TextDirection.vertical;
  double thickness(Map<String, Object?> info) => (vertical ? info['width'] : info['height'])! as double;
  final medianThickness = npMedian(infos.map(thickness));
  final medianArea = npMedian(infos.map((i) => i['area']! as double));
  final medianHeight = npMedian(infos.map((i) => i['height']! as double));
  final medianWidth = npMedian(infos.map((i) => i['width']! as double));
  final kept = <Map<String, Object?>>[];
  final skipped = <Map<String, Object?>>[];
  for (final info in infos) {
    final thicknessRatio = thickness(info) / math.max(1.0, medianThickness);
    final areaRatio = (info['area']! as double) / math.max(1.0, medianArea);
    info['thickness_ratio_to_block_median'] = thicknessRatio;
    info['height_ratio_to_block_median'] = (info['height']! as double) / math.max(1.0, medianHeight);
    info['width_ratio_to_block_median'] = (info['width']! as double) / math.max(1.0, medianWidth);
    info['area_ratio_to_block_median'] = areaRatio;
    (thicknessRatio < 0.7 && areaRatio < 0.75 ? skipped : kept).add(info);
  }
  if (kept.isEmpty) return (cleaned, const []);
  return (
    [for (final i in kept) if ((i['text']! as String).isNotEmpty) i['text']! as String],
    [for (final i in skipped) if ((i['text']! as String).isNotEmpty) i],
  );
}

(int, int, int, int) _ocrLineAxisBox(TextLine line) {
  final p = line.polygon;
  if (p != null) {
    final xs = p.map((q) => q.x), ys = p.map((q) => q.y);
    return (xs.reduce(math.min).toInt(), ys.reduce(math.min).toInt(), xs.reduce(math.max).toInt(), ys.reduce(math.max).toInt());
  }
  final b = line.box!;
  return (b.x1, b.y1, b.x2, b.y2);
}
