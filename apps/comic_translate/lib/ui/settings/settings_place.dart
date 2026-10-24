/// Where the settings open (the owner's idea): over the whole window, or as
/// a panel beside the page, so a change shows on the page at once. A button
/// in the settings switches between the two. While the app runs they open
/// as they were left; after a restart as chosen in the settings (over the
/// whole window unless changed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import 'settings_screen.dart';

/// The settings panel beside the page: its section, or null when closed.
final settingsPanelProvider = NotifierProvider<SettingsPanel, SettingsSection?>(SettingsPanel.new);

class SettingsPanel extends Notifier<SettingsSection?> {
  /// How the settings were shown last while the app runs (null: not
  /// switched yet).
  bool? asPanelNow;

  @override
  SettingsSection? build() => null;

  void show(SettingsSection section) => state = section;

  void close() => state = null;
}

bool _asPanel(WidgetRef ref) {
  final now = ref.read(settingsPanelProvider.notifier).asPanelNow;
  if (now != null) return now;
  final s = ref.read(settingsProvider);
  return s.settingsView == 'panel' || (s.settingsView == 'last' && s.settingsLastView == 'panel');
}

Route<void> _fullWindow(SettingsSection section) =>
    MaterialPageRoute<void>(builder: (_) => SettingsScreen(initial: section));

/// Opens the settings at [section], over the whole window or as the panel.
void openSettings(BuildContext context, WidgetRef ref, [SettingsSection section = SettingsSection.general]) {
  if (_asPanel(ref)) {
    ref.read(settingsPanelProvider.notifier).show(section);
  } else {
    Navigator.of(context).push(_fullWindow(section));
  }
}

/// The open settings from the whole window to the panel or back, staying at
/// [section]; remembered.
void switchSettingsView(
  BuildContext context,
  WidgetRef ref, {
  required bool toPanel,
  required SettingsSection section,
}) {
  final panel = ref.read(settingsPanelProvider.notifier)..asPanelNow = toPanel;
  ref.read(settingsProvider.notifier).change((s) => s.settingsLastView = toPanel ? 'panel' : 'full');
  if (toPanel) {
    Navigator.of(context).pop();
    panel.show(section);
  } else {
    final navigator = Navigator.of(context);
    panel.close();
    navigator.push(_fullWindow(section));
  }
}
