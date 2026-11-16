import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// A tiny dictionary in the format of `tools/dictionary/build_dictionary.py`.
String makeDictionary(Directory dir, {String format = '1'}) {
  final path = p.join(dir.path, 'dictionary.sqlite');
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
  db.execute('CREATE TABLE entry(w TEXT PRIMARY KEY, word TEXT, data TEXT)');
  db.execute('CREATE TABLE form(f TEXT, lemma TEXT, note TEXT)');
  for (final (k, v) in [('format', format), ('from', 'en'), ('to', 'ru')]) {
    db.execute('INSERT INTO meta VALUES(?,?)', [k, v]);
  }
  void entry(String word, Map<String, Object> data) =>
      db.execute('INSERT INTO entry VALUES(?,?,?)', [word.toLowerCase(), word, jsonEncode(data)]);
  entry('give up', {
    'verb': {
      'tr': {
        'surrender': ['сдаваться', 'сдаться'],
        'stop, quit': ['бросать'],
      },
      'en': [
        {
          'g': 'To surrender.',
          't': ['transitive'],
          'x': ['He gave himself up.'],
        },
      ],
    },
    'phrase': {
      'ru': [
        {
          'g': 'бросать',
          't': <String>[],
          'x': [
            ['Nicky is giving up her job.', 'Никки бросает работу.'],
          ],
        },
      ],
    },
  });
  entry('guy', {
    'noun': {
      'tr': {
        'male, man': ['парень'],
      },
    },
    'name': {
      'tr': {
        'male given name': ['Гай'],
      },
    },
  });
  entry('guys', {
    'noun': {
      'of': ['plural of guy'],
    },
  });
  entry('jump', {
    'verb': {
      'tr': {
        '': ['прыгать'],
      },
    },
  });
  entry('ain\'t', {
    'verb': {
      'en': [
        {
          'g': 'Am not.',
          't': ['informal'],
          'x': <String>[],
        },
      ],
    },
  });
  for (final (f, lemma, note) in [
    ('gave', 'give', 'past'),
    ('guys', 'guy', 'plural'),
    ('gave up', 'give up', 'past'),
  ]) {
    db.execute('INSERT INTO form VALUES(?,?,?)', [f, lemma, note]);
  }
  db.close();
  return path;
}

void main() {
  late Directory dir;
  late OfflineDictionary dict;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dict_test');
    dict = OfflineDictionary.open(makeDictionary(dir));
  });

  tearDown(() {
    dict.dispose();
    dir.deleteSync(recursive: true);
  });

  test('a phrase in capitals with punctuation is found', () {
    final cards = dict.lookup('  GIVE UP!! ');
    expect(cards.single.headword, 'give up');
    expect(cards.single.note, isNull);
    final verb = cards.single.parts.first;
    expect(verb.pos, 'verb');
    expect(verb.translations.first.sense, 'surrender');
    expect(verb.translations.first.words, ['сдаваться', 'сдаться']);
    expect(verb.english.single.examples.single.text, 'He gave himself up.');
    final phrase = cards.single.parts[1];
    expect(phrase.russian.single.examples.single.translation, 'Никки бросает работу.');
    expect(cards.single.hasRussian, isTrue);
  });

  test('forms lead to the main form', () {
    final cards = dict.lookup('Guys');
    expect(cards.map((c) => c.headword), ['guys', 'guy']);
    expect(cards.first.isFormOnly, isTrue);
    expect(cards[1].note, 'plural');
    expect(cards[1].parts.last.pos, 'name');
  });

  test('a phrase whose first word is a form is found by the main form', () {
    expect(dict.lookup('gave up').single.headword, 'give up');
    expect(dict.lookup('gave  up').single.headword, 'give up');
  });

  test('simple English endings when Wiktionary lists no form', () {
    final cards = dict.lookup('jumping');
    expect(cards.single.headword, 'jump');
    expect(cards.single.note, '≈ jump');
    expect(dict.lookup('jumped').single.headword, 'jump');
  });

  test('curly apostrophes and English-only words', () {
    final card = dict.lookup('AIN’T').single;
    expect(card.headword, "ain't");
    expect(card.hasRussian, isFalse);
    expect(card.parts.single.english.single.tags, ['informal']);
  });

  test('unknown words and empty text give nothing', () {
    expect(dict.lookup('qwertyuiop'), isEmpty);
    expect(dict.lookup(' !? '), isEmpty);
  });

  test('suggestions by the beginning of a word', () {
    expect(dict.suggest('GU'), ['guy', 'guys']);
    expect(dict.suggest('g', limit: 1), ['give up']);
    expect(dict.suggest(''), isEmpty);
  });

  test('a file of another format is refused', () {
    final other = Directory.systemTemp.createTempSync('dict_test2');
    addTearDown(() => other.deleteSync(recursive: true));
    expect(() => OfflineDictionary.open(makeDictionary(other, format: '9')), throwsA(isA<DictionaryFormatException>()));
    expect(() => OfflineDictionary.open(p.join(other.path, 'none.sqlite')), throwsA(isA<DictionaryFormatException>()));
  });

  test('lemma guesses', () {
    expect(englishLemmaGuesses('parties'), contains('party'));
    expect(englishLemmaGuesses('stopped'), contains('stop'));
    expect(englishLemmaGuesses("freakin'"), contains('freaking'));
    expect(normalizeDictQuery('«Hey,  DUDE…»'), 'hey, dude');
  });
}
