/// Settings of the exchange with a chat AI (ChatGPT, Gemini, Claude…): the
/// user sends cut-outs of the text to a chat by hand and pastes its answer
/// back. New in this project.
library;

import 'glossary.dart';
import 'text_export.dart';

/// What the chat is asked to do.
/// Between the original and the translation in the chat's answer, unless
/// the user chose another one.
const defaultExchangeSeparator = '-->';

/// Taken off around all of an original or a translation in the chat's
/// answer by default: bold and quotes (chats like to add them). Each closes
/// with its own pair (see `closingMark`): `«` with `»`.
const defaultAnswerMarks = ['**', '"', '«', '“', '„', '「', '『'];

enum ExchangeMode {
  /// Write down the text of each piece.
  recognize,

  /// Translate text the app already has.
  translate,

  /// Both in one message: `[01-003] original --> translation`.
  both;

  /// The chat looks at pictures (not only at text).
  bool get sendsImages => this != translate;

  static ExchangeMode parse(String? name) => values.firstWhere((m) => m.name == name, orElse: () => both);
}

/// How the cut-outs are put on sheets.
enum SheetGrouping {
  /// As many as fit on a sheet of [ExchangeSettings.sheetMaxPx].
  size,

  /// [ExchangeSettings.perSheet] on each sheet (fewer when they do not fit).
  count;

  static SheetGrouping parse(String? name) => values.firstWhere((g) => g.name == name, orElse: () => size);
}

/// Where the picture of the whole page goes (it helps the chat understand
/// who speaks and what happens).
enum ContextImage {
  off,

  /// A picture of its own next to the sheets.
  separate,

  /// On the sheet, before the cut-outs of the page.
  onSheet;

  static ContextImage parse(String? name) => values.firstWhere((c) => c.name == name, orElse: () => off);
}

/// Which pictures are written to the exchange folder.
enum ExchangeImages {
  sheets,

  /// One file per piece (`01-003.png`), in folders of
  /// [ExchangeSettings.cropsPerFolder].
  crops,
  both;

  bool get hasSheets => this != crops;
  bool get hasCrops => this != sheets;

  static ExchangeImages parse(String? name) => values.firstWhere((i) => i.name == name, orElse: () => sheets);
}

/// Which text files are written: `ALL.txt`, one file per page, or both.
enum ExchangeTextFiles {
  all,
  pages,
  both;

  bool get hasAll => this != pages;
  bool get hasPages => this != all;

  static ExchangeTextFiles parse(String? name) => values.firstWhere((t) => t.name == name, orElse: () => all);
}

class ExchangeSettings {
  const ExchangeSettings({
    this.together = true,
    this.apart = false,
    this.grouping = SheetGrouping.size,
    this.perSheet = 8,
    this.sheetMaxPx = 1600,
    this.sheetPerPage = false,
    this.partPages = 0,
    this.contextImage = ContextImage.off,
    this.images = ExchangeImages.sheets,
    this.cropsPerFolder = 10,
    this.textFiles = ExchangeTextFiles.all,
    this.splitFiles = true,
    this.separator = defaultExchangeSeparator,
    this.answerMarks = defaultAnswerMarks,
    this.placeholder = '',
    this.prompts = const {},
    this.presets = const {},
    this.answerFromClipboard = false,
    this.sharedTexts = true,
    this.ownStyles = const [],
    this.activeStyles = const [],
    this.textExport = const TextExportOptions(),
  });

  static const minSheetPx = 600;
  static const maxSheetPx = 4096;

  /// When both reading and translating go through the chat: one message
  /// for both (else reading first, then translating).
  final bool together;

  /// Reading and translating in one message: the chat writes the originals
  /// and the translations as two lists (two answer fields) instead of
  /// `original --> translation` on each line.
  final bool apart;
  final SheetGrouping grouping;
  final int perSheet;

  /// Longest side of a sheet. Chats shrink larger pictures, and small
  /// letters become unreadable.
  final int sheetMaxPx;

  /// Each page starts a new sheet.
  final bool sheetPerPage;

  /// The exchange window shows this many pages at a time, one part after
  /// another ("Next"); 0: all pages at once.
  final int partPages;
  final ContextImage contextImage;
  final ExchangeImages images;
  final int cropsPerFolder;
  final ExchangeTextFiles textFiles;

  /// The original and the translation in two more files
  /// (`ALL_original.txt`, `ALL_translation.txt`) besides `ALL.txt`.
  final bool splitFiles;

  /// Between the original and the translation in the chat's answer.
  final String separator;

  /// Taken off around all of an original or a translation of the answer.
  final List<String> answerMarks;

  /// Put into pieces the answer has nothing for; empty leaves them as they
  /// are.
  final String placeholder;

  /// The user's own instructions for the chat; missing or empty = the
  /// built-in ones.
  final Map<ExchangePrompt, String> prompts;

