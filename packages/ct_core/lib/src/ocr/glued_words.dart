/// Splitting English words that the OCR glued together ("REALLIFE" becomes
/// "REAL LIFE"). Not in the original: on tiny text (screenshots, 5–7 px
/// letters) the one-pixel gap between words is lost and the recognizer reads
/// two words as one.
///
/// Only words missing from the dictionary are split, and only into words of
/// the dictionary (the most likely split by word frequency). Letters are never
/// changed, so names and sound effects stay as they were unless they happen to
/// be made of common words. On the OCR output of the step 2 experiment this
/// found 8 % more right words with fewer wrong ones.
library;

import 'dart:math' as math;

import '../model/language.dart';
import '../model/text_block.dart';

/// Words of up to this many letters are pieces of a split only when they are
/// among the [_shortWordRank] most frequent words: otherwise garbage like
/// "SECLRE" falls apart into rare short words ("SEC", "LRE").
const _shortWordLength = 3;
const _shortWordRank = 1000;

/// Cost added for every piece: fewer pieces win between similar splits.
const _piecePenalty = 2.0;

/// Shorter words are left alone.
const _minLength = 4;

/// Pieces longer than this are not looked for.
const _maxPieceLength = 24;

/// Contractions written without the apostrophe (the OCR often drops it):
/// words, not "A RENT" or "WE VE".
const _contractions = [
  'arent', 'isnt', 'wasnt', 'werent', 'dont', 'doesnt', 'didnt', 'wont', 'wouldnt', 'couldnt', 'shouldnt', //
  'havent', 'hasnt', 'hadnt', 'mustnt', 'neednt', 'aint', 'im', 'ive', 'youre', 'youve', 'youll', 'youd', //
  'theyre', 'theyve', 'theyll', 'theyd', 'weve', 'thats', 'theres', 'heres', 'whos', 'whats', 'wheres',
];

const _contractionRank = 500;

/// What follows the apostrophe of a contraction ("I'M", "IT'S", "WE'LL").
const _suffixes = ['LL', 'RE', 'VE', 'S', 'T', 'M', 'D'];

final _word = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");
final _apostrophe = RegExp("['’]");
final _camel = RegExp('[a-z][A-Z]');

/// An English word list with frequencies, splitting glued words.
class GluedWords {
  GluedWords._(this._known, this._pieces);

  /// Every word of the list (upper case): not split.
  final Set<String> _known;

  /// Words a glued word may be split into (upper case) → cost
  /// (−log of the word's share).
  final Map<String, double> _pieces;

  /// A list of `word count` lines, most frequent first (the SymSpell
  /// frequency dictionary format).
  factory GluedWords.parse(String text) {
    final words = <(String, int)>[];
    var total = 0;
    for (final line in text.split('\n')) {
      final space = line.indexOf(' ');
      if (space <= 0) continue;
      final count = int.tryParse(line.substring(space + 1).trim());
      if (count == null || count <= 0) continue;
      words.add((line.substring(0, space).toUpperCase(), count));
      total += count;
    }
    final known = <String>{for (final (w, _) in words) w, for (final c in _contractions) c.toUpperCase()};
    final pieces = <String, double>{};
    // Contractions of four letters or more are pieces too ("CLEARLYISNT"),
    // as common as the word of rank [_contractionRank].
    final common = words.length > _contractionRank ? words[_contractionRank].$2 : 1;
    for (final c in _contractions) {
      if (c.length >= 4) pieces[c.toUpperCase()] = -math.log(common / total);
    }
    for (final (rank, (w, count)) in words.indexed) {
      if (w.length == 1 && w != 'A' && w != 'I') continue;
      if (w.length <= _shortWordLength && rank >= _shortWordRank) continue;
      if (w.length > _maxPieceLength || pieces.containsKey(w)) continue;
      pieces[w] = -math.log(count / total);
    }
    return GluedWords._(known, pieces);
  }

  int get length => _known.length;

