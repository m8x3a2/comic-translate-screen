/// The model-independent parts of offline translation with Marian models
/// (OPUS-MT): tokens, preparing comic text and beam search. New in this
/// project (the original only translates through online services).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sentencepiece.dart';

/// Source pieces through the source SentencePiece model, ids through the
/// shared `vocab.json` (as `MarianTokenizer` of transformers).
class MarianTokenizer {
  MarianTokenizer(this.source, this.vocab)
    : _pieces = {for (final e in vocab.entries) e.value: e.key},
      unknownId = vocab['<unk>'] ?? 1,
      eosId = vocab['</s>'] ?? 0,
      padId = vocab['<pad>'] ?? vocab.length - 1;

  factory MarianTokenizer.fromFiles(Uint8List sourceSpm, String vocabJson) => MarianTokenizer(
    SentencePieceModel.parse(sourceSpm),
    (jsonDecode(vocabJson) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())),
  );

  final SentencePieceModel source;
  final Map<String, int> vocab;
  final Map<int, String> _pieces;
  final int unknownId;
  final int eosId;

  /// Also the token the decoder starts from.
  final int padId;

  /// Token ids of [text], ending with `</s>`.
  List<int> encode(String text) => [for (final p in source.encodeAsPieces(text)) vocab[p] ?? unknownId, eosId];

  /// Text of [ids] (special tokens left out).
  String decode(List<int> ids) {
    final text = StringBuffer();
    for (final id in ids) {
      if (id == eosId || id == padId) continue;
      final piece = _pieces[id];
      if (piece == null || piece == '<unk>') continue;
      text.write(piece);
    }
    return text.toString().replaceAll(spSpace, ' ').trim();
  }
}

final _letters = RegExp(r'\p{L}', unicode: true);
final _sentenceStart = RegExp(r'(^|[.!?…]\s+|["«“(]\s*)(\p{Ll})', unicode: true);

/// A line written in capitals, as comics are: the models translate it far
/// better in ordinary case.
bool isAllCaps(String text) => _letters.hasMatch(text) && text.toUpperCase() == text && text.toLowerCase() != text;

/// [text] in sentence case when it is all capitals ("WHAT? NO!" → "What?
/// No!", the English "I" kept); other text as it is.
String sentenceCase(String text) {
  if (!isAllCaps(text)) return text;
  var t = text.toLowerCase().replaceAllMapped(_sentenceStart, (m) => '${m[1]}${m[2]!.toUpperCase()}');
  t = t.replaceAllMapped(RegExp(r"(?<![\p{L}'])i(?![\p{L}])", unicode: true), (_) => 'I');
  return t;
}

final _sentenceEnd = RegExp(r'(?<=[.!?…])\s+');

/// [text] split after sentence ends. Marian models tend to drop sentences
/// of a long input; each sentence is translated on its own.
List<String> splitSentences(String text) => [
  for (final s in text.split(_sentenceEnd))
    if (s.trim().isNotEmpty) s.trim(),
];

/// One hypothesis of the beam search.
class BeamHypothesis {
  BeamHypothesis(this.tokens, this.score);

  /// Generated tokens (the start token excluded).
  final List<int> tokens;

  /// Sum of the log-probabilities.
  final double score;

  double get normalized => score / math.max(1, tokens.length);
}

/// The next step of a decoder: for every live hypothesis (in order, given
/// by the index of its parent of the previous step, -1 at the first step),
/// the log-probabilities of the next token.
typedef DecoderStep = List<Float32List> Function(List<int> lastTokens, List<int> parents);

/// Beam search over [step] (greedy with [beams] 1): tokens until `</s>`
/// ([eos]), never [banned] (the pad token), at most [maxLength] tokens.
/// Scores are normalized by length, as transformers does with a length
/// penalty of 1.
List<int> beamSearch(
  DecoderStep step, {
  required int startToken,
  required int eos,
  required int maxLength,
  int beams = 4,
  Set<int> banned = const {},
}) {
  var live = [BeamHypothesis(const [], 0)];
  var parents = const [-1];
  final done = <BeamHypothesis>[];
  for (var t = 0; t < maxLength && live.isNotEmpty; t++) {
    final logProbs = step([for (final h in live) h.tokens.isEmpty ? startToken : h.tokens.last], parents);
    final candidates = <(int, int, double)>[];
    for (var b = 0; b < live.length; b++) {
      final lp = logProbs[b];
      for (final id in banned) {
        if (id < lp.length) lp[id] = double.negativeInfinity;
      }
      // The best few of this hypothesis are enough.
      for (final id in _topK(lp, beams + 1)) {
        candidates.add((b, id, live[b].score + lp[id]));
      }
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    final next = <BeamHypothesis>[];
    final nextParents = <int>[];
    for (final (b, id, score) in candidates) {
      final tokens = [...live[b].tokens, id];
      if (id == eos) {
        done.add(BeamHypothesis(tokens, score));
      } else {
        next.add(BeamHypothesis(tokens, score));
        nextParents.add(b);
      }
      if (next.length == beams) break;
    }
    live = next;
    parents = nextParents;
    if (done.length >= beams) {
      // Enough finished, and none of the live ones is ahead of them.
      final bestDone = done.map((h) => h.normalized).reduce(math.max);
      if (live.every((h) => h.normalized < bestDone)) break;
    }
  }
  final all = done.isEmpty ? live : done;
  final best = all.reduce((a, b) => b.normalized > a.normalized ? b : a);
  return [
    for (final id in best.tokens)
      if (id != eos) id,
  ];
}

/// Indices of the [k] largest values.
List<int> _topK(Float32List v, int k) {
  final top = <int>[];
  for (var i = 0; i < v.length; i++) {
    if (v[i] == double.negativeInfinity) continue;
    if (top.length < k) {
      top.add(i);
      top.sort((a, b) => v[b].compareTo(v[a]));
    } else if (v[i] > v[top.last]) {
      top[top.length - 1] = i;
      top.sort((a, b) => v[b].compareTo(v[a]));
    }
  }
  return top;
}

/// Log-softmax of [logits] in place.
Float32List logSoftmax(Float32List logits) {
  var max = double.negativeInfinity;
  for (final v in logits) {
    if (v > max) max = v;
  }
  var sum = 0.0;
  for (final v in logits) {
    sum += math.exp(v - max);
  }
  final log = max + math.log(sum);
  for (var i = 0; i < logits.length; i++) {
    logits[i] -= log;
  }
  return logits;
}