  /// Instructions of the user's own kept under names, for each kind; the
  /// one in use is in [prompts] (see [activePreset]).
  final Map<ExchangePrompt, List<PromptPreset>> presets;

  /// Back in the exchange window with an answer of the chat in the clipboard
  /// (lines with labels): offer to paste it.
  final bool answerFromClipboard;

  /// What the user wrote into the text files stays when the mode changes
  /// (one set of files for every mode); off: each mode starts from fresh
  /// templates.
  final bool sharedTexts;

  /// Styles of translation the user wrote (ids `own_1`, …).
  final List<PromptStyle> ownStyles;

  /// The styles the instructions ask for (ids of built-in and own ones).
  final List<String> activeStyles;

  /// The choices of the Export text window.
  final TextExportOptions textExport;

  /// Built-in and own styles.
  List<PromptStyle> get allStyles => [...builtInPromptStyles, ...ownStyles];

  /// The styles asked for, in the order of [allStyles].
  List<PromptStyle> get chosenStyles => [
    for (final s in allStyles)
      if (activeStyles.contains(s.id)) s,
  ];

  /// The instructions [mode] uses with these settings.
  ExchangePrompt promptKind(ExchangeMode mode) => ExchangePrompt.of(mode, apart: apart);

  /// The user's own instructions for [kind] ('' = the built-in ones).
  String promptFor(ExchangePrompt kind) => prompts[kind] ?? '';

  /// The presets of [kind], in the order they were saved.
  List<PromptPreset> presetsFor(ExchangePrompt kind) => presets[kind] ?? const [];

  /// The preset of [kind] in use (the instructions are its text); null: the
  /// built-in instructions, or own ones not saved under a name.
  PromptPreset? activePreset(ExchangePrompt kind) {
    final now = promptFor(kind).trim();
    if (now.isEmpty) return null;
    return presetsFor(kind).where((p) => p.text.trim() == now).firstOrNull;
  }

  /// [copyWith] with [preset] kept for [kind] (one of the same name is
  /// replaced) and in use.
  ExchangeSettings withPreset(ExchangePrompt kind, PromptPreset preset) => copyWith(
    presets: {
      ...presets,
      kind: [
        for (final p in presetsFor(kind))
          if (p.name != preset.name) p,
        preset,
      ],
    },
  ).withPrompt(kind, preset.text);

  /// [copyWith] without the preset [name] of [kind] (the instructions in use
  /// stay as they are).
  ExchangeSettings withoutPreset(ExchangePrompt kind, String name) => copyWith(
    presets: {
      ...presets,
      kind: [
        for (final p in presetsFor(kind))
          if (p.name != name) p,
      ],
    },
  );

  ExchangeSettings copyWith({
    bool? together,
    bool? apart,
    SheetGrouping? grouping,
    int? perSheet,
    int? sheetMaxPx,
    bool? sheetPerPage,
    int? partPages,
    ContextImage? contextImage,
    ExchangeImages? images,
    int? cropsPerFolder,
    ExchangeTextFiles? textFiles,
    bool? splitFiles,
    String? separator,
    List<String>? answerMarks,
    String? placeholder,
    Map<ExchangePrompt, String>? prompts,
    Map<ExchangePrompt, List<PromptPreset>>? presets,
    bool? answerFromClipboard,
    bool? sharedTexts,
    List<PromptStyle>? ownStyles,
    List<String>? activeStyles,
    TextExportOptions? textExport,
  }) => ExchangeSettings(
    together: together ?? this.together,
    apart: apart ?? this.apart,
    grouping: grouping ?? this.grouping,
    perSheet: perSheet ?? this.perSheet,
    sheetMaxPx: sheetMaxPx ?? this.sheetMaxPx,
    sheetPerPage: sheetPerPage ?? this.sheetPerPage,
    partPages: partPages ?? this.partPages,
    contextImage: contextImage ?? this.contextImage,
    images: images ?? this.images,
    cropsPerFolder: cropsPerFolder ?? this.cropsPerFolder,
    textFiles: textFiles ?? this.textFiles,
    splitFiles: splitFiles ?? this.splitFiles,
    separator: separator ?? this.separator,
    answerMarks: answerMarks ?? this.answerMarks,
    placeholder: placeholder ?? this.placeholder,
    prompts: prompts ?? this.prompts,
    presets: presets ?? this.presets,
    answerFromClipboard: answerFromClipboard ?? this.answerFromClipboard,
    sharedTexts: sharedTexts ?? this.sharedTexts,
    ownStyles: ownStyles ?? this.ownStyles,
    activeStyles: activeStyles ?? this.activeStyles,
    textExport: textExport ?? this.textExport,
  );

