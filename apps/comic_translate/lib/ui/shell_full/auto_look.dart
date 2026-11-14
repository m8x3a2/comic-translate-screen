/// "Auto look" (the owner's idea): the bubbles drawn like their original
/// lettering in one go — the closest font, the size of the source letters,
/// and the colour, bold, italic and outline back to the automatic look
/// (which follows the original). For each bubble its own font, or one font
/// for all. Not in the original.
library;

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/block_looks.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import 'font_suggest.dart';

/// What "Auto look" sets.
enum AutoLookPart {
  /// The font closest to the source lettering.
  font,

  /// The size of the source letters.
  size,

  /// Colour, bold, italic, underline and outline back to automatic.
  look,
}

/// What came of an "Auto look".
class AutoLookResult {
  const AutoLookResult(this.changed, this.unmeasured);

  /// Bubbles that changed.
  final int changed;

  /// Bubbles whose source lettering is not measured (no font or size for
  /// them: they are read again first).
  final int unmeasured;
}

/// A text of at most 28 characters of [text] to draw the fonts with.
String _sampleOf(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length > 28 ? t.substring(0, 28).trim() : t;
}

/// The lettering shape of [b], or null when it is not measured.
LetteringShape? _shapeOf(TextBlock b) {
  final s = b.sourceStyle;
  return s == null ? null : LetteringShape.of(s, b.text, lines: math.max(1, b.lines.length));
}

/// Sets [parts] for the bubbles of [scope] ([picked]: the bubbles of the
/// open page for [LookScope.picked]); [perBubble]: each bubble its own font.
Future<AutoLookResult> applyAutoLook(
  WidgetRef ref,
  Set<AutoLookPart> parts,
  LookScope scope, {
  List<int> picked = const [],
  bool perBubble = true,
}) async {
  final targets = lookTargets(ref, scope, picked);
  final all = [
    for (final (page, which) in targets)
      for (final i in which) page.blocks[i],
  ];
  final choices = fontChoices(ref);
  // One font for all: the one closest to the usual lettering of the bubbles.
  String? common;
  var commonDone = false;
  Future<String?> commonFont() async {
    if (commonDone) return common;
    commonDone = true;
    final shape = LetteringShape.ofPage(all);
    final measured = [
      for (final b in all)
        if (_shapeOf(b) != null) b,
    ]..sort((a, b) => b.text.length.compareTo(a.text.length));
    if (shape == null || measured.isEmpty) return null;
    final ranked = await rankFonts(shape, _sampleOf(measured.first.text), choices);
    return common = ranked.firstOrNull?.setting;
  }

  // Page id and bubble → its font ('' : the default one).
  final fonts = <(String, int), String?>{};
  var unmeasured = 0;
  for (final (page, which) in targets) {
    for (final i in which) {
      final b = page.blocks[i];
      if (b.text.trim().isEmpty) continue;
      final shape = _shapeOf(b);
      if (shape == null) unmeasured++;
      if (!parts.contains(AutoLookPart.font)) continue;
      if (perBubble && shape != null) {
        final ranked = await rankFonts(shape, _sampleOf(b.text), choices);
        fonts[(page.id, i)] = ranked.firstOrNull?.setting ?? await commonFont();
      } else {
        fonts[(page.id, i)] = await commonFont();
      }
    }
  }
  var changed = 0;
  for (final (page, which) in targets) {
    // The page may have changed while the fonts were compared.
    final now = ref.read(workspaceProvider).byId(page.id);
    if (now == null || !identical(now.blocks, page.blocks)) continue;
    restyleBlocks(ref, page, which, (b, i) {
      var s = b.style ?? const BlockStyle();
      final before = s;
      if (parts.contains(AutoLookPart.font) && fonts.containsKey((page.id, i))) {
        // '' is the default font: no font of the bubble's own.
        final f = fonts[(page.id, i)];
        if (f != null) s = s.copyWith(fontFamily: f.isEmpty ? null : f);
      }
      if (parts.contains(AutoLookPart.size)) {
        final px = sourceSizeFor(b, page);
        if (px != null) s = s.copyWith(sourceSizePx: px, fontSizePt: null);
      }
      if (parts.contains(AutoLookPart.look)) {
        s = s.copyWith(
          color: null,
          bold: null,
          italic: null,
          underline: null,
          outline: null,
          outlineColor: null,
          outlineWidth: null,
          preset: null,
        );
      }
      if (s != before) changed++;
      return s;
    });
  }
  return AutoLookResult(changed, unmeasured);
}

