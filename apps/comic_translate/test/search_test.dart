// Find and replace: matching options, replacements, and "preserve case"
// against the original (`_apply_preserve_case`, reference
// test_data/reference/search.json).

import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/state/search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('preserve case as in the original', () {
    final file = File(p.join(Directory.current.path, '..', '..', 'test_data', 'reference', 'search.json'));
    final cases = ((jsonDecode(file.readAsStringSync()) as Map)['preserve_case'] as List).cast<Map>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final matched = c['matched'] as String, replacement = c['replacement'] as String;
      expect(applyPreserveCase(matched, replacement), c['out'], reason: '"$matched" → "$replacement"');
    }
  });

  test('replacements: whole words in any script, case, groups, preserve case', () {
    const o = SearchOptions(query: 'кот', wholeWord: true);
    expect(replaceAll('кот котик Кот', o, 'пёс'), ('пёс котик пёс', 2));
    expect(replaceAll('кот котик Кот', o.copyWith(matchCase: true), 'пёс'), ('пёс котик Кот', 1));
    expect(replaceAll('кот Кот КОТ', o.copyWith(preserveCase: true), 'пёс'), ('пёс Пёс ПЁС', 3));

    const re = SearchOptions(query: r'(\w+)@(\w+)', regex: true, preserveCase: true);
    expect(replaceAll('Ann@home', re, r'$2 of $1'), ('Home of Ann', 1), reason: 'first letter only: not title case');
    expect(
      replaceAt('a b A', 4, const SearchOptions(query: 'a', preserveCase: true), 'xy'),
      'a b XY',
      reason: 'one capital is upper case',
    );
    expect(replaceAt('a b', 1, const SearchOptions(query: 'a'), 'x'), isNull, reason: 'no match there any more');
  });
}
