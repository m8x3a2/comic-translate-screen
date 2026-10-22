/// Settings of the exchange with a chat AI (ChatGPT, Gemini, Claude…): the
/// user sends cut-outs of the text to a chat by hand and pastes its answer
/// back. New in this project.
library;

/// What the chat is asked to do.
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
    this.grouping = SheetGrouping.size,
    this.perSheet = 8,
    this.sheetMaxPx = 1600,
    this.sheetPerPage = false,
    this.contextImage = ContextImage.off,
    this.images = ExchangeImages.sheets,
    this.cropsPerFolder = 10,
    this.textFiles = ExchangeTextFiles.all,
    this.placeholder = '',
    this.promptRecognize = '',
    this.promptTranslate = '',
    this.promptBoth = '',
  });

  static const minSheetPx = 600;
  static const maxSheetPx = 4096;

  /// When both reading and translating go through the chat: one message
  /// for both (else reading first, then translating).
  final bool together;
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

  /// Put into pieces the answer has nothing for; empty leaves them as they
  /// are.
  final String placeholder;

  /// The user's own instructions for the chat; empty = the built-in ones.
  final String promptRecognize;
  final String promptTranslate;
  final String promptBoth;

  String promptFor(ExchangeMode mode) => switch (mode) {
    ExchangeMode.recognize => promptRecognize,
    ExchangeMode.translate => promptTranslate,
    ExchangeMode.both => promptBoth,
  };

  ExchangeSettings copyWith({
    bool? together,
    SheetGrouping? grouping,
    int? perSheet,
    int? sheetMaxPx,
    bool? sheetPerPage,
    ContextImage? contextImage,
    ExchangeImages? images,
    int? cropsPerFolder,
    ExchangeTextFiles? textFiles,
    String? placeholder,
    String? promptRecognize,
    String? promptTranslate,
    String? promptBoth,
  }) => ExchangeSettings(
    together: together ?? this.together,
    grouping: grouping ?? this.grouping,
    perSheet: perSheet ?? this.perSheet,
    sheetMaxPx: sheetMaxPx ?? this.sheetMaxPx,
    sheetPerPage: sheetPerPage ?? this.sheetPerPage,
    contextImage: contextImage ?? this.contextImage,
    images: images ?? this.images,
    cropsPerFolder: cropsPerFolder ?? this.cropsPerFolder,
    textFiles: textFiles ?? this.textFiles,
    placeholder: placeholder ?? this.placeholder,
    promptRecognize: promptRecognize ?? this.promptRecognize,
    promptTranslate: promptTranslate ?? this.promptTranslate,
    promptBoth: promptBoth ?? this.promptBoth,
  );

  /// [copyWith] for the prompt of [mode].
  ExchangeSettings withPrompt(ExchangeMode mode, String prompt) => switch (mode) {
    ExchangeMode.recognize => copyWith(promptRecognize: prompt),
    ExchangeMode.translate => copyWith(promptTranslate: prompt),
    ExchangeMode.both => copyWith(promptBoth: prompt),
  };

  Map<String, Object?> toJson() => {
    'together': together,
    'grouping': grouping.name,
    'per_sheet': perSheet,
    'sheet_max_px': sheetMaxPx,
    'sheet_per_page': sheetPerPage,
    'context_image': contextImage.name,
    'images': images.name,
    'crops_per_folder': cropsPerFolder,
    'text_files': textFiles.name,
    'placeholder': placeholder,
    'prompt_recognize': promptRecognize,
    'prompt_translate': promptTranslate,
    'prompt_both': promptBoth,
  };

  factory ExchangeSettings.fromJson(Map<String, Object?> json) {
    const d = ExchangeSettings();
    int number(String key, int fallback, int min, int max) {
      final v = json[key];
      return v is num ? v.toInt().clamp(min, max) : fallback;
    }

    String text(String key) => json[key] is String ? json[key] as String : '';
    return ExchangeSettings(
      together: json['together'] is bool ? json['together'] as bool : d.together,
      grouping: SheetGrouping.parse(json['grouping'] as String?),
      perSheet: number('per_sheet', d.perSheet, 1, 200),
      sheetMaxPx: number('sheet_max_px', d.sheetMaxPx, minSheetPx, maxSheetPx),
      sheetPerPage: json['sheet_per_page'] is bool ? json['sheet_per_page'] as bool : d.sheetPerPage,
      contextImage: ContextImage.parse(json['context_image'] as String?),
      images: ExchangeImages.parse(json['images'] as String?),
      cropsPerFolder: number('crops_per_folder', d.cropsPerFolder, 1, 1000),
      textFiles: ExchangeTextFiles.parse(json['text_files'] as String?),
      placeholder: text('placeholder'),
      promptRecognize: text('prompt_recognize'),
      promptTranslate: text('prompt_translate'),
      promptBoth: text('prompt_both'),
    );
  }
}
