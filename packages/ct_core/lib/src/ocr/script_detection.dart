/// Model-independent parts of script identification (the "Auto" source
/// language): which line of a block is read, how it is prepared for the OSD
/// LSTM model (Tesseract's script detector ported to ONNX) and how its output
/// becomes a script label. Port of `modules/detection/script_detection.py`.
library;

import 'dart:typed_data';

import '../detection/heuristic_lines.dart';
import '../image/raster.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// Height of the model input.
const scriptInputHeight = 48;

/// Label index 0 ("NULL").
const _nullChar = 0;

/// CTC blank (`UNICHAR_BROKEN`).
const _blankChar = 2;

/// Input of the OSD model: `(1, 1, 48, width)` float32.
class ScriptInput {
  ScriptInput(this.data, this.width);

  final Float32List data;
  final int width;
}

/// Tesseract `STATS::ile` over the 256 buckets of [buckets].
double statsIle(List<int> buckets, double frac) {
  var total = 0;
  for (final b in buckets) {
    total += b;
  }
  if (total == 0) return 0.0;
  var target = frac * total;
  if (target < 1.0) target = 1.0;
  if (target > total) target = total.toDouble();
  var s = 0;
  var index = 0;
  while (index <= 255 && s < target) {
    s += buckets[index];
    index++;
  }
  if (index > 0) return index - (s - target) / buckets[index - 1];
  return 0.0;
}

/// Black and white points of a grey line image (`ComputeBlackWhite` of
/// Tesseract): local minima and maxima along its middle row.
(double, double) blackWhite(Uint8List gray, int width, int height) {
  final mins = List<int>.filled(256, 0), maxes = List<int>.filled(256, 0);
  if (width >= 3) {
    final row = (height ~/ 2) * width;
    var prev = gray[row], curr = gray[row + 1];
    for (var x = 1; x < width - 1; x++) {
      final next = gray[row + x + 1];
      if ((curr < prev && curr <= next) || (curr <= prev && curr < next)) mins[curr]++;
      if ((curr > prev && curr >= next) || (curr >= prev && curr > next)) maxes[curr]++;
      prev = curr;
      curr = next;
    }
  }
  if (!mins.any((v) => v != 0)) mins[0] = 1;
  if (!maxes.any((v) => v != 0)) maxes[255] = 1;
  return (statsIle(mins, 0.25), statsIle(maxes, 0.75));
}

/// `_preprocess`: [crop] scaled to 48 px high (Pillow bicubic), made grey,
/// turned to dark text on light when mostly dark, and normalised by its
/// black and white points to about [-1, 1].
ScriptInput scriptInput(RgbImage crop) {
  final w = pyRound(crop.width * (scriptInputHeight / crop.height));
  final nw = w < 1 ? 1 : w;
  final scaled = pilResize(crop, nw, scriptInputHeight);
  final n = nw * scriptInputHeight;
  final grey = Uint8List(n);
  final rgb = scaled.data;
  for (var i = 0; i < n; i++) {
    grey[i] = (0.3 * rgb[i * 3] + 0.5 * rgb[i * 3 + 1] + 0.2 * rgb[i * 3 + 2] + 0.5).floor();
  }
  if (npMedian(grey) < 64.0) {
    for (var i = 0; i < n; i++) {
      grey[i] = 255 - grey[i];
    }
  }
  final (black, white) = blackWhite(grey, nw, scriptInputHeight);
  var contrast = (white - black) / 2.0;
  if (contrast <= 0.0) contrast = 1.0;
  // black and contrast are numpy float64 scalars: the arithmetic runs in
  // double precision and is rounded to float32 once at the end.
  final data = Float32List(n);
  for (var i = 0; i < n; i++) {
    data[i] = (grey[i] - black) / contrast - 1.0;
  }
  return ScriptInput(data, nw);
}

