/// Labels of the pieces sent to a chat and reading the chat's answer.
///
/// Every piece of text gets a label `[page-block]` (`[01-003]`: page 1,
/// block 3, both counted from 1). The chat answers line by line with the
/// labels, so missing or reordered lines break nothing:
///
/// ```
/// [01-003] I'M LATE! --> Я ОПОЗДАЛ!
/// ```
library;

import 'dart:convert';

import '../model/geometry.dart';
import '../model/text_block.dart';
import 'glossary.dart';
import 'exchange_settings.dart';

/// `[01-003]`: page 1, block 3.
class ExchangeLabel implements Comparable<ExchangeLabel> {
  const ExchangeLabel(this.page, this.block);

  /// Both counted from 1.
  final int page;
  final int block;

  /// `01-003` (more digits when needed).
  String get code => '${'$page'.padLeft(2, '0')}-${'$block'.padLeft(3, '0')}';

  @override
  String toString() => '[$code]';

  static final _code = RegExp(r'^\s*[\[［]?\s*(\d{1,4})\s*' + _dash + r'\s*(\d{1,4})\s*[\]］]?\s*$');

  /// `01-003`, `[1-3]` …; null when [text] is not a label.
  static ExchangeLabel? tryParse(String text) {
    final m = _code.firstMatch(text);
    return m == null ? null : ExchangeLabel(int.parse(m[1]!), int.parse(m[2]!));
  }

  @override
  bool operator ==(Object other) => other is ExchangeLabel && other.page == page && other.block == block;

  @override
  int get hashCode => Object.hash(page, block);

  @override
  int compareTo(ExchangeLabel other) => page != other.page ? page - other.page : block - other.block;

  /// Labels written by the user: `01-002, 03-005`, `[1-2] [3-5]`. Throws
  /// [FormatException] naming the part that is not a label.
  static List<ExchangeLabel> parseList(String text) {
    final labels = <ExchangeLabel>[];
    for (final part in text.replaceAll(RegExp(r'[\[\]]'), ' ').split(RegExp(r'[,;\s]+'))) {
      if (part.isEmpty) continue;
      final label = tryParse(part);
      if (label == null) throw FormatException(part);
      if (!labels.contains(label)) labels.add(label);
    }
    return labels;
  }
}

/// One piece of text sent to the chat.
class ExchangeItem {
  const ExchangeItem({
    required this.label,
    required this.pageId,
    required this.blockIndex,
    required this.box,
    this.text = '',
    this.translation = '',
    this.speaker,
  });

  final ExchangeLabel label;

  /// The page and the block (0-based) the piece came from.
  final String pageId;
  final int blockIndex;

  /// The block's box when it was sent: finds the block again if blocks were
  /// added or removed meanwhile.
  final BBox box;

  /// Text and translation the app had when it was sent.
  final String text;
  final String translation;

  /// Who says it, as the user told.
  final Speaker? speaker;

  /// `[f] ` before the text for the chat; empty without a speaker.
  String get speakerTag => speaker == null ? '' : '[${speaker!.tag}] ';

  Map<String, Object?> toJson() => {
    'label': label.code,
    'page_id': pageId,
    'block': blockIndex,
    'xyxy': box.toJson(),
    'text': text,
    if (translation.isNotEmpty) 'translation': translation,
    if (speaker != null) 'speaker': speaker!.tag,
  };

  factory ExchangeItem.fromJson(Map<String, Object?> json) => ExchangeItem(
    label: ExchangeLabel.tryParse(json['label'] as String? ?? '') ?? const ExchangeLabel(0, 0),
    pageId: json['page_id'] as String? ?? '',
    blockIndex: (json['block'] as num?)?.toInt() ?? 0,
    box: BBox.fromJson(json['xyxy']),
    text: json['text'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    speaker: Speaker.parse(json['speaker'] as String?),
  );
}

/// What the chat wrote for one label.
class ExchangeReply {
  const ExchangeReply({
    this.original,
    this.translation,
    this.missingArrow = false,
    this.speaker,
    this.hasSpeaker = false,
  });

  /// The same with [speaker] told ([hasSpeaker]: a tag was written; `[-]`
  /// tells there is no speaker).
  ExchangeReply withSpeaker(Speaker? speaker, {bool hasSpeaker = true}) => ExchangeReply(
    original: original,
    translation: translation,
    missingArrow: missingArrow,
    speaker: speaker,
    hasSpeaker: hasSpeaker,
  );

  /// Who says it: `[m]`, `[f]`, `[n]` after the label (`[-]`: nobody told).
  final Speaker? speaker;
  final bool hasSpeaker;

  /// The text as read (any mode: in translate, only from the original's
  /// text file, a correction of the text sent).
  final String? original;

  /// The translation (any mode: when reading, it may come along).
  final String? translation;

