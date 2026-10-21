/// The list of keyboard shortcuts and mouse actions (F1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/key_bindings.dart';
import '../common/labels.dart';

Future<void> showShortcuts(BuildContext context) {
  final l = context.l10n;
  final keys = KeyBindings.of(ProviderScope.containerOf(context, listen: false).read(settingsProvider));
  List<(String, String)> rows(ShortcutGroup group) => [
    for (final a in ShortcutAction.values)
      if (a.group == group) (keys.labelOf(a).isEmpty ? '—' : keys.labelOf(a), shortcutLabel(l, a)),
  ];
  final groups = [
    (l.keysGroupFiles, rows(ShortcutGroup.files)),
    (l.keysGroupTools, rows(ShortcutGroup.tools)),
    (l.keysGroupEdit, [...rows(ShortcutGroup.edit), ('Enter / Shift+Enter', l.keyFindNext)]),
    (
      l.keysGroupMouse,
      [
        (l.mouseWheel, l.mouseWheelHelp),
        (l.mouseWheel, l.mouseWheelStrip),
        (l.mouseMiddle, l.mouseMiddleHelp),
        (l.mouseGrab, l.mouseMiddleHelp),
        (l.mouseDouble, l.mouseDoubleHelp),
        (l.mousePickPages, l.keyPickPages),
      ],
    ),
    (l.keysGroupWindow, rows(ShortcutGroup.window)),
  ];
  return showDialog<void>(
    context: context,
    builder: (c) {
      final theme = Theme.of(c);
      return AlertDialog(
        icon: const Icon(Icons.keyboard_outlined),
        title: Text(l.shortcutsTitle),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (title, rows) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  for (final (keys, what) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 190,
                            child: Text(keys, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: Text(what, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Text(l.keysNote, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.close))],
      );
    },
  );
}
