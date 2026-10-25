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

import '../model/geometry.dart';
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

  static final _code = RegExp(r'^\s*\[?\s*(\d{1,4})\s*[-–—]\s*(\d{1,4})\s*\]?\s*$');

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

  Map<String, Object?> toJson() => {
    'label': label.code,
    'page_id': pageId,
    'block': blockIndex,
    'xyxy': box.toJson(),
    'text': text,
    if (translation.isNotEmpty) 'translation': translation,
  };

  factory ExchangeItem.fromJson(Map<String, Object?> json) => ExchangeItem(
    label: ExchangeLabel.tryParse(json['label'] as String? ?? '') ?? const ExchangeLabel(0, 0),
    pageId: json['page_id'] as String? ?? '',
    blockIndex: (json['block'] as num?)?.toInt() ?? 0,
    box: BBox.fromJson(json['xyxy']),
    text: json['text'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
  );
}

/// What the chat wrote for one label.
class ExchangeReply {
  const ExchangeReply({this.original, this.translation, this.missingArrow = false});

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
  return ExchangeAnswer(
    {
      for (final l in labels)
        l: ExchangeReply(
          original: given(originals.replies[l]?.original),
          translation: given(translations.replies[l]?.translation),
        ),
    },
    repeated: [...originals.repeated, ...translations.repeated],
  );
}

// A label in brackets anywhere: [01-003], 【01-003】; without brackets only
// at the start of a line and followed by ':' / ')' / '.' / '-' or a space:
// "01-003: text", "**01-003** text".
final _bracketed = RegExp(r'[\[【]\s*(\d{1,4})\s*[-–—]\s*(\d{1,4})\s*[\]】]');
final _bare = RegExp(r'^[ \t>•*_#-]*(?:\d+[.)]\s+)?[*_]*(\d{1,4})[-–—](\d{1,4})[*_]*(?=[\s:.)]|$)', multiLine: true);

/// `-->`, `->`, `→`, `=>`, `⟶`, `—>` between the original and the translation.
const _arrows = r'-{1,3}>|=>|→|⟶|—>|–>';

/// The user's [separator] or one of the usual arrows.
RegExp _arrow(String separator) {
  final own = separator.trim().isEmpty ? '' : '${RegExp.escape(separator.trim())}|';
  return RegExp(r'\s*(?:' + own + _arrows + r')\s*');
}

final _fence = RegExp(r'^[ \t]*```.*$', multiLine: true);

/// Reads the chat's [answer]. Text before the first label and after a blank
/// line that ends a piece (the chat's own remarks) is left out; lines of one
/// piece are joined with spaces.
ExchangeAnswer parseExchangeAnswer(String answer, ExchangeMode mode, {String separator = defaultExchangeSeparator}) {
  final arrow = _arrow(separator);
  final text = answer.replaceAll('\r\n', '\n').replaceAll(_fence, '');
  final marks = <(int start, int end, ExchangeLabel label)>[];
  for (final m in _bracketed.allMatches(text)) {
    marks.add((m.start, m.end, ExchangeLabel(int.parse(m[1]!), int.parse(m[2]!))));
  }
  for (final m in _bare.allMatches(text)) {
    if (marks.any((k) => m.start < k.$2 && k.$1 < m.end)) continue;
    marks.add((m.start, m.end, ExchangeLabel(int.parse(m[1]!), int.parse(m[2]!))));
  }
  marks.sort((a, b) => a.$1 - b.$1);
  final replies = <ExchangeLabel, ExchangeReply>{};
  final repeated = <ExchangeLabel>[];
  for (final (i, (_, end, label)) in marks.indexed) {
    final stop = i + 1 < marks.length ? marks[i + 1].$1 : text.length;
    final body = _cleanBody(text.substring(end, stop));
    if (replies.containsKey(label)) {
      repeated.add(label);
      continue;
    }
    replies[label] = _reply(body, mode, arrow);
  }
  return ExchangeAnswer(replies, repeated: repeated);
}

ExchangeReply _reply(String body, ExchangeMode mode, RegExp arrows) {
  final arrow = arrows.firstMatch(body);
  switch (mode) {
    case ExchangeMode.recognize:
      // The translation may come along: `original --> translation`.
      if (arrow == null) return ExchangeReply(original: body);
      return ExchangeReply(
        original: _unquote(body.substring(0, arrow.start)),
        translation: _unquote(body.substring(arrow.end)),
      );
    case ExchangeMode.translate:
      // The chat repeated the original before the translation.
      return ExchangeReply(translation: arrow == null ? body : _unquote(body.substring(arrow.end)));
    case ExchangeMode.both:
      if (arrow == null) return ExchangeReply(translation: body, missingArrow: body.isNotEmpty);
      return ExchangeReply(
        original: _unquote(body.substring(0, arrow.start)),
        translation: _unquote(body.substring(arrow.end)),
      );
  }
}

String _cleanBody(String raw) {
  var s = raw.replaceFirst(RegExp(r'^[ \t]*[:：)\]-]?[ \t]*'), '');
  // A blank line ends the piece: what follows is the chat talking.
  final blank = RegExp(r'\n[ \t]*\n').firstMatch(s.trimLeft());
  if (blank != null) s = s.trimLeft().substring(0, blank.start);
  s = s.split('\n').map((l) => l.trim().replaceFirst(RegExp(r'^[>•]\s*'), '')).where((l) => l.isNotEmpty).join(' ');
  s = s.replaceAll(RegExp(r'^\*\*|\*\*$'), '').trim();
  return _unquote(s);
}

const _quotes = {'"': '"', '“': '”', '«': '»', '„': '“', '「': '」', '『': '』'};

/// Takes off quotes around all of [s] (chats like to add them).
String _unquote(String s) {
  final t = s.trim();
  if (t.length >= 2) {
    final close = _quotes[t[0]];
    if (close != null && t.endsWith(close) && !t.substring(1, t.length - 1).contains(close)) {
      return t.substring(1, t.length - 1).trim();
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
