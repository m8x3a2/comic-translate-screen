/// The names and words of the project and how to translate them: plain
/// text, kept in the project, for the chat and translators over the
/// network.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
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
  final _search = TextEditingController();
  String? _note;

  /// Lines with a delete button and search, or the text to edit freely.
  bool _asList = true;

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  void _deleteLine(int index) {
    final lines = _text.text.replaceAll('\r\n', '\n').split('\n')..removeAt(index);
    setState(() => _text.text = lines.join('\n'));
  }

  Widget _list(AppLocalizations l, ThemeData theme) {
    final query = _search.text.trim().toLowerCase();
    final lines = _text.text.replaceAll('\r\n', '\n').split('\n');
    final shown = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty && (query.isEmpty || lines[i].toLowerCase().contains(query))) i,
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: l.glossarySearch,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 320,
          child: shown.isEmpty
              ? Center(child: Text(query.isEmpty ? l.glossaryEmptyList : l.glossaryNothing, style: muted))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, k) {
                    final line = lines[shown[k]];
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 13,
                              color: line.trimLeft().startsWith('#') ? theme.colorScheme.onSurfaceVariant : null,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l.glossaryDeleteLine,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteLine(shown[k]),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
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
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, icon: const Icon(Icons.list), label: Text(l.glossaryAsList)),
                ButtonSegment(value: false, icon: const Icon(Icons.edit_note), label: Text(l.glossaryAsText)),
              ],
              selected: {_asList},
              onSelectionChanged: (v) => setState(() => _asList = v.first),
            ),
            const SizedBox(height: 8),
            if (_asList)
              _list(l, theme)
            else
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
