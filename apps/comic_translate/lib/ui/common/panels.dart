/// Panels of the editor window that fold away (the owner's site Learn-words
/// does the same): a "☰" button hides a panel, which leaves a narrow strip
/// with the same button to bring it back. Which panels are hidden is kept in
/// the settings (`ui.hidden_panels`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import 'labels.dart';

/// The panels that fold.
abstract final class Panels {
  static const pages = 'pages';
  static const tools = 'tools';
  static const text = 'text';
}

/// Panel [id] is hidden.
bool panelHidden(WidgetRef ref, String id) => ref.watch(settingsProvider.select((s) => s.hiddenPanels.contains(id)));

/// Hides panel [id] or shows it again.
void togglePanel(WidgetRef ref, String id) => ref.read(settingsProvider.notifier).change((s) {
  if (!s.hiddenPanels.remove(id)) s.hiddenPanels.add(id);
});

/// The "☰" button of panel [id].
class PanelToggle extends ConsumerWidget {
  const PanelToggle(this.id, {super.key, required this.label});

  final String id;

  /// The panel's name, for the tooltip.
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = panelHidden(ref, id);
    return IconButton(
      tooltip: hidden ? context.l10n.panelShow(label) : context.l10n.panelHide(label),
      visualDensity: VisualDensity.compact,
      onPressed: () => togglePanel(ref, id),
      icon: const Icon(Icons.menu),
    );
  }
}

/// What is left of a hidden side panel: a narrow column with the "☰" button
/// and the panel's name written upwards.
class FoldedSidePanel extends StatelessWidget {
  const FoldedSidePanel(this.id, {super.key, required this.label});

  final String id;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          const SizedBox(height: 4),
          PanelToggle(id, label: label),
          const SizedBox(height: 8),
          RotatedBox(
            quarterTurns: 3,
            child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
          ),
        ],
      ),
    );
  }
}

/// What is left of the hidden tool bar: a thin row with the "☰" button.
class FoldedToolBar extends StatelessWidget {
  const FoldedToolBar({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          PanelToggle(Panels.tools, label: label),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}
