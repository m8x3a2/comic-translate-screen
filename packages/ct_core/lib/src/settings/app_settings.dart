import '../export/export_pages.dart';
import '../exchange/exchange_settings.dart';
import '../ocr/text_prep.dart';
import '../export/strip_export.dart';
import '../inpainting/clean_level.dart';
import '../plugins/engines.dart';
import '../render/layout.dart';
import '../render/text_case.dart';
import '../render/upscale.dart';

/// What the pages are: each kind finds text its own way.
enum ContentKind {
  /// Comics, manga, webtoons: speech bubbles and captions.
  comics,

  /// Screenshots of sites, games and visual novels: lines of ordinary text.
  screens,
}

/// User settings stored in `settings.json` (never secrets).
///
/// Defaults follow the original application (`app/ui/settings/settings_page.py`).
/// Unknown keys are kept in [extra] so that newer files survive a round trip
/// through an older build.
class AppSettings {
  AppSettings({
    this.detector = 'rtdetr_v2',
    this.contentKind = ContentKind.comics,
    this.screenDetector = 'ppocr_lines',
    this.ocr = 'default',
    this.translator = 'openai_compatible',
    this.inpainter = 'lama',
    this.textMask = comicTextDetectorId,
    this.useGpu = false,
    this.textPrep = 'fatality_comix',
    this.screenTextPrep = 'plain_x1_5',
    this.fixCyrillicLookalikes = false,
    this.splitGluedWords = false,
    this.checkLines = true,
    this.textPrepSeconds = 60,
    this.inpaint = const InpaintConfig(),
    this.sourceLanguage = 'English',
    this.targetLanguage = 'Russian',
    this.extraContext = '',
    this.sendPageImage = false,
    this.render = const RenderSettings(),
    this.upscale = const UpscaleSettings(),
    this.export = const ExportSettings(),
    this.exchange = const ExchangeSettings(),
    this.modelsDir = '',
    this.theme = 'dark',
    this.uiLanguage = 'ru',
    Map<String, String>? shortcuts,
    Set<String>? hiddenPanels,
    Map<String, String>? gpuCpuModels,
    this.showLookInPanel = true,
    this.gridTileSize = 190,
    this.translateSelected = false,
    this.testMode = false,
    this.autoBugReport = true,
    this.projectAutosave = true,
    List<String>? recentProjects,
    Map<String, Map<String, Object?>>? plugins,
    Set<String>? approvedNetworkPlugins,
    Map<String, Object?>? extra,
  }) : shortcuts = shortcuts ?? {},
       hiddenPanels = hiddenPanels ?? {},
       gpuCpuModels = gpuCpuModels ?? {},
       recentProjects = recentProjects ?? [],
       plugins = plugins ?? {},
       approvedNetworkPlugins = approvedNetworkPlugins ?? {},
       extra = extra ?? {};

  static const schemaVersion = 1;

  /// Selected plugin ids.
  String detector;

  /// What is being translated: comics (speech bubbles, [detector]) or
  /// screens — sites, games, visual novels (lines of ordinary text,
  /// [screenDetector]). New in this project.
  ContentKind contentKind;
  String screenDetector;

  /// The detector of the current [contentKind].
  String get activeDetector => contentKind == ContentKind.screens ? screenDetector : detector;
  String ocr;
  String translator;
  String inpainter;

  /// The `TextMasker` that finds the letters for the inpainting network, or
  /// '' for the original's mask alone. Together with [inpainter] it makes
  /// the cleaning level (see `clean_level.dart`). New in this project.
  String textMask;

  bool useGpu;

  /// Models that failed on this computer's graphics card: model file name
  /// → why. With the GPU on they open on the processor right away. Cleared
  /// by "Try again" in the settings.
  Map<String, String> gpuCpuModels;

  /// How small text is prepared for reading (`TextUpscaler` plugin ids):
  /// for comics and for screens. New in this project (step 2 of the plan:
  /// a neural network for comics, plain ×1.5 for sharp screen fonts).
  String textPrep;
  String screenTextPrep;

  /// The text preparation of the current [contentKind].
  String get activeTextPrep => contentKind == ContentKind.screens ? screenTextPrep : textPrep;

  /// For Cyrillic source languages, replace Latin look-alike letters that OCR
  /// returns in Cyrillic text ("HET" → "НЕТ"). Off by default: Latin words in
  /// the comic (signs, "OK") would become Cyrillic too. New in this project.
  bool fixCyrillicLookalikes;

  /// After OCR, split English words the recognizer glued together
  /// ("REALLIFE" → "REAL LIFE", see `glued_words.dart`). Off by default: the
  /// button in the text panel does it on demand. New in this project.
  bool splitGluedWords;

