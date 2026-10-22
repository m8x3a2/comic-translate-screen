/// The exchange window: pictures and instructions for a chat AI (ChatGPT,
/// Gemini, Claude…), then the chat's answer pasted back and written into
/// the pages.
library;

import 'dart:async';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../services/file_clipboard.dart';
import '../../state/app_state.dart';
import '../../state/exchange.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import 'main_screen.dart' show showInExplorer;

/// Opens the exchange window for [request]; with [existing], the folder of
/// an earlier exchange is opened instead of writing a new one. True when
/// the answer was applied.
Future<bool> showExchangeDialog(BuildContext context, ExchangeRequest request, {ExchangeManifest? existing}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExchangeDialog(request: request, existing: existing),
    ) ??
    false;

class ExchangeDialog extends ConsumerStatefulWidget {
  const ExchangeDialog({super.key, required this.request, this.existing});

  final ExchangeRequest request;
  final ExchangeManifest? existing;

  @override
  ConsumerState<ExchangeDialog> createState() => _ExchangeDialogState();
}

class _ExchangeDialogState extends ConsumerState<ExchangeDialog> {
  late ExchangeMode _mode = widget.existing?.mode ?? widget.request.mode;
  ExchangeExport? _export;
  Object? _exportError;
  var _exporting = false;
  var _again = false;
  Timer? _debounce;

  final _groups = TextEditingController();
  String? _groupsError;

  final _answer = TextEditingController();
  ExchangeMatch? _match;

  /// The answer came from the text files of the folder.
  List<String>? _fromFiles;

