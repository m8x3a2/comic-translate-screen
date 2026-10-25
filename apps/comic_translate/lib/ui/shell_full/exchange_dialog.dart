/// The exchange window: pictures and instructions for a chat AI (ChatGPT,
/// Gemini, Claude…), then the chat's answer pasted back and written into
/// the pages.
library;

import 'dart:async';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../services/file_clipboard.dart';
import '../../state/app_state.dart';
import '../../state/exchange.dart';
import '../../state/workspace.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../settings/settings_screen.dart';
import 'exchange_gallery.dart';
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

class _ExchangeDialogState extends ConsumerState<ExchangeDialog> with WidgetsBindingObserver {
  late ExchangeMode _mode = widget.existing?.mode ?? widget.request.mode;

  /// The folder as written; the large view follows it.
  final _shown = ValueNotifier<ExchangeExport?>(null);
  ExchangeExport? get _export => _shown.value;
  set _export(ExchangeExport? export) => _shown.value = export;
  Object? _exportError;
  var _exporting = false;
  var _again = false;
  Timer? _debounce;

  /// One folder for this window: the pictures are made again in it when
  /// the options change, so what was copied never disappears.
  Directory? _dir;

  /// What the text files were written for: they are written again only
  /// when it changes (the user may have written into them).
  String? _textsKey;

  final _groups = TextEditingController();
  String? _groupsError;

  /// The instructions, changed by the user for this time or not.
  final _prompt = TextEditingController();
  var _promptChanged = false;

  /// Pictures picked for copying (file names); none: all of them.
  final _selected = <String>{};
  final _strip = ScrollController();

  /// The answer; with two fields, [_answer] holds the originals and
  /// [_answer2] the translations.
  final _answer = TextEditingController();
  final _answer2 = TextEditingController();
  ExchangeMatch? _match;

  /// The answer came from the text files of the folder.
  List<String>? _fromFiles;

  /// What the last copy did.
  String? _note;

  /// [_note] stays when the pictures are made again (it tells why).
  var _keepNote = false;

  /// The pictures of one page only (its number in the labels); null: all.
  /// The same in the large view.
  final _page = ValueNotifier<int?>(null);

  /// What this window put into the clipboard (not an answer to offer).
  String? _copied;

  /// An answer of the chat found in the clipboard and how many pieces it
  /// has; [_seen]: offered already (pasted or closed).
  String? _offer;
  var _offerFound = 0;
  String? _seen;

  ExchangeSettings get _options => ref.read(settingsProvider).exchange;

  /// Two answer fields: reading and translating in one message, as two lists.
  bool get _twoFields => _mode == ExchangeMode.both && _options.apart;