/// `_dominant_script`: CTC best path of [scores] (`steps` × `classes`), then
/// the most frequent non-blank label; empty when none.
String dominantScript(Float32List scores, int steps, int classes, List<String> labels) {
  final counts = <int, int>{};
  var prev = _blankChar;
  for (var t = 0; t < steps; t++) {
    var best = 0;
    var bestValue = scores[t * classes];
    for (var c = 1; c < classes; c++) {
      final v = scores[t * classes + c];
      if (v > bestValue) {
        bestValue = v;
        best = c;
      }
    }
    if (best != _blankChar && best != prev) counts[best] = (counts[best] ?? 0) + 1;
    prev = best;
  }
  if (counts.isEmpty) return '';
  var best = counts.keys.first;
  for (final e in counts.entries) {
    if (e.value > counts[best]!) best = e.key;
  }
  return best == _nullChar ? '' : labels[best];
}

int _lineArea(BBox a) => (a.x2 - a.x1 < 1 ? 1 : a.x2 - a.x1) * (a.y2 - a.y1 < 1 ? 1 : a.y2 - a.y1);

/// `_largest_line_crop`: the largest text line of [block] (its lines from
/// detection, or lines found again in its crop) and the text direction; the
/// whole block when no line can be cut out; null for an empty block.
(RgbImage, String)? largestLineCrop(RgbImage image, TextBlock block) {
  final b = block.xyxy;
  final x1 = b.x1 < 0 ? 0 : b.x1, y1 = b.y1 < 0 ? 0 : b.y1;
  final x2 = b.x2 > image.width ? image.width : b.x2, y2 = b.y2 > image.height ? image.height : b.y2;
  if (x2 <= x1 || y2 <= y1) return null;
  final crop = image.crop(BBox(x1, y1, x2, y2));

  String direction;
  BBox line;
  if (block.lines.isNotEmpty && block.direction != TextDirection.unknown) {
    direction = block.direction.id;
    var best = block.lines.first.axisBox;
    for (final l in block.lines.skip(1)) {
      final a = l.axisBox;
      if (_lineArea(a) > _lineArea(best)) best = a;
    }
    line = BBox(best.x1 - x1, best.y1 - y1, best.x2 - x1, best.y2 - y1);
  } else {
    final (lines, dir) = detectLinesAndDirectionInCrop(crop, block.sourceLang);
    direction = dir;
    if (lines.isEmpty) return (crop, direction);
    var best = lines.first.axisBox;
    for (final l in lines.skip(1)) {
      final a = l.axisBox;
      if (_lineArea(BBox(a[0], a[1], a[2], a[3])) > _lineArea(BBox(best[0], best[1], best[2], best[3]))) best = a;
    }
    line = BBox(best[0], best[1], best[2], best[3]);
  }

  final lx1 = line.x1 < 0 ? 0 : line.x1, ly1 = line.y1 < 0 ? 0 : line.y1;
  final lx2 = line.x2 > crop.width ? crop.width : line.x2, ly2 = line.y2 > crop.height ? crop.height : line.y2;
  if (lx2 <= lx1 || ly2 <= ly1) return (crop, direction);
  return (crop.crop(BBox(lx1, ly1, lx2, ly2)), direction);
}

/// `np.rot90(image, k=1)`: turned a quarter counter-clockwise.
RgbImage rotate90(RgbImage image) {
  final w = image.width, h = image.height;
  final out = Uint8List(w * h * 3);
  final src = image.data;
  for (var i = 0; i < w; i++) {
    for (var j = 0; j < h; j++) {
      final s = (j * w + (w - 1 - i)) * 3, d = (i * h + j) * 3;
      out[d] = src[s];
      out[d + 1] = src[s + 1];
      out[d + 2] = src[s + 2];
    }
  }
  return RgbImage(h, w, out);
}

/// What the OSD model reads for [block]: its largest line, upright, prepared
/// (`detect_block_script` before inference). Null when there is nothing to
/// read (the script is then empty).
ScriptInput? scriptInputForBlock(RgbImage image, TextBlock block) {
  final found = largestLineCrop(image, block);
  if (found == null) return null;
  var (crop, direction) = found;
  if (crop.height < 3 || crop.width < 3) return null;
  if (direction == 'vertical') crop = rotate90(crop);
  final input = scriptInput(crop);
  return input.width < 3 ? null : input;
}
