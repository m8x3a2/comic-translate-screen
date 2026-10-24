/// Look buttons of the text panel, for the step pages (the current page or
/// the selected ones) or one block of the current page: capitals or
/// ordinary letters, letter size as in the original, back to the automatic
/// look. Each changed page is one undo step. Not in the original.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'workspace.dart';

/// Pages and the blocks on them the buttons act on.
List<(PageEntry, List<int>)> _targets(WidgetRef ref, int? block) {
  final ws = ref.read(workspaceProvider);
  if (block != null) {
    final page = ws.currentPage;
    return page == null || block < 0 || block >= page.blocks.length
        ? const []
        : [
            (page, [block]),
          ];
  }
  return [
    for (final page in ws.stepPages) (page, [for (var i = 0; i < page.blocks.length; i++) i]),
  ];
}

void _restyle(WidgetRef ref, PageEntry page, List<int> which, BlockStyle? Function(TextBlock b, int i) style) {
  final blocks = [for (final b in page.blocks) b.copy()];
  var changed = false;
  for (final i in which) {
    final next = style(blocks[i], i);
    final s = next == null || next.isEmpty ? null : next;
    if (s == blocks[i].style) continue;
    blocks[i].style = s;
    changed = true;
  }
  if (changed) ref.read(workspaceProvider.notifier).edit(page.id, (p) => p.copyWith(blocks: blocks));
}

/// Whether [b] is drawn in capitals with [settings].
bool drawnInCapitals(TextBlock b, AppSettings settings) =>
    pyIsUpper(casedTranslation(b, settings.textCase, upperCase: b.style?.upperCase));

/// Capitals for all the blocks when any of them is drawn in ordinary
/// letters, else ordinary letters for all.
void toggleCapitals(WidgetRef ref, {int? block}) {
  final settings = ref.read(settingsProvider);
  final targets = _targets(ref, block);
  final translated = [
    for (final (page, which) in targets)
      for (final i in which)
        if (page.blocks[i].translation.trim().isNotEmpty) page.blocks[i],
  ];
  final upper = translated.isEmpty || !translated.every((b) => drawnInCapitals(b, settings));
  for (final (page, which) in targets) {
    _restyle(ref, page, which, (b, _) => (b.style ?? const BlockStyle()).copyWith(upperCase: upper));
  }
}

/// Lettering this much larger or smaller than the page's usual keeps its
/// own size (shouts, small notes).
const _ownSize = 0.35;

/// The source letter height [b] takes with "size as in the original": the
/// page's usual one, so that bubbles match, unless its own clearly differs.
double? sourceSizeFor(TextBlock b, PageEntry page) {
  final own = b.sourceStyle?.letterPx;
  if (own == null) return null;
  final sizes = [
    for (final o in page.blocks)
      if (o.sourceStyle?.letterPx case final px? when isMostlyUpperCase(o.text) == isMostlyUpperCase(b.text)) px,
  ];
  final usual = npMedian(sizes);
  return (own / usual - 1).abs() > _ownSize ? own : usual;
}

/// Turns "size as in the original" on for the blocks (off when it is on
/// for all of them); returns how many blocks have it now, or null when
/// none of them knows its source size.
int? toggleSourceSize(WidgetRef ref, {int? block}) {
  final targets = _targets(ref, block);
  final known = [
    for (final (page, which) in targets)
      for (final i in which)
        if (page.blocks[i].sourceStyle?.letterPx != null) page.blocks[i],
  ];
  if (known.isEmpty) return null;
  final off = known.every((b) => b.style?.sourceSizePx != null);
  var count = 0;
  for (final (page, which) in targets) {
    _restyle(ref, page, which, (b, _) {
      final s = b.style ?? const BlockStyle();
      if (off) return s.copyWith(sourceSizePx: null);
      final px = sourceSizeFor(b, page);
      if (px == null) return s;
      count++;
      return s.copyWith(sourceSizePx: px, fontSizePt: null);
    });
  }
  return count;
}

/// The automatic look again for every block.
void resetLooks(WidgetRef ref, {int? block}) {
  for (final (page, which) in _targets(ref, block)) {
    _restyle(ref, page, which, (_, _) => null);
  }
}
