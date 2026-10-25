/// The Export window: what to save (translated pages, cleaned pages, texts),
/// in which form (folder, ZIP, CBZ, CB7, PDF) and which pages (original
/// `start_export_as` and the export chapters dialog).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/labels.dart';

class ExportChoice {
  const ExportChoice(this.settings, {required this.currentOnly, this.numbers});

  /// The window's choices, remembered for next time.
  final ExportSettings settings;
  final bool currentOnly;

  /// The pages written by number (0-based among all pages), if chosen so.
  final Set<int>? numbers;
}

/// Which pages the Export window saves.
enum _Which { all, current, numbers }

Future<ExportChoice?> showExportDialog(
  BuildContext context, {
  required ExportSettings initial,
  required int pageCount,
  required int chapters,
  required bool currentAvailable,
  required bool hasSevenZip,
  bool webtoon = false,
  int allCount = 0,
  Set<int> doneIndexes = const {},
  String picked = '',
  VoidCallback? onExportText,
}) => showDialog<ExportChoice>(
  context: context,
  builder: (_) => _ExportDialog(
    initial: initial,
    pageCount: pageCount,
    chapters: chapters,
    currentAvailable: currentAvailable,
    hasSevenZip: hasSevenZip,
    webtoon: webtoon,
    allCount: allCount,
    doneIndexes: doneIndexes,
    picked: picked,
    onExportText: onExportText,
  ),
);

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({
    required this.initial,
    required this.pageCount,
    required this.chapters,
    required this.currentAvailable,
    required this.hasSevenZip,
    required this.webtoon,
    required this.allCount,
    required this.doneIndexes,
    required this.picked,
    required this.onExportText,
  });

  final ExportSettings initial;

  /// Closes the window for "Export text".
  final VoidCallback? onExportText;

  /// Translated pages (the ones "All" saves).
  final int pageCount;
  final int chapters;
  final bool currentAvailable;
  final bool hasSevenZip;

  /// All open pages, the translated ones among them (0-based), and the
  /// picked pages as numbers ("1,5-8"; empty: none picked).
  final int allCount;
  final Set<int> doneIndexes;
  final String picked;

  /// The webtoon mode: the strip can be saved joined or cut again.
  final bool webtoon;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late ExportSettings _s = () {
    var s = widget.initial;
    if (s.container == ExportContainer.cb7 && !widget.hasSevenZip) s = s.copyWith(container: ExportContainer.cbz);
    if (s.imageFormat == 'psd' && s.container.forReaders) s = s.copyWith(imageFormat: 'source');
    if (s.imageFormat == 'psd') s = s.copyWith(strip: StripExport.pages);
    return s;
  }();
  // Picked pages are offered first.
  late _Which _which = widget.picked.isEmpty ? _Which.all : _Which.numbers;
  late final _numbers = TextEditingController(text: widget.picked);
  late final _slice = TextEditingController(text: '${widget.initial.sliceHeight}');
  late final _prefix = TextEditingController(text: widget.initial.namePrefix);
  late final _start = TextEditingController(text: widget.initial.nameStart);

  /// The first names the template gives, as files.
  String get _example {
    final ext = switch (_s.imageFormat) {
      'source' => '',
      final f => '.$f',
    };
    final t = NameTemplate(_s.namePrefix, _s.nameStart);
    return '${t.nameOf(0)}$ext, ${t.nameOf(1)}$ext, ${t.nameOf(2)}$ext…';
  }

  final _scroll = ScrollController();

  /// The pages in the numbers field, or the part that is not a page.
  (Set<int>?, String?) get _parsed {
    try {
      return (parsePageNumbers(_numbers.text, widget.allCount), null);
    } on FormatException catch (e) {
      return (null, e.message);
    }
  }

  /// Translated pages among the numbers.
  Set<int> get _numbered => (_parsed.$1 ?? const {}).intersection(widget.doneIndexes);

  /// Brings the end of the window into view (after the next frame).
  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  void initState() {
    super.initState();
    // Picked pages are offered: their numbers in view.
    if (_which == _Which.numbers) _scrollDown();
  }

  @override
  void dispose() {
    _numbers.dispose();
    _slice.dispose();
    _prefix.dispose();
    _start.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _psd => _s.imageFormat == 'psd';

  bool get _ready => _s.container.forReaders
      ? _s.withTranslated || _s.withCleaned
      : _s.withTranslated || _s.withCleaned || _s.withRawText || _s.withTranslatedText;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final readers = _s.container.forReaders;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget check(String label, bool value, ExportSettings Function(bool v) change, {bool enabled = true}) =>
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label),
          value: value,
          onChanged: enabled ? (v) => setState(() => _s = change(v ?? false)) : null,
        );
    String containerLabel(ExportContainer c) => c == ExportContainer.folder ? l.exportFolder : c.name.toUpperCase();
    return AlertDialog(
      icon: const Icon(Icons.save_alt),
      title: Text(l.export),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading(l.exportWhat),
              check(l.exportTranslatedPages, _s.withTranslated, (v) => _s.copyWith(withTranslated: v)),
              check(l.exportCleanedPages, _s.withCleaned, (v) => _s.copyWith(withCleaned: v)),
              check(l.exportRecognizedJson, _s.withRawText, (v) => _s.copyWith(withRawText: v), enabled: !readers),
              check(
                l.exportTranslatedJson,
                _s.withTranslatedText,
                (v) => _s.copyWith(withTranslatedText: v),
                enabled: !readers,
              ),
              heading(l.exportWhere),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ExportContainer.values)
                    Tooltip(
                      message: c == ExportContainer.cb7 && !widget.hasSevenZip ? l.exportNeeds7zip : '',
                      child: ChoiceChip(
                        label: Text(containerLabel(c)),
                        selected: _s.container == c,
                        onSelected: c == ExportContainer.cb7 && !widget.hasSevenZip
                            ? null
                            : (_) => setState(
                                () => _s = _s.copyWith(
                                  container: c,
                                  // Comic readers take pictures, not PSD files.
                                  imageFormat: c.forReaders && _psd ? 'source' : null,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
              if (readers)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.exportReaderNote, style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_s.imageFormat),
                initialValue: _s.imageFormat,
                decoration: InputDecoration(
                  labelText: l.imageFormat,
                  helperText: _psd ? l.exportPsdHelp : (_s.container == ExportContainer.pdf ? l.exportPdfFormat : null),
                  helperMaxLines: 3,
                ),
                items: [
                  for (final f in ExportSettings.formats)
                    DropdownMenuItem(
                      value: f,
                      enabled: f != 'psd' || !readers,
                      child: Text(switch (f) {
                        'source' => l.formatSource,
                        'psd' => l.formatPsd,
                        _ => f.toUpperCase(),
                      }),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _s = _s.copyWith(imageFormat: v, strip: v == 'psd' ? StripExport.pages : null)),
              ),
              if (_s.container != ExportContainer.pdf) ...[
                heading(l.exportNames),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.exportNamesPages)),
                    ButtonSegment(value: true, label: Text(l.exportNamesTemplate)),
                  ],
                  selected: {_s.namesByTemplate},
                  onSelectionChanged: (v) {
                    setState(() => _s = _s.copyWith(namesByTemplate: v.first));
                    if (v.first) _scrollDown();
                  },
                ),
                if (_s.namesByTemplate) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _prefix,
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            labelText: l.exportNamePrefix,
                            hintText: 'spider man ',
                          ),
                          onChanged: (v) => setState(() => _s = _s.copyWith(namePrefix: v)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _start,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            labelText: l.exportNameStart,
                            errorText: NameTemplate.validStart(_start.text) ? null : l.exportNameStartWrong,
                          ),
                          onChanged: (v) => setState(() {
                            if (NameTemplate.validStart(v)) _s = _s.copyWith(nameStart: v);
                          }),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l.exportNamesExample(_example), style: theme.textTheme.bodySmall),
                  ),
                ],
              ],
              if (widget.webtoon) ...[
                heading(l.exportStrip),
                SegmentedButton<StripExport>(
                  segments: [
                    ButtonSegment(value: StripExport.pages, label: Text(l.exportStripPages)),
                    ButtonSegment(value: StripExport.single, label: Text(l.exportStripSingle), enabled: !_psd),
                    ButtonSegment(value: StripExport.slices, label: Text(l.exportStripSlices), enabled: !_psd),
                  ],
                  selected: {_s.strip},
                  onSelectionChanged: (v) {
                    setState(() => _s = _s.copyWith(strip: v.first));
                    // The part height comes below: in view.
                    _scrollDown();
                  },
                ),
                if (_psd)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.exportPsdPagesOnly, style: theme.textTheme.bodySmall),
                  ),
                if (_s.strip == StripExport.single)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.exportStripSingleHelp, style: theme.textTheme.bodySmall),
                  ),
                if (_s.strip == StripExport.slices)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _slice,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l.exportSliceHeight,
                        helperText: l.exportStripHelp,
                        helperMaxLines: 3,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) _s = _s.copyWith(sliceHeight: n.clamp(minSliceHeight, maxSliceHeight));
                      },
                    ),
                  ),
              ],
              heading(l.exportWhich),
              SegmentedButton<_Which>(
                segments: [
                  ButtonSegment(value: _Which.all, label: Text(l.exportAllPages('${widget.pageCount}'))),
                  ButtonSegment(
                    value: _Which.current,
                    label: Text(l.exportCurrentPage),
                    enabled: widget.currentAvailable,
                  ),
                  ButtonSegment(value: _Which.numbers, label: Text(l.exportNumbers), enabled: widget.allCount > 1),
                ],
                selected: {_which},
                onSelectionChanged: (v) {
                  setState(() => _which = v.first);
                  if (_which == _Which.numbers) _scrollDown();
                },
              ),
              if (_which == _Which.numbers)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _numbers,
                    autofocus: widget.picked.isEmpty,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      labelText: l.pageNumbers,
                      hintText: l.pageNumbersHint,
                      errorText: _parsed.$2 == null ? null : l.pageNumbersWrong(_parsed.$2!, '${widget.allCount}'),
                      helperText: _parsed.$2 == null
                          ? l.exportNumbersReady('${_numbered.length}', '${_parsed.$1!.length}')
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (widget.chapters > 1 && _which != _Which.current)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: check(l.exportByChapter('${widget.chapters}'), _s.byChapter, (v) => _s.copyWith(byChapter: v)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onExportText != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onExportText!();
            },
            icon: const Icon(Icons.notes),
            label: Text(l.textExportMenu),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _ready && (_which != _Which.numbers || _numbered.isNotEmpty)
              ? () => Navigator.pop(
                  context,
                  ExportChoice(
                    _s,
                    currentOnly: _which == _Which.current,
                    numbers: _which == _Which.numbers ? _numbered : null,
                  ),
                )
              : null,
          child: Text(l.exportStart),
        ),
      ],
    );
  }
}
