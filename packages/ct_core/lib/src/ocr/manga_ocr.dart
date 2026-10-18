/// Model-independent parts of manga-ocr (Japanese): image preparation,
/// token decoding and text clean-up. Port of
/// `modules/ocr/manga_ocr/mobile/onnx_engine.py`.
library;

import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/pil.dart';

part 'manga_ocr_tables.g.dart';

const mangaOcrImageSize = 224;
const mangaOcrMaxSequenceLength = 256;
const mangaOcrMaxPositionId = 127;
const mangaOcrStartToken = 2;
const mangaOcrEndToken = 3;
const _specialTokenThreshold = 5;

/// `_preprocess_into`: fits [crop] into a white 224×224 square (bilinear
/// resize, centred) and returns CHW float32 RGB values in [0, 1].
Float32List mangaOcrPreprocess(RgbImage crop) {
  if (crop.width == 0 || crop.height == 0) throw ArgumentError('Empty image passed to manga-ocr');
  const size = mangaOcrImageSize;
  final scale = (size / crop.width) < (size / crop.height) ? size / crop.width : size / crop.height;
  final dstW = (crop.width * scale).toInt().clamp(1, 1 << 30);
  final dstH = (crop.height * scale).toInt().clamp(1, 1 << 30);
  final resized = pilResize(crop, dstW, dstH, filter: PilFilter.bilinear);
  final ox = (size - dstW) ~/ 2, oy = (size - dstH) ~/ 2;

  final out = Float32List(3 * size * size)..fillRange(0, 3 * size * size, 1.0);
  const plane = size * size;
  for (var y = 0; y < dstH; y++) {
    final ty = y + oy;
    if (ty < 0 || ty >= size) continue;
    for (var x = 0; x < dstW; x++) {
      final tx = x + ox;
      if (tx < 0 || tx >= size) continue;
      final s = (y * dstW + x) * 3;
      final d = ty * size + tx;
      out[d] = _unit[resized.data[s]];
      out[plane + d] = _unit[resized.data[s + 1]];
      out[2 * plane + d] = _unit[resized.data[s + 2]];
    }
  }
  return out;
}

/// `v / 255.0` in float32.
final Float32List _unit = Float32List.fromList([for (var v = 0; v < 256; v++) v / 255.0]);

/// Python `str.splitlines()` (all of Python's line boundaries).
List<String> pySplitLines(String text) {
  final out = <String>[];
  final buf = StringBuffer();
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    final isBreak = c == 0x0a || c == 0x0b || c == 0x0c || c == 0x0d || (c >= 0x1c && c <= 0x1e) ||
        c == 0x85 || c == 0x2028 || c == 0x2029;
    if (!isBreak) {
      buf.writeCharCode(c);
      continue;
    }
    if (c == 0x0d && i + 1 < units.length && units[i + 1] == 0x0a) i++;
    out.add(buf.toString());
    buf.clear();
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

/// manga-ocr vocabulary and text post-processing.
class MangaOcrText {
  MangaOcrText(this.vocab);

  factory MangaOcrText.fromVocabFile(String text) => MangaOcrText(pySplitLines(text));

  final List<String> vocab;

  /// `_decode` + `_postprocess`.
  String decode(List<int> tokenIds) {
    final pieces = StringBuffer();
    for (final id in tokenIds) {
      if (id < _specialTokenThreshold) continue;
      if (id < vocab.length) pieces.write(vocab[id]);
    }
    return postprocess(pieces.toString());
  }

  static bool _isPySpace(int r) =>
      (r >= 0x09 && r <= 0x0d) ||
      (r >= 0x1c && r <= 0x20) ||
      r == 0x85 ||
      r == 0xa0 ||
      r == 0x1680 ||
      (r >= 0x2000 && r <= 0x200a) ||
      r == 0x2028 ||
      r == 0x2029 ||
      r == 0x202f ||
      r == 0x205f ||
      r == 0x3000;

  static final _dotRun = RegExp('[${RegExp.escape(_mojibakeDotClass)}]{2,}', unicode: true);
  static final _repeatedDots = RegExp(r'([.．・･])\1{3,}', unicode: true);
  static final _punctuationOnly = RegExp(
      r'^[.．・･。,…ー—\-~〜「」『』（）()［］\[\]!?！？\s]+$',
      unicode: true);
  static final _dotLike = RegExp(r'^[.．・･。,…]$', unicode: true);
  static final _separatorOnly = RegExp(r'^[\-‐‑‒–—―ーｰ─━~〜～…‥・･.。,、，·•]+$', unicode: true);
  static final _kanaLoop = RegExp(r'([ぁ-ゖァ-ヺ])\1{7,}', unicode: true);
  static final _separatorRuns = RegExp(
      r'[\-‐‑‒–—―ーｰ─━~〜～…‥・･.。,、，·•]{8,}',
      unicode: true);

  /// `_postprocess`.
  static String postprocess(String text) {
    text = String.fromCharCodes(text.runes.where((r) => !_isPySpace(r)));
    text = text.replaceAll(_mojibakeEllipsis, '...');
    text = text.replaceAllMapped(_dotRun, (m) => '.' * m[0]!.runes.length);
    text = h2z(text);
    text = text.replaceAll(_separatorRuns, '');
    if (text.isEmpty) return '';
    if (_isPathologicalPunctuationRun(text) || _isPathologicalSeparatorRun(text) || _isPathologicalKanaLoop(text)) {
      return '';
    }
    return text.replaceAllMapped(_repeatedDots, (m) => '${m[1]}${m[1]}${m[1]}');
  }

  /// `jaconv.h2z(text, ascii=True, digit=True)`: half-width kana, ASCII and
  /// digits to full width.
  static String h2z(String text) {
    for (final (from, to) in _h2zDakuten) {
      text = text.replaceAll(from, to);
    }
    final out = StringBuffer();
    for (final r in text.runes) {
      final mapped = _h2zMap[r];
      if (mapped != null) {
        out.write(mapped);
      } else {
        out.writeCharCode(r);
      }
    }
    return out.toString();
  }

  static bool _isPathologicalPunctuationRun(String text) {
    final chars = text.runes.toList();
    if (chars.length < 12) return false;
    if (!_punctuationOnly.hasMatch(text)) return false;
    final dotLike = chars.where((r) => _dotLike.hasMatch(String.fromCharCode(r))).length;
    return dotLike / chars.length >= 0.85;
  }

  static bool _isPathologicalSeparatorRun(String text) => text.runes.length >= 8 && _separatorOnly.hasMatch(text);

  static bool _isPathologicalKanaLoop(String text) {
    final length = text.runes.length;
    if (length < 12) return false;
    final m = _kanaLoop.firstMatch(text);
    if (m == null) return false;
    final run = m[0]!.runes.length;
    return run >= 16 || run / length >= 0.5;
  }
}
