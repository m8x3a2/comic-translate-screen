/// "Export text" (the owner's idea): the dialogues of the chosen pages as
/// plain text, the originals and/or the translations, to keep or to give a
/// chat as context. The labels are the ones of the exchange, so the lines
/// match `ALL.txt`.
library;

import 'exchange_answer.dart';
import 'exchange_files.dart';

/// Which texts are written; [both] makes two files.
enum TextExportPart {
  original,
  translation,
  both;

  bool get hasOriginal => this != translation;
  bool get hasTranslation => this != original;

  static TextExportPart parse(String? name) => values.firstWhere((v) => v.name == name, orElse: () => both);
}

/// `{n}` in the heading of a page: its number; `{name}`: its file name.
const textExportPageNumber = '{n}';
const textExportPageName = '{name}';

/// The choices of the Export text window, remembered for next time.
class TextExportOptions {
  const TextExportOptions({
    this.part = TextExportPart.both,
    this.labels = true,
    this.headings = true,
    this.speakers = true,
    this.heading = '',
  });

  final TextExportPart part;

  /// `[01-003]` before each line; without them bubbles with no text are
  /// left out.
  final bool labels;

  /// A heading before each page.
  final bool headings;

  /// `[f]` before the lines of bubbles whose speaker was told.
  final bool speakers;

  /// The heading of a page with [textExportPageNumber]; empty: the one of the
  /// interface language.
  final String heading;

  TextExportOptions copyWith({TextExportPart? part, bool? labels, bool? headings, bool? speakers, String? heading}) =>
      TextExportOptions(
        part: part ?? this.part,
        labels: labels ?? this.labels,
        headings: headings ?? this.headings,
        speakers: speakers ?? this.speakers,
        heading: heading ?? this.heading,
      );

  Map<String, Object?> toJson() => {
    'part': part.name,
    'labels': labels,
    'headings': headings,
    'speakers': speakers,
    'heading': heading,
  };

  factory TextExportOptions.fromJson(Object? json) {
    if (json is! Map) return const TextExportOptions();
    const d = TextExportOptions();
    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    return TextExportOptions(
      part: TextExportPart.parse(json['part'] as String?),
      labels: flag('labels', d.labels),
      headings: flag('headings', d.headings),
      speakers: flag('speakers', d.speakers),
      heading: json['heading'] is String ? json['heading'] as String : '',
    );
  }
}

/// The text of [pages]: their translations when [translation], else their
/// originals. [heading] is the heading of a page with [textExportPageNumber]
/// and [textExportPageName] in it (used when [TextExportOptions.headings]).
String exportedText(
  List<ExchangePage> pages, {
  required bool translation,
  required TextExportOptions options,
  required String heading,
}) {
  final parts = <String>[];
  for (final page in pages) {
    final lines = [
      if (options.headings)
        heading.replaceAll(textExportPageNumber, '${page.number}').replaceAll(textExportPageName, page.name).trim(),
    ];
    for (final (i, b) in page.blocks.indexed) {
      final text = _oneLine(translation ? b.translation : b.text);
      if (text.isEmpty && !options.labels) continue;
      final tag = options.speakers && b.speaker != null ? '[${b.speaker!.tag}] ' : '';
      final label = options.labels ? '${ExchangeLabel(page.number, i + 1)} ' : '';
      lines.add('$label$tag$text'.trim());
    }
    if (lines.isNotEmpty) parts.add(lines.join('\n'));
  }
  return '${parts.join('\n\n')}\n';
}

/// The name of the file of the originals or the translations for [base]
/// (the project's name).
String textExportName(String base, {required bool translation}) =>
    '${base}_${translation ? 'translation' : 'original'}.txt';

String _oneLine(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