  /// Mode both, but the line had no `-->`: all of it was taken as the
  /// translation.
  final bool missingArrow;

  bool get isEmpty => (original ?? '').isEmpty && (translation ?? '').isEmpty;
}

class ExchangeAnswer {
  const ExchangeAnswer(this.replies, {this.repeated = const []});

  /// In the order of the answer.
  final Map<ExchangeLabel, ExchangeReply> replies;

  /// Labels the answer had more than once (the first one counts).
  final List<ExchangeLabel> repeated;

  bool get isEmpty => replies.isEmpty;
}

final _listsDivider = RegExp(r'^[ \t]*={3,}[ \t]*$', multiLine: true);

/// An answer written as two lists (originals, a line of `===`, then the
/// translations): the two parts, or null without such a line.
(String originals, String translations)? splitExchangeLists(String answer) {
  final m = _listsDivider.firstMatch(answer.replaceAll('\r\n', '\n'));
  if (m == null) return null;
  final text = answer.replaceAll('\r\n', '\n');
  return (text.substring(0, m.start).trim(), text.substring(m.end).trim());
}

/// One answer from the originals and the translations given apart (two
/// fields, or two text files): `[01-003] I'M LATE!` in one, `[01-003] Я
/// ОПОЗДАЛ!` in the other. Empty lines count as not answered.
ExchangeAnswer mergeExchangeAnswers(ExchangeAnswer originals, ExchangeAnswer translations) {
  String? given(String? s) => s == null || s.trim().isEmpty ? null : s;
  final labels = [
    ...originals.replies.keys,
    for (final l in translations.replies.keys)
      if (!originals.replies.containsKey(l)) l,
  ];
  // Who speaks: as told in the originals, else in the translations.
  ExchangeReply? told(ExchangeLabel l) =>
      [originals.replies[l], translations.replies[l]].firstWhere((r) => r?.hasSpeaker ?? false, orElse: () => null);
  return ExchangeAnswer(
    {
      for (final l in labels)
        l: ExchangeReply(
          original: given(originals.replies[l]?.original),
          translation: given(translations.replies[l]?.translation),
          speaker: told(l)?.speaker,
          hasSpeaker: told(l) != null,
        ),
    },
    repeated: [...originals.repeated, ...translations.repeated],
  );
}

/// The dashes between the page and the piece: the hyphen, the dashes and the
/// minus, also the wide one of Chinese and Japanese text.
const _dash = '[-‐‑–—−－]';

// A label in brackets anywhere: [01-003], 【01-003】, ［01-003］; without
// brackets only at the start of a line and followed by ':' / ')' / '.' / '-'
// or a space: "01-003: text", "**01-003** text".
final _bracketed = RegExp(r'[\[【［〔]\s*(\d{1,4})\s*' + _dash + r'\s*(\d{1,4})\s*[\]】］〕]');
final _bare = RegExp(
  r'^[ \t>•*_#|-]*(?:\d+[.)]\s+)?[*_]*(\d{1,4})' + _dash + r'(\d{1,4})[*_]*(?=[\s:.)]|$)',
  multiLine: true,
);

/// `-->`, `->`, `→`, `=>`, `⟶`, `—>` between the original and the translation.
const _arrows = r'-{1,3}>|=>|→|⟶|—>|–>';

/// The user's [separator] or one of the usual arrows.
RegExp _arrow(String separator) {
  final own = separator.trim().isEmpty ? '' : '${RegExp.escape(separator.trim())}|';
  return RegExp(r'\s*(?:' + own + _arrows + r')\s*');
}

final _fence = RegExp(r'^[ \t]*```.*$', multiLine: true);

/// A key of an answer given as JSON: `"01-003": "Привет"`.
final _jsonKey = RegExp(r'"(\d{1,4})' + _dash + r'(\d{1,4})"(?=\s*:)');

/// The value after a JSON key (`: "Привет",`), up to what closes it.
final _jsonValue = RegExp(r'^"?\s*:\s*"((?:[^"\\]|\\.)*)"[\s,}\]"]*$');

/// A heading on a line of its own: `## Page 2`, `**Page 2**`, `__Page 2:__`.
final _heading = RegExp(r'^\s*(?:#{1,6}\s.*|(\*\*|__)[^*_]+\1:?)\s*$');

/// Reads the chat's [answer]. Text before the first label and after a blank
/// line that ends a piece (the chat's own remarks) is left out; lines of one
/// piece are joined with spaces.
ExchangeAnswer parseExchangeAnswer(
  String answer,
  ExchangeMode mode, {
  String separator = defaultExchangeSeparator,
  List<String> marks = defaultAnswerMarks,
}) {
  final arrow = _arrow(separator);
  // Words suggested for the glossary are no answer for a piece.
  final text = withoutNewTerms(answer).replaceAll(_fence, '');
  final found = <(int start, int end, ExchangeLabel label)>[];
  for (final m in _bracketed.allMatches(text)) {
    found.add((m.start, m.end, ExchangeLabel(int.parse(m[1]!), int.parse(m[2]!))));
  }
  for (final m in [..._jsonKey.allMatches(text), ..._bare.allMatches(text)]) {
    if (found.any((k) => m.start < k.$2 && k.$1 < m.end)) continue;
    found.add((m.start, m.end, ExchangeLabel(int.parse(m[1]!), int.parse(m[2]!))));
  }
  found.sort((a, b) => a.$1 - b.$1);
  final replies = <ExchangeLabel, ExchangeReply>{};
  final repeated = <ExchangeLabel>[];
  for (final (i, (_, end, label)) in found.indexed) {
    final stop = i + 1 < found.length ? _lineStartBefore(text, found[i + 1].$1, end) : text.length;
    final body = _fromTableRow(_cleanBody(text.substring(end, stop), marks), separator, marks);
    if (replies.containsKey(label)) {
      repeated.add(label);
      continue;
    }
    // Who speaks, before the text: `[f] Я опоздала`.
    if (_speakerTag.firstMatch(body) case final tag?) {
      final speaker = Speaker.parse(tag[1]);
      replies[label] = _reply(_plain(body.substring(tag.end), marks), mode, arrow, marks).withSpeaker(speaker);
    } else {
      replies[label] = _reply(body, mode, arrow, marks);
    }
  }
  return ExchangeAnswer(replies, repeated: repeated);
}

// Only list marks before a label on its line: `2. `, `- `, `### `, the
// bar of a table row.
final _listMarks = RegExp(r'^[ \t>•*_#|"-]*(?:\d+[.)])?[ \t>•*_#|"-]*$');

/// A row of a table (chats like to answer so): `| [01-003] | Hi | Привет |`
/// gives the cells after the label, the first one the original and the last
/// one the translation, put as `Hi --> Привет`; a speaker tag in a cell goes
/// to the front. Anything else is [body] as it is.
String _fromTableRow(String body, String separator, List<String> marks) {
  final row = body.replaceFirst(RegExp(r'^[*_ \t]*'), '');
  if (!row.startsWith('|')) return body;
  String? tag;
  final cells = <String>[];
  for (var cell in row.split('|')) {
    if (_speakerTag.firstMatch(cell.trim()) case final m?) {
      tag ??= m[0]!.trim();
      cell = cell.trim().substring(m.end);
    }
    cell = _plain(cell, marks);
    if (cell.isNotEmpty) cells.add(cell);
  }
  if (cells.isEmpty) return tag ?? '';
  final text = cells.length == 1 ? cells.single : '${cells.first} $separator ${cells.last}';
  return tag == null ? text : '$tag $text';
}

/// Where the piece before the label at [start] ends: before the numbering
/// or the list mark of the label's line (not before [after], the end of the
/// previous label).
int _lineStartBefore(String text, int start, int after) {
  final line = text.lastIndexOf('\n', start - 1) + 1;
  if (line <= after) return start;
  return _listMarks.hasMatch(text.substring(line, start)) ? line : start;
}

/// `[m]`, `[f]`, `[n]` (also `[м]`, `[ж]`, `[ср]`), or `[-]` for nobody.
final _speakerTag = RegExp(r'^\[\s*(m|f|n|м|ж|ср|-|—)\s*\]\s*', caseSensitive: false);

ExchangeReply _reply(String body, ExchangeMode mode, RegExp arrows, List<String> marks) {
  final arrow = arrows.firstMatch(body);
  switch (mode) {
    case ExchangeMode.recognize:
      // The translation may come along: `original --> translation`.
      if (arrow == null) return ExchangeReply(original: body);
      return ExchangeReply(
        original: _plain(body.substring(0, arrow.start), marks),
        translation: _plain(body.substring(arrow.end), marks),
      );
    case ExchangeMode.translate:
      // The chat repeated the original before the translation.
      return ExchangeReply(translation: arrow == null ? body : _plain(body.substring(arrow.end), marks));
    case ExchangeMode.both:
      if (arrow == null) return ExchangeReply(translation: body, missingArrow: body.isNotEmpty);
      return ExchangeReply(
        original: _plain(body.substring(0, arrow.start), marks),
        translation: _plain(body.substring(arrow.end), marks),
      );
  }
}

String _cleanBody(String raw, List<String> marks) {
  if (_jsonValue.firstMatch(raw.trim()) case final m?) {
    try {
      return (jsonDecode('"${m[1]}"') as String).trim();
    } on FormatException {
      // Not JSON after all: read as text.
    }
  }
  var s = raw.replaceFirst(RegExp(r'^[ \t]*[:：)\]-]?[ \t]*'), '');
  // A blank line ends the piece: what follows is the chat talking.
  final blank = RegExp(r'\n[ \t]*\n').firstMatch(s.trimLeft());
  if (blank != null) s = s.trimLeft().substring(0, blank.start);
  final lines = s.split('\n');
  // So does a heading (pages of several).
  final heading = _headingAt(lines);
  s = lines
      .take(heading ?? lines.length)
      .map((l) => l.trim().replaceFirst(RegExp(r'^[>•]\s*'), ''))
      .where((l) => l.isNotEmpty)
      // Each line in bold of its own: the bold goes, not only around all.
      .map((l) => lines.length > 1 ? l.replaceFirstMapped(_boldLine, (m) => m[2]!.trim()) : l)
      .join(' ');
  return _plain(s, marks);
}

/// The line of [lines] (those of one piece) where a heading ends it; not the
/// label's own line. `## Page 2` anywhere; a line in bold (`**Page 2**`) only
/// after text of the piece and with nothing but headings after it: a reply
/// the chat put in bold under the label (`[01-003]` / `**Привет**`) is text.
/// (A reply of two lines both in bold reads as a reply and a heading: chats
/// give one line per label.)
int? _headingAt(List<String> lines) {
  bool hasText(String l) => l.replaceAll(RegExp(r'[*_\s:：)\]-]'), '').isNotEmpty;
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (_markdownHeading.hasMatch(line)) return i;
    if (!_heading.hasMatch(line)) continue;
    final textBefore = lines.take(i).any(hasText);
    final headingsAfter = lines.skip(i + 1).every((l) => !hasText(l) || _heading.hasMatch(l));
    if (textBefore && headingsAfter) return i;
  }
  return null;
}

