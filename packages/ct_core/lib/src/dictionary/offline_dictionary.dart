/// The offline dictionary: a word or phrase of the original looked up in one
/// SQLite file built from Wiktionary (`tools/dictionary/build_dictionary.py`,
/// English to Russian for now). New in this project.
///
/// A word is found as it is, through the forms Wiktionary knows (ran → run,
/// guys → guy, y'know → you know) and, failing that, through simple English
/// endings (-s, -ed, -ing…); a phrase whose first word is a form is found by
/// its first form (gave up → give up).
library;

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// An example of use, with its translation when the dictionary has one.
class DictExample {
  const DictExample(this.text, [this.translation]);

  final String text;
  final String? translation;
}

/// One meaning: an explanation (in Russian or in English), labels like
/// `colloquial`, examples.
class DictSense {
  const DictSense(this.gloss, {this.tags = const [], this.examples = const []});

  final String gloss;
  final List<String> tags;
  final List<DictExample> examples;
}

/// Russian words for one meaning; [sense] says which (in English), or is
/// empty.
class DictTranslation {
  const DictTranslation(this.sense, this.words);

  final String sense;
  final List<String> words;
}

/// What the dictionary says about a word as one part of speech.
class DictPart {
  const DictPart({
    required this.pos,
    this.translations = const [],
    this.russian = const [],
    this.english = const [],
    this.formOf = const [],
  });

  /// Wiktionary's part of speech: noun, verb, adj, adv, intj, phrase, name…
  final String pos;

  /// Russian words by meaning (English Wiktionary).
  final List<DictTranslation> translations;

  /// Meanings explained in Russian, with translated examples (Russian
  /// Wiktionary).
  final List<DictSense> russian;

  /// Meanings explained in English.
  final List<DictSense> english;

  /// "plural of guy", "simple past of run".
  final List<String> formOf;

  bool get hasRussian => translations.isNotEmpty || russian.isNotEmpty;
}

/// A found word: [headword] as the dictionary writes it, [note] how it was
/// reached from the looked-up text (`past`, `≈ run`), null for the text
/// itself.
class DictCard {
  const DictCard(this.headword, this.parts, {this.note});

  final String headword;
  final String? note;
  final List<DictPart> parts;

  bool get hasRussian => parts.any((p) => p.hasRussian);

  /// Only "form of …" lines: the card of the main form says the rest.
  bool get isFormOnly => parts.every((p) => p.translations.isEmpty && p.russian.isEmpty && p.english.isEmpty);
}

/// The dictionary file could not be opened.
class DictionaryFormatException implements Exception {
  const DictionaryFormatException(this.message);

  final String message;

  @override
  String toString() => 'DictionaryFormatException: $message';
}

class OfflineDictionary {
  OfflineDictionary._(this._db, this.from, this.to);

