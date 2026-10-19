import '../export/export_pages.dart';
import '../plugins/engines.dart';
import '../render/layout.dart';
import '../render/upscale.dart';

/// User settings stored in `settings.json` (never secrets).
///
/// Defaults follow the original application (`app/ui/settings/settings_page.py`).
/// Unknown keys are kept in [extra] so that newer files survive a round trip
/// through an older build.
class AppSettings {
  AppSettings({
    this.detector = 'rtdetr_v2',
    this.ocr = 'default',
    this.translator = 'openai_compatible',
    this.inpainter = 'aot',
    this.useGpu = false,
    this.upscaleSmallText = true,
    this.fixCyrillicLookalikes = false,
    this.inpaint = const InpaintConfig(),
    this.sourceLanguage = 'English',
    this.targetLanguage = 'Russian',
    this.extraContext = '',
    this.sendPageImage = false,
    this.render = const RenderSettings(),
    this.upscale = const UpscaleSettings(),
    this.export = const ExportSettings(),
    this.modelsDir = '',
    this.theme = 'dark',
    this.uiLanguage = 'ru',
    this.testMode = false,
    this.projectAutosave = true,
    List<String>? recentProjects,
    Map<String, Map<String, Object?>>? plugins,
    Set<String>? approvedNetworkPlugins,
    Map<String, Object?>? extra,
  })  : recentProjects = recentProjects ?? [],
        plugins = plugins ?? {},
        approvedNetworkPlugins = approvedNetworkPlugins ?? {},
        extra = extra ?? {};

  static const schemaVersion = 1;

  /// Selected plugin ids.
  String detector;
  String ocr;
  String translator;
  String inpainter;

  bool useGpu;

  /// Enlarge pages with small text (screenshots, low-resolution scans)
  /// before line splitting and OCR. New in this project.
  bool upscaleSmallText;

  /// For Cyrillic source languages, replace Latin look-alike letters that OCR
  /// returns in Cyrillic text ("HET" → "НЕТ"). Off by default: Latin words in
  /// the comic (signs, "OK") would become Cyrillic too. New in this project.
  bool fixCyrillicLookalikes;
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

  /// "Render text in upper case" (off by default, as in the original): when
  /// on, translations are upper-cased; when off, all-caps translations are
  /// turned into sentence case.
  bool get upperCase => render.upperCase;
  set upperCase(bool value) => render = render.copyWith(upperCase: value);

  /// Enlarging small pages before the translation is drawn, so the letters
  /// stay readable. New in this project.
  UpscaleSettings upscale;

  /// Saving results (GUI export and the automatic export after a batch run).
  ExportSettings export;

  /// Folder with downloaded models; empty = `models` in the data folder.
  String modelsDir;

  /// `dark`, `light` or `system`.
  String theme;
  String uiLanguage;

  /// Save per-stage artifacts for every run (see docs/DIAGNOSTICS.md).
  bool testMode;

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
          'ocr': ocr,
          'translator': translator,
          'inpainter': inpainter,
          'use_gpu': useGpu,
          'upscale_small_text': upscaleSmallText,
          'fix_cyrillic_lookalikes': fixCyrillicLookalikes,
        },
        'inpaint': inpaint.toJson(),
        'languages': {'source': sourceLanguage, 'target': targetLanguage},
        'llm': {'extra_context': extraContext, 'send_page_image': sendPageImage},
        'render': render.toJson(),
        'upscale': upscale.toJson(),
        'export': export.toJson(),
        'models': {'dir': modelsDir},
        'ui': {'theme': theme, 'language': uiLanguage},
        'test_mode': testMode,
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
    final models = group('models');
    final projects = group('projects');
    const known = {
      'schema_version', 'tools', 'inpaint', 'languages', 'llm', 'render', 'upscale', 'export', 'models', 'ui', 'test_mode', 'plugins', //
      'approved_network_plugins', 'projects',
    };
    final strategyName = pick<String>(inpaint, 'strategy', defaults.inpaint.strategy.name);
    return AppSettings(
      detector: pick(tools, 'detector', defaults.detector),
      ocr: pick(tools, 'ocr', defaults.ocr),
      translator: pick(tools, 'translator', defaults.translator),
      inpainter: pick(tools, 'inpainter', defaults.inpainter),
      useGpu: pick(tools, 'use_gpu', defaults.useGpu),
      upscaleSmallText: pick(tools, 'upscale_small_text', defaults.upscaleSmallText),
      fixCyrillicLookalikes: pick(tools, 'fix_cyrillic_lookalikes', defaults.fixCyrillicLookalikes),
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
      modelsDir: pick(models, 'dir', defaults.modelsDir),
      theme: pick(ui, 'theme', defaults.theme),
      uiLanguage: pick(ui, 'language', defaults.uiLanguage),
      testMode: pick(json, 'test_mode', defaults.testMode),
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
  });

  static const formats = ['source', 'png', 'jpg', 'webp'];

  /// `source` (same as the input page), `png`, `jpg` or `webp`.
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
  }) =>
      ExportSettings(
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
    );
  }
}
