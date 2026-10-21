/// The Export window: what to save (translated pages, cleaned pages, texts),
/// in which form (folder, ZIP, CBZ, CB7, PDF) and which pages (original
/// `start_export_as` and the export chapters dialog).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/labels.dart';

class ExportChoice {
  const ExportChoice(this.settings, {required this.currentOnly});

  /// The window's choices, remembered for next time.
  final ExportSettings settings;
  final bool currentOnly;
}

Future<ExportChoice?> showExportDialog(
  BuildContext context, {
  required ExportSettings initial,
  required int pageCount,
  required int chapters,
  required bool currentAvailable,
  required bool hasSevenZip,
  bool webtoon = false,
}) => showDialog<ExportChoice>(
  context: context,
  builder: (_) => _ExportDialog(
    initial: initial,
    pageCount: pageCount,
    chapters: chapters,
    currentAvailable: currentAvailable,
    hasSevenZip: hasSevenZip,
    webtoon: webtoon,
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
  });

  final ExportSettings initial;
  final int pageCount;
  final int chapters;
  final bool currentAvailable;
  final bool hasSevenZip;

  /// The webtoon mode: the strip can be saved joined or cut again.
  final bool webtoon;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late ExportSettings _s = widget.initial.container == ExportContainer.cb7 && !widget.hasSevenZip
      ? widget.initial.copyWith(container: ExportContainer.cbz)
      : widget.initial;
  bool _currentOnly = false;
  late final _slice = TextEditingController(text: '${widget.initial.sliceHeight}');
  final _scroll = ScrollController();

  @override
  void dispose() {
    _slice.dispose();
    _scroll.dispose();
    super.dispose();
  }

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
              check(
                l.exportRecognizedJson,
                _s.withRawText,
                (v) => _s.copyWith(withRawText: v),
                enabled: !readers,
              ),
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
                            : (_) => setState(() => _s = _s.copyWith(container: c)),
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
                initialValue: _s.imageFormat,
                decoration: InputDecoration(
                  labelText: l.imageFormat,
                  helperText: _s.container == ExportContainer.pdf ? l.exportPdfFormat : null,
                  helperMaxLines: 2,
                ),
                items: [
                  for (final f in ExportSettings.formats)
                    DropdownMenuItem(value: f, child: Text(f == 'source' ? l.formatSource : f.toUpperCase())),
                ],
                onChanged: (v) => setState(() => _s = _s.copyWith(imageFormat: v)),
              ),
              if (widget.webtoon) ...[
                heading(l.exportStrip),
                SegmentedButton<StripExport>(
                  segments: [
                    ButtonSegment(value: StripExport.pages, label: Text(l.exportStripPages)),
                    ButtonSegment(value: StripExport.single, label: Text(l.exportStripSingle)),
                    ButtonSegment(value: StripExport.slices, label: Text(l.exportStripSlices)),
                  ],
                  selected: {_s.strip},
                  onSelectionChanged: (v) {
                    setState(() => _s = _s.copyWith(strip: v.first));
                    // The part height comes below: in view.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.animateTo(
                          _scroll.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  },
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
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.exportAllPages('${widget.pageCount}'))),
                  ButtonSegment(value: true, label: Text(l.exportCurrentPage), enabled: widget.currentAvailable),
                ],
                selected: {_currentOnly},
                onSelectionChanged: (v) => setState(() => _currentOnly = v.first),
              ),
              if (widget.chapters > 1 && !_currentOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: check(
                    l.exportByChapter('${widget.chapters}'),
                    _s.byChapter,
                    (v) => _s.copyWith(byChapter: v),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _ready ? () => Navigator.pop(context, ExportChoice(_s, currentOnly: _currentOnly)) : null,
          child: Text(l.exportStart),
        ),
      ],
    );
  }
}
