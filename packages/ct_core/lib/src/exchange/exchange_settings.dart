/// Settings of the exchange with a chat AI (ChatGPT, Gemini, Claude…): the
/// user sends cut-outs of the text to a chat by hand and pastes its answer
/// back. New in this project.
library;

/// What the chat is asked to do.
/// Between the original and the translation in the chat's answer, unless
/// the user chose another one.
const defaultExchangeSeparator = '-->';

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
    this.contextImage = ContextImage.off,
    this.images = ExchangeImages.sheets,
    this.cropsPerFolder = 10,
    this.textFiles = ExchangeTextFiles.all,
    this.splitFiles = true,
    this.separator = defaultExchangeSeparator,
    this.placeholder = '',
    this.prompts = const {},
    this.answerFromClipboard = false,
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
  final ContextImage contextImage;
  final ExchangeImages images;
  final int cropsPerFolder;
  final ExchangeTextFiles textFiles;

  /// The original and the translation in two more files
  /// (`ALL_original.txt`, `ALL_translation.txt`) besides `ALL.txt`.
  final bool splitFiles;

  /// Between the original and the translation in the chat's answer.
  final String separator;

  /// Put into pieces the answer has nothing for; empty leaves them as they
  /// are.
  final String placeholder;

  /// The user's own instructions for the chat; missing or empty = the
  /// built-in ones.
  final Map<ExchangePrompt, String> prompts;

  /// Back in the exchange window with an answer of the chat in the clipboard
  /// (lines with labels): offer to paste it.
  final bool answerFromClipboard;

  /// The instructions [mode] uses with these settings.
  ExchangePrompt promptKind(ExchangeMode mode) => ExchangePrompt.of(mode, apart: apart);

  /// The user's own instructions for [kind] ('' = the built-in ones).
  String promptFor(ExchangePrompt kind) => prompts[kind] ?? '';

  ExchangeSettings copyWith({
    bool? together,
    bool? apart,
    SheetGrouping? grouping,
    int? perSheet,
    int? sheetMaxPx,
    bool? sheetPerPage,
    ContextImage? contextImage,
    ExchangeImages? images,
    int? cropsPerFolder,
    ExchangeTextFiles? textFiles,
    bool? splitFiles,
    String? separator,
    String? placeholder,
    Map<ExchangePrompt, String>? prompts,
    bool? answerFromClipboard,
  }) => ExchangeSettings(
    together: together ?? this.together,
    apart: apart ?? this.apart,
    grouping: grouping ?? this.grouping,
    perSheet: perSheet ?? this.perSheet,
    sheetMaxPx: sheetMaxPx ?? this.sheetMaxPx,
    sheetPerPage: sheetPerPage ?? this.sheetPerPage,
    contextImage: contextImage ?? this.contextImage,
    images: images ?? this.images,
    cropsPerFolder: cropsPerFolder ?? this.cropsPerFolder,
    textFiles: textFiles ?? this.textFiles,
    splitFiles: splitFiles ?? this.splitFiles,
    separator: separator ?? this.separator,
    placeholder: placeholder ?? this.placeholder,
    prompts: prompts ?? this.prompts,
    answerFromClipboard: answerFromClipboard ?? this.answerFromClipboard,
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
    'context_image': contextImage.name,
    'images': images.name,
    'crops_per_folder': cropsPerFolder,
    'text_files': textFiles.name,
    'split_files_too': splitFiles,
    'separator': separator,
    'placeholder': placeholder,
    for (final kind in ExchangePrompt.values) kind.key: promptFor(kind),
    'answer_from_clipboard': answerFromClipboard,
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
      contextImage: ContextImage.parse(json['context_image'] as String?),
      images: ExchangeImages.parse(json['images'] as String?),
      cropsPerFolder: number('crops_per_folder', d.cropsPerFolder, 1, 1000),
      textFiles: ExchangeTextFiles.parse(json['text_files'] as String?),
      splitFiles: flag('split_files_too', d.splitFiles),
      separator: text('separator').trim().isEmpty ? d.separator : text('separator').trim(),
      placeholder: text('placeholder'),
      answerFromClipboard: flag('answer_from_clipboard', d.answerFromClipboard),
      prompts: {
        for (final kind in ExchangePrompt.values)
          if (text(kind.key).trim().isNotEmpty) kind: text(kind.key),
      },
    );
  }
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
