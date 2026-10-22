/// The exchange pictures over the whole window: the pictures large, to pick
/// the ones to copy, and every piece of text in order with its number, to
/// make own sheets ("a new sheet from here").
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../common/labels.dart';

/// What the large view changed.
class GalleryResult {
  const GalleryResult(this.selected, {this.groups});

  /// Pictures picked for copying.
  final Set<String> selected;

  /// New own sheets (`1-4, 5-6`; empty: as usual), or null when unchanged.
  final String? groups;
}

/// Opens the large view of [export]; [onCopy] copies pictures (file names in
/// its folder) and tells what happened.
Future<GalleryResult?> showExchangeGallery(
  BuildContext context,
  ExchangeExport export, {
  required Set<String> selected,
  required String groups,
  required String Function(List<String> files) onCopy,
  bool pieces = false,
}) => showDialog<GalleryResult>(
  context: context,
  builder: (_) => _Gallery(export: export, selected: selected, groups: groups, onCopy: onCopy, pieces: pieces),
);

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

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.export,
    required this.selected,
    required this.groups,
    required this.onCopy,
    required this.pieces,
  });

  final ExchangeExport export;
  final Set<String> selected;
  final String groups;
  final String Function(List<String> files) onCopy;
  final bool pieces;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final _selected = {...widget.selected};
  late var _piecesTab = widget.pieces && widget.export.previews.isNotEmpty;
  late final _breaks = breaksFromGroups(widget.groups, widget.export.items.length);
  var _breaksChanged = false;
  String? _note;

  List<String> get _pictures => widget.export.pictures;

  void _close() => Navigator.pop(
    context,
    GalleryResult(_selected, groups: _breaksChanged ? groupsFromBreaks(_breaks, widget.export.items.length) : null),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final picked = [
      for (final f in _pictures)
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
                if (widget.export.previews.isNotEmpty)
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
              file: p.join(widget.export.dir, f),
              name: f,
              range: pieceRange(widget.export, f),
              selected: _selected.contains(f),
              onTap: () => setState(() => _selected.contains(f) ? _selected.remove(f) : _selected.add(f)),
            ),
        ],
      ),
    ),
  ];

  List<Widget> _piecesView(AppLocalizations l, ThemeData theme) {
    final items = widget.export.items;
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
          FilledButton(onPressed: _close, child: Text(l.chatGroupsApply)),
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
                  number: i + 1,
                  label: it.label.code,
                  file: widget.export.previews[it.label.code] == null
                      ? null
                      : p.join(widget.export.dir, widget.export.previews[it.label.code]!),
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