  /// [word] split into words ("REALLIFE" → "REAL LIFE"), or [word] itself
  /// when it is a word, too short, has an apostrophe or capitals inside
  /// ("YouTube"), or cannot be made of words.
  String splitWord(String word) {
    if (word.length < _minLength || word.contains("'") || word.contains('’') || _camel.hasMatch(word)) return word;
    final up = word.toUpperCase();
    if (_known.contains(up)) return word;
    final n = up.length;
    final best = List<double>.filled(n + 1, double.infinity)..[0] = 0;
    final back = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= n; i++) {
      for (var j = math.max(0, i - _maxPieceLength); j < i; j++) {
        if (best[j] == double.infinity) continue;
        final cost = _pieces[up.substring(j, i)];
        if (cost == null) continue;
        final v = best[j] + cost + _piecePenalty;
        if (v < best[i]) {
          best[i] = v;
          back[i] = j;
        }
      }
    }
    if (best[n] == double.infinity) return word;
    final cuts = <int>[];
    for (var i = n; i > 0; i = back[i]) {
      cuts.add(back[i]);
    }
    if (cuts.length < 2) return word;
    final out = StringBuffer();
    for (final (k, start) in cuts.reversed.indexed) {
      if (k > 0) out.write(' ');
      final end = k + 1 < cuts.length ? cuts[cuts.length - k - 2] : n;
      out.write(word.substring(start, end));
    }
    return out.toString();
  }

  /// A word with an apostrophe glued to the next word ("I'MDONE" →
  /// "I'M DONE", "DON'TKNOW" → "DON'T KNOW"), or [word] itself.
  String splitAfterApostrophe(String word) {
    final parts = word.split(_apostrophe);
    if (parts.length != 2 || _camel.hasMatch(word)) return word;
    final tail = parts[1];
    final up = tail.toUpperCase();
    for (final s in _suffixes) {
      if (!up.startsWith(s) || up.length - s.length < 2) continue;
      final rest = tail.substring(s.length);
      final restUp = rest.toUpperCase();
      final split = _pieces.containsKey(restUp) ? rest : splitWord(rest);
      if (identical(split, rest) && !_pieces.containsKey(restUp)) continue;
      final cut = word.length - rest.length;
      return '${word.substring(0, cut)} $split';
    }
    return word;
  }

  /// [text] with its glued words split, and how many were split. Case,
  /// punctuation and line breaks stay.
  (String, int) splitText(String text) {
    var count = 0;
    final out = text.replaceAllMapped(_word, (m) {
      final w = m[0]!;
      final s = _apostrophe.hasMatch(w) ? splitAfterApostrophe(w) : splitWord(w);
      if (!identical(s, w)) count++;
      return s;
    });
    return (count == 0 ? text : out, count);
  }

  /// Splits the glued words of the English blocks of [blocks] (see
  /// [isEnglishBlock]) in place. Returns how many words were split.
  int splitBlocks(Iterable<TextBlock> blocks, {required String sourceLanguage}) {
    var total = 0;
    for (final b in blocks) {
      if (!isEnglishBlock(b, sourceLanguage)) continue;
      final (text, n) = splitText(b.text);
      if (n == 0) continue;
      total += n;
      b.texts = [for (final t in b.texts) splitText(t).$1];
      b.text = text;
    }
    return total;
  }
}

/// [b] is English text: the page language is English, or "Auto" found Latin
/// letters in it.
bool isEnglishBlock(TextBlock b, String sourceLanguage) =>
    sourceLanguage == 'English' || (sourceLanguage == Languages.auto && b.sourceLang == 'en');

/// Lines thinner than this (pixels on the page, as the detector found them)
/// are text too small to read well: about 5–7 px letters.
const smallTextLinePx = 14.0;

/// The text of [b] is very small (see [smallTextLinePx]).
bool isSmallText(TextBlock b) => (b.linePx ?? double.infinity) < smallTextLinePx;
