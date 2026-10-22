/// Enlarging small text before line splitting and OCR. Not in the original:
/// screenshots and low-resolution scans have 6–8 px glyphs, too small for the
/// line heuristics (their thresholds are in pixels) and for the recognizers.
/// Detection boxes are fine at that size, so only the reading step works on
/// an enlarged copy; block geometry is returned in page coordinates.
library;

import 'dart:math' as math;

import '../detection/heuristic_lines.dart';
import '../image/raster.dart';
import '../imaging/pil.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// Line thickness (height of horizontal lines, width of vertical columns)
/// the reading step aims for.
const readingTargetLinePx = 36.0;

/// Pages are enlarged only when that gains at least this factor.
const readingMinGain = 1.25;
const readingMaxFactor = 4.0;

/// Upper bound for the enlarged page (pixels), to keep memory in check.
const readingMaxPixels = 60000000;

/// Thickness of every heuristic line of [blocks].
List<int> lineThicknesses(List<TextBlock> blocks) => [
      for (final b in blocks)
        for (final l in b.lines)
          () {
            final a = l.axisBox;
            return b.direction == TextDirection.vertical ? a.x2 - a.x1 + 1 : a.y2 - a.y1 + 1;
          }(),
    ];

/// How much to enlarge a page for reading, from its smaller lines (25th
/// percentile of line thickness). 1 when the text is large enough.
double readingScaleFactor(RgbImage image, List<TextBlock> blocks) {
  final t = lineThicknesses(blocks);
  if (t.isEmpty) return 1.0;
  final small = npPercentile(t, 25);
  var f = math.min(readingMaxFactor, readingTargetLinePx / math.max(1.0, small));
  f = math.min(f, math.sqrt(readingMaxPixels / (image.width * image.height)));
  return f >= readingMinGain ? f : 1.0;
}

/// A page prepared for reading: the (possibly enlarged) image, with the
/// blocks moved into its coordinates until [restore] is called.
class ReadingPage {
  ReadingPage._(this.image, this.blocks, this.scaleX, this.scaleY, this._boxes, this._bubbles);

  final RgbImage image;
  final List<TextBlock> blocks;
  final double scaleX;
  final double scaleY;
  final List<BBox> _boxes;
  final List<BBox?> _bubbles;

  bool get scaled => scaleX != 1.0 || scaleY != 1.0;

  /// Puts the blocks back into page coordinates (lines scaled down, boxes
  /// restored exactly).
  void restore() {
    if (!scaled) return;
    for (final (i, b) in blocks.indexed) {
      b.xyxy = _boxes[i];
      b.bubbleXyxy = _bubbles[i];
      b.lines = [for (final l in b.lines) scaleLine(l, 1 / scaleX, 1 / scaleY)];
    }
  }
}

/// Enlarges [image] when its text is small (see [readingScaleFactor]) and
/// re-splits the blocks into lines on the enlarged copy. With
/// [sourceLanguageCode] the line splitter also gets the language hint.
///
/// Blocks without lines (boxes drawn by hand, or resized) are split first,
/// on the page as it is: otherwise their text would not count towards the
/// enlargement and they would be read as one line.
ReadingPage prepareReading(RgbImage image, List<TextBlock> blocks, {String sourceLanguageCode = '', bool enabled = true}) {
  final bare = [for (final b in blocks) if (b.lines.isEmpty) b];
  if (bare.isNotEmpty) {
    try {
      annotateBlocksWithHeuristicLines(image, bare, sourceLanguage: sourceLanguageCode);
    } on Object {
      // The heuristics gave up: those blocks are read whole, as before.
    }
  }
  for (final b in blocks) {
    final t = lineThicknesses([b]);
    if (t.isNotEmpty) b.linePx = npPercentile(t, 50);
  }
  final f = enabled ? readingScaleFactor(image, blocks) : 1.0;
  final boxes = [for (final b in blocks) b.xyxy];
  final bubbles = [for (final b in blocks) b.bubbleXyxy];
  if (f == 1.0) return ReadingPage._(image, blocks, 1.0, 1.0, boxes, bubbles);

  final w = (image.width * f).round(), h = (image.height * f).round();
  final sx = w / image.width, sy = h / image.height;
  final scaledImage = pilResize(image, w, h, filter: PilFilter.lanczos);
  for (final b in blocks) {
    b.xyxy = scaleBox(b.xyxy, sx, sy);
    final bubble = b.bubbleXyxy;
    if (bubble != null) b.bubbleXyxy = scaleBox(bubble, sx, sy);
    b.lines = [];
  }
  annotateBlocksWithHeuristicLines(scaledImage, blocks, sourceLanguage: sourceLanguageCode);
  return ReadingPage._(scaledImage, blocks, sx, sy, boxes, bubbles);
}

/// [b] scaled outwards (the result covers the scaled box).
BBox scaleBox(BBox b, double sx, double sy) =>
    BBox((b.x1 * sx).floor(), (b.y1 * sy).floor(), (b.x2 * sx).ceil(), (b.y2 * sy).ceil());

/// [l] with every coordinate scaled and rounded.
TextLine scaleLine(TextLine l, double sx, double sy) {
  final p = l.polygon;
  if (p != null) {
    return TextLine.polygon([for (final q in p) Point2((q.x * sx).roundToDouble(), (q.y * sy).roundToDouble())]);
  }
  final b = l.box!;
  return TextLine.box(BBox((b.x1 * sx).round(), (b.y1 * sy).round(), (b.x2 * sx).round(), (b.y2 * sy).round()));
}
