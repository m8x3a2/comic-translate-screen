/// The names and words of the project and how to translate them: plain
/// text, kept in the project, for the chat and translators over the
/// network.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/workspace.dart';
import '../common/labels.dart';

/// Edits the glossary of the open project. True when it changed.
Future<bool> showGlossaryDialog(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const _GlossaryDialog()) ?? false;

class _GlossaryDialog extends ConsumerStatefulWidget {
  const _GlossaryDialog();

  @override
  ConsumerState<_GlossaryDialog> createState() => _GlossaryDialogState();
}

class _GlossaryDialogState extends ConsumerState<_GlossaryDialog> {
  late final _text = TextEditingController(text: ref.read(workspaceProvider).glossary);
  String? _note;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'txt', extensions: ['txt', 'md']),
      ],
    );
    if (file == null) return;
    final text = await File(file.path).readAsString();
    if (!mounted) return;
    setState(() => _text.text = text);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final place = await getSaveLocation(
      suggestedName: 'glossary.txt',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'txt', extensions: ['txt']),
      ],
    );
    if (place == null) return;
    await File(place.path).writeAsString(_text.text);
    if (mounted) setState(() => _note = l.glossarySaved(place.path));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final g = Glossary.parse(_text.text);
    return AlertDialog(
      title: Text(l.glossaryTitle),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.glossaryHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 10,
              maxLines: 18,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
              decoration: InputDecoration(hintText: l.glossaryHint, border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(l.glossaryCounts(g.entries.length, g.notes.length), style: theme.textTheme.bodySmall),
            if (_note != null)
              Text(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
      actions: [
        TextButton.icon(onPressed: _load, icon: const Icon(Icons.file_open_outlined), label: Text(l.glossaryLoad)),
        TextButton.icon(onPressed: _save, icon: const Icon(Icons.save_alt), label: Text(l.glossarySave)),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final changed = _text.text != ref.read(workspaceProvider).glossary;
            ref.read(workspaceProvider.notifier).setGlossary(_text.text);
            Navigator.pop(context, changed);
          },
          child: Text(l.glossaryApply),
        ),
      ],
    );
  }
}
