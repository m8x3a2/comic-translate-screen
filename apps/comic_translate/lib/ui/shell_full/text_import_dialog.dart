/// "Load text" (the owner's idea, the pair of "Export text"): a chat's answer
/// to the exported text, pasted or from a txt file, goes into the bubbles by
/// its labels. What changes is shown before "Apply"; Ctrl+Z undoes it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/exchange.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

Future<void> showTextImportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const TextImportDialog());

class TextImportDialog extends ConsumerStatefulWidget {
  const TextImportDialog({super.key});

  @override
  ConsumerState<TextImportDialog> createState() => _TextImportDialogState();
}

class _TextImportDialogState extends ConsumerState<TextImportDialog> {
  final _text = TextEditingController();
  TextImportTarget _target = TextImportTarget.translation;
  String? _error;
  bool _applying = false;

  // The last reading, kept while the text, the target and the pages stay.
  (String, TextImportTarget, List<PageEntry>)? _readFor;
  TextImport? _read;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// All pages of the project, numbered as the labels count them.
  static List<ExchangePage> _pages(WorkspaceState ws) => [
    for (final (i, page) in ws.pages.indexed)
      ExchangePage(id: page.id, number: i + 1, name: page.name, blocks: page.blocks),
  ];

  TextImport? _reading(WorkspaceState ws) {
    final text = _text.text;
    if (text.trim().isEmpty) return null;
    final key = (text, _target, ws.pages);
    if (_readFor case (final t, final g, final p) when t == text && g == _target && identical(p, ws.pages)) {
      return _read;
    }
    final options = ref.read(settingsProvider).exchange;
    final heading = options.textExport.heading.trim().isEmpty
        ? '${context.l10n.textExportPage} $textExportPageNumber'
        : options.textExport.heading;
    _readFor = key;
    return _read = readTextImport(
      _pages(ws),
      text,
      _target,
      heading: heading,
      separator: options.separator,
      marks: options.answerMarks,
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || !mounted) return;
    setState(() {
      _text.text = text;
      _error = null;
    });
  }

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'txt', extensions: ['txt', 'md']),
      ],
    );
    if (file == null || !mounted) return;
    try {
      final bytes = await File(file.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _text.text = utf8.decode(bytes, allowMalformed: true);
        _error = null;
      });
    } on FileSystemException catch (e) {
      if (mounted) setState(() => _error = context.l10n.textImportFileError(e.osError?.message ?? e.message));
    }
  }

  Future<void> _apply(TextImport read) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _applying = true);
    final result = await applyExchange(
      ref.read(workspaceProvider.notifier),
      ref.read(workspaceProvider),
      read.items,
      read.match,
      _target.mode,
    );
    if (!mounted) return;
    Navigator.pop(context);
    messenger?.showSnackBar(SnackBar(content: Text(l.textImportApplied('${result.changed}')), showCloseIcon: true));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final read = _reading(ws);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final small = theme.textTheme.bodySmall;

    final input = [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.textImportTarget),
          SegmentedButton<TextImportTarget>(
            segments: [
              ButtonSegment(value: TextImportTarget.translation, label: Text(l.textImportToTranslation)),
              ButtonSegment(value: TextImportTarget.original, label: Text(l.textImportToOriginal)),
            ],
            selected: {_target},
            onSelectionChanged: (v) => setState(() => _target = v.first),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(l.textImportArrowHint, style: small),
      ),
      TextField(
        controller: _text,
        minLines: wide ? 16 : 8,
        maxLines: wide ? 16 : 8,
        style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: l.textImportAnswer,
          alignLabelWithHint: true,
          errorText: _error,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: Text(l.textImportPaste)),
          OutlinedButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l.textImportOpen),
          ),
        ],
      ),
    ];

    final String status;
    if (read == null) {
      status = l.textImportEmpty;
    } else if (!read.labelsFound) {
      status = l.textImportNoLabels;
    } else {
      status = l.textImportSummary('${read.answered}', '${read.changes.length}', '${read.missing.length}');
    }
    final unknown = read?.unknown ?? const <ExchangeLabel>[];
    final changes = read?.changes ?? const <TextImportChange>[];
    final list = [
      Text(l.textImportChanges, style: theme.textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(status, style: small?.copyWith(color: read != null && !read.labelsFound ? theme.colorScheme.error : null)),
      if (unknown.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l.textImportUnknown(unknown.take(12).join(' ') + (unknown.length > 12 ? ' …' : '')),
            style: small?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      const SizedBox(height: 8),
      Container(
        height: wide ? 380 : 220,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: read != null && read.labelsFound && changes.isEmpty
            ? Center(child: Text(l.textImportNothing, style: small))
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: changes.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (_, i) => _ChangeRow(change: changes[i]),
              ),
      ),
    ];

    Widget column(List<Widget> children) =>
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);
    return AlertDialog(
      title: Text(l.textImportTitle),
      content: SizedBox(
        width: wide ? 1000 : 720,
        child: SingleChildScrollView(
          child: column([
            Text(l.textImportHelp, style: small),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(input)),
                  const SizedBox(width: 24),
                  Expanded(child: column(list)),
                ],
              )
            else ...[
              ...input,
              const SizedBox(height: 16),
              ...list,
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
        FilledButton.icon(
          onPressed: changes.isEmpty || _applying ? null : () => _apply(read!),
          icon: const Icon(Icons.check),
          label: Text(l.textImportApply),
        ),
      ],
    );
  }
}

/// `[02-003]` and what changes: the text and/or the translation, was → will be.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final TextImportChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = change.before, a = change.after;
    final old = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    Widget pair(String before, String after) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (before.trim().isNotEmpty) Text(before, style: old),
        Text('→ $after'),
      ],
    );
    final speaker = a.speaker != b.speaker && a.speaker != null ? ' [${a.speaker!.tag}]' : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text('${change.label}$speaker', style: const TextStyle(fontFamily: 'Consolas', fontSize: 13)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.text != b.text) pair(b.text, a.text),
              if (a.translation != b.translation) pair(b.translation, a.translation),
            ],
          ),
        ),
      ],
    );
  }
}
