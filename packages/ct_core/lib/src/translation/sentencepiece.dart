/// SentencePiece unigram tokenizer (the `.spm` models of OPUS-MT): reading
/// the model file, normalizing text as the model was trained (`nmt_nfkc`
/// character map, whitespace) and splitting it into the most likely pieces.
///
/// A port of the parts of google/sentencepiece the OPUS-MT models use
/// (`normalizer.cc`, `unigram_model.cc`, the darts-clone trie of the
/// precompiled character map), checked against the Python `sentencepiece`
/// package on the test sentences (`test_data/reference/sentencepiece.json`).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The word boundary mark of SentencePiece ("▁").
const spSpace = '▁';

/// Piece types of `sentencepiece_model.proto`.
enum SpPieceType { normal, unknown, control, userDefined, unused, byte }

class SentencePieceModel {
  SentencePieceModel._(
    this.pieces,
    this.scores,
    this.types,
    this._charsMap,
    this.addDummyPrefix,
    this.removeExtraWhitespaces,
  ) : _index = {
        for (var i = 0; i < pieces.length; i++)
          if (types[i] == SpPieceType.normal || types[i] == SpPieceType.userDefined) pieces[i]: i,
      },
      _maxPieceLength = pieces.fold(0, (m, p) => math.max(m, p.length)),
      unknownId = math.max(0, types.indexOf(SpPieceType.unknown)),
      _minScore = scores.fold(0.0, (m, s) => math.min(m, s));

  final List<String> pieces;
  final List<double> scores;
  final List<SpPieceType> types;
  final _CharsMap? _charsMap;
  final bool addDummyPrefix;
  final bool removeExtraWhitespaces;
  final Map<String, int> _index;
  final int _maxPieceLength;
  final int unknownId;
  final double _minScore;

  /// Reads a serialized `ModelProto`.
  factory SentencePieceModel.parse(Uint8List bytes) {
    final pieces = <String>[];
    final scores = <double>[];
    final types = <SpPieceType>[];
    Uint8List? charsMap;
    var dummyPrefix = true, extraSpaces = true;
    for (final (field, value) in _Proto(bytes).fields()) {
      if (field == 1 && value is Uint8List) {
        var piece = '';
        var score = 0.0;
        var type = SpPieceType.normal;
        for (final (f, v) in _Proto(value).fields()) {
          if (f == 1 && v is Uint8List) piece = utf8.decode(v);
          if (f == 2 && v is double) score = v;
          if (f == 3 && v is int) type = SpPieceType.values[(v - 1).clamp(0, SpPieceType.values.length - 1)];
        }
        pieces.add(piece);
        scores.add(score);
        types.add(type);
      } else if (field == 3 && value is Uint8List) {
        for (final (f, v) in _Proto(value).fields()) {
          if (f == 2 && v is Uint8List && v.isNotEmpty) charsMap = v;
          if (f == 3 && v is int) dummyPrefix = v != 0;
          if (f == 4 && v is int) extraSpaces = v != 0;
        }
      }
    }
    return SentencePieceModel._(
      pieces,
      scores,
      types,
      charsMap == null ? null : _CharsMap(charsMap),
      dummyPrefix,
      extraSpaces,
    );
  }

  /// [text] as the model sees it: characters mapped, spaces collapsed and
  /// written as "▁", one "▁" in front.
  String normalize(String text) {
    final bytes = utf8.encode(text);
    final out = StringBuffer();
    var prevSpace = removeExtraWhitespaces;
    var started = false;
    void put(String s) {
      for (final rune in s.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          if (removeExtraWhitespaces && prevSpace) continue;
          if (!started) continue;
          out.write(spSpace);
          prevSpace = true;
        } else {
          if (!started) {
            started = true;
            if (addDummyPrefix) out.write(spSpace);
          }
          out.write(ch);
          prevSpace = false;
        }
      }
    }

