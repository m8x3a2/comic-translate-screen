/// Building text blocks from raw detections. Port of
/// `DetectionEngine.create_text_blocks` (`modules/detection/base.py`).
library;

import 'dart:math' as math;

import '../image/raster.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import 'foreground_color.dart';
import 'geometry.dart';

/// Splits blocks into lines and infers their direction (heuristic_lines).
typedef LineAnnotator = void Function(RgbImage image, List<TextBlock> blocks);

/// Filters and merges detector boxes, assigns each text box to the speech
/// bubble containing or overlapping it, measures the text colour and finally
/// lets [annotateLines] split blocks into lines.
List<TextBlock> createTextBlocks(
  RgbImage image,
  List<BBox> textBoxes,
  List<BBox> bubbleBoxes, {
  LineAnnotator? annotateLines,
  void Function(Object error, StackTrace stack)? onAnnotateError,
}) {
  final w = image.width, h = image.height;
  var texts = filterAndFixBboxes(textBoxes, imageHeight: h, imageWidth: w);
  final bubbles = filterAndFixBboxes(bubbleBoxes, imageHeight: h, imageWidth: w);
  texts = mergeOverlappingBoxes(texts);
  if (texts.isEmpty) return [];

  final colors = <List<int>?>[
    for (final t in texts)
      () {
        final x1 = math.max(0, t.x1), y1 = math.max(0, t.y1);
        final x2 = math.min(w, t.x2), y2 = math.min(h, t.y2);
        if (x2 > x1 && y2 > y1) return extractForegroundColor(image.crop(BBox(x1, y1, x2, y2)));
        return null;
      }(),
  ];

  final blocks = <TextBlock>[];
  for (var i = 0; i < texts.length; i++) {
    final text = texts[i];
    BBox? bubble;
    for (final b in bubbles) {
      if (doesRectangleFit(b, text) || doRectanglesOverlap(b, text)) {
        bubble = b;
        break;
      }
    }
    blocks.add(TextBlock(
      xyxy: text,
      bubbleXyxy: bubble,
      textClass: bubble == null ? TextClass.free : TextClass.bubble,
      fontColor: colors[i],
    ));
  }

  if (annotateLines != null) {
    try {
      annotateLines(image, blocks);
    } catch (e, st) {
      // The original prints and continues with unannotated blocks.
      onAnnotateError?.call(e, st);
    }
  }
  return blocks;
}
