/// Words for values shown in several places: stages, skip reasons,
/// durations, languages, privacy.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/workspace.dart';
import 'key_bindings.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String stageLabel(AppLocalizations l, String? stage) => switch (stage) {
  'loading' => l.stageLoading,
  '01_detect' => l.stageDetect,
  '02_ocr' => l.stageOcr,
  '03_translate' => l.stageTranslate,
  '04_mask' || '05_inpaint' => l.stageClean,
  '06_render' => l.stageRender,
  'exchange' => l.stageExchange,
  _ => '',
};

/// Share of a page's work done when [stage] starts (detection and cleaning
/// take most of the time).
double stageFraction(String? stage) => switch (stage) {
  '01_detect' => 0.0,
  '02_ocr' => 0.2,
  '03_translate' => 0.4,
  '04_mask' => 0.55,
  '05_inpaint' => 0.6,
  '06_render' => 0.9,
  _ => 0.0,
};

/// Why a page was skipped, in plain words; with [details] the technical
/// message is added in brackets.
String reasonLabel(AppLocalizations l, SkipReason? reason, {bool details = true}) => switch (reason) {
  ModelMissingReason(:final model) => l.reasonModelMissing(model),
  TranslationFailedReason(:final kind, :final message) =>
    details ? l.withDetails(translationErrorLabel(l, kind), message) : translationErrorLabel(l, kind),
  UnreadableImageReason() => l.reasonImage,
  WorkerStoppedReason() => l.reasonWorkerStopped,
  OtherReason(:final message) => message,
  null => '',
};

String translationErrorLabel(AppLocalizations l, TranslationErrorKind kind) => switch (kind) {
  TranslationErrorKind.config => l.trErrConfig,
  TranslationErrorKind.auth => l.trErrAuth,
  TranslationErrorKind.credits => l.trErrCredits,
  TranslationErrorKind.notFound => l.trErrNotFound,
  TranslationErrorKind.rateLimit => l.trErrRateLimit,
  TranslationErrorKind.server => l.trErrServer,
  TranslationErrorKind.network => l.trErrNetwork,
  TranslationErrorKind.timeout => l.trErrTimeout,
  TranslationErrorKind.badReply => l.trErrBadReply,
  TranslationErrorKind.other => l.trErrOther,
};

/// Errors the user fixes in the translator settings.
bool fixedInSettings(SkipReason? reason) =>
    reason is TranslationFailedReason &&
    const {
      TranslationErrorKind.config,
      TranslationErrorKind.auth,
      TranslationErrorKind.credits,
      TranslationErrorKind.notFound,
    }.contains(reason.kind);

/// `1:05`, `12:30`, `1:02:03`.
String formatDuration(Duration d) {
  final s = d.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return s >= 3600 ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}' : '${s ~/ 60}:${two(s % 60)}';
}

/// An enlargement factor with at most one decimal, in the interface
/// language's style: `1.5`, `2` (`1,5` in Russian and other comma languages).
String formatFactor(BuildContext context, double f) {
  final text = (f * 10).round() % 10 == 0 ? '${f.round()}' : f.toStringAsFixed(1);
  const pointLanguages = {'en', 'ja', 'ko', 'zh'};
  return pointLanguages.contains(Localizations.localeOf(context).languageCode) ? text : text.replaceAll('.', ',');
}

/// [text] that a line never breaks inside ("Очистить 2 с" stays whole).
String keepTogether(String text) => text.replaceAll(' ', ' ');

/// How long a step took: `0,4 с`, `12 с`, `1 мин 05 с`.
String formatStepTime(BuildContext context, int ms) {
  final l = context.l10n;
  // Under a tenth of a second still shows as 0,1 s, not 0.
  if (ms < 9950) return l.secondsShort(formatFactor(context, (ms < 100 ? 100 : ms) / 1000));
  final s = (ms / 1000).round();
  if (s < 60) return l.secondsShort('$s');
  return l.minutesSeconds('${s ~/ 60}', '${s % 60}'.padLeft(2, '0'));
}

IconData privacyIcon(Privacy p) => switch (p) {
  Privacy.local => Icons.computer,
  Privacy.lan => Icons.lan_outlined,
  Privacy.cloud => Icons.cloud_outlined,
};

String privacyLabel(AppLocalizations l, Privacy p) => switch (p) {
  Privacy.local => l.privacyLocalBadge,
  Privacy.lan => l.privacyLanBadge,
  Privacy.cloud => l.privacyCloudBadge,
};

/// A small chip saying where a plugin sends data.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge(this.privacy, {super.key, this.host, this.iconOnly = false});

  final Privacy privacy;
  final String? host;

  /// Only the icon (narrow windows); the words are in the tooltip.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sends = privacy.sendsData;
    final fg = sends ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    final label = privacyLabel(context.l10n, privacy);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: sends ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(privacyIcon(privacy), size: 14, color: fg),
          if (!iconOnly) const SizedBox(width: 4),
          if (!iconOnly)
            Flexible(
              child: Text(
                host == null || host!.isEmpty ? label : '$label · $host',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
              ),
            ),
        ],
      ),
    );
  }
}

