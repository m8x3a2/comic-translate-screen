/// Keys: every keyboard shortcut, and a new key for any of them (original
/// `app/ui/settings/shortcuts_page.py`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/key_bindings.dart';
import '../common/labels.dart';
import 'settings_screen.dart' show SettingsGroup;

class KeysSection extends ConsumerWidget {
  const KeysSection({super.key});

  Future<void> _change(BuildContext context, WidgetRef ref, ShortcutAction action, KeyBindings keys) async {
    final chosen = await showDialog<({KeyCombo? combo})>(
      context: context,
      builder: (_) => _KeyCaptureDialog(action: action, keys: keys),
    );
    if (chosen == null) return;
    ref.read(settingsProvider.notifier).change((s) => setShortcut(s, action, chosen.combo));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final keys = KeyBindings.of(settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(l.keysSettingsHelp, style: theme.textTheme.bodyMedium),
        ),
        for (final group in ShortcutGroup.values)
          SettingsGroup(
            title: shortcutGroupLabel(l, group),
            children: [
              for (final action in ShortcutAction.values)
                if (action.group == group)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 4),
                    title: Text(shortcutLabel(l, action)),
                    onTap: () => _change(context, ref, action, keys),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (keys.keysOf(action).isEmpty)
                          Text(l.keysNone, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        for (final combo in keys.keysOf(action)) KeyCap(combo.toString()),
                        IconButton(
                          tooltip: l.keysChange,
                          onPressed: () => _change(context, ref, action, keys),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        SizedBox(
                          width: 40,
                          child: settings.shortcuts.containsKey(action.id)
                              ? IconButton(
                                  tooltip: l.keysDefault,
                                  onPressed: () =>
                                      ref.read(settingsProvider.notifier).change((s) => resetShortcut(s, action)),
                                  icon: const Icon(Icons.restart_alt, size: 20),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

/// A key combination drawn like a key.
class KeyCap extends StatelessWidget {
  const KeyCap(this.text, {super.key, this.large = false});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 8, vertical: large ? 8 : 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(text, style: large ? theme.textTheme.titleMedium : theme.textTheme.labelMedium),
    );
  }
}

/// Waits for a key: returns the combination, `(combo: null)` for "no key",
/// or null when cancelled. Every key goes to it, Esc and F11 included.
class _KeyCaptureDialog extends StatefulWidget {
  const _KeyCaptureDialog({required this.action, required this.keys});

  final ShortcutAction action;
  final KeyBindings keys;

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  KeyCombo? _combo;

  @override
  void initState() {
    super.initState();
    capturingShortcut = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    capturingShortcut = false;
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) {
      final combo = KeyCombo.ofEvent(e, HardwareKeyboard.instance);
      if (combo != null && mounted) setState(() => _combo = combo);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final combo = _combo;
    final taken = combo == null ? null : widget.keys.actionOf(combo);
    final reserved = combo?.reserved ?? false;
    return AlertDialog(
      icon: const Icon(Icons.keyboard_outlined),
      title: Text(l.keysCaptureTitle(shortcutLabel(l, widget.action))),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.keysCaptureBody),
            const SizedBox(height: 16),
            KeyCap(combo?.toString() ?? '…', large: true),
            const SizedBox(height: 12),
            if (reserved)
              Text(l.keysCaptureReserved, style: TextStyle(color: theme.colorScheme.error))
            else if (taken != null && taken != widget.action)
              Text(l.keysCaptureTaken(shortcutLabel(l, taken)), textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, (combo: null)), child: Text(l.keysCaptureNoKey)),
        FilledButton(
          onPressed: combo == null || reserved ? null : () => Navigator.pop(context, (combo: combo)),
          child: Text(l.save),
        ),
      ],
    );
  }
}
