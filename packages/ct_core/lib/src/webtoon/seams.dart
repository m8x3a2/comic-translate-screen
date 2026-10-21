/// Webtoon pages read as one strip: a bubble cut by the edge between two
/// pages is one block of the upper page that reaches below its bottom.
///
/// The original (`pipeline/webtoon_batch/`) detects both pages apart and
/// joins the two halves it finds at the edge (`_match_split_blocks`). Here
/// the upper page is detected together with the top of the page below, so
/// the detector sees the whole bubble; blocks that start on the lower page
/// are left to it, and the lower page drops what continues a block of the
/// page above. Reading and cleaning such a block use the page with the rows
/// of the next page it needs; the cleaned part below the edge is kept with
/// the upper page as a patch, drawn over the lower page.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';

/// Where the page below starts horizontally, in the upper page's pixels:
/// pages of the strip are centred on each other.
int seamDx(int upperWidth, int lowerWidth) => (upperWidth - lowerWidth) ~/ 2;

/// Rows of the next page detection looks at: bubbles rarely reach further
/// below the edge than the page is wide.
int detectionReach(int pageWidth, int nextHeight) => math.min(nextHeight, math.max(256, pageWidth));

/// Room around a block that reading and cleaning use (crops, dilation).
const seamPad = 48;

/// How many rows below [pageHeight] the blocks reach (0: none).
int overflowOf(Iterable<TextBlock> blocks, int pageHeight) {
  var bottom = pageHeight;
  for (final b in blocks) {
    bottom = math.max(bottom, math.max(b.xyxy.y2, b.bubbleXyxy?.y2 ?? 0));
  }
  return bottom - pageHeight;
}

/// Rows of the next page an image of the page needs for [blocks] (0: none).
int seamRows(Iterable<TextBlock> blocks, int pageHeight, int nextHeight) {
  final over = overflowOf(blocks, pageHeight);
  return over <= 0 ? 0 : math.min(nextHeight, over + seamPad);
}

/// [page] with the first [rows] rows of [next] below it, in [page]'s width
/// ([next] centred on it; white where it is narrower).
RgbImage extendBelow(RgbImage page, RgbImage next, int rows) {
  rows = math.min(rows, next.height);
  if (rows <= 0) return page;
  final w = page.width;
  final out = Uint8List((page.height + rows) * w * 3)..fillRange(page.data.length, (page.height + rows) * w * 3, 255);
  out.setRange(0, page.data.length, page.data);
  final dx = seamDx(w, next.width);
  final from = math.max(0, dx), to = math.min(w, dx + next.width);
  if (to > from) {
    for (var y = 0; y < rows; y++) {
      final dst = ((page.height + y) * w + from) * 3;
      final src = (y * next.width + from - dx) * 3;
      out.setRange(dst, dst + (to - from) * 3, next.data, src);
    }
  }
  return RgbImage(w, page.height + rows, out);
}

/// The blocks that start on the page (above [pageHeight]); the others
/// belong to the page below.
List<TextBlock> ownBlocks(Iterable<TextBlock> found, int pageHeight) => [
  for (final b in found)
    if (b.xyxy.y1 < pageHeight) b,
];

/// Where the blocks of the page above reach into the page below, in the
/// lower page's pixels.
List<BBox> reachInto(Iterable<TextBlock> upper, int upperHeight, int upperWidth, int lowerWidth) {
  final dx = seamDx(upperWidth, lowerWidth);
  return [
    for (final b in upper)
      if (b.xyxy.y2 > upperHeight)
        BBox(b.xyxy.x1 - dx, b.xyxy.y1 - upperHeight, b.xyxy.x2 - dx, b.xyxy.y2 - upperHeight),
  ];
}

/// [blocks] without those lying mostly (over [share] of their box) in
/// [covered]: they continue a bubble of the page above.
List<TextBlock> withoutCovered(Iterable<TextBlock> blocks, List<BBox> covered, {double share = 0.5}) => [
  for (final b in blocks)
    if (!covered.any((c) => (b.xyxy.intersection(c)?.area ?? 0) > share * math.max(1, b.xyxy.area))) b,
];

/// A cleaned part of the page below, kept with the page above: [image] goes
/// at the upper page's bottom-left corner, where [alpha] is set.
class SeamPatch {
  SeamPatch(this.image, this.alpha) : assert(image.width == alpha.width && image.height == alpha.height);

  final RgbImage image;
  final GrayImage alpha;
}

/// Splits an extended page cleaned with [mask] into the page itself and the
/// patch below its bottom (null when nothing below was cleaned).
(RgbImage, SeamPatch?) splitBelow(RgbImage cleaned, GrayImage mask, int pageHeight) {
  if (cleaned.height <= pageHeight) return (cleaned, null);
  final w = cleaned.width;
  final page = RgbImage(w, pageHeight, Uint8List.fromList(Uint8List.sublistView(cleaned.data, 0, w * pageHeight * 3)));
  final rows = cleaned.height - pageHeight;
  final alpha = GrayImage.zeros(w, rows);
  var any = false;
  for (var y = 0; y < rows && pageHeight + y < mask.height; y++) {
    for (var x = 0; x < w && x < mask.width; x++) {
      if (mask.at(x, pageHeight + y) > 0) {
        alpha.data[y * w + x] = 255;
        any = true;
      }
    }
  }
  if (!any) return (page, null);
  final below = RgbImage(w, rows, Uint8List.fromList(Uint8List.sublistView(cleaned.data, w * pageHeight * 3)));
  return (page, SeamPatch(below, alpha));
}

/// [lower] with the [patch] of the page above (of [upperWidth]) drawn over
/// its top.
RgbImage applyPatch(RgbImage lower, SeamPatch patch, int upperWidth) {
  final out = lower.clone();
  final dx = seamDx(upperWidth, lower.width);
  final pw = patch.image.width;
  for (var y = 0; y < patch.image.height && y < lower.height; y++) {
    for (var px = 0; px < pw; px++) {
      if (patch.alpha.data[y * pw + px] == 0) continue;
      final x = px - dx;
      if (x < 0 || x >= lower.width) continue;
      final s = (y * pw + px) * 3, d = (y * lower.width + x) * 3;
      out.data[d] = patch.image.data[s];
      out.data[d + 1] = patch.image.data[s + 1];
      out.data[d + 2] = patch.image.data[s + 2];
    }
  }
  return out;
}

/// The mask rows of a page extended by [rows]: [mask] (the page's size or
/// already extended) padded with empty rows.
GrayImage extendMask(GrayImage mask, int height) {
  if (mask.height >= height) return mask;
  final out = GrayImage.zeros(mask.width, height);
  out.data.setRange(0, mask.data.length, mask.data);
  return out;
}
