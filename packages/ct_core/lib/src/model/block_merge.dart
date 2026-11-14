/// "Merge into one bubble" (not in the original): blocks that the detector
/// cut out of one speech become one block again.
library;

import 'geometry.dart';
import 'language.dart';
import 'text_block.dart';

/// [blocks] (two or more, in reading order) as one block: the box around all
/// of them, their lines, texts and translations one after another. The look,
/// the languages and the measured lettering come from the first; its own
/// text box goes (the drawn text is placed anew). Who speaks: the first one
/// told. The outline of the letters is dropped (found again when cleaning).
TextBlock mergeBlocks(List<TextBlock> blocks) {
  if (blocks.isEmpty) throw ArgumentError('no blocks to merge');
  final first = blocks.first;
  if (blocks.length == 1) return first.copy();
  var box = first.xyxy;
  BBox? bubble;
  for (final b in blocks) {
    box = box.union(b.xyxy);
    if (b.bubbleXyxy case final bb?) bubble = bubble == null ? bb : bubble.union(bb);
  }
  // Chinese, Japanese and Thai have no spaces between words.
  final glue = Languages.isNoSpaceCode(first.sourceLang) ? '' : ' ';
  final targetGlue = Languages.isNoSpaceCode(first.targetLang) ? '' : ' ';
  String joined(Iterable<String> parts, String by) => [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ].join(by);
  final style = first.style?.copyWith(textBox: null, runs: const []);
  return first.copy()
    ..xyxy = box
    ..bubbleXyxy = bubble != null && bubble.containsBox(box) ? bubble : null
    ..lines = [for (final b in blocks) ...b.lines]
    ..fixedLines = blocks.every((b) => b.fixedLines)
    ..segmentationPoints = null
    ..texts = [for (final b in blocks) ...b.texts]
    ..text = joined(blocks.map((b) => b.text), glue)
    ..translation = joined(blocks.map((b) => b.translation), targetGlue)
    ..untranslated = blocks.any((b) => b.untranslated) && blocks.every((b) => b.translation.trim().isEmpty)
    ..style = style == null || style.isEmpty ? null : style
    ..speaker = blocks.map((b) => b.speaker).nonNulls.firstOrNull
    ..linePx = blocks.map((b) => b.linePx).nonNulls.firstOrNull;
}
