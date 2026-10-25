/// "Export text" (the owner's idea): the dialogues of the chosen pages, the
/// originals and/or the translations, into txt files or the clipboard: to
/// keep, or to give a chat as context.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../state/app_state.dart';
import '../../state/export.dart';
import '../../state/project.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

Future<void> showTextExportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _TextExportDialog());

class _TextExportDialog extends ConsumerStatefulWidget {
  const _TextExportDialog();

  @override
  ConsumerState<_TextExportDialog> createState() => _TextExportDialogState();
}

class _TextExportDialogState extends ConsumerState<_TextExportDialog> {
  late TextExportOptions _o = ref.read(settingsProvider).exchange.textExport;

  // The picked pages are offered; empty: all.
  late final _numbers = TextEditingController(
    text: () {
      final ws = ref.read(workspaceProvider);
      return ws.selectedPages.length < 2
          ? ''
          : pageNumbersText([
              for (final (i, page) in ws.pages.indexed)
                if (ws.selectedPages.contains(page.id)) i,
            ]);
    }(),
  );
  late final _heading = TextEditingController(text: _o.heading);

  /// Which text the preview shows when both are written.
  bool _showTranslation = false;
  String? _note;

  @override
  void dispose() {
    _numbers.dispose();
    _heading.dispose();
    super.dispose();
  }

  /// The pages in the numbers field (all when empty), or the part that is
  /// not a page.
  (List<ExchangePage>?, String?) _pages(WorkspaceState ws) {
    final Set<int> picked;
    try {
      picked = _numbers.text.trim().isEmpty
          ? {for (var i = 0; i < ws.pages.length; i++) i}
          : parsePageNumbers(_numbers.text, ws.pages.length);
    } on FormatException catch (e) {
      return (null, e.message);
    }
    return (
      [
        for (final (i, page) in ws.pages.indexed)
          if (picked.contains(i)) ExchangePage(id: page.id, number: i + 1, name: page.name, blocks: page.blocks),
      ],
      null,
    );
  }

  String _text(List<ExchangePage> pages, {required bool translation}) => exportedText(
    pages,
    translation: translation,
    options: _o,
    heading: _o.heading.trim().isEmpty ? '${context.l10n.textExportPage} $textExportPageNumber' : _o.heading,
  );

  /// Remembers the choices for next time.
  void _remember() =>
      ref.read(settingsProvider.notifier).change((s) => s.exchange = s.exchange.copyWith(textExport: _o));

  /// The name the files start with: the project's, else the chapter's.
  String get _base {
    final ws = ref.read(workspaceProvider);
    final chapter = ws.pages.isEmpty ? '' : chapterOf(ws.pages.first);
    return ref.read(projectProvider).name ?? (chapter.isNotEmpty ? chapter : 'comic');
  }

  Future<void> _save(List<ExchangePage> pages) async {
    final l = context.l10n;
    _remember();
    final parts = [if (_o.part.hasOriginal) false, if (_o.part.hasTranslation) true];
    final written = <String>[];
    if (parts.length == 1) {
      final place = await getSaveLocation(
        suggestedName: textExportName(_base, translation: parts.single),
        acceptedTypeGroups: const [
          XTypeGroup(label: 'txt', extensions: ['txt']),
        ],
      );
      if (place == null || !mounted) return;
      await File(place.path).writeAsString(_text(pages, translation: parts.single));
      written.add(place.path);
    } else {
      // Two files: a folder for them.
      final dir = await getDirectoryPath(confirmButtonText: l.textExportSave);
      if (dir == null || !mounted) return;
      for (final translation in parts) {
        final file = File(p.join(dir, textExportName(_base, translation: translation)));
        await file.writeAsString(_text(pages, translation: translation));
        written.add(file.path);
      }
    }
    if (mounted) setState(() => _note = l.textExportSaved(written.join('\n')));
  }