  /// [copyWith] for the user's own instructions of [kind] ('' = back to the
  /// built-in ones).
  ExchangeSettings withPrompt(ExchangePrompt kind, String prompt) => copyWith(
    prompts: {
      for (final e in prompts.entries)
        if (e.key != kind) e.key: e.value,
      if (prompt.trim().isNotEmpty) kind: prompt,
    },
  );

  Map<String, Object?> toJson() => {
    'together': together,
    'apart': apart,
    'grouping': grouping.name,
    'per_sheet': perSheet,
    'sheet_max_px': sheetMaxPx,
    'sheet_per_page': sheetPerPage,
    'part_pages': partPages,
    'context_image': contextImage.name,
    'images': images.name,
    'crops_per_folder': cropsPerFolder,
    'text_files': textFiles.name,
    'split_files_too': splitFiles,
    'separator': separator,
    'answer_marks': answerMarks,
    'placeholder': placeholder,
    for (final kind in ExchangePrompt.values) kind.key: promptFor(kind),
    'prompt_presets': {
      for (final e in presets.entries)
        if (e.value.isNotEmpty) e.key.key: [for (final p in e.value) p.toJson()],
    },
    'answer_from_clipboard': answerFromClipboard,
    'shared_texts': sharedTexts,
    'own_styles': [for (final s in ownStyles) s.toJson()],
    'active_styles': activeStyles,
    'text_export': textExport.toJson(),
  };

  factory ExchangeSettings.fromJson(Map<String, Object?> json) {
    const d = ExchangeSettings();
    int number(String key, int fallback, int min, int max) {
      final v = json[key];
      return v is num ? v.toInt().clamp(min, max) : fallback;
    }

    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    String text(String key) => json[key] is String ? json[key] as String : '';
    return ExchangeSettings(
      together: flag('together', d.together),
      apart: flag('apart', d.apart),
      grouping: SheetGrouping.parse(json['grouping'] as String?),
      perSheet: number('per_sheet', d.perSheet, 1, 200),
      sheetMaxPx: number('sheet_max_px', d.sheetMaxPx, minSheetPx, maxSheetPx),
      sheetPerPage: flag('sheet_per_page', d.sheetPerPage),
      partPages: number('part_pages', d.partPages, 0, 100),
      contextImage: ContextImage.parse(json['context_image'] as String?),
      images: ExchangeImages.parse(json['images'] as String?),
      cropsPerFolder: number('crops_per_folder', d.cropsPerFolder, 1, 1000),
      textFiles: ExchangeTextFiles.parse(json['text_files'] as String?),
      splitFiles: flag('split_files_too', d.splitFiles),
      separator: text('separator').trim().isEmpty ? d.separator : text('separator').trim(),
      answerMarks: json['answer_marks'] is List
          ? [
              for (final m in (json['answer_marks'] as List).whereType<String>())
                if (m.trim().isNotEmpty && m.trim() != '*') m.trim(),
            ]
          : d.answerMarks,
      placeholder: text('placeholder'),
      answerFromClipboard: flag('answer_from_clipboard', d.answerFromClipboard),
      sharedTexts: flag('shared_texts', d.sharedTexts),
      ownStyles: [
        for (final s in (json['own_styles'] is List ? json['own_styles'] as List : const [])) ?PromptStyle.fromJson(s),
      ],
      activeStyles: [...(json['active_styles'] is List ? json['active_styles'] as List : const []).whereType<String>()],
      textExport: TextExportOptions.fromJson(json['text_export']),
      prompts: {
        for (final kind in ExchangePrompt.values)
          if (text(kind.key).trim().isNotEmpty) kind: text(kind.key),
      },
      presets: {
        if (json['prompt_presets'] case final Map<Object?, Object?> all)
          for (final kind in ExchangePrompt.values)
            if (all[kind.key] case final List<Object?> list) kind: [for (final p in list) ?PromptPreset.fromJson(p)],
      },
    );
  }
}

/// Instructions of the user's own kept under a name, to pick from.
class PromptPreset {
  const PromptPreset(this.name, this.text);

  final String name;
  final String text;

  Map<String, Object?> toJson() => {'name': name, 'text': text};

  static PromptPreset? fromJson(Object? json) => switch (json) {
    {'name': final String name, 'text': final String text} when name.trim().isNotEmpty => PromptPreset(
      name.trim(),
      text,
    ),
    _ => null,
  };
}

/// The instructions for the chat: one per mode, and reading with
/// translating as two lists.
enum ExchangePrompt {
  recognize('prompt_recognize'),
  translate('prompt_translate'),
  both('prompt_both'),
  bothApart('prompt_both_apart');

  const ExchangePrompt(this.key);

  /// Its key in the settings.
  final String key;

  static ExchangePrompt of(ExchangeMode mode, {bool apart = false}) => switch (mode) {
    ExchangeMode.recognize => recognize,
    ExchangeMode.translate => translate,
    ExchangeMode.both => apart ? bothApart : both,
  };
}
