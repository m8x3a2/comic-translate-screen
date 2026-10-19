/// Find and replace in the recognized text or the translations (original
/// `controllers/search_replace.py`).
library;

import 'package:ct_core/ct_core.dart';

import 'workspace.dart';

class SearchOptions {
  const SearchOptions({
    this.query = '',
    this.inSource = false,
    this.matchCase = false,
    this.wholeWord = false,
    this.regex = false,
    this.allPages = true,
  });

  final String query;

  /// Search the recognized text instead of the translations.
  final bool inSource;
  final bool matchCase;
  final bool wholeWord;

  /// [query] is a regular expression (replacements may use `$1`).
  final bool regex;

  /// Every page, else the current one.
  final bool allPages;

  SearchOptions copyWith({
    String? query,
    bool? inSource,
    bool? matchCase,
    bool? wholeWord,
    bool? regex,
    bool? allPages,
  }) => SearchOptions(
    query: query ?? this.query,
    inSource: inSource ?? this.inSource,
    matchCase: matchCase ?? this.matchCase,
    wholeWord: wholeWord ?? this.wholeWord,
    regex: regex ?? this.regex,
    allPages: allPages ?? this.allPages,
  );
}

class SearchMatch {
  const SearchMatch(this.pageId, this.block, this.start, this.end);

  final String pageId;
  final int block;
  final int start;
  final int end;
}

/// The pattern for [o]; throws [FormatException] for a bad regular
/// expression. Null for an empty query.
RegExp? searchPattern(SearchOptions o) {
  if (o.query.isEmpty) return null;
  var source = o.regex ? o.query : RegExp.escape(o.query);
  // Word edges that also work for Cyrillic and other scripts.
  if (o.wholeWord) source = r'(?<![\p{L}\p{N}_])(?:' + source + r')(?![\p{L}\p{N}_])';
  return RegExp(source, caseSensitive: o.matchCase, unicode: true);
}

String _field(TextBlock b, SearchOptions o) => o.inSource ? b.text : b.translation;

/// Every match in [pages] (or only [current] when not all pages), in page
/// and block order.
List<SearchMatch> findMatches(List<PageEntry> pages, SearchOptions o, {String? current}) {
  final re = searchPattern(o);
  if (re == null) return const [];
  return [
    for (final page in pages)
      if (o.allPages || page.id == current)
        for (final (i, b) in page.blocks.indexed)
          for (final m in re.allMatches(_field(b, o)))
            if (m.end > m.start) SearchMatch(page.id, i, m.start, m.end),
  ];
}

/// [replacement] for one match: groups (`$1`, `${name}`) with regular
/// expressions, literal text otherwise.
String _expand(Match m, String replacement, bool regex) {
  if (!regex) return replacement;
  return replacement.replaceAllMapped(RegExp(r'\$(\d+|\{\w+\})'), (g) {
    final ref = g[1]!;
    if (ref.startsWith('{')) {
      final name = ref.substring(1, ref.length - 1);
      return m is RegExpMatch && m.groupNames.contains(name) ? (m.namedGroup(name) ?? '') : '';
    }
    final n = int.parse(ref);
    return n <= m.groupCount ? (m.group(n) ?? '') : '';
  });
}

/// [text] with the match at [start] replaced; null when it is not there
/// any more.
String? replaceAt(String text, int start, SearchOptions o, String replacement) {
  final re = searchPattern(o);
  if (re == null) return null;
  for (final m in re.allMatches(text)) {
    if (m.start == start && m.end > m.start) {
      return text.replaceRange(m.start, m.end, _expand(m, replacement, o.regex));
    }
  }
  return null;
}

/// [text] with every match replaced, and how many there were.
(String, int) replaceAll(String text, SearchOptions o, String replacement) {
  final re = searchPattern(o);
  if (re == null) return (text, 0);
  var count = 0;
  final out = text.replaceAllMapped(re, (m) {
    if (m.end == m.start) return m[0]!;
    count++;
    return _expand(m, replacement, o.regex);
  });
  return (out, count);
}

/// Applies a replacement result to block [b] for [o]'s field.
void setField(TextBlock b, SearchOptions o, String value) => o.inSource ? b.text = value : b.translation = value;
