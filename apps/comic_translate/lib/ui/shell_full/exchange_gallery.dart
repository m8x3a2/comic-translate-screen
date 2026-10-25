/// The exchange pictures over the whole window: the pictures large, to pick
/// the ones to copy, and every piece of text in order with its number, to
/// make own sheets ("a new sheet from here").
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../common/labels.dart';

/// What the large view changed.
class GalleryResult {
  const GalleryResult(this.selected, {this.groups});

  /// Pictures picked for copying.
  final Set<String> selected;

  /// New own sheets (`1-4, 5-6`; empty: as usual), or null when unchanged.
  final String? groups;
}

/// Opens the large view of [export] (made again while it is open when the
/// options change); [onCopy] copies pictures (file names in its folder) and
/// tells what happened. [page]: the page whose pictures are shown, the same
/// as in the exchange window; [onPage] picks another one and tells whether
/// each page now starts its own sheet.
Future<GalleryResult?> showExchangeGallery(
  BuildContext context,
  ValueListenable<ExchangeExport?> export, {
  required ValueListenable<int?> page,
  required bool Function(int? page) onPage,
  required ValueChanged<bool> onPerPage,
  required Set<String> selected,
  required String groups,
  required String Function(List<String> files) onCopy,
  bool pieces = false,
}) => showDialog<GalleryResult>(
  context: context,
  builder: (_) => _Gallery(
    export: export,
    page: page,
    onPage: onPage,
    onPerPage: onPerPage,
    selected: selected,
    groups: groups,
    onCopy: onCopy,
    pieces: pieces,
  ),
);

/// The pictures of [export] showing [page]; all of them for null or a page
/// they do not show.
List<String> picturesOfPage(ExchangeExport export, int? page) {
  final own = [
    for (final f in export.pictures)
      if (page == null || picturePages(export, f).contains(page)) f,
  ];
  return own.isEmpty ? export.pictures : own;
}

/// What is written under [picture]: the pieces on it (`1–4`) and, when the
/// pictures show several pages, which page (`p. 2 · 5–7`); empty for a
/// picture of a whole page.
String pictureCaption(AppLocalizations l, ExchangeExport export, String picture) {
  final range = pieceRange(export, picture);
  if (range.isEmpty) return range;
  final several = {for (final f in export.pictures) ...picturePages(export, f)}.length > 1;
  return several ? '${l.chatPicturePages(pagesText(picturePages(export, picture)))} · $range' : range;
}

/// "All pages (5) / Page 2 (1)…" over the pictures; nothing when they show
/// one page only.
class ExchangePagePicker extends StatelessWidget {
  const ExchangePagePicker({super.key, required this.export, required this.page, required this.onChanged});

