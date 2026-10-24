/// Cleaning levels of the settings (new in this project): which text masker
/// finds the letters and which network removes them. Chosen by the night
/// experiment of 2026-10-25 (`self\mask-inpaint-experiment`).
library;

import '../models/model_manager.dart';
import '../plugins/engines.dart';
import '../plugins/settings_schema.dart';
import '../plugins/registry.dart';
import '../settings/app_settings.dart';

/// The comic-text-detector plugin (`TextMasker`).
const comicTextDetectorId = 'comic_text_detector';

enum CleanLevel {
  /// The original's mask and AOT.
  simple('', 'aot'),

  /// comic-text-detector letters and AOT.
  medium(comicTextDetectorId, 'aot'),

  /// comic-text-detector letters and LaMa (manga): the default.
  high(comicTextDetectorId, 'lama');

  const CleanLevel(this.textMask, this.inpainter);

  final String textMask;
  final String inpainter;

  /// The level of [settings], or null for a combination of none.
  static CleanLevel? of(AppSettings settings) {
    for (final l in values) {
      if (l.textMask == settings.textMask && l.inpainter == settings.inpainter) return l;
    }
    return null;
  }

  void applyTo(AppSettings settings) {
    settings
      ..textMask = textMask
      ..inpainter = inpainter;
  }
}

/// The text masker of [settings], or null: none chosen, or its model is not
/// downloaded (the original's mask is used alone then).
Future<TextMasker?> loadTextMasker(
  PluginRegistry registry,
  AppSettings settings,
  PluginConfig? config,
  PluginEnvironment env,
) async {
  final id = settings.textMask;
  if (id.isEmpty || !registry.contains(id)) return null;
  try {
    return await registry.instance<TextMasker>(id, config ?? PluginConfig(), env);
  } on ModelNotInstalledException catch (e) {
    env.log.warn('text_masker_model_missing', {'error': e.toString()});
    return null;
  }
}
