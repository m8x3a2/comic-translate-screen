/// Settings back to their defaults: one section of the settings window, or
/// all of them. API keys (secure storage), the recent projects and the
/// downloaded models are not touched. The same copying of a section takes
/// a settings template (`settings_templates.dart`).
library;

import 'package:ct_core/ct_core.dart';

enum SettingsPart { general, translator, exchange, ocr, cleaning, text, upscale, export, keys, models }

/// The fields of section [part] in [s] made as in [from].
///
/// [reset] (back to the defaults) also puts back what belongs to this
/// computer: the use of the graphics card, the models folder, how the
/// settings were shown last, the internet permissions of the translators.
/// A template leaves those as they are.
void copySettingsPart(
  AppSettings s,
  AppSettings from,
  PluginRegistry registry,
  SettingsPart part, {
  bool reset = false,
}) {
  void plugins(Set<PluginKind> kinds) {
    bool ofKinds(String id) => registry.contains(id) && kinds.contains(registry.info(id).kind);
    s.plugins.removeWhere((id, _) => ofKinds(id));
    for (final e in from.plugins.entries) {
      if (ofKinds(e.key)) s.plugins[e.key] = {...e.value};
    }
  }

  switch (part) {
    case SettingsPart.general:
      s
        ..uiLanguage = from.uiLanguage
        ..theme = from.theme
        ..projectAutosave = from.projectAutosave
        ..testMode = from.testMode
        ..autoBugReport = from.autoBugReport
        ..gridTileSize = from.gridTileSize
        ..translateSelected = from.translateSelected
        ..splitInside = from.splitInside
        ..showNavigator = from.showNavigator
        ..settingsView = from.settingsView
        ..appIcon = from.appIcon
        ..lookParts = from.lookParts == null ? null : [...from.lookParts!]
        ..hiddenPanels = {...from.hiddenPanels};
      if (reset) {
        s
          ..useGpu = from.useGpu
          ..settingsLastView = from.settingsLastView;
      }
    case SettingsPart.translator:
      s
        ..translator = from.translator
        ..extraContext = from.extraContext
        ..sendPageImage = from.sendPageImage
        ..dictShowEnglish = from.dictShowEnglish;
      if (reset) {
        s.approvedNetworkPlugins.clear();
      } else {
        // The languages go with the translator in a template.
        s
          ..sourceLanguage = from.sourceLanguage
          ..targetLanguage = from.targetLanguage;
      }
      plugins({PluginKind.translator});
    case SettingsPart.ocr:
      s
        ..detector = from.detector
        ..contentKind = from.contentKind
        ..screenDetector = from.screenDetector
        ..ocr = from.ocr
        ..textPrep = from.textPrep
        ..screenTextPrep = from.screenTextPrep
        ..readLevel = from.readLevel
        ..screenReadLevel = from.screenReadLevel
        ..fixCyrillicLookalikes = from.fixCyrillicLookalikes
        ..splitGluedWords = from.splitGluedWords
        ..checkLines = from.checkLines
        ..textPrepSeconds = from.textPrepSeconds;
      // Own servers are of this computer.
      if (reset) s.ownServerOcrProfile = from.ownServerOcrProfile;
      plugins({PluginKind.detector, PluginKind.ocr, PluginKind.textPrep, PluginKind.reader});
    case SettingsPart.cleaning:
      s
        ..inpainter = from.inpainter
        ..textMask = from.textMask
        ..colourLetters = from.colourLetters
        ..inpaint = from.inpaint;
      plugins({PluginKind.inpainter, PluginKind.textMask});
    case SettingsPart.text:
      s.render = from.render;
    case SettingsPart.upscale:
      s.upscale = from.upscale;
    case SettingsPart.exchange:
      s.exchange = from.exchange;
    case SettingsPart.export:
      s.export = from.export;
    case SettingsPart.keys:
      s.shortcuts = {...from.shortcuts};
    case SettingsPart.models:
      if (reset) s.modelsDir = from.modelsDir;
  }
}

void resetSettings(AppSettings s, PluginRegistry registry, {SettingsPart? part}) {
  final d = AppSettings();
  for (final p in part == null ? SettingsPart.values : [part]) {
    copySettingsPart(s, d, registry, p, reset: true);
  }
  if (part == null) {
    s
      ..sourceLanguage = d.sourceLanguage
      ..targetLanguage = d.targetLanguage
      ..plugins.removeWhere((id, _) => !id.startsWith(AppSettings.ownServerStoragePrefix))
      ..lockedParts.clear()
      ..extra.clear();
  }
}