/// A whole line in bold: `**Привет**`.
final _boldLine = RegExp(r'^(\*\*|__)([^*_]+)\1$');

/// A Markdown heading: `## Page 2`.
final _markdownHeading = RegExp(r'^\s*#{1,6}\s');

const _closers = {
  '«': '»',
  '“': '”',
  '„': '“',
  '‹': '›',
  '「': '」',
  '『': '』',
  '【': '】',
  '（': '）',
  '(': ')',
  '[': ']',
  '{': '}',
  '<': '>',
};

/// The mark that closes [open]: `»` for `«`, `**` for `**`.
String closingMark(String open) => [for (final c in open.split('').reversed) _closers[c] ?? c].join();

/// Marks as the user writes them, separated by spaces; a lone `*` is left
/// out (it stresses a word: `Я *НЕ* пойду`).
List<String> parseAnswerMarks(String text) => [
  for (final m in text.trim().split(RegExp(r'\s+')))
    if (m.isNotEmpty && m != '*') m,
];

/// [s] without the bold mark of a bold label (`**[01-003]** Привет`,
/// `**[01-003] Привет**`) and without [marks] around all of it, in any order
/// (`**«Привет»**`); marks inside stay (`Я **НЕ** пойду`, `"Hi" and "bye"`).
String _plain(String s, List<String> marks) {
  var t = s.trim();
  if ('**'.allMatches(t).length.isOdd) {
    if (t.startsWith('**')) {
      t = t.substring(2).trim();
    } else if (t.endsWith('**')) {
      t = t.substring(0, t.length - 2).trim();
    }
  }
  for (var changed = true; changed;) {
    changed = false;
    for (final open in marks) {
      final close = closingMark(open);
      if (open.isEmpty || open == '*' || t.length < open.length + close.length) continue;
      if (!t.startsWith(open) || !t.endsWith(close)) continue;
      final inner = t.substring(open.length, t.length - close.length);
      if (inner.contains(close)) continue;
      t = inner.trim();
      changed = true;
    }
  }
  return t;
}

/// The user's own grouping of pieces into sheets: `1-4, 5-6, 7` — numbers
/// count the pieces in order from 1. Returns 0-based indexes; pieces not
/// named are left to the usual grouping. Throws [FormatException] with the
/// part that is wrong.
List<List<int>> parseSheetGroups(String text, int count) {
  final groups = <List<int>>[];
  final used = <int>{};
  for (final part in text.split(RegExp(r'[,;]'))) {
    final t = part.trim();
    if (t.isEmpty) continue;
    final m = RegExp(r'^(\d+)\s*(?:[-–—]\s*(\d+))?$').firstMatch(t);
    if (m == null) throw FormatException(t);
    final a = int.parse(m[1]!), b = m[2] == null ? a : int.parse(m[2]!);
    if (a < 1 || b < a || b > count) throw FormatException(t);
    final group = [for (var i = a - 1; i < b; i++) i];
    if (group.any(used.contains)) throw FormatException(t);
    used.addAll(group);
    groups.add(group);
  }
  return groups;
}