  Future<void> _copy(String text) async {
    _remember();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _note = context.l10n.textExportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final (pages, wrong) = _pages(ws);
    final both = _o.part == TextExportPart.both;
    final translation = both ? _showTranslation : _o.part == TextExportPart.translation;
    final shown = pages == null ? '' : _text(pages, translation: translation);
    final speakers = ws.pages.any((page) => page.blocks.any((b) => b.speaker != null));
    void change(TextExportOptions o) => setState(() => _o = o);
    Widget check(String label, bool value, TextExportOptions Function(bool v) to) => CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      value: value,
      onChanged: (v) => change(to(v ?? false)),
    );
    final options = [
      TextField(
        controller: _numbers,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: l.pageNumbers,
          hintText: l.pageNumbersHint,
          errorText: wrong == null ? null : l.pageNumbersWrong(wrong, '${ws.pages.length}'),
          helperText: wrong == null
              ? (_numbers.text.trim().isEmpty
                    ? l.textExportAllPages('${ws.pages.length}')
                    : l.textExportSomePages('${pages!.length}'))
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.textExportWhat),
          SegmentedButton<TextExportPart>(
            segments: [
              ButtonSegment(value: TextExportPart.original, label: Text(l.textExportOriginal)),
              ButtonSegment(value: TextExportPart.translation, label: Text(l.textExportTranslation)),
              ButtonSegment(value: TextExportPart.both, label: Text(l.textExportBoth)),
            ],
            selected: {_o.part},
            onSelectionChanged: (v) => change(_o.copyWith(part: v.first)),
          ),
        ],
      ),
      if (both)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.textExportTwoFiles, style: theme.textTheme.bodySmall),
        ),
      const SizedBox(height: 4),
      check(l.textExportLabels, _o.labels, (v) => _o.copyWith(labels: v)),
      if (speakers) check(l.textExportSpeakers, _o.speakers, (v) => _o.copyWith(speakers: v)),
      check(l.textExportHeadings, _o.headings, (v) => _o.copyWith(headings: v)),
      if (_o.headings)
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 8),
          child: TextField(
            controller: _heading,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l.textExportHeading,
              hintText: '${l.textExportPage} $textExportPageNumber',
              helperText: l.textExportHeadingHelp(textExportPageNumber, textExportPageName),
              helperMaxLines: 2,
            ),
            onChanged: (v) => change(_o.copyWith(heading: v)),
          ),
        ),
    ];
    // Wide windows: the preview beside the choices, as tall as they are.
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final preview = [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(l.textExportPreview, style: theme.textTheme.titleSmall),
          ),
          if (both) ...[
            ChoiceChip(
              label: Text(l.textExportOriginal),
              selected: !_showTranslation,
              onSelected: (_) => setState(() => _showTranslation = false),
            ),
            ChoiceChip(
              label: Text(l.textExportTranslation),
              selected: _showTranslation,
              onSelected: (_) => setState(() => _showTranslation = true),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Container(
        height: wide ? 380 : 220,
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            shown.trim().isEmpty ? l.textExportEmpty : shown,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
        ),
      ),
      if (_note != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
        ),
    ];
    Widget column(List<Widget> children) =>
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);
    return AlertDialog(
      title: Text(l.textExportTitle),
      content: SizedBox(
        width: wide ? 1000 : 720,
        child: SingleChildScrollView(
          child: column([
            Text(l.textExportHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 440, child: column(options)),
                  const SizedBox(width: 24),
                  Expanded(child: column(preview)),
                ],
              )
            else ...[
              ...options,
              const SizedBox(height: 8),
              ...preview,
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
        TextButton.icon(
          onPressed: pages == null || pages.isEmpty ? null : () => _copy(shown),
          icon: const Icon(Icons.copy),
          label: Text(both ? l.textExportCopyShown : l.textExportCopy),
        ),
        FilledButton.icon(
          onPressed: pages == null || pages.isEmpty ? null : () => _save(pages),
          icon: const Icon(Icons.save_alt),
          label: Text(l.textExportSave),
        ),
      ],
    );
  }
}
