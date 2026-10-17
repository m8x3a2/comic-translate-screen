/// Reading order of text blocks. Port of `sort_blk_list` from
/// `modules/utils/textblock.py`.
library;

import '../model/text_block.dart';
import 'geometry.dart';

/// Sorts blocks top to bottom; blocks on the same row go left to right, or
/// right to left for vertical text when [rightToLeft] (Japanese).
List<TextBlock> sortBlocks(List<TextBlock> blocks, {bool rightToLeft = false}) {
  final sorted = <TextBlock>[];
  for (final blk in stableSortedBy(blocks, (b) => b.center.y)) {
    var inserted = false;
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      if (blk.center.y > s.xyxy.y2) continue;
      if (blk.center.y < s.xyxy.y1) {
        sorted.insert(i + 1, blk);
        inserted = true;
        break;
      }
      final pairVertical = blk.direction == TextDirection.vertical || s.direction == TextDirection.vertical;
      final pairRtl = pairVertical ? rightToLeft : false;
      if (pairRtl && blk.center.x > s.center.x) {
        sorted.insert(i, blk);
        inserted = true;
        break;
      }
      if (!pairRtl && blk.center.x < s.center.x) {
        sorted.insert(i, blk);
        inserted = true;
        break;
      }
    }
    if (!inserted) sorted.add(blk);
  }
  return sorted;
}