  String get _separator => widget.existing?.separator ?? _options.separator;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _export = existing.export;
      _prompt.text = existing.export?.prompt ?? '';
      _dir = Directory(existing.export?.dir ?? '');
    } else {
      unawaited(_rebuild());
    }
    _answer.addListener(_parse);
    _answer2.addListener(_parse);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _shown.dispose();
    _page.dispose();
    _groups.dispose();
    _prompt.dispose();
    _strip.dispose();
    _answer.dispose();
    _answer2.dispose();
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
      final dir = _dir ??= newExchangeDir(ref.read(servicesProvider).paths);
      final e = settings.exchange;
      final textsKey = '${_mode.name}|${e.splitFiles}|${e.textFiles.name}';
      final out = await exportExchange(
        dir,
        ref.read(workspaceProvider),
        pages,
        _mode,
        settings,
        groups: groups,
        keepTexts: textsKey == _textsKey,
        promptText: _promptChanged ? _prompt.text : null,
      );
      _textsKey = textsKey;
      if (!mounted) return;
      // The same image files are written again: every size of them shown
      // before is forgotten (the pictures are keyed by [out], so they load
      // again).
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      setState(() {
        _export = out;
        // What was copied is gone; why the sheets changed stays once.
        _note = _keepNote ? _note : null;
        _keepNote = false;
        _selected.removeWhere((f) => !out.pictures.contains(f));
        if (!_promptChanged) _prompt.text = out.prompt;
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

  /// Other instructions apply (mode or two fields changed): own changes of
  /// this time go.
  void _resetPrompt() => _promptChanged = false;

  void _parse() {
    final export = _export;
    if (export == null) return;
    final sep = _separator;
    final ExchangeAnswer? answer;
    if (_twoFields) {
      answer = _answer.text.trim().isEmpty && _answer2.text.trim().isEmpty
          ? null
          : mergeExchangeAnswers(
              parseExchangeAnswer(_answer.text, ExchangeMode.recognize, separator: sep),
              parseExchangeAnswer(_answer2.text, ExchangeMode.translate, separator: sep),
            );
    } else {
      answer = _answer.text.trim().isEmpty ? null : parseExchangeAnswer(_answer.text, export.mode, separator: sep);
    }
    setState(() {
      _fromFiles = null;
      _match = answer == null ? null : matchExchangeAnswer(export.items, answer, export.mode);
    });
  }

  void _setAnswer(String text) {
    if (_twoFields) {
      if (splitExchangeLists(text) case (final originals, final translations)) {
        _answer.text = originals;
        _answer2.text = translations;
      } else if (_answer.text.trim().isEmpty) {
        _answer.text = text;
      } else {
        _answer2.text = text;
      }
    } else {
      _answer.text = text;
    }
  }

  Future<void> _fromTextFiles() async {
    final export = _export;
    if (export == null) return;
    final dir = Directory(export.dir);
    final match = await readExchangeFolder(dir, await ExchangeManifest.read(dir));
    if (!mounted) return;
    for (final c in [_answer, _answer2]) {
      c.removeListener(_parse);
      c.clear();
      c.addListener(_parse);
    }
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
    _setAnswer(await File(file.path).readAsString());
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final text?) _setAnswer(text);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkClipboard());
  }

  /// Back in the window (from the chat): an answer with labels in the
  /// clipboard is offered for pasting, when the user asked for it.
  Future<void> _checkClipboard() async {
    final export = _export;
    if (export == null || !_options.answerFromClipboard) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted || text.trim().isEmpty || text == _seen || text == _copied || text == _answer.text) return;
    final sep = _separator;
    final lists = splitExchangeLists(text);
    final answer = lists == null
        ? parseExchangeAnswer(text, export.mode, separator: sep)
        : mergeExchangeAnswers(
            parseExchangeAnswer(lists.$1, ExchangeMode.recognize, separator: sep),
            parseExchangeAnswer(lists.$2, ExchangeMode.translate, separator: sep),
          );
    // Lines still as they were sent (the text to translate) are no answer.
    final found = matchExchangeAnswer(export.items, answer, export.mode, ignoreUnchanged: true).replies.length;
    setState(() {
      _offer = found == 0 ? null : text;
      _offerFound = found;
    });
  }

  void _takeOffer({required bool paste}) {
    final text = _offer;
    if (text == null) return;
    setState(() {
      _seen = text;
      _offer = null;
    });
    if (paste) _setAnswer(text);
  }

  /// Shows the pictures of [page] (null: all). A sheet with pieces of
  /// several pages would bring other pages along, so each page then starts
  /// a sheet of its own; true when that was switched on.
  bool _pickPage(int? page) {
    final export = _export;
    final mixed = export != null && export.pictures.any((f) => picturePages(export, f).length > 1);
    final perPage = page != null && mixed && !_options.sheetPerPage;
    setState(() {
      _page.value = page;
      if (perPage) {
        _note = context.l10n.chatSheetPerPageOn;
        _keepNote = true;
      }
    });
    if (perPage) unawaited(_changeOptions((e) => e.copyWith(sheetPerPage: true)));
    return perPage;
  }

  Future<void> _copyText() async {
    final export = _export;
    if (export == null) return;
    final text = exchangeTextLines(export.items);
    await Clipboard.setData(ClipboardData(text: text));
    _copied = text;
    if (mounted) setState(() => _note = context.l10n.chatCopiedText);
  }

  /// Copies [files] (names in the folder); returns what happened.
  String _copy(List<String> files) {
    final export = _export;
    final l = context.l10n;
    if (export == null) return '';
    final ok = copyFilesToClipboard([for (final f in files) p.join(export.dir, f)]);
    return ok
        ? (files.length == 1 ? l.chatCopiedOne(p.basename(files.single)) : l.chatCopiedPictures(files.length))
        : l.chatCopyFailed;
  }

  void _copyPictures(List<String> files) => setState(() => _note = _copy(files));

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _prompt.text));
    _copied = _prompt.text;
    if (mounted) setState(() => _note = context.l10n.chatCopiedPrompt);
  }

  Future<void> _openGallery({bool pieces = false}) async {
    final export = _export;
    if (export == null) return;
    final result = await showExchangeGallery(
      context,
      _shown,
      page: _page,
      onPage: _pickPage,
      onPerPage: (v) => unawaited(_changeOptions((e) => e.copyWith(sheetPerPage: v))),
      selected: _selected,
      groups: _groups.text,
      onCopy: _copy,
      pieces: pieces,
    );
    if (result == null || !mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(result.selected);
    });
    if (result.groups case final groups?) {
      _groups.text = groups;
      unawaited(_rebuild());
    }
  }

  Future<void> _editTemplate() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen(initial: SettingsSection.exchange)));
    if (!mounted) return;
    setState(_resetPrompt);
    unawaited(_rebuild());
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
                  if (!widget.request.modeFixed && !existing)
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
                          _resetPrompt();
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
                        if (!existing) Padding(padding: const EdgeInsets.only(top: 8), child: _optionsRow(l, theme)),
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

  Widget _optionsRow(AppLocalizations l, ThemeData theme) {
    final s = ref.watch(settingsProvider.select((s) => s.exchange));
    final sheets = _mode.sendsImages;
    final items = _export?.items ?? const <ExchangeItem>[];
    Widget dropdown<T>(
      String label,
      T value,
      Map<T, String> options,
      void Function(T v) onChanged, {
      double width = 200,
    }) => SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        // Long names (other languages) end with "…" instead of spilling over.
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
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
          dropdown(
            l.chatSheets,
            s.grouping,
            {SheetGrouping.size: l.chatGroupingSize, SheetGrouping.count: l.chatGroupingCount},
            (v) => _changeOptions((e) => e.copyWith(grouping: v)),
            width: 240,
          ),
          if (s.grouping == SheetGrouping.count)
            dropdown(l.chatPerSheet, s.perSheet, {
              for (final n in {1, 2, 3, 4, 6, 8, 10, 12, 16, 20, 30, s.perSheet}.toList()..sort()) n: '$n',
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
            width: 220,
            child: TextField(
              controller: _groups,
              decoration: InputDecoration(
                labelText: l.chatGroups,
                hintText: l.chatGroupsHint,
                // Which number is which piece.
                helperText: items.isEmpty
                    ? null
                    : l.chatGroupsNumbers(items.first.label.code, items.length, items.last.label.code),
                errorText: _groupsError,
                errorMaxLines: 3,
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l.chatGalleryPieces,
                  onPressed: _export == null || _export!.previews.isEmpty ? null : () => _openGallery(pieces: true),
                  icon: const Icon(Icons.content_cut),
                ),
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
    final all = export?.pictures ?? const <String>[];
    // With many pages, the pictures of one.
    final pictures = export == null ? all : picturesOfPage(export, _page.value);
    final picked = [
      for (final f in all)
        if (_selected.contains(f)) f,
    ];
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (pictures.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => _copyPictures(picked.isEmpty ? pictures : picked),
                      icon: const Icon(Icons.collections_outlined),
                      label: Text(
                        picked.isEmpty ? l.chatCopyPictures(pictures.length) : l.chatCopySelected(picked.length),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _copyPrompt,
                    icon: const Icon(Icons.content_copy),
                    label: Text(l.chatCopyPrompt),
                  ),
                  // The text alone, for instructions of the user's own.
                  if (_mode == ExchangeMode.translate)
                    FilledButton.tonalIcon(
                      onPressed: _copyText,
                      icon: const Icon(Icons.notes),
                      label: Text(l.chatCopyText),
                    ),
                  ExchangePagePicker(export: export, page: _page.value, onChanged: _pickPage),
                  if (all.isNotEmpty)
                    IconButton(
                      tooltip: l.chatGalleryOpen,
                      onPressed: _openGallery,
                      icon: const Icon(Icons.open_in_full),
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
              if (pictures.isNotEmpty) ...[const SizedBox(height: 12), _pictureStrip(l, export, pictures)],
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(_promptChanged ? l.chatPromptChanged : l.chatShowPrompt, style: theme.textTheme.bodyMedium),
                children: [
                  TextField(
                    controller: _prompt,
                    minLines: 6,
                    maxLines: 14,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (_) {
                      if (!_promptChanged) setState(() => _promptChanged = true);
                    },
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_promptChanged)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _resetPrompt();
                              _prompt.text = export.prompt;
                            });
                            unawaited(_rebuild());
                          },
                          child: Text(l.chatPromptUndo),
                        ),
                      TextButton.icon(
                        onPressed: _editTemplate,
                        icon: const Icon(Icons.tune),
                        label: Text(l.chatPromptTemplate),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The pictures in a row: the wheel scrolls it sideways, arrows at the
  /// ends, a tick on each to pick it for copying.
  Widget _pictureStrip(AppLocalizations l, ExchangeExport export, List<String> pictures) {
    void by(double dx) {
      if (!_strip.hasClients) return;
      final to = (_strip.offset + dx).clamp(0.0, _strip.position.maxScrollExtent);
      unawaited(_strip.animateTo(to, duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
    }

    return Row(
      children: [
        IconButton(onPressed: () => by(-320), icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Listener(
            onPointerSignal: (e) {
              if (e is! PointerScrollEvent || !_strip.hasClients) return;
              // The strip takes the wheel: the window behind it stays.
              GestureBinding.instance.pointerSignalResolver.register(e, (e) {
                final s = e as PointerScrollEvent;
                final d = s.scrollDelta.dx != 0 ? s.scrollDelta.dx : s.scrollDelta.dy;
                _strip.jumpTo((_strip.offset + d).clamp(0.0, _strip.position.maxScrollExtent));
              });
            },
            child: Scrollbar(
              controller: _strip,
              thumbVisibility: true,
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 14),
                  itemCount: pictures.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = pictures[i];
                    return _Thumb(
                      // Made again with the folder: the picture loads anew.
                      key: ValueKey((export, f)),
                      file: p.join(export.dir, f),
                      name: f,
                      range: pictureCaption(l, export, f),
                      selected: _selected.contains(f),
                      onToggle: () => setState(() => _selected.contains(f) ? _selected.remove(f) : _selected.add(f)),
                      onCopy: () => _copyPictures([f]),
                      copyTooltip: l.chatCopyOne,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        IconButton(onPressed: () => by(320), icon: const Icon(Icons.chevron_right)),
      ],
    );
  }

  Widget _answerCard(AppLocalizations l, ThemeData theme) {
    final match = _match;
    final total = _export?.items.length ?? 0;
    final warn = TextStyle(color: theme.colorScheme.error);
    final s = ref.watch(settingsProvider.select((s) => s.exchange));
    final two = _mode == ExchangeMode.both && s.apart;
    final sep = _separator;
    TextField field(TextEditingController c, String hint, {String? label}) => TextField(
      controller: c,
      minLines: 6,
      maxLines: 9,
      style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    );
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.chatStep2, style: theme.textTheme.titleMedium)),
                if (_mode == ExchangeMode.both && widget.existing == null)
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(l.chatOneField)),
                      ButtonSegment(value: true, label: Text(l.chatTwoFields)),
                    ],
                    selected: {s.apart},
                    onSelectionChanged: (v) {
                      setState(_resetPrompt);
                      unawaited(_changeOptions((e) => e.copyWith(apart: v.first)).then((_) => _parse()));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_offer != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.content_paste_go, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.chatClipboardOffer(_offerFound, total),
                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                    TextButton(onPressed: () => _takeOffer(paste: true), child: Text(l.chatClipboardPaste)),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => _takeOffer(paste: false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (match != null) ...[
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
              if (match.missingArrow.isNotEmpty) Text(l.chatNoArrow(sep, _codes(match.missingArrow)), style: warn),
              if (match.repeated.isNotEmpty) Text(l.chatRepeated(_codes(match.repeated))),
              const SizedBox(height: 8),
            ],
            if (two)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field(_answer, l.chatAnswerHint, label: l.chatOriginalField)),
                  const SizedBox(width: 8),
                  Expanded(child: field(_answer2, l.chatAnswerHintTranslation, label: l.chatTranslationField)),
                ],
              )
            else
              field(_answer, _mode == ExchangeMode.both ? "[01-003] I'M LATE! $sep Я ОПОЗДАЛ!" : l.chatAnswerHint),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: Text(l.chatPaste)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _export == null ? null : _fromTextFiles,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(l.chatFromFiles),
                    ),
                    InfoHint(switch (_mode) {
                      ExchangeMode.translate => l.chatFromFilesInfoTranslate(sep),
                      ExchangeMode.recognize => l.chatFromFilesInfoRecognize(sep),
                      ExchangeMode.both => l.chatFromFilesInfoBoth(sep),
                    }),
                  ],
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
  const _Thumb({
    super.key,
    required this.file,
    required this.name,
    required this.range,
    required this.selected,
    required this.onToggle,
    required this.onCopy,
    required this.copyTooltip,
  });

  final String file;
  final String name;

  /// Running numbers of the pieces on it (`1–4`).
  final String range;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 108,
            constraints: const BoxConstraints(minWidth: 60, maxWidth: 220),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? theme.colorScheme.primary : theme.dividerColor,
                width: selected ? 3 : 1,
              ),
            ),
            child: Image.file(File(file), fit: BoxFit.contain, cacheHeight: 216),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(value: selected, onChanged: (_) => onToggle()),
            ),
            Text(range.isEmpty ? name : range, style: theme.textTheme.labelSmall),
            IconButton(
              tooltip: copyTooltip,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy),
            ),
          ],
        ),
      ],
    );
  }
}
