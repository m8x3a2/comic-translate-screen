/// "Split glued words" of the text panel: English words the OCR read as one
/// ("REALLIFE") are split on the step pages (the current page or the
/// selected ones) or in one block of the current page. Each changed page is
/// one undo step.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pipeline/word_list.dart';
import 'app_state.dart';
import 'workspace.dart';

/// How many words were split; null when the word list is missing.
Future<int?> splitGluedWordsOnPages(WidgetRef ref, {int? block}) async {
  final words = await loadGluedWords();
  if (words == null) return null;
  final ws = ref.read(workspaceProvider);
  final settings = ref.read(settingsProvider);
  final workspace = ref.read(workspaceProvider.notifier);
  final pages = block == null ? ws.stepPages : [?ws.currentPage];
  var total = 0;
  for (final page in pages) {
    final blocks = [for (final b in page.blocks) b.copy()];
    final which = block == null ? blocks : [if (block >= 0 && block < blocks.length) blocks[block]];
    final n = words.splitBlocks(which, sourceLanguage: page.sourceOf(settings));
    if (n == 0) continue;
    total += n;
    workspace.edit(page.id, (p) => p.copyWith(blocks: blocks));
  }
  return total;
}

/// The typical line thickness of the very small text on [blocks] (pixels),
/// or null when none of it is very small.
double? smallTextLinePxOf(List<TextBlock> blocks) {
  final small = [
    for (final b in blocks)
      if (isSmallText(b) && b.text.trim().isNotEmpty) b.linePx!,
  ];
  if (small.isEmpty) return null;
  return npPercentile(small, 50);
}