  /// Opens the dictionary file at [path] for reading.
  factory OfflineDictionary.open(String path) {
    if (!File(path).existsSync()) throw DictionaryFormatException('no dictionary file at $path');
    final Database db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
    } on SqliteException catch (e) {
      throw DictionaryFormatException('cannot open the dictionary: ${e.message}');
    }
    try {
      final meta = {for (final r in db.select('SELECT k, v FROM meta')) r['k'] as String: r['v'] as String};
      if (meta['format'] != '1') throw DictionaryFormatException('unknown dictionary format ${meta['format']}');
      return OfflineDictionary._(db, meta['from'] ?? 'en', meta['to'] ?? 'ru');
    } on SqliteException catch (e) {
      db.close();
      throw DictionaryFormatException('not a dictionary file: ${e.message}');
    } on DictionaryFormatException {
      db.close();
      rethrow;
    }
  }

  final Database _db;

  /// Language codes: what is looked up and what it is translated into.
  final String from;
  final String to;

  late final _entry = _db.prepare('SELECT word, data FROM entry WHERE w = ?');
  late final _forms = _db.prepare('SELECT lemma, note FROM form WHERE f = ?');
  late final _prefix = _db.prepare('SELECT word FROM entry WHERE w >= ? AND w < ? ORDER BY w LIMIT ?');

  /// The cards for [text] (a word or a phrase): the text itself first, then
  /// the main forms. Empty when the dictionary does not know it.
  List<DictCard> lookup(String text) {
    final w = normalizeDictQuery(text);
    if (w.isEmpty) return const [];
    final found = <DictCard>[];
    final seen = <String>{};
    void add(String key, [String? note]) {
      if (!seen.add(key)) return;
      final card = _card(key, note);
      if (card != null) found.add(card);
    }

    add(w);
    for (final (lemma, note) in _formsOf(w)) {
      add(normalizeDictQuery(lemma), note.isEmpty ? lemma : note);
    }
    if (found.every((c) => c.isFormOnly)) {
      for (final g in englishLemmaGuesses(w)) {
        add(g, '≈ $g');
      }
    }
    if (found.isEmpty && w.contains(' ')) {
      final space = w.indexOf(' ');
      final first = w.substring(0, space), rest = w.substring(space);
      for (final (lemma, _) in _formsOf(first)) {
        add('${normalizeDictQuery(lemma)}$rest', '$lemma$rest');
      }
    }
    return found;
  }

  /// Up to [limit] words starting with [prefix], in order (for the search
  /// field of the dictionary window).
  List<String> suggest(String prefix, {int limit = 30}) {
    final w = normalizeDictQuery(prefix);
    if (w.isEmpty) return const [];
    return [
      for (final r in _prefix.select([w, '$w\u{10FFFF}', limit])) r['word'] as String,
    ];
  }

  void dispose() {
    _entry.close();
    _forms.close();
    _prefix.close();
    _db.close();
  }

  List<(String, String)> _formsOf(String w) => [
    for (final r in _forms.select([w])) (r['lemma'] as String, (r['note'] as String?) ?? ''),
  ];

  DictCard? _card(String key, String? note) {
    final rows = _entry.select([key]);
    if (rows.isEmpty) return null;
    final data = jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    return DictCard(rows.first['word'] as String, [
      for (final MapEntry(:key, :value) in data.entries) _part(key, value as Map<String, dynamic>),
    ], note: note);
  }

  static DictPart _part(String pos, Map<String, dynamic> d) => DictPart(
    pos: pos,
    translations: [
      for (final MapEntry(:key, :value) in ((d['tr'] as Map<String, dynamic>?) ?? const {}).entries)
        DictTranslation(key, [for (final w in value as List) w as String]),
    ],
    russian: [
      for (final s in (d['ru'] as List?) ?? const [])
        _sense(s as Map<String, dynamic>, (x) {
          final pair = x as List;
          final tr = pair.length > 1 ? pair[1] as String : '';
          return DictExample(pair[0] as String, tr.isEmpty ? null : tr);
        }),
    ],
    english: [
      for (final s in (d['en'] as List?) ?? const [])
        _sense(s as Map<String, dynamic>, (x) => DictExample(x as String)),
    ],
    formOf: [for (final s in (d['of'] as List?) ?? const []) s as String],
  );

  static DictSense _sense(Map<String, dynamic> s, DictExample Function(Object?) example) => DictSense(
    s['g'] as String,
    tags: [for (final t in (s['t'] as List?) ?? const []) t as String],
    examples: [for (final x in (s['x'] as List?) ?? const []) example(x)],
  );
}

final _edges = RegExp(r'''^[\s.,!?;:"“”„«»()\[\]…\-—–*~_/\\]+|[\s.,!?;:"“”„«»()\[\]…\-—–*~_/\\]+$''');

/// The key a text is looked up by: lower case, `’` as `'`, one space
/// between words, no punctuation around.
String normalizeDictQuery(String text) => text
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .toLowerCase()
    .replaceAll(_edges, '')
    .split(RegExp(r'\s+'))
    .where((s) => s.isNotEmpty)
    .join(' ');

/// Guesses at the main form of an English word, for words whose forms
/// Wiktionary does not list (tried in order).
List<String> englishLemmaGuesses(String w) {
  final out = <String>[];
  if (w.endsWith("'s") || w.endsWith("s'")) out.add(w.substring(0, w.length - 2));
  if (w.endsWith('ies')) out.add('${w.substring(0, w.length - 3)}y');
  if (w.endsWith('es')) out.add(w.substring(0, w.length - 2));
  if (w.endsWith('s')) out.add(w.substring(0, w.length - 1));
  for (final suffix in const ['ing', 'ed', 'er', 'est']) {
    if (!w.endsWith(suffix) || w.length <= suffix.length + 2) continue;
    final stem = w.substring(0, w.length - suffix.length);
    out
      ..add(stem)
      ..add('${stem}e');
    if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) out.add(stem.substring(0, stem.length - 1));
    if (stem.endsWith('i')) out.add('${stem.substring(0, stem.length - 1)}y');
  }
  if (w.endsWith("in'")) out.add('${w.substring(0, w.length - 1)}g');
  return out;
}