  /// What the last copy did.
  String? _note;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _export = existing.export;
    } else {
      unawaited(_rebuild());
    }
    _answer.addListener(_parse);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _groups.dispose();
    _answer.dispose();
    super.dispose();
  }

  List<ExchangePage> get _pages => exchangePages(ref.read(workspaceProvider), widget.request);

  /// Writes the exchange folder again (options changed).
  Future<void> _rebuild() async {
    if (_exporting) {
      _again = true;
      return;
    }
    final settings = ref.read(settingsProvider);
    final pages = _pages;
    final count = exchangeItems(pages, _mode).length;
    List<List<int>> groups = const [];
    try {
      groups = parseSheetGroups(_groups.text, count);
      _groupsError = null;
    } on FormatException catch (e) {
      setState(() => _groupsError = context.l10n.chatGroupsError(e.message, count));
    }
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final dir = newExchangeDir(ref.read(servicesProvider).paths);
      final out = await exportExchange(dir, ref.read(workspaceProvider), pages, _mode, settings, groups: groups);
      if (!mounted) return;
      setState(() {
        _export = out;
        _note = null;
      });
      _parse();
    } catch (e, st) {
      ref.read(servicesProvider).appLog.error('exchange_export_failed', e, st);
      if (mounted) setState(() => _exportError = e);
    } finally {
      if (mounted) setState(() => _exporting = false);
      if (_again && mounted) {
        _again = false;
        unawaited(_rebuild());
      }
    }
  }

  void _rebuildSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => unawaited(_rebuild()));
  }

  Future<void> _changeOptions(ExchangeSettings Function(ExchangeSettings s) change) async {
    await ref.read(settingsProvider.notifier).change((s) => s.exchange = change(s.exchange));
    _rebuildSoon();
  }

  void _parse() {
    final export = _export;
    if (export == null) return;
    final text = _answer.text;
    setState(() {
      _fromFiles = null;
      _match = text.trim().isEmpty
          ? null
          : matchExchangeAnswer(export.items, parseExchangeAnswer(text, export.mode), export.mode);
    });
  }

  Future<void> _fromTextFiles() async {
    final export = _export;
    if (export == null) return;
    final dir = Directory(export.dir);
    final match = await readExchangeFolder(dir, await ExchangeManifest.read(dir));
    if (!mounted) return;
    _answer.removeListener(_parse);
    _answer.clear();
    _answer.addListener(_parse);
    setState(() {
      _match = match;
      _fromFiles = {...match.sources.values}.toList()..sort();
    });
  }

  Future<void> _openTxt() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'txt', extensions: ['txt', 'md']),
      ],
    );
    if (file == null) return;
    _answer.text = await File(file.path).readAsString();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final text?) _answer.text = text;
  }

  void _copyPictures(List<String> files) {
    final export = _export;
    if (export == null) return;
    final l = context.l10n;
    final ok = copyFilesToClipboard([for (final f in files) p.join(export.dir, f)]);
    setState(
      () => _note = ok
          ? (files.length == 1 ? l.chatCopiedOne(p.basename(files.single)) : l.chatCopiedPictures(files.length))
          : l.chatCopyFailed,
    );
  }

  Future<void> _copyPrompt() async {
    final export = _export;
    if (export == null) return;
    await Clipboard.setData(ClipboardData(text: export.prompt));
    if (mounted) setState(() => _note = context.l10n.chatCopiedPrompt);
  }

  void _apply() {
    final export = _export, match = _match;
    if (export == null || match == null) return;
    final settings = ref.read(settingsProvider);
    final result = applyExchange(
      ref.read(workspaceProvider.notifier),
      ref.read(workspaceProvider),
      export.items,
      match,
      export.mode,
      placeholder: settings.exchange.placeholder,
    );
    ref.read(servicesProvider).appLog.child(stage: 'exchange').info('exchange_applied', {
      'mode': export.mode.name,
      'found': match.replies.length,
      'missing': match.missing.length,
      'changed': result.changed,
      'lost': result.lost.length,
    });
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context, true);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          [l.chatApplied(result.changed), if (result.lost.isNotEmpty) l.chatLost(_codes(result.lost))].join('\n'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final export = _export;
    final existing = widget.existing != null;
    final pages = existing ? widget.existing!.pages.length : widget.request.pageIds.length;
    final count = export?.items.length ?? (existing ? 0 : exchangeItems(_pages, _mode).length);
    final canApply = export != null && (_match?.replies.isNotEmpty ?? false);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 860),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.chatTitle, style: theme.textTheme.titleLarge)),
                  if (!widget.request.fromRun && !existing)
                    SegmentedButton<ExchangeMode>(
                      segments: [
                        ButtonSegment(value: ExchangeMode.both, label: Text(l.chatModeBoth)),
                        ButtonSegment(value: ExchangeMode.recognize, label: Text(l.chatModeRecognize)),
                        ButtonSegment(value: ExchangeMode.translate, label: Text(l.chatModeTranslate)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) {
                        setState(() {
                          _mode = s.first;
                          _match = null;
                        });
                        unawaited(_rebuild());
                      },
                    )
                  else
                    Chip(label: Text(_modeLabel(l, _mode))),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.chatSubtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(l.chatPieces(count, pages), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    // Wide: what to send and the answer side by side, both in sight.
                    builder: (context, c) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Room for the floating labels of the fields.
                        if (!existing) Padding(padding: const EdgeInsets.only(top: 8), child: _options(l)),
                        const SizedBox(height: 12),
                        if (c.maxWidth >= 1000)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _sendCard(l, theme)),
                              const SizedBox(width: 12),
                              Expanded(child: _answerCard(l, theme)),
                            ],
                          )
                        else ...[
                          _sendCard(l, theme),
                          const SizedBox(height: 12),
                          _answerCard(l, theme),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (export != null)
                    TextButton.icon(
                      onPressed: () => showInExplorer(export.dir),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l.chatOpenFolder),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: canApply ? _apply : null,
                    icon: const Icon(Icons.check),
                    label: Text(widget.request.fromRun ? l.chatApplyContinue : l.chatApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _options(AppLocalizations l) {
    final s = ref.watch(settingsProvider.select((s) => s.exchange));
    final sheets = _mode.sendsImages;
    Widget dropdown<T>(String label, T value, Map<T, String> items, void Function(T v) onChanged) => SizedBox(
      width: 200,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sheets) ...[
          dropdown(l.chatSheets, s.grouping, {
            SheetGrouping.size: l.chatGroupingSize,
            SheetGrouping.count: l.chatGroupingCount,
          }, (v) => _changeOptions((e) => e.copyWith(grouping: v))),
          if (s.grouping == SheetGrouping.count)
            dropdown(l.chatPerSheet, s.perSheet, {
              for (final n in {2, 4, 6, 8, 10, 12, 16, 20, 30, s.perSheet}.toList()..sort()) n: '$n',
            }, (v) => _changeOptions((e) => e.copyWith(perSheet: v))),
          dropdown(l.chatSheetSize, s.sheetMaxPx, {
            for (final n in {1200, 1600, 2000, 2400, 3000, s.sheetMaxPx}.toList()..sort()) n: '$n px',
          }, (v) => _changeOptions((e) => e.copyWith(sheetMaxPx: v))),
        ],
        dropdown(l.chatContextImage, s.contextImage, {
          ContextImage.off: l.chatContextOff,
          ContextImage.separate: l.chatContextSeparate,
          if (sheets) ContextImage.onSheet: l.chatContextOnSheet,
        }, (v) => _changeOptions((e) => e.copyWith(contextImage: v))),
        if (sheets) ...[
          SizedBox(
            width: 200,
            child: TextField(
              controller: _groups,
              decoration: InputDecoration(
                labelText: l.chatGroups,
                hintText: l.chatGroupsHint,
                errorText: _groupsError,
                errorMaxLines: 3,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _rebuildSoon(),
            ),
          ),
          FilterChip(
            label: Text(l.chatSheetPerPage),
            selected: s.sheetPerPage,
            onSelected: (v) => _changeOptions((e) => e.copyWith(sheetPerPage: v)),
          ),
        ],
      ],
    );
  }

  Widget _sendCard(AppLocalizations l, ThemeData theme) {
    final export = _export;
    final pictures = export?.pictures ?? const <String>[];
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chatStep1, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(pictures.isEmpty ? l.chatStep1TextHelp : l.chatStep1Help, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (_exporting && export == null)
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(l.chatPreparing),
                ],
              )
            else if (_exportError != null)
              Text(l.chatExportFailed('$_exportError'), style: TextStyle(color: theme.colorScheme.error))
            else if (export != null && export.items.isEmpty)
              Text(l.chatNoPieces, style: TextStyle(color: theme.colorScheme.error))
            else if (export != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (pictures.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => _copyPictures(pictures),
                      icon: const Icon(Icons.collections_outlined),
                      label: Text(l.chatCopyPictures(pictures.length)),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _copyPrompt,
                    icon: const Icon(Icons.content_copy),
                    label: Text(l.chatCopyPrompt),
                  ),
                  if (_exporting)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              if (_note != null) ...[
                const SizedBox(height: 8),
                Text(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
              ],
              if (pictures.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pictures.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _Thumb(
                      file: p.join(export.dir, pictures[i]),
                      name: pictures[i],
                      tooltip: l.chatCopyOne,
                      onTap: () => _copyPictures([pictures[i]]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.chatShowPrompt, style: theme.textTheme.bodyMedium),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: theme.colorScheme.surfaceContainerHighest,
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(child: SelectableText(export.prompt)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _answerCard(AppLocalizations l, ThemeData theme) {
    final match = _match;
    final total = _export?.items.length ?? 0;
    final warn = TextStyle(color: theme.colorScheme.error);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chatStep2, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (match != null) ...[
              const SizedBox(height: 4),
              Text(
                l.chatFound(match.replies.length, total),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: match.replies.length == total ? Colors.green.shade600 : null,
                ),
              ),
              if (_fromFiles case final files? when files.isNotEmpty) Text(l.chatFromFilesNote(files.join(', '))),
              if (match.missing.isNotEmpty) Text(l.chatMissing(_codes(match.missing)), style: warn),
              if (match.unknown.isNotEmpty) Text(l.chatUnknown(_codes(match.unknown)), style: warn),
              if (match.missingArrow.isNotEmpty) Text(l.chatNoArrow(_codes(match.missingArrow)), style: warn),
              if (match.repeated.isNotEmpty) Text(l.chatRepeated(_codes(match.repeated))),
            ],
            if (match != null) const SizedBox(height: 8),
            TextField(
              controller: _answer,
              minLines: 6,
              maxLines: 9,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
              decoration: InputDecoration(
                hintText: _mode == ExchangeMode.both ? l.chatAnswerHintBoth : l.chatAnswerHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: Text(l.chatPaste)),
                Tooltip(
                  message: l.chatFromFilesHelp,
                  child: OutlinedButton.icon(
                    onPressed: _export == null ? null : _fromTextFiles,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l.chatFromFiles),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openTxt,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(l.chatOpenTxt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _codes(List<ExchangeLabel> labels) {
  const most = 20;
  final shown = [for (final l in labels.take(most)) l.code].join(', ');
  return labels.length > most ? '$shown … (+${labels.length - most})' : shown;
}

String _modeLabel(AppLocalizations l, ExchangeMode mode) => switch (mode) {
  ExchangeMode.both => l.chatModeBoth,
  ExchangeMode.recognize => l.chatModeRecognize,
  ExchangeMode.translate => l.chatModeTranslate,
};

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.name, required this.tooltip, required this.onTap});

  final String file;
  final String name;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            Container(
              height: 108,
              constraints: const BoxConstraints(minWidth: 60, maxWidth: 220),
              decoration: BoxDecoration(border: Border.all(color: theme.dividerColor)),
              child: Image.file(File(file), fit: BoxFit.contain, cacheHeight: 216),
            ),
            const SizedBox(height: 4),
            Text(name, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