/// Groups of the models screen.
enum ModelGroup { core, language, textPrep, extra }

ModelGroup modelGroupOf(String id) => switch (id) {
  'rtdetr-v2-int8' ||
  'aot-inpainting' ||
  'ppocr-v5-det-mobile' ||
  'lama-manga' ||
  'comic-text-detector' => ModelGroup.core,
  'ppocr-v5-rec-en' ||
  'ppocr-v5-rec-latin' ||
  'ppocr-v5-rec-eslav' ||
  'ppocr-v5-rec-korean' ||
  'ppocr-v6-rec-small' ||
  'manga-ocr-mobile' ||
  'osd-script-id' => ModelGroup.language,
  'waifu2x-cunet-art-2x' || 'waifu2x-swin-art-2x' || 'fatality-comix-4x' => ModelGroup.textPrep,
  _ => ModelGroup.extra,
};

/// Short name and explanation of a model, in the interface language.
(String title, String info) modelText(AppLocalizations l, ModelSpec m) => switch (m.id) {
  'rtdetr-v2-int8' => (l.modelDetector, l.modelDetectorInfo),
  'aot-inpainting' => (l.modelAot, l.modelAotInfo),
  'lama-manga' => (l.modelLama, l.modelLamaInfo),
  'comic-text-detector' => (l.modelCtd, l.modelCtdInfo),
  'ppocr-v5-rec-en' => (l.modelOcrEn, l.modelOcrEnInfo),
  'ppocr-v5-rec-latin' => (l.modelOcrLatin, l.modelOcrLatinInfo),
  'ppocr-v5-rec-eslav' => (l.modelOcrEslav, l.modelOcrEslavInfo),
  'ppocr-v5-rec-korean' => (l.modelOcrKorean, l.modelOcrKoreanInfo),
  'ppocr-v6-rec-small' => (l.modelOcrChinese, l.modelOcrChineseInfo),
  'manga-ocr-mobile' => (l.modelOcrJapanese, l.modelOcrJapaneseInfo),
  'osd-script-id' => (l.modelOsd, l.modelOsdInfo),
  'ppocr-v5-det-mobile' => (l.modelLines, l.modelLinesInfo),
  'opus-mt-en-ru' => (l.modelOpusEnRu, l.modelOpusInfo),
  'opus-mt-ru-en' => (l.modelOpusRuEn, l.modelOpusInfo),
  'waifu2x-cunet-art-2x' => (l.modelW2xCunet, l.modelW2xCunetInfo),
  'waifu2x-swin-art-2x' => (l.modelW2xSwin, l.modelW2xSwinInfo),
  'fatality-comix-4x' => (l.modelFatality, l.modelFatalityInfo),
  _ => (m.displayName, m.purpose),
};

/// What a keyboard shortcut does, as the settings and F1 show it.
String shortcutLabel(AppLocalizations l, ShortcutAction a) => switch (a) {
  ShortcutAction.open => l.keyOpen,
  ShortcutAction.save => l.keySave,
  ShortcutAction.saveAs => l.keySaveAs,
  ShortcutAction.paste => l.keyPaste,
  ShortcutAction.translateAll => l.keyTranslateAll,
  ShortcutAction.previousPage => l.keyPreviousPage,
  ShortcutAction.nextPage => l.keyNextPage,
  ShortcutAction.pan => l.keyPan,
  ShortcutAction.boxes => l.keyBoxes,
  ShortcutAction.text => l.keyText,
  ShortcutAction.brush => l.keyBrush,
  ShortcutAction.eraser => l.keyEraser,
  ShortcutAction.brushSmaller => l.keyBrushSmaller,
  ShortcutAction.brushLarger => l.keyBrushLarger,
  ShortcutAction.undo => l.keyUndo,
  ShortcutAction.redo => l.keyRedo,
  ShortcutAction.deleteBox => l.keyDelete,
  ShortcutAction.deselect => l.keyDeselect,
  ShortcutAction.find => l.keyFind,
  ShortcutAction.help => l.keyHelp,
  ShortcutAction.navigator => l.keyNavigator,
  ShortcutAction.fullScreen => l.keyFullScreen,
};

String shortcutGroupLabel(AppLocalizations l, ShortcutGroup g) => switch (g) {
  ShortcutGroup.files => l.keysGroupFiles,
  ShortcutGroup.tools => l.keysGroupTools,
  ShortcutGroup.edit => l.keysGroupEdit,
  ShortcutGroup.window => l.keysGroupWindow,
};

/// What a model file does, by its file name (`en_PP-OCRv5_rec_mobile_infer.onnx`
/// → "text recognition (english)"); the file name when unknown.
String modelFileLabel(AppLocalizations l, String file) {
  final spec = ModelCatalog.all.where((m) => m.files.any((f) => f.name == file)).firstOrNull;
  return switch (spec) {
    null => file,
    final s when modelGroupOf(s.id) == ModelGroup.language => l.gpuFallbackOcr(modelText(l, s).$1.toLowerCase()),
    final s => modelText(l, s).$1,
  };
}
