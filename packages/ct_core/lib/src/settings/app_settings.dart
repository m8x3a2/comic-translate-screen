import 'dart:convert';

import '../export/export_pages.dart';
import '../exchange/exchange_settings.dart';
import '../ocr/read_level.dart';
import '../ocr/text_prep.dart';
import '../export/strip_export.dart';
import '../inpainting/clean_level.dart';
import '../plugins/engines.dart';
import '../plugins/settings_schema.dart' show SecretSetting;
import '../render/layout.dart';
import '../usage/usage_log.dart' show UsageSink;
import '../render/text_case.dart';
import '../render/upscale.dart';
import 'own_server_keys.dart';
import 'request_template.dart';
import 'secret_store.dart' show pluginSecretKey;

/// What the pages are: each kind finds text its own way.
enum ContentKind {
  /// Comics, manga, webtoons: speech bubbles and captions.
  comics,

  /// Screenshots of sites, games and visual novels: lines of ordinary text.
  screens,
}

/// What "Translate" does with frames found but not read yet (no text). New
/// in this project.
enum EmptyFrames {
  /// Asks each time.
  ask,

  /// Reads them first.
  read,

  /// Translates the rest: they stay empty and are not sent.
  skip,
}

/// Named instructions for the network models, separate from manual chat exchange.
enum ModelPromptKind { ocr, translation }

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
    this.translator = 'openrouter',
    this.inpainter = 'lama',
    this.textMask = comicTextDetectorId,
    this.colourLetters = true,
    this.useGpu = false,
    this.textPrep = 'fatality_comix',
    this.screenTextPrep = 'plain_x1_5',
    this.readLevel = ReadLevel.medium,
    this.screenReadLevel = ReadLevel.medium,
    this.fixCyrillicLookalikes = false,
    this.splitGluedWords = false,
    this.checkLines = true,
    this.dictShowEnglish = true,
    this.textPrepSeconds = 60,
    this.emptyFrames = EmptyFrames.ask,
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
    Set<String>? lockedParts,
    Map<String, String>? gpuCpuModels,
    this.showLookInPanel = true,
    this.gridTileSize = 190,
    this.translateSelected = false,
    this.splitInside = 'auto',
    this.showNavigator = false,
    this.settingsView = 'full',
    this.settingsLastView = 'full',
    this.appIcon = 'green',
    this.lookParts,
    this.textPanelWidth,
    this.testMode = false,
    this.autoBugReport = true,
    this.projectAutosave = true,
    List<String>? recentProjects,
    Map<String, Map<String, Object?>>? plugins,
    Map<String, String>? ownServerNames,
    this.ownServerProfile = '',
    this.ownServersByName = false,
    this.ownServerOcrProfile,
    Map<String, RequestTemplate>? requestTemplates,
    Map<ModelPromptKind, List<PromptPreset>>? modelPromptPresets,
    Map<String, OwnServerKeys>? ownServerKeys,
    Set<String>? approvedNetworkPlugins,
    Map<String, Object?>? extra,
  }) : shortcuts = shortcuts ?? {},
       hiddenPanels = hiddenPanels ?? {},
       lockedParts = lockedParts ?? {},
       gpuCpuModels = gpuCpuModels ?? {},
       recentProjects = recentProjects ?? [],
       plugins = plugins ?? {},
       ownServerNames = ownServerNames ?? {},
       requestTemplates = requestTemplates ?? {},
       modelPromptPresets = modelPromptPresets ?? {},
       ownServerKeys = ownServerKeys ?? {},
       approvedNetworkPlugins = approvedNetworkPlugins ?? {},
       extra = extra ?? {};

  /// 2: OpenRouter got a translator of its own (see [moveOwnServerToOpenRouter]).
  static const schemaVersion = 2;

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

  /// Whether coloured letters the [textMask] finds on plain background are
  /// followed over the drawing by their colour (`colour_letters.dart`).
  /// New in this project.
  bool colourLetters;

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

  /// The recognition level (see `read_level.dart`) for comics and for
  /// screens. New in this project.
  ReadLevel readLevel;
  ReadLevel screenReadLevel;

  /// The recognition level of the current [contentKind].
  ReadLevel get activeReadLevel => contentKind == ContentKind.screens ? screenReadLevel : readLevel;

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

  /// The cards of the offline dictionary show English explanations too
  /// (folded, open by themselves when a word has no Russian). New in this
  /// project.
  bool dictShowEnglish;

  /// Lines are checked on these pages: [checkLines] is on and the pages are
  /// comics (the line detector of "Sites and games" finds exact lines).
  bool get checksLines => checkLines && contentKind == ContentKind.comics;

  /// Time a neural text preparation may spend on one page (seconds; 0: no
  /// limit), see `readingNeuralBudgetMs`. New in this project.
  int textPrepSeconds;

  /// What the "Translate" step does with frames that have no text (the
  /// answer remembered in its question, or chosen in the settings).
  EmptyFrames emptyFrames;
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

  /// Sections of the settings window under a lock: ready-made sets and
  /// templates leave them as they are (names of the app's `SettingsPart`).
  Set<String> lockedParts;

  /// The text panel shows the look of styled words (bold, colour, size...);
  /// off: plain text. Not in the original.
  bool showLookInPanel;

  /// Width of a page in the grid of all pages (logical pixels).
  int gridTileSize;

  /// "Translate all" translates only the picked pages when some are picked
  /// (the choice under its arrow).
  bool translateSelected;

  /// How "Find blocks inside" cuts a block (the choice under its arrow):
  /// `auto`, `columns` or `paragraphs` (an `InsideSplit` name).
  String splitInside;

  /// The mini view of the page (or the webtoon strip) is shown.
  bool showNavigator;

  /// How the settings open: `full` (over the whole window), `panel` (beside
  /// the page) or `last` (as the last time, [settingsLastView]).
  String settingsView;
  String settingsLastView;

  /// The icon of the window and taskbar: [appIcons] — `green` (the program's
  /// own, the translator), `blue`/`navy` (the spare cats) or `custom` (the user's picture,
  /// [AppPaths.customIcon]).
  String appIcon;

  static const appIcons = ['green', 'blue', 'navy', 'custom'];

  /// The parts ticked last in "Apply to others" (`LookPart` names); null:
  /// the usual ones.
  List<String>? lookParts;

  /// Width of the "Text" panel dragged by hand, in logical pixels; null:
  /// it follows the window.
  double? textPanelWidth;

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

  /// Named connections have independent settings and API keys. The empty
  /// profile continues to use the original connection's storage keys.
  final Map<String, String> ownServerNames;
  String ownServerProfile;
  bool ownServersByName;

  /// Null keeps the independent OCR address used by older settings.
  String? ownServerOcrProfile;
  final Map<String, RequestTemplate> requestTemplates;
  final Map<ModelPromptKind, List<PromptPreset>> modelPromptPresets;
  final Map<String, OwnServerKeys> ownServerKeys;

  static const ownServerStoragePrefix = 'openai_compatible_';

  static String ownServerStorageId(String profile) =>
      profile.isEmpty ? 'openai_compatible' : '$ownServerStoragePrefix$profile';

  static String ownServerSecretKey(String storageId, String slot) =>
      pluginSecretKey(storageId, slot.isEmpty ? 'api_key' : 'api_key.$slot');

  OwnServerKeys keysForOwnServer(String storageId) => ownServerKeys[storageId] ?? OwnServerKeys();

  void setOwnServerKeys(String storageId, OwnServerKeys keys) {
    if (keys.isDefault) {
      ownServerKeys.remove(storageId);
    } else {
      ownServerKeys[storageId] = keys;
    }
  }

  String pluginStorageId(String id) => id == 'openai_compatible' && ownServerNames.containsKey(ownServerProfile)
      ? ownServerStorageId(ownServerProfile)
      : id;

  Map<String, Object?> pluginValues(String id) {
    final profile = ownServerOcrProfile;
    if (id == 'openai_compatible_ocr' && profile != null) {
      final connectionId = ownServerStorageId(profile);
      final connection = plugins[connectionId];
      final template = requestTemplateFor(connectionId);
      return {
        ...?plugins[id],
        'api_url': connection?['api_url'],
        'chat_path': template != null && template.chatPath.isNotEmpty ? template.chatPath : connection?['chat_path'],
        'models_path': template != null && template.modelsPath.isNotEmpty
            ? template.modelsPath
            : connection?['models_path'],
        if (template != null && template.http.isNotEmpty) RequestTemplate.httpSettingKey: jsonEncode(template.httpJson),
      };
    }
    if (id == 'openrouter_ocr') {
      final template = requestTemplateFor('openrouter');
      return {
        ...?plugins[id],
        if (template != null && template.http.isNotEmpty) RequestTemplate.httpSettingKey: jsonEncode(template.httpJson),
      };
    }
    return pluginValuesForStorage(pluginStorageId(id));
  }

  Map<String, Object?> pluginValuesForStorage(String storageId) {
    final values = plugins[storageId] ?? const <String, Object?>{};
    final template = requestTemplateFor(storageId);
    if (template == null) return values;
    return {
      ...values,
      ...template.overrides,
      RequestTemplate.keyStatusPathKey: template.keyStatusPath,
      RequestTemplate.keyStatusFieldsKey: jsonEncode(template.keyStatusFields),
      if (template.http.isNotEmpty) RequestTemplate.httpSettingKey: jsonEncode(template.httpJson),
    };
  }

  RequestTemplate? requestTemplateFor(String storageId) =>
      requestTemplates[plugins[storageId]?[RequestTemplate.selectionKey]];

  void removeRequestTemplate(String id) {
    requestTemplates.remove(id);
    plugins.updateAll(
      (_, values) =>
          values[RequestTemplate.selectionKey] == id ? ({...values}..remove(RequestTemplate.selectionKey)) : values,
    );
  }

  /// Where the API keys of OpenRouter are listed ([keysForOwnServer]): its
  /// translator and its OCR share them; the first one is the key kept
  /// before there could be several.
  static const openRouterKeysId = 'openrouter';

  /// [sink] counting each request of OpenRouter for the API key chosen now
  /// (the usage counter shows the spending of each key).
  UsageSink? countUsageTo(UsageSink? sink) {
    if (sink == null) return null;
    final key = keysForOwnServer(openRouterKeysId).activeId;
    return (usage) =>
        sink(usage.plugin == 'openrouter' || usage.plugin == 'openrouter_ocr' ? usage.withKey(key) : usage);
  }

  String? pluginSettingSecretKey(String id, SecretSetting field) {
    final profile = ownServerOcrProfile;
    final connection = switch (id) {
      'openai_compatible' => pluginStorageId(id),
      'openai_compatible_ocr' when profile != null => ownServerStorageId(profile),
      'openrouter' || 'openrouter_ocr' => openRouterKeysId,
      _ => null,
    };
    if (connection != null && field.key == 'api_key') {
      final slot = keysForOwnServer(connection).activeId;
      return slot == null ? null : ownServerSecretKey(connection, slot);
    }
    return field.storeKey(pluginStorageId(id));
  }

  /// The "Own server" translator's [values] point at OpenRouter: its address,
  /// or none (which meant OpenRouter before it had a translator of its own).
  static bool ownServerIsOpenRouter(Map<String, Object?> values) {
    final url = (values['api_url'] as String? ?? '').trim();
    return url.isEmpty || Uri.tryParse(url)?.host.toLowerCase() == 'openrouter.ai';
  }

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
      'colour_letters': colourLetters,
      'use_gpu': useGpu,
      if (gpuCpuModels.isNotEmpty) 'gpu_cpu_models': gpuCpuModels,
      'text_prep': textPrep,
      'screen_text_prep': screenTextPrep,
      'read_level': readLevel.name,
      'screen_read_level': screenReadLevel.name,
      'fix_cyrillic_lookalikes': fixCyrillicLookalikes,
      'split_glued_words': splitGluedWords,
      'check_lines': checkLines,
      'dict_show_english': dictShowEnglish,
      'text_prep_seconds': textPrepSeconds,
      'empty_frames': emptyFrames.name,
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
      if (lockedParts.isNotEmpty) 'locked_parts': [...lockedParts],
      if (!showLookInPanel) 'show_look_in_panel': false,
      if (gridTileSize != 190) 'grid_tile_size': gridTileSize,
      if (translateSelected) 'translate_selected': true,
      if (splitInside != 'auto') 'split_inside': splitInside,
      if (showNavigator) 'show_navigator': true,
      if (settingsView != 'full') 'settings_view': settingsView,
      if (settingsLastView != 'full') 'settings_last_view': settingsLastView,
      if (appIcon != 'green') 'app_icon': appIcon,
      if (lookParts != null) 'look_parts': lookParts,
      if (textPanelWidth != null) 'text_panel_width': textPanelWidth,
    },
    'test_mode': testMode,
    'auto_bug_report': autoBugReport,
    'projects': {'autosave': projectAutosave, 'recent': recentProjects},
    'plugins': plugins,
    if (modelPromptPresets.isNotEmpty)
      'model_prompt_presets': {
        for (final entry in modelPromptPresets.entries)
          entry.key.name: [for (final preset in entry.value) preset.toJson()],
      },
    if (requestTemplates.isNotEmpty)
      'request_templates': {for (final entry in requestTemplates.entries) entry.key: entry.value.toJson()},
    if (ownServerKeys.isNotEmpty)
      'own_server_keys': {for (final entry in ownServerKeys.entries) entry.key: entry.value.toJson()},
    if (ownServerNames.isNotEmpty || ownServersByName || ownServerOcrProfile != null)
      'own_servers': {
        'active': ownServerProfile,
        'names': ownServerNames,
        'by_name': ownServersByName,
        if (ownServerOcrProfile != null) 'ocr_profile': ownServerOcrProfile,
      },
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
    final ownServers = group('own_servers');
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
      'own_servers',
      'request_templates',
      'model_prompt_presets',
      'own_server_keys',
      'approved_network_plugins', 'projects',
    };
    // Before step 2.1 a switch turned the enlarging of small text off.
    final oldOff = tools['upscale_small_text'] == false;
    final strategyName = pick<String>(inpaint, 'strategy', defaults.inpaint.strategy.name);
    final settings = AppSettings(
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
      colourLetters: pick(tools, 'colour_letters', defaults.colourLetters),
      useGpu: pick(tools, 'use_gpu', defaults.useGpu),
      gpuCpuModels: {
        for (final e in ((tools['gpu_cpu_models'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      textPrep: pick(tools, 'text_prep', oldOff ? textPrepOffId : defaults.textPrep),
      screenTextPrep: pick(tools, 'screen_text_prep', oldOff ? textPrepOffId : defaults.screenTextPrep),
      readLevel: ReadLevel.values.asNameMap()[tools['read_level']] ?? defaults.readLevel,
      screenReadLevel: ReadLevel.values.asNameMap()[tools['screen_read_level']] ?? defaults.screenReadLevel,
      fixCyrillicLookalikes: pick(tools, 'fix_cyrillic_lookalikes', defaults.fixCyrillicLookalikes),
      splitGluedWords: pick(tools, 'split_glued_words', defaults.splitGluedWords),
      checkLines: pick(tools, 'check_lines', defaults.checkLines),
      dictShowEnglish: pick(tools, 'dict_show_english', defaults.dictShowEnglish),
      textPrepSeconds: pick(tools, 'text_prep_seconds', defaults.textPrepSeconds),
      emptyFrames: EmptyFrames.values.asNameMap()[tools['empty_frames']] ?? defaults.emptyFrames,
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
      lockedParts: {...?(ui['locked_parts'] as List?)?.whereType<String>()},
      showLookInPanel: ui['show_look_in_panel'] != false,
      gridTileSize: ((ui['grid_tile_size'] as num?)?.toInt() ?? 190).clamp(100, 400),
      translateSelected: ui['translate_selected'] == true,
      splitInside: const {'columns', 'paragraphs'}.contains(ui['split_inside']) ? ui['split_inside'] as String : 'auto',
      showNavigator: ui['show_navigator'] == true,
      settingsView: const {'panel', 'last'}.contains(ui['settings_view']) ? ui['settings_view'] as String : 'full',
      settingsLastView: ui['settings_last_view'] == 'panel' ? 'panel' : 'full',
      appIcon: appIcons.contains(ui['app_icon']) ? ui['app_icon'] as String : 'green',
      lookParts: ui['look_parts'] is List ? [...(ui['look_parts'] as List).whereType<String>()] : null,
      textPanelWidth: (ui['text_panel_width'] as num?)?.toDouble().clamp(200.0, 1200.0),
      testMode: pick(json, 'test_mode', defaults.testMode),
      autoBugReport: pick(json, 'auto_bug_report', defaults.autoBugReport),
      projectAutosave: pick(projects, 'autosave', defaults.projectAutosave),
      recentProjects: [...?(projects['recent'] as List?)?.whereType<String>()],
      plugins: {
        for (final e in group('plugins').entries)
          if (e.value is Map) e.key: (e.value as Map).cast<String, Object?>(),
      },
      ownServerNames: {
        for (final e in (ownServers['names'] as Map? ?? const {}).entries)
          if (e.key is String && (e.key as String).isNotEmpty && e.value is String) e.key as String: e.value as String,
      },
      ownServerProfile: pick(ownServers, 'active', ''),
      ownServersByName: ownServers['by_name'] == true,
      ownServerOcrProfile: ownServers['ocr_profile'] is String ? ownServers['ocr_profile'] as String : null,
      modelPromptPresets: {
        if (json['model_prompt_presets'] case final Map all)
          for (final kind in ModelPromptKind.values)
            if (all[kind.name] case final List list) kind: [for (final item in list) ?PromptPreset.fromJson(item)],
      },
      requestTemplates: {
        if (json['request_templates'] case final Map templates)
          for (final entry in templates.entries)
            if (entry.key case final String id when id.isNotEmpty) id: ?RequestTemplate.fromJson(entry.value),
      },
      ownServerKeys: {
        if (json['own_server_keys'] case final Map keys)
          for (final entry in keys.entries)
            if (entry.key case final String id) id: ?OwnServerKeys.fromJson(entry.value),
      },
      approvedNetworkPlugins: {...?(json['approved_network_plugins'] as List?)?.whereType<String>()},
      extra: {
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
    if (((json['schema_version'] as num?) ?? 1) < 2) settings.moveOwnServerToOpenRouter();
    return settings;
  }

  /// Once, for settings from before OpenRouter had a translator of its own:
  /// the "Own server" translator pointed at OpenRouter (or at nothing, which
  /// meant it) moves there with its model and the rest. The key moves in the
  /// secure storage at start (`AppServices.init`).
  void moveOwnServerToOpenRouter() {
    final own = plugins['openai_compatible'];
    if (!ownServerIsOpenRouter(own ?? const {})) return;
    if (own != null) {
      plugins['openrouter'] = {
        for (final e in own.entries)
          if (e.key != 'api_url' && e.key != 'token_limit_param') e.key: e.value,
        ...?plugins['openrouter'],
      };
    }
    if (translator == 'openai_compatible') translator = 'openrouter';
    if (approvedNetworkPlugins.contains('openai_compatible@openrouter.ai')) {
      approvedNetworkPlugins.add('openrouter@openrouter.ai');
    }
  }
}

/// How results are saved. As in the original, a batch run can also save the
/// recognized text, the translations and the cleaned pages automatically, to
/// `comic_translate_<timestamp>` next to the input ([rawText],
/// [translatedText], [cleanedImage]). The other fields keep the last
/// choices of the Export window, when it is told to [remember] them.
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
    this.namesByTemplate = false,
    this.namePrefix = '',
    this.nameStart = '001',
    this.remember = false,
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

  /// File names "text + number" instead of the page names ([NameTemplate]).
  final bool namesByTemplate;
  final String namePrefix;
  final String nameStart;

  /// The Export window opens with these choices; off: with the defaults
  /// (new, 2026-11-05).
  final bool remember;

  /// What the Export window opens with: these choices when [remember] is
  /// on, else the defaults (the automatic export keeps its own).
  ExportSettings get forWindow =>
      remember ? this : ExportSettings(rawText: rawText, translatedText: translatedText, cleanedImage: cleanedImage);

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
    names: namesByTemplate ? NameTemplate(namePrefix, nameStart) : null,
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
    bool? namesByTemplate,
    String? namePrefix,
    String? nameStart,
    bool? remember,
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
    namesByTemplate: namesByTemplate ?? this.namesByTemplate,
    namePrefix: namePrefix ?? this.namePrefix,
    nameStart: nameStart ?? this.nameStart,
    remember: remember ?? this.remember,
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
    'names_by_template': namesByTemplate,
    'name_prefix': namePrefix,
    'name_start': nameStart,
    'remember': remember,
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
      namesByTemplate: flag('names_by_template', d.namesByTemplate),
      namePrefix: json['name_prefix'] is String ? json['name_prefix'] as String : d.namePrefix,
      nameStart: json['name_start'] is String && NameTemplate.validStart(json['name_start'] as String)
          ? json['name_start'] as String
          : d.nameStart,
      remember: flag('remember', d.remember),
    );
  }
}