/// "Auto look…": what to set and where, then sets it. [picked]: the bubbles
/// picked together, or the selected one.
Future<void> showAutoLookDialog(BuildContext context, WidgetRef ref, {List<int> picked = const []}) async {
  final ws = ref.read(workspaceProvider);
  final page = ws.currentPage;
  if (page == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  int bubbles(Iterable<PageEntry> pages) => pages.fold(0, (n, p) => n + p.blocks.length);
  final choice = await showDialog<(Set<AutoLookPart>, LookScope, bool)>(
    context: context,
    builder: (_) => _AutoLookDialog(
      picked: picked,
      onPage: page.blocks.length,
      pickedPages: ws.selectedPages.length > 1 ? bubbles(ws.stepPages) : 0,
      allPages: ws.pages.length > 1 ? bubbles(ws.pages) : 0,
    ),
  );
  if (choice == null) return;
  final (parts, scope, perBubble) = choice;
  messenger.showSnackBar(SnackBar(content: Text(l.autoLookWorking), duration: const Duration(seconds: 30)));
  final result = await applyAutoLook(ref, parts, scope, picked: picked, perBubble: perBubble);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          [
            l.autoLookDone('${result.changed}'),
            if (result.unmeasured > 0 && !parts.every((p) => p == AutoLookPart.look))
              l.autoLookUnmeasured('${result.unmeasured}'),
          ].join(' '),
        ),
        showCloseIcon: true,
      ),
    );
}

class _AutoLookDialog extends StatefulWidget {
  const _AutoLookDialog({
    required this.picked,
    required this.onPage,
    required this.pickedPages,
    required this.allPages,
  });

  final List<int> picked;

  /// Bubbles in each place (0: the place is not offered).
  final int onPage, pickedPages, allPages;

  @override
  State<_AutoLookDialog> createState() => _AutoLookDialogState();
}

class _AutoLookDialogState extends State<_AutoLookDialog> {
  final _parts = {...AutoLookPart.values};
  var _perBubble = true;
  late LookScope _scope = widget.picked.isNotEmpty ? LookScope.picked : LookScope.page;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    String label(AutoLookPart p) => switch (p) {
      AutoLookPart.font => l.font,
      AutoLookPart.size => l.sizeFromSource,
      AutoLookPart.look => l.autoLookColours,
    };
    final places = [
      if (widget.picked.length > 1)
        (LookScope.picked, l.lookScopePicked('${widget.picked.length}'))
      else if (widget.picked.length == 1)
        (LookScope.picked, l.autoLookThisBubble('${widget.picked.single + 1}')),
      (LookScope.page, l.lookScopePage('${widget.onPage}')),
      if (widget.pickedPages > 0) (LookScope.pickedPages, l.lookScopePickedPages('${widget.pickedPages}')),
      if (widget.allPages > 0) (LookScope.allPages, l.lookScopeAll('${widget.allPages}')),
    ];
    return AlertDialog(
      title: Text(l.autoLookTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.autoLookHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in AutoLookPart.values)
                    FilterChip(
                      label: Text(label(p)),
                      selected: _parts.contains(p),
                      onSelected: (v) => setState(() => v ? _parts.add(p) : _parts.remove(p)),
                    ),
                ],
              ),
              if (_parts.contains(AutoLookPart.font)) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l.autoLookEach)),
                    ButtonSegment(value: false, label: Text(l.autoLookOne)),
                  ],
                  selected: {_perBubble},
                  onSelectionChanged: (v) => setState(() => _perBubble = v.first),
                ),
              ],
              const SizedBox(height: 16),
              Text(l.lookApplyWhere, style: theme.textTheme.titleSmall),
              for (final (scope, text) in places)
                RadioListTile<LookScope>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: scope,
                  // ignore: deprecated_member_use
                  groupValue: _scope,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _scope = v ?? _scope),
                  title: Text(text),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _parts.isEmpty ? null : () => Navigator.pop(context, (_parts, _scope, _perBubble)),
          child: Text(l.textImportApply),
        ),
      ],
    );
  }
}