    var i = 0;
    while (i < bytes.length) {
      final m = _charsMap?.longestMatch(bytes, i);
      if (m != null) {
        put(m.$2);
        i += m.$1;
      } else {
        final n = _utf8Length(bytes[i]);
        put(utf8.decode(bytes.sublist(i, math.min(bytes.length, i + n)), allowMalformed: true));
        i += n;
      }
    }
    var s = out.toString();
    if (removeExtraWhitespaces) {
      while (s.endsWith(spSpace)) {
        s = s.substring(0, s.length - spSpace.length);
      }
    }
    return s;
  }

  /// The most likely pieces of [text] (Viterbi over the piece scores);
  /// a run of characters no piece covers is one unknown piece.
  List<String> encodeAsPieces(String text) {
    final chars = normalize(text).runes.map(String.fromCharCode).toList();
    final n = chars.length;
    final best = List<double>.filled(n + 1, double.negativeInfinity)..[0] = 0;
    final back = List<int>.filled(n + 1, 0);
    final unknownScore = _minScore - 10;
    for (var i = 0; i < n; i++) {
      if (best[i] == double.negativeInfinity) continue;
      var piece = '';
      var matched = false;
      for (var j = i; j < n && j - i < _maxPieceLength; j++) {
        piece += chars[j];
        final id = _index[piece];
        if (id == null) continue;
        matched = matched || j == i;
        final v = best[i] + scores[id];
        if (v > best[j + 1]) {
          best[j + 1] = v;
          back[j + 1] = i;
        }
      }
      if (!matched) {
        final v = best[i] + unknownScore;
        if (v > best[i + 1]) {
          best[i + 1] = v;
          back[i + 1] = i;
        }
      }
    }
    final out = <String>[];
    for (var i = n; i > 0; i = back[i]) {
      out.add(chars.sublist(back[i], i).join());
    }
    final pieces = out.reversed.toList();
    // Neighbouring unknown characters make one unknown piece.
    final merged = <String>[];
    var prevUnknown = false;
    for (final p in pieces) {
      final unknown = !_index.containsKey(p);
      if (unknown && prevUnknown) {
        merged[merged.length - 1] += p;
      } else {
        merged.add(p);
      }
      prevUnknown = unknown;
    }
    return merged;
  }

  /// Whether [piece] is a piece of the model (unknown pieces are not).
  bool contains(String piece) => _index.containsKey(piece);
}

int _utf8Length(int lead) => lead < 0x80
    ? 1
    : lead < 0xE0
    ? 2
    : lead < 0xF0
    ? 3
    : 4;

/// The precompiled character map of a normalizer: a darts-clone double-array
/// trie over UTF-8 byte strings, whose values point into a table of
/// zero-terminated replacements.
class _CharsMap {
  _CharsMap(Uint8List blob) {
    final data = ByteData.sublistView(blob);
    final trieSize = data.getUint32(0, Endian.little);
    _units = Uint32List(trieSize ~/ 4);
    for (var i = 0; i < _units.length; i++) {
      _units[i] = data.getUint32(4 + i * 4, Endian.little);
    }
    _normalized = Uint8List.sublistView(blob, 4 + trieSize);
  }

  late final Uint32List _units;
  late final Uint8List _normalized;

  static int _offset(int unit) => (unit >> 10) << ((unit & (1 << 9)) >> 6);
  static int _label(int unit) => unit & ((1 << 31) | 0xFF);
  static bool _hasLeaf(int unit) => ((unit >> 8) & 1) == 1;
  static int _value(int unit) => unit & ((1 << 31) - 1);

  /// The longest key at [start] of [bytes]: (its length in bytes, the
  /// replacement), or null.
  (int, String)? longestMatch(List<int> bytes, int start) {
    var nodePos = 0;
    var unit = _units[nodePos];
    nodePos ^= _offset(unit);
    (int, int)? found;
    for (var i = start; i < bytes.length; i++) {
      final c = bytes[i];
      if (c == 0) break;
      nodePos ^= c;
      if (nodePos >= _units.length) break;
      unit = _units[nodePos];
      if (_label(unit) != c) break;
      nodePos ^= _offset(unit);
      if (_hasLeaf(unit)) found = (i - start + 1, _value(_units[nodePos]));
    }
    if (found == null) return null;
    var end = found.$2;
    while (end < _normalized.length && _normalized[end] != 0) {
      end++;
    }
    return (found.$1, utf8.decode(_normalized.sublist(found.$2, end), allowMalformed: true));
  }
}

/// A protobuf message read field by field: (field number, value) with
/// varints as int, fixed32 as float, length-delimited as bytes.
class _Proto {
  _Proto(this._b);

  final Uint8List _b;

  Iterable<(int, Object)> fields() sync* {
    var i = 0;
    int varint() {
      var result = 0, shift = 0;
      while (true) {
        final byte = _b[i++];
        result |= (byte & 0x7f) << shift;
        if (byte < 0x80) return result;
        shift += 7;
      }
    }

    final data = ByteData.sublistView(_b);
    while (i < _b.length) {
      final key = varint();
      final field = key >> 3, wire = key & 7;
      switch (wire) {
        case 0:
          yield (field, varint());
        case 1:
          yield (field, data.getFloat64(i, Endian.little));
          i += 8;
        case 2:
          final n = varint();
          yield (field, Uint8List.sublistView(_b, i, i + n));
          i += n;
        case 5:
          yield (field, data.getFloat32(i, Endian.little));
          i += 4;
        default:
          throw FormatException('Unsupported protobuf wire type $wire');
      }
    }
  }
}
