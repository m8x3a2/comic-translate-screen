/// Words for values shown in several places: stages, skip reasons,
/// durations, languages, privacy.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/workspace.dart';

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
enum ModelGroup { core, language, extra }

ModelGroup modelGroupOf(String id) => switch (id) {
  'rtdetr-v2-int8' || 'aot-inpainting' => ModelGroup.core,
  'ppocr-v5-rec-en' ||
  'ppocr-v5-rec-latin' ||
  'ppocr-v5-rec-eslav' ||
  'ppocr-v5-rec-korean' ||
  'ppocr-v6-rec-small' ||
  'manga-ocr-mobile' ||
  'osd-script-id' => ModelGroup.language,
  _ => ModelGroup.extra,
};

/// Short name and explanation of a model, in the interface language.
(String title, String info) modelText(AppLocalizations l, ModelSpec m) => switch (m.id) {
  'rtdetr-v2-int8' => (l.modelDetector, l.modelDetectorInfo),
  'aot-inpainting' => (l.modelAot, l.modelAotInfo),
  'lama-manga' => (l.modelLama, l.modelLamaInfo),
  'ppocr-v5-rec-en' => (l.modelOcrEn, l.modelOcrEnInfo),
  'ppocr-v5-rec-latin' => (l.modelOcrLatin, l.modelOcrLatinInfo),
  'ppocr-v5-rec-eslav' => (l.modelOcrEslav, l.modelOcrEslavInfo),
  'ppocr-v5-rec-korean' => (l.modelOcrKorean, l.modelOcrKoreanInfo),
  'ppocr-v6-rec-small' => (l.modelOcrChinese, l.modelOcrChineseInfo),
  'manga-ocr-mobile' => (l.modelOcrJapanese, l.modelOcrJapaneseInfo),
  'osd-script-id' => (l.modelOsd, l.modelOsdInfo),
  _ => (m.displayName, m.purpose),
};
