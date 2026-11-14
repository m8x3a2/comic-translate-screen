/// Settings back to their defaults: one section of the settings window, or
/// all of them. API keys (secure storage), the recent projects and the
/// downloaded models are not touched.
library;

import 'package:ct_core/ct_core.dart';

enum SettingsPart { general, translator, exchange, ocr, cleaning, text, upscale, export, keys, models }

void resetSettings(AppSettings s, PluginRegistry registry, {SettingsPart? part}) {
  final d = AppSettings();
  void forgetPlugins(Set<PluginKind> kinds) =>
      s.plugins.removeWhere((id, _) => registry.contains(id) && kinds.contains(registry.info(id).kind));
  final parts = part == null ? SettingsPart.values : [part];
  for (final p in parts) {
    switch (p) {
      case SettingsPart.general:
        s
          ..uiLanguage = d.uiLanguage
          ..theme = d.theme
          ..useGpu = d.useGpu
          ..projectAutosave = d.projectAutosave
          ..testMode = d.testMode
          ..autoBugReport = d.autoBugReport
          ..gridTileSize = d.gridTileSize
          ..translateSelected = d.translateSelected
          ..splitInside = d.splitInside
          ..showNavigator = d.showNavigator
          ..settingsView = d.settingsView
          ..settingsLastView = d.settingsLastView
          ..appIcon = d.appIcon
          ..lookParts = d.lookParts
          ..hiddenPanels.clear();
      case SettingsPart.translator:
        s
          ..translator = d.translator
          ..extraContext = d.extraContext
          ..sendPageImage = d.sendPageImage
          ..approvedNetworkPlugins.clear();
        forgetPlugins({PluginKind.translator});
      case SettingsPart.ocr:
        s
          ..detector = d.detector
          ..contentKind = d.contentKind
          ..screenDetector = d.screenDetector
          ..ocr = d.ocr
          ..ownServerOcrProfile = d.ownServerOcrProfile
          ..textPrep = d.textPrep
          ..screenTextPrep = d.screenTextPrep
          ..readLevel = d.readLevel
          ..screenReadLevel = d.screenReadLevel
          ..fixCyrillicLookalikes = d.fixCyrillicLookalikes
          ..splitGluedWords = d.splitGluedWords
          ..checkLines = d.checkLines
          ..textPrepSeconds = d.textPrepSeconds;
        forgetPlugins({PluginKind.detector, PluginKind.ocr, PluginKind.textPrep, PluginKind.reader});
      case SettingsPart.cleaning:
        s
          ..inpainter = d.inpainter
          ..textMask = d.textMask
          ..colourLetters = d.colourLetters
          ..inpaint = d.inpaint;
        forgetPlugins({PluginKind.inpainter, PluginKind.textMask});
      case SettingsPart.text:
        s.render = d.render;
      case SettingsPart.upscale:
        s.upscale = d.upscale;
      case SettingsPart.exchange:
        s.exchange = d.exchange;
      case SettingsPart.export:
        s.export = d.export;
      case SettingsPart.keys:
        s.shortcuts.clear();
      case SettingsPart.models:
        s.modelsDir = d.modelsDir;
    }
  }
  if (part == null) {
    s
      ..sourceLanguage = d.sourceLanguage
      ..targetLanguage = d.targetLanguage
      ..plugins.removeWhere((id, _) => !id.startsWith(AppSettings.ownServerStoragePrefix))
      ..extra.clear();
  }
}