  final ExchangeExport export;
  final int? page;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pagesOf = [for (final f in export.pictures) picturePages(export, f)];
    final numbers = {for (final ps in pagesOf) ...ps}.toList()..sort();
    if (numbers.length < 2) return const SizedBox.shrink();
    return DropdownButton<int?>(
      value: numbers.contains(page) ? page : null,
      isDense: true,
      items: [
        DropdownMenuItem(value: null, child: Text(l.chatPagesAll(export.pictures.length))),
        for (final n in numbers)
          DropdownMenuItem(value: n, child: Text(l.chatPageOnly(n, pagesOf.where((ps) => ps.contains(n)).length))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Running numbers (from 1) of the pieces on a sheet, as `1–4` or `5, 7`.
String pieceRange(ExchangeExport export, String sheet) {
  final order = {for (final (i, it) in export.items.indexed) it.label.code: i + 1};
  final numbers = [for (final c in export.sheetLabels[sheet] ?? const <String>[]) ?order[c]]..sort();
  if (numbers.isEmpty) return '';
  final contiguous = numbers.last - numbers.first + 1 == numbers.length;
  return contiguous
      ? (numbers.length == 1 ? '${numbers.first}' : '${numbers.first}–${numbers.last}')
      : numbers.join(', ');
}

/// The pages (their numbers in the labels) with pieces on [picture]: one for
/// a picture of a page or a single cut-out, more for a sheet across pages.
Set<int> picturePages(ExchangeExport export, String picture) {
  final name = p.basename(picture);
  if (RegExp(r'^page_(\d+)_context\.jpg$').firstMatch(name) case final m?) return {int.parse(m[1]!)};
  final codes = export.sheetLabels[picture] ?? [p.basenameWithoutExtension(name)];
  return {for (final c in codes) ?ExchangeLabel.tryParse(c)?.page};
}

/// [pages] in short: `1`, `1–3`, `1, 4`.
String pagesText(Set<int> pages) {
  final sorted = pages.toList()..sort();
  if (sorted.length > 1 && sorted.last - sorted.first + 1 == sorted.length) return '${sorted.first}–${sorted.last}';
  return sorted.join(', ');
}

/// Own sheets from where new sheets start (0-based piece indexes, without
/// 0): `1-4, 5-6, 7-19`; empty without breaks.
String groupsFromBreaks(Set<int> breaks, int count) {
  final starts = [0, ...(breaks.where((b) => b > 0 && b < count).toList()..sort())];
  if (starts.length < 2) return '';
  return [
    for (final (i, s) in starts.indexed)
      () {
        final end = (i + 1 < starts.length ? starts[i + 1] : count) - 1;
        return s == end ? '${s + 1}' : '${s + 1}-${end + 1}';
      }(),
  ].join(', ');
}

/// Where sheets start in own sheets [text] (0-based, without 0).
Set<int> breaksFromGroups(String text, int count) {
  try {
    return {
      for (final g in parseSheetGroups(text, count))
        if (g.first > 0) g.first,
      // What follows a group starts a new sheet too.
      for (final g in parseSheetGroups(text, count))
        if (g.last + 1 < count) g.last + 1,
    };
  } on FormatException {
    return {};
  }
}

class _Gallery extends ConsumerStatefulWidget {
  const _Gallery({
    required this.export,
    required this.page,
    required this.onPage,
    required this.onPerPage,
    required this.selected,
    required this.groups,
    required this.onCopy,
    required this.pieces,
  });

  final ValueListenable<ExchangeExport?> export;
  final ValueListenable<int?> page;
  final bool Function(int? page) onPage;

  /// Turns "each page on a new sheet" on or off.
  final ValueChanged<bool> onPerPage;
  final Set<String> selected;
  final String groups;
  final String Function(List<String> files) onCopy;
  final bool pieces;

  @override
  ConsumerState<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<_Gallery> {
  late final _selected = {...widget.selected};
  late var _piecesTab = widget.pieces && _export.previews.isNotEmpty;
  late final _breaks = breaksFromGroups(widget.groups, _export.items.length);
  var _breaksChanged = false;
  String? _note;

  /// The folder as it is now (it was there when the view opened).
  late ExchangeExport _last = widget.export.value!;
  ExchangeExport get _export => _last = widget.export.value ?? _last;

  /// The pictures of the page picked (all of them for none).
  List<String> get _pictures => picturesOfPage(_export, widget.page.value);

  void _close() => Navigator.pop(
    context,
    GalleryResult(_selected, groups: _breaksChanged ? groupsFromBreaks(_breaks, _export.items.length) : null),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.export, widget.page]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final picked = [
      for (final f in _export.pictures)
        if (_selected.contains(f)) f,
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_export.previews.isNotEmpty)
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(l.chatGalleryPictures)),
                      ButtonSegment(value: true, label: Text(l.chatGalleryPieces)),
                    ],
                    selected: {_piecesTab},
                    onSelectionChanged: (s) => setState(() => _piecesTab = s.first),
                  )
                else
                  Text(l.chatGalleryPictures, style: theme.textTheme.titleLarge),
                const Spacer(),
                // Always in the same place: the line of sheets beside it grows.
                if (_piecesTab) ...[
                  FilledButton(onPressed: _close, child: Text(l.chatGroupsApply)),
                  const SizedBox(width: 8),
                ],
                IconButton(tooltip: l.close, onPressed: _close, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            if (_piecesTab) ..._piecesView(l, theme) else ..._picturesView(l, theme, picked),
          ],
        ),
      ),
    );
  }

  List<Widget> _picturesView(AppLocalizations l, ThemeData theme, List<String> picked) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ExchangePagePicker(
          export: _export,
          page: widget.page.value,
          onChanged: (v) {
            final perPage = widget.onPage(v);
            setState(() => _note = perPage ? l.chatSheetPerPageOn : null);
          },
        ),
        if (_export.sheets.isNotEmpty)
          FilterChip(
            label: Text(l.chatSheetPerPage),
            selected: ref.watch(settingsProvider.select((s) => s.exchange.sheetPerPage)),
            onSelected: widget.onPerPage,
          ),
        FilledButton.icon(
          onPressed: picked.isEmpty ? null : () => setState(() => _note = widget.onCopy(picked)),
          icon: const Icon(Icons.collections_outlined),
          label: Text(l.chatCopySelected(picked.length)),
        ),
        OutlinedButton(onPressed: () => setState(() => _selected.addAll(_pictures)), child: Text(l.chatSelectAll)),
        OutlinedButton(
          onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
          child: Text(l.chatSelectNone),
        ),
        if (_note != null) Text(_note!, style: TextStyle(color: theme.colorScheme.primary)),
      ],
    ),
    const SizedBox(height: 12),
    Expanded(
      child: GridView.extent(
        maxCrossAxisExtent: 560,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: [
          for (final f in _pictures)
            _BigPicture(
              // Made again with the folder: the picture loads anew.
              key: ValueKey((_export, f)),
              file: p.join(_export.dir, f),
              name: f,
              range: pictureCaption(l, _export, f),
              selected: _selected.contains(f),
              onTap: () => setState(() => _selected.contains(f) ? _selected.remove(f) : _selected.add(f)),
            ),
        ],
      ),
    ),
  ];

  List<Widget> _piecesView(AppLocalizations l, ThemeData theme) {
    final items = _export.items;
    final groups = groupsFromBreaks(_breaks, items.length);
    return [
      Text(l.chatPiecesHelp, style: theme.textTheme.bodySmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.chatGroupsNow(groups.isEmpty ? l.chatGroupsAuto : groups), style: theme.textTheme.titleSmall),
          if (_breaks.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _breaks.clear();
                _breaksChanged = true;
              }),
              child: Text(l.chatGroupsClear),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, it) in items.indexed)
                _PieceTile(
                  key: ValueKey((_export, it.label)),
                  number: i + 1,
                  label: it.label.code,
                  file: _export.previews[it.label.code] == null
                      ? null
                      : p.join(_export.dir, _export.previews[it.label.code]!),
                  startsSheet: i == 0 || _breaks.contains(i),
                  onTap: i == 0
                      ? null
                      : () => setState(() {
                          _breaks.contains(i) ? _breaks.remove(i) : _breaks.add(i);
                          _breaksChanged = true;
                        }),
                  tooltip: l.chatNewSheetHere,
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _BigPicture extends StatelessWidget {
  const _BigPicture({
    super.key,
    required this.file,
    required this.name,
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final String file;
  final String name;
  final String range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor, width: selected ? 3 : 1),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(child: Image.file(File(file), fit: BoxFit.contain)),
            Row(
              children: [
                Checkbox(value: selected, onChanged: (_) => onTap()),
                Expanded(child: Text(range.isEmpty ? name : '$name  ·  $range')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    super.key,
    required this.number,
    required this.label,
    required this.file,
    required this.startsSheet,
    required this.onTap,
    required this.tooltip,
  });

  final int number;
  final String label;
  final String? file;
  final bool startsSheet;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = theme.colorScheme.primary;
    return Tooltip(
      message: onTap == null ? '' : tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: startsSheet ? mark : theme.dividerColor, width: startsSheet ? 5 : 1),
              top: BorderSide(color: theme.dividerColor),
              right: BorderSide(color: theme.dividerColor),
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$number', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('[$label]', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  if (startsSheet) Icon(Icons.content_cut, size: 16, color: mark),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 110,
                width: double.infinity,
                child: file == null ? null : Image.file(File(file!), fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
