/// "Load text" (the owner's idea, the pair of "Export text"): a chat's
/// answer to the exported text, or a text file, goes back into the bubbles
/// by its labels `[02-003]`. Only text, no sheets and no exchange folder:
/// good for any chat, also for free models that take no pictures.
library;

import '../model/text_block.dart';
import '../translation/llm_protocol.dart' show hasTranslatableContent;
import 'exchange_answer.dart';
import 'exchange_files.dart';
import 'exchange_settings.dart';
import 'text_export.dart';

/// Where the loaded lines go.
enum TextImportTarget {
  /// Into the translations; `original --> translation` fills both.
  translation,

  /// Into the recognised text (a corrected original); with an arrow the
  /// translation too.
  original;

  /// How the answer is read and written.
  ExchangeMode get mode => this == translation ? ExchangeMode.both : ExchangeMode.recognize;

  static TextImportTarget parse(String? name) => values.firstWhere((v) => v.name == name, orElse: () => translation);
}

/// One bubble the loaded text changes.
class TextImportChange {
  const TextImportChange({required this.label, required this.pageId, required this.before, required this.after});

  final ExchangeLabel label;
  final String pageId;

  /// The bubble now and with the loaded text.
  final TextBlock before;
  final TextBlock after;
}

/// What a loaded text gives for the pages.
class TextImport {
  const TextImport({
    required this.items,
    required this.match,
    required this.changes,
    required this.missing,
    required this.labelsFound,
  });

  /// Every bubble of the pages, by its label.
  final List<ExchangeItem> items;

  /// The answers (lines with nothing after the label are no answer).
  final ExchangeMatch match;

  /// Bubbles that would change, in the order of the pages.
  final List<TextImportChange> changes;

  /// Bubbles with text (with any text for the original) the loaded text has
  /// nothing for: they stay as they are.
  final List<ExchangeLabel> missing;

  /// Whether the text had any label at all (else: export with labels).
  final bool labelsFound;

  /// Labels of the text with no such bubble.
  List<ExchangeLabel> get unknown => match.unknown;

  int get answered => match.replies.length;
}

/// Reads [text] (a chat's answer, a file) for [pages], all pages of the
/// project with their numbers. [heading] is the page heading of "Export
/// text" (with `{n}` / `{name}`): such lines are no part of a bubble, even
/// when a chat left out the blank line before them.
TextImport readTextImport(
  List<ExchangePage> pages,
  String text,
  TextImportTarget target, {
  String heading = '',
  String separator = defaultExchangeSeparator,
  List<String> marks = defaultAnswerMarks,
}) {
  final mode = target.mode;
  final parsed = parseExchangeAnswer(
    withoutPageHeadings(text.replaceAll('﻿', ''), heading),
    mode,
    separator: separator,
    marks: marks,
  );
  // A label with nothing after it (an empty bubble of the export, a line
  // the chat left empty) changes nothing.
  final answer = ExchangeAnswer({
    for (final e in parsed.replies.entries)
      if (!e.value.isEmpty || e.value.hasSpeaker) e.key: e.value,
  }, repeated: parsed.repeated);
  final items = exchangeItems(pages, ExchangeMode.recognize);
  final match = matchExchangeAnswer(items, answer, mode);
  final blocks = {for (final page in pages) page.id: page.blocks};
  final changes = <TextImportChange>[];
  final missing = <ExchangeLabel>[];
  for (final it in items) {
    final before = blocks[it.pageId]![it.blockIndex];
    final reply = match.replies[it.label];
    if (reply == null) {
      if (target == TextImportTarget.original || hasTranslatableContent(before.text)) missing.add(it.label);
      continue;
    }
    final after = before.copy();
    if (applyExchangeReply(after, reply, mode)) {
      changes.add(TextImportChange(label: it.label, pageId: it.pageId, before: before, after: after));
    }
  }
  return TextImport(
    items: items,
    match: match,
    changes: changes,
    missing: missing,
    labelsFound: parsed.replies.isNotEmpty,
  );
}

/// [text] without page headings on lines of their own: the [heading] of
/// "Export text" and the usual `Page 3` / `Страница 3`, also in bold or as
/// a markdown heading.
String withoutPageHeadings(String text, String heading) {
  final own = _headingPattern(heading);
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  return lines
      .where((line) {
        final core = line.trim().replaceAll(_wrappers, '');
        if (core.isEmpty) return true;
        return !(_usualHeading.hasMatch(core) ||
            (own?.hasMatch(line.trim()) ?? false) ||
            (own?.hasMatch(core) ?? false));
      })
      .join('\n');
}

/// Markdown around a heading: `## `, `**`, `__`, a closing colon.
final _wrappers = RegExp(r'^[#*_>\s]+|[*_:\s]+$');

final _usualHeading = RegExp(r'^(?:page|pg\.?|p\.|страница|стр\.?)\s*\d{1,4}$', caseSensitive: false);

/// The user's heading with `{n}` as a number and `{name}` as any text.
RegExp? _headingPattern(String heading) {
  final h = heading.trim();
  if (h.isEmpty) return null;
  final body = h.splitMapJoin(
    RegExp('${RegExp.escape(textExportPageNumber)}|${RegExp.escape(textExportPageName)}'),
    onMatch: (m) => m[0] == textExportPageNumber ? r'\d{1,4}' : r'.+',
    onNonMatch: (s) => RegExp.escape(s).replaceAll(RegExp(r'\s+'), r'\s*'),
  );
  return RegExp('^$body\$', caseSensitive: false);
}

/// The request put before the exported text by "Copy with a request to
/// translate": in English, which every chat understands.
String textTranslateRequest(String targetLanguage) =>
    'Translate the lines below into $targetLanguage. Keep the label at the start of each line as it is (the '
    'page and bubble numbers in square brackets), one line per label, in the same order. Keep the tags [m], '
    '[f], [n] after a label. Write only the translated lines, nothing else.';