  /// Before OCR, check the lines the heuristics split comic blocks into and
  /// let the PP-OCR line detector redo the wrong ones (see `line_check.dart`).
  /// New in this project.
  bool checkLines;

  /// Lines are checked on these pages: [checkLines] is on and the pages are
  /// comics (the line detector of "Sites and games" finds exact lines).
  bool get checksLines => checkLines && contentKind == ContentKind.comics;

  /// Time a neural text preparation may spend on one page (seconds; 0: no
  /// limit), see `readingNeuralBudgetMs`. New in this project.
  int textPrepSeconds;
  InpaintConfig inpaint;

  /// Default languages for new pages (canonical English names).
  String sourceLanguage;
  String targetLanguage;

  /// Extra context about the comic sent to LLM translators.
  String extraContext;

  /// Send the page image to translators that accept it (off by default,
  /// as in the original).
  bool sendPageImage;

  /// Text rendering (font, sizes, colours, outline...), defaults of the
  /// original.
  RenderSettings render;

  /// Letter case of the drawn translations (the original has one switch,
  /// "Render text in upper case"; see [TextCase]).
  TextCase get textCase => render.textCase;
  set textCase(TextCase value) => render = render.copyWith(textCase: value);

  /// Enlarging small pages before the translation is drawn, so the letters
  /// stay readable. New in this project.
  UpscaleSettings upscale;

  /// Saving results (GUI export and the automatic export after a batch run).
  ExportSettings export;

  /// The exchange with a chat AI by hand (new in this project).
  ExchangeSettings exchange;

  /// Folder with downloaded models; empty = `models` in the data folder.
  String modelsDir;

  /// `dark`, `light` or `system`.
  String theme;
  String uiLanguage;

  /// Keyboard shortcuts changed by the user: action id → key combination
  /// (`Ctrl+Shift+S`; empty: no key). Actions not listed keep their
  /// default keys.
  Map<String, String> shortcuts;

  /// Editor panels folded away by the user (`pages`, `tools`, `text`).
  Set<String> hiddenPanels;

  /// The text panel shows the look of styled words (bold, colour, size...);
  /// off: plain text. Not in the original.
  bool showLookInPanel;

  /// Width of a page in the grid of all pages (logical pixels).
  int gridTileSize;

  /// "Translate all" translates only the picked pages when some are picked
  /// (the choice under its arrow).
  bool translateSelected;

  /// Save per-stage artifacts for every run (see docs/DIAGNOSTICS.md).
  bool testMode;

  /// An unexpected error builds a bug report by itself (kept on this
  /// computer only; on by default).
  bool autoBugReport;

  /// A project that has a file saves itself shortly after every change (on
  /// by default; the original's project auto-save is off by default).
  bool projectAutosave;

  /// Recently opened or saved projects, most recent first.
  List<String> recentProjects;

  static const maxRecentProjects = 12;

  /// Non-secret settings of each plugin: plugin id → key → value.
  Map<String, Map<String, Object?>> plugins;

  /// Plugins that send data off the device and that the user has approved.
  Set<String> approvedNetworkPlugins;

  Map<String, Object?> extra;

  Map<String, Object?> pluginValues(String id) => plugins[id] ?? const {};

