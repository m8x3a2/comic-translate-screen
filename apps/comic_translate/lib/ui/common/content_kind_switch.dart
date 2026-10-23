/// "Comics / Sites and games": what the pages are, which decides how text is
/// found (speech bubbles or lines of ordinary text). The same setting in the
/// editor's tool bar (icons) and in the settings (with labels).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import 'labels.dart';

class ContentKindSwitch extends ConsumerWidget {
  const ContentKindSwitch({super.key, this.compact = false, this.onSwitched});

  /// Icons only, the labels in tooltips.
  final bool compact;

  /// Called after the user switched the kind.
  final void Function(ContentKind kind)? onSwitched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final kind = ref.watch(settingsProvider.select((s) => s.contentKind));
    ButtonSegment<ContentKind> segment(ContentKind k, IconData icon, String label, String help) => ButtonSegment(
      value: k,
      icon: Icon(icon, size: 18),
      label: compact ? null : Text(label),
      tooltip: '$label — $help',
    );
    return SegmentedButton<ContentKind>(
      segments: [
        segment(ContentKind.comics, Icons.auto_stories_outlined, l.contentComics, l.contentComicsHelp),
        segment(ContentKind.screens, Icons.web_outlined, l.contentScreens, l.contentScreensHelp),
      ],
      selected: {kind},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        ref.read(settingsProvider.notifier).change((x) => x.contentKind = s.first);
        onSwitched?.call(s.first);
      },
    );
  }
}
