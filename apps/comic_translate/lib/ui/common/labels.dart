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

String reasonLabel(AppLocalizations l, SkipReason? reason) => switch (reason) {
  ModelMissingReason(:final model) => l.reasonModelMissing(model),
  TranslationFailedReason(:final message) => l.reasonTranslation(message),
  UnreadableImageReason() => l.reasonImage,
  OtherReason(:final message) => message,
  null => '',
};

/// `1:05`, `12:30`, `1:02:03`.
String formatDuration(Duration d) {
  final s = d.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return s >= 3600 ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}' : '${s ~/ 60}:${two(s % 60)}';
}

/// Languages are shown in their own script: «Русский», «日本語».
String languageLabel(String name) => Languages.byName(name)?.nativeLabel ?? name;

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
