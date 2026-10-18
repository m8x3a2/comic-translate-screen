import '../plugins/engines.dart';

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
    this.inpaint = const InpaintConfig(),
    this.sourceLanguage = 'English',
    this.targetLanguage = 'Russian',
    this.extraContext = '',
    this.sendPageImage = false,
    this.upperCase = false,
    this.theme = 'dark',
    this.uiLanguage = 'ru',
    this.testMode = false,
    Map<String, Map<String, Object?>>? plugins,
    Set<String>? approvedNetworkPlugins,
    Map<String, Object?>? extra,
  })  : plugins = plugins ?? {},
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
  InpaintConfig inpaint;

  /// Default languages for new pages (canonical English names).
  String sourceLanguage;
  String targetLanguage;

  /// Extra context about the comic sent to LLM translators.
  String extraContext;

  /// Send the page image to translators that accept it (off by default,
  /// as in the original).
  bool sendPageImage;

  /// "Render text in upper case" (off by default, as in the original): when
  /// on, translations are upper-cased; when off, all-caps translations are
  /// turned into sentence case.
  bool upperCase;

  /// `dark`, `light` or `system`.
  String theme;
  String uiLanguage;

  /// Save per-stage artifacts for every run (see docs/DIAGNOSTICS.md).
  bool testMode;

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
        },
        'inpaint': inpaint.toJson(),
        'languages': {'source': sourceLanguage, 'target': targetLanguage},
        'llm': {'extra_context': extraContext, 'send_page_image': sendPageImage},
        'render': {'upper_case': upperCase},
        'ui': {'theme': theme, 'language': uiLanguage},
        'test_mode': testMode,
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
    const known = {
      'schema_version', 'tools', 'inpaint', 'languages', 'llm', 'render', 'ui', 'test_mode', 'plugins', //
      'approved_network_plugins',
    };
    final strategyName = pick<String>(inpaint, 'strategy', defaults.inpaint.strategy.name);
    return AppSettings(
      detector: pick(tools, 'detector', defaults.detector),
      ocr: pick(tools, 'ocr', defaults.ocr),
      translator: pick(tools, 'translator', defaults.translator),
      inpainter: pick(tools, 'inpainter', defaults.inpainter),
      useGpu: pick(tools, 'use_gpu', defaults.useGpu),
      upscaleSmallText: pick(tools, 'upscale_small_text', defaults.upscaleSmallText),
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
      upperCase: pick(render, 'upper_case', defaults.upperCase),
      theme: pick(ui, 'theme', defaults.theme),
      uiLanguage: pick(ui, 'language', defaults.uiLanguage),
      testMode: pick(json, 'test_mode', defaults.testMode),
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
