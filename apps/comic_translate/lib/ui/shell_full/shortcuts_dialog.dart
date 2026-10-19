/// The list of keyboard shortcuts and mouse actions (F1).
library;

import 'package:flutter/material.dart';

import '../common/labels.dart';

Future<void> showShortcuts(BuildContext context) {
  final l = context.l10n;
  final groups = [
    (l.keysGroupFiles, [
      ('Ctrl+O', l.keyOpen),
      ('Ctrl+Enter', l.keyTranslateAll),
      ('PageUp / PageDown', l.keyPages),
    ]),
    (l.keysGroupTools, [
      ('H, V', l.keyPan),
      ('R', l.keyBoxes),
      ('T', l.keyText),
      ('B', l.keyBrush),
      ('E', l.keyEraser),
      ('[  ]', l.keyBrushSize),
    ]),
    (l.keysGroupEdit, [
      ('Ctrl+Z', l.keyUndo),
      ('Ctrl+Y, Ctrl+Shift+Z', l.keyRedo),
      ('Delete', l.keyDelete),
      ('Esc', l.keyDeselect),
      ('Ctrl+F', l.keyFind),
      ('Enter / Shift+Enter', l.keyFindNext),
    ]),
    (l.keysGroupMouse, [
      (l.mouseWheel, l.mouseWheelHelp),
      (l.mouseMiddle, l.mouseMiddleHelp),
      (l.mouseDouble, l.mouseDoubleHelp),
    ]),
    (l.keysGroupWindow, [
      ('F1', l.keyHelp),
      ('F11', l.keyFullScreen),
    ]),
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