  Map<String, Object?> toJson() => {
    ...extra,
    'schema_version': schemaVersion,
    'tools': {
      'detector': detector,
      'content': contentKind.name,
      'screen_detector': screenDetector,
      'ocr': ocr,
      'translator': translator,
      'inpainter': inpainter,
      'text_mask': textMask,
      'use_gpu': useGpu,
      if (gpuCpuModels.isNotEmpty) 'gpu_cpu_models': gpuCpuModels,
      'text_prep': textPrep,
      'screen_text_prep': screenTextPrep,
      'fix_cyrillic_lookalikes': fixCyrillicLookalikes,
      'split_glued_words': splitGluedWords,
      'check_lines': checkLines,
      'text_prep_seconds': textPrepSeconds,
    },
    'inpaint': inpaint.toJson(),
    'languages': {'source': sourceLanguage, 'target': targetLanguage},
    'llm': {'extra_context': extraContext, 'send_page_image': sendPageImage},
    'render': render.toJson(),
    'upscale': upscale.toJson(),
    'export': export.toJson(),
    'exchange': exchange.toJson(),
    'models': {'dir': modelsDir},
    'ui': {
      'theme': theme,
      'language': uiLanguage,
      if (shortcuts.isNotEmpty) 'shortcuts': shortcuts,
      if (hiddenPanels.isNotEmpty) 'hidden_panels': [...hiddenPanels],
      if (!showLookInPanel) 'show_look_in_panel': false,
      if (gridTileSize != 190) 'grid_tile_size': gridTileSize,
      if (translateSelected) 'translate_selected': true,
    },
    'test_mode': testMode,
    'auto_bug_report': autoBugReport,
    'projects': {'autosave': projectAutosave, 'recent': recentProjects},
    'plugins': plugins,
    'approved_network_plugins': approvedNetworkPlugins.toList()..sort(),
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    Map<String, Object?> group(String key) => (json[key] as Map?)?.cast<String, Object?>() ?? const {};
    T pick<T>(Map<String, Object?> m, String key, T fallback) {
      final v = m[key];
      return v is T ? v : fallback;
    }

    final defaults = AppSettings();
    final tools = group('tools');
    final inpaint = group('inpaint');
    final languages = group('languages');
    final llm = group('llm');
    final ui = group('ui');
    final render = group('render');
    final upscale = group('upscale');
    final export = group('export');
    final exchange = group('exchange');
    final models = group('models');
    final projects = group('projects');
    const known = {
      'schema_version',
      'tools',
      'inpaint',
      'languages',
      'llm',
      'render',
      'upscale',
      'export',
      'exchange',
      'models',
      'ui',
      'test_mode',
      'auto_bug_report',
      'plugins', //
      'approved_network_plugins', 'projects',
    };
    // Before step 2.1 a switch turned the enlarging of small text off.
    final oldOff = tools['upscale_small_text'] == false;
    final strategyName = pick<String>(inpaint, 'strategy', defaults.inpaint.strategy.name);
    return AppSettings(
      detector: pick(tools, 'detector', defaults.detector),
      contentKind: ContentKind.values.asNameMap()[tools['content']] ?? defaults.contentKind,
      screenDetector: pick(tools, 'screen_detector', defaults.screenDetector),
      ocr: pick(tools, 'ocr', defaults.ocr),
      translator: pick(tools, 'translator', defaults.translator),
      // Files from before the cleaning levels (no text_mask) left on the old
      // default AOT get the new default level.
      inpainter: tools.containsKey('text_mask') || tools['inpainter'] != 'aot'
          ? pick(tools, 'inpainter', defaults.inpainter)
          : defaults.inpainter,
      textMask: pick(tools, 'text_mask', defaults.textMask),
      useGpu: pick(tools, 'use_gpu', defaults.useGpu),
      gpuCpuModels: {
        for (final e in ((tools['gpu_cpu_models'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      textPrep: pick(tools, 'text_prep', oldOff ? textPrepOffId : defaults.textPrep),
      screenTextPrep: pick(tools, 'screen_text_prep', oldOff ? textPrepOffId : defaults.screenTextPrep),
      fixCyrillicLookalikes: pick(tools, 'fix_cyrillic_lookalikes', defaults.fixCyrillicLookalikes),
      splitGluedWords: pick(tools, 'split_glued_words', defaults.splitGluedWords),
      checkLines: pick(tools, 'check_lines', defaults.checkLines),
      textPrepSeconds: pick(tools, 'text_prep_seconds', defaults.textPrepSeconds),
      inpaint: InpaintConfig(
        strategy: HdStrategy.values.firstWhere((s) => s.name == strategyName, orElse: () => HdStrategy.resize),
        resizeLimit: pick<num>(inpaint, 'resize_limit', defaults.inpaint.resizeLimit).toInt(),
        cropMargin: pick<num>(inpaint, 'crop_margin', defaults.inpaint.cropMargin).toInt(),
        cropTriggerSize: pick<num>(inpaint, 'crop_trigger_size', defaults.inpaint.cropTriggerSize).toInt(),
      ),
      sourceLanguage: pick(languages, 'source', defaults.sourceLanguage),
      targetLanguage: pick(languages, 'target', defaults.targetLanguage),
      extraContext: pick(llm, 'extra_context', defaults.extraContext),
      sendPageImage: pick(llm, 'send_page_image', defaults.sendPageImage),
      render: RenderSettings.fromJson(render),
      upscale: UpscaleSettings.fromJson(upscale),
      export: ExportSettings.fromJson(export),
      exchange: ExchangeSettings.fromJson(exchange),
      modelsDir: pick(models, 'dir', defaults.modelsDir),
      theme: pick(ui, 'theme', defaults.theme),
      uiLanguage: pick(ui, 'language', defaults.uiLanguage),
      shortcuts: {
        for (final e in ((ui['shortcuts'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      hiddenPanels: {...?(ui['hidden_panels'] as List?)?.whereType<String>()},
      showLookInPanel: ui['show_look_in_panel'] != false,
      gridTileSize: ((ui['grid_tile_size'] as num?)?.toInt() ?? 190).clamp(100, 400),
      translateSelected: ui['translate_selected'] == true,
      testMode: pick(json, 'test_mode', defaults.testMode),
      autoBugReport: pick(json, 'auto_bug_report', defaults.autoBugReport),
      projectAutosave: pick(projects, 'autosave', defaults.projectAutosave),
      recentProjects: [...?(projects['recent'] as List?)?.whereType<String>()],
      plugins: {
        for (final e in group('plugins').entries)
          if (e.value is Map) e.key: (e.value as Map).cast<String, Object?>(),
      },
      approvedNetworkPlugins: {...?(json['approved_network_plugins'] as List?)?.whereType<String>()},
      extra: {
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }
}

/// How results are saved. As in the original, a batch run can also save the
/// recognized text, the translations and the cleaned pages automatically, to
/// `comic_translate_<timestamp>` next to the input ([rawText],
/// [translatedText], [cleanedImage]). The other fields remember the last
/// choices of the Export window.
class ExportSettings {
  const ExportSettings({
    this.imageFormat = 'source',
    this.rawText = false,
    this.translatedText = false,
    this.cleanedImage = false,
    this.container = ExportContainer.folder,
    this.withTranslated = true,
    this.withCleaned = false,
    this.withRawText = false,
    this.withTranslatedText = false,
    this.byChapter = true,
    this.strip = StripExport.pages,
    this.sliceHeight = 1280,
  });

  static const formats = ['source', 'png', 'jpg', 'webp', 'psd'];

  /// `source` (same as the input page), `png`, `jpg`, `webp` or `psd`
  /// (layered Photoshop files, made by the app: see [ExportOptions.imageFormat]).
  final String imageFormat;
  final bool rawText;
  final bool translatedText;
  final bool cleanedImage;

  final ExportContainer container;
  final bool withTranslated;
  final bool withCleaned;
  final bool withRawText;
  final bool withTranslatedText;

  /// One file per chapter (source archive) when there are several.
  final bool byChapter;

  /// Webtoons: pages as they are, one picture, or cut again into parts of
  /// about [sliceHeight] rows.
  final StripExport strip;
  final int sliceHeight;

  bool get anyAutomatic => rawText || translatedText || cleanedImage;

  /// The Export window's choices.
  ExportOptions get options => ExportOptions(
    container: container,
    imageFormat: imageFormat,
    translated: withTranslated,
    cleaned: withCleaned,
    recognizedText: withRawText,
    translatedText: withTranslatedText,
    byChapter: byChapter,
    strip: strip,
    sliceHeight: sliceHeight,
  );

  ExportSettings copyWith({
    String? imageFormat,
    bool? rawText,
    bool? translatedText,
    bool? cleanedImage,
    ExportContainer? container,
    bool? withTranslated,
    bool? withCleaned,
    bool? withRawText,
    bool? withTranslatedText,
    bool? byChapter,
    StripExport? strip,
    int? sliceHeight,
  }) => ExportSettings(
    imageFormat: imageFormat ?? this.imageFormat,
    rawText: rawText ?? this.rawText,
    translatedText: translatedText ?? this.translatedText,
    cleanedImage: cleanedImage ?? this.cleanedImage,
    container: container ?? this.container,
    withTranslated: withTranslated ?? this.withTranslated,
    withCleaned: withCleaned ?? this.withCleaned,
    withRawText: withRawText ?? this.withRawText,
    withTranslatedText: withTranslatedText ?? this.withTranslatedText,
    byChapter: byChapter ?? this.byChapter,
    strip: strip ?? this.strip,
    sliceHeight: sliceHeight ?? this.sliceHeight,
  );

  Map<String, Object?> toJson() => {
    'image_format': imageFormat,
    'raw_text': rawText,
    'translated_text': translatedText,
    'cleaned_image': cleanedImage,
    'container': container.name,
    'with_translated': withTranslated,
    'with_cleaned': withCleaned,
    'with_raw_text': withRawText,
    'with_translated_text': withTranslatedText,
    'by_chapter': byChapter,
    'strip': strip.name,
    'slice_height': sliceHeight,
  };

  factory ExportSettings.fromJson(Map<String, Object?> json) {
    const d = ExportSettings();
    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    final format = json['image_format'];
    return ExportSettings(
      imageFormat: format is String && formats.contains(format) ? format : d.imageFormat,
      rawText: flag('raw_text', d.rawText),
      translatedText: flag('translated_text', d.translatedText),
      cleanedImage: flag('cleaned_image', d.cleanedImage),
      container: ExportContainer.parse(json['container'] as String?),
      withTranslated: flag('with_translated', d.withTranslated),
      withCleaned: flag('with_cleaned', d.withCleaned),
      withRawText: flag('with_raw_text', d.withRawText),
      withTranslatedText: flag('with_translated_text', d.withTranslatedText),
      byChapter: flag('by_chapter', d.byChapter),
      strip: StripExport.parse(json['strip'] as String?),
      sliceHeight: (json['slice_height'] as num?)?.toInt().clamp(minSliceHeight, maxSliceHeight) ?? d.sliceHeight,
    );
  }
}
