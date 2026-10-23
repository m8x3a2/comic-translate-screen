/// Preparing small text for line splitting and OCR. Not in the original:
/// screenshots and low-resolution scans have 6–8 px glyphs, too small for the
/// line heuristics (their thresholds are in pixels) and for the recognizers.
/// Detection boxes are fine at that size, so only the reading step works on
/// enlarged copies, and only of the pieces with thin lines: each piece is
/// enlarged by a [TextUpscaler] (plain Lanczos or a neural network) and the
/// pieces are put together on canvases. Blocks with ordinary text are read
/// on the page as it is. Block geometry is returned in page coordinates.
///
/// The experiment of step 2 (`ocr-experiment/RESULTS.md`) set the factor:
/// enlarging to a target line height (≈×3) merged the gaps between words;
/// ×2 (comics) and ×1.5 (screens) read best.
library;

import 'dart:math' as math;

import '../detection/heuristic_lines.dart';
import '../diagnostics/event_log.dart';
import '../image/raster.dart';
import '../imaging/py_compat.dart';
import '../model/geometry.dart';
import '../model/language.dart';
import '../model/text_block.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';
import 'line_check.dart';
import 'text_prep.dart';

/// Blocks whose lines are thinner than this (median line thickness, page
/// pixels) are read from an enlarged copy. Thicker text gains little: the
/// recognizers scale every line to 48 px anyway.
const readingSmallLinePx = 20.0;

/// On a page with small text, blocks with lines up to this thickness (or
/// with no lines found) are enlarged too: on tiny text the line splitter
/// often takes two or three lines for one thick line.
const readingUnsureLinePx = 64.0;

/// Margin around each piece (page pixels): the line splitter looks a few
/// pixels past a block, and the neural networks are least exact at the
/// edges.
const readingPieceMargin = 8;

/// Upper bound for one canvas of enlarged pieces (pixels); pieces of a long
/// page (webtoon) are spread over several canvases.
const readingMaxPixels = 16000000;

/// Time a neural network may spend on the pieces of one page by default
/// (ms, by its estimate corrected with the speed it shows; the setting
/// `tools.text_prep_seconds`). Pieces with the smallest
/// text go first; the rest are enlarged plainly (Lanczos, same factor).
/// "High" takes about 250 s per million pixels on a laptop processor: a
/// page full of text took over ten minutes before.
const readingNeuralBudgetMs = 60000;

/// Thickness of every heuristic line of [blocks].
List<int> lineThicknesses(List<TextBlock> blocks) => [
  for (final b in blocks)
    for (final l in b.lines)
      () {
        final a = l.axisBox;
        return b.direction == TextDirection.vertical ? a.x2 - a.x1 + 1 : a.y2 - a.y1 + 1;
      }(),
];

/// [b] has small text (its lines are known and thin).
bool isSmallLines(TextBlock b) => (b.linePx ?? double.infinity) < readingSmallLinePx;

/// The blocks of a page that are read from an enlarged copy: none when no
/// block has small text, else those with lines thinner than
/// [readingUnsureLinePx] or unknown.
List<TextBlock> blocksToEnlarge(List<TextBlock> blocks) => blocks.any(isSmallLines)
    ? [
        for (final b in blocks)
          if ((b.linePx ?? 0) < readingUnsureLinePx) b,
      ]
    : const [];

/// Enlarged pieces of a page put together, with the blocks they hold (in
/// canvas coordinates until [ReadingPage.restore]).
class ReadingCanvas {
  ReadingCanvas._(this.image, this.blocks, this.region, this.scaleX, this.scaleY, this.pieces);

  final RgbImage image;
  final List<TextBlock> blocks;

  /// The part of the page the canvas covers.
  final BBox region;
  final double scaleX;
  final double scaleY;

  /// Enlarged pieces on it.
  final int pieces;

  BBox toCanvas(BBox b) => BBox(
    ((b.x1 - region.x1) * scaleX).floor(),
    ((b.y1 - region.y1) * scaleY).floor(),
    ((b.x2 - region.x1) * scaleX).ceil(),
    ((b.y2 - region.y1) * scaleY).ceil(),
  );

  TextLine lineToCanvas(TextLine l) => scaleLine(translateLine(l, -region.x1, -region.y1), scaleX, scaleY);

  TextLine lineToPage(TextLine l) => translateLine(scaleLine(l, 1 / scaleX, 1 / scaleY), region.x1, region.y1);
}

/// A page prepared for reading: the blocks read on the page as it is
/// ([asIs]) and the canvases of enlarged pieces.
class ReadingPage {
  ReadingPage._(this.asIs, this.canvases, this.factor, this._saved, [this.plainPieces = 0]);

  final List<TextBlock> asIs;
  final List<ReadingCanvas> canvases;

  /// How much the pieces were enlarged (1: nothing was).
  final double factor;
  final Map<TextBlock, _Saved> _saved;

  bool get scaled => canvases.isNotEmpty;

  /// Enlarged pieces, all canvases together.
  int get pieces => canvases.fold(0, (n, c) => n + c.pieces);

  /// Pieces enlarged plainly instead of by the neural network, to keep the
  /// page within [readingNeuralBudgetMs].
  final int plainPieces;

  /// Puts the blocks back into page coordinates: boxes and the lines of a
  /// line detector exactly as they were, lines found on a canvas scaled
  /// down.
  void restore() {
    for (final c in canvases) {
      for (final b in c.blocks) {
        final s = _saved[b]!;
        b.xyxy = s.box;
        b.bubbleXyxy = s.bubble;
        b.lines = b.fixedLines ? s.lines : [for (final l in b.lines) c.lineToPage(l)];
      }
    }
  }
}

class _Saved {
  _Saved(this.box, this.bubble, this.lines);

  final BBox box;
  final BBox? bubble;
  final List<TextLine> lines;
}

/// Splits [blocks] into lines where needed, notes their line thickness
/// (`TextBlock.linePx`) and enlarges the pieces with small text with
/// [upscaler] (no enlarging without one, or when its factor is 1). With
/// [sourceLanguageCode] the line splitter also gets the language hint.
///
/// Blocks without lines (boxes drawn by hand, or resized) are split first,
/// on the page as it is: otherwise their text size would be unknown and they
/// would be read as one line. With [lineChecker] the heuristic lines are
/// then checked (see `line_check.dart`), before the text size is taken from
/// them. A neural [upscaler] keeps to [neuralBudgetMs] a page (0 or less:
/// no limit).
Future<ReadingPage> prepareReading(
  RgbImage image,
  List<TextBlock> blocks, {
  String sourceLanguageCode = '',
  TextUpscaler? upscaler,
  LineDetector? lineChecker,
  int neuralBudgetMs = readingNeuralBudgetMs,
  PluginContext? context,
}) async {
  final bare = [
    for (final b in blocks)
      if (b.lines.isEmpty) b,
  ];
  if (bare.isNotEmpty) {
    try {
      annotateBlocksWithHeuristicLines(image, bare, sourceLanguage: sourceLanguageCode);
    } on Object {
      // The heuristics gave up: those blocks are read whole, as before.
    }
  }
  if (lineChecker != null) {
    await checkBlockLines(image, blocks, lineChecker, context ?? _noContext, languageCode: sourceLanguageCode);
  }
  for (final b in blocks) {
    final t = lineThicknesses([b]);
    if (t.isNotEmpty) b.linePx = npPercentile(t, 50);
  }
  final f = upscaler?.factor ?? 1.0;
  final small = f > 1.0 ? blocksToEnlarge(blocks) : const <TextBlock>[];
  if (small.isEmpty) return ReadingPage._(blocks, const [], 1.0, const {});

  // Pieces: blocks with a margin, overlapping ones joined.
  final pieces = mergeOverlapping([
    for (final b in small) b.xyxy.inflate(readingPieceMargin, readingPieceMargin).clampTo(image.width, image.height),
  ]).where((r) => !r.isEmpty).toList()..sort((a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1));

  // Canvases: pieces from the top down while the canvas stays small enough.
  final groups = <List<BBox>>[];
  BBox? region;
  for (final r in pieces) {
    final joined = region == null ? r : region.union(r);
    if (region != null && joined.area * f * f > readingMaxPixels) {
      groups.add([r]);
      region = r;
    } else {
      if (groups.isEmpty) groups.add([]);
      groups.last.add(r);
      region = joined;
    }
  }

  final saved = <TextBlock, _Saved>{};
  final canvases = <ReadingCanvas>[];
  final placed = <TextBlock>{};
  final budget = _Budget(upscaler!, pieces, small, neuralBudgetMs);
  final plain = PlainTextUpscaler(plainX2Info, f);
  var plainPieces = 0;
  try {
    for (final group in groups) {
      final region = group.reduce((a, b) => a.union(b));
      final g = math.min(f, math.max(1.0, math.sqrt(readingMaxPixels / math.max(1, region.area))));
      final w = math.max(1, (region.width * g).round()), h = math.max(1, (region.height * g).round());
      final canvas = RgbImage.filled(w, h, 255, 255, 255);
      final sx = w / region.width, sy = h / region.height;
      for (final r in group) {
        final x1 = ((r.x1 - region.x1) * sx).round(), x2 = ((r.x2 - region.x1) * sx).round();
        final y1 = ((r.y1 - region.y1) * sy).round(), y2 = ((r.y2 - region.y1) * sy).round();
        if (x2 <= x1 || y2 <= y1) continue;
        // The work runs in the background isolate: a cancel gets in here.
        await context?.cancel.checkpoint();
        final k = pieces.indexOf(r);
        final RgbImage piece;
        if (budget.neural.contains(k)) {
          final sw = Stopwatch()..start();
          piece = await upscaler.enlarge(image.crop(r), x2 - x1, y2 - y1, context ?? _noContext);
          budget.record(k, sw.elapsedMilliseconds);
        } else {
          piece = await plain.enlarge(image.crop(r), x2 - x1, y2 - y1, context ?? _noContext);
          plainPieces++;
        }
        paste(canvas, piece, x1, y1);
      }
      final inside = [
        for (final b in small)
          if (!placed.contains(b) &&
              group.any(
                (r) => r.containsBox(
                  b.xyxy.inflate(readingPieceMargin, readingPieceMargin).clampTo(image.width, image.height),
                ),
              ))
            b,
      ];
      placed.addAll(inside);
      final c = ReadingCanvas._(canvas, inside, region, sx, sy, group.length);
      for (final b in inside) {
        saved[b] = _Saved(b.xyxy, b.bubbleXyxy, b.lines);
        b.xyxy = c.toCanvas(b.xyxy);
        final bubble = b.bubbleXyxy;
        if (bubble != null) b.bubbleXyxy = c.toCanvas(bubble);
        // Lines of a line detector are exact: they are only moved.
        b.lines = b.fixedLines ? [for (final l in b.lines) c.lineToCanvas(l)] : [];
      }
      final split = [
        for (final b in inside)
          if (!b.fixedLines) b,
      ];
      if (split.isNotEmpty) annotateBlocksWithHeuristicLines(canvas, split, sourceLanguage: sourceLanguageCode);
      canvases.add(c);
    }
  } on Object {
    // Stopped half way (cancelled): the blocks moved so far go back.
    ReadingPage._(const [], canvases, f, saved).restore();
    rethrow;
  }
  final asIs = [
    for (final b in blocks)
      if (!placed.contains(b)) b,
  ];
  if (plainPieces > 0) {
    context?.log.info('text_prep_budget', {
      'with': upscaler.info.id,
      'neural': pieces.length - plainPieces,
      'plain': plainPieces,
      'neural_ms': budget.spentMs.round(),
    });
  }
  return ReadingPage._(asIs, canvases, f, saved, plainPieces);
}

/// Which pieces the neural network enlarges ([neural]): those with the
/// smallest text first, while their estimated time fits in [budgetMs] (all
/// of them when it is 0 or less). Planned again after every piece, with the
/// speed it showed.
class _Budget {
  _Budget(this.upscaler, this.pieces, List<TextBlock> small, this.budgetMs) {
    double need(BBox r) {
      final inside = [
        for (final b in small)
          if (r.containsBox(b.xyxy)) b.linePx ?? readingUnsureLinePx,
      ];
      return inside.isEmpty ? readingUnsureLinePx : inside.reduce(math.min);
    }

    final needs = [for (final r in pieces) need(r)];
    order = [for (var i = 0; i < pieces.length; i++) i]
      ..sort((a, b) => needs[a] != needs[b] ? needs[a].compareTo(needs[b]) : pieces[a].area.compareTo(pieces[b].area));
    neural = _plan();
  }

  final TextUpscaler upscaler;
  final List<BBox> pieces;
  final int budgetMs;
  late final List<int> order;
  late Set<int> neural;
  final _done = <int>{};
  var spentMs = 0.0;
  var _estimatedDone = 0.0;

  /// Real time against the estimate (1 until a piece is done).
  double get _speed => _estimatedDone > 0 ? spentMs / _estimatedDone : 1.0;

  double _estimate(int i) => upscaler.estimateMs(pieces[i].width, pieces[i].height);

  Set<int> _plan() {
    final left = budgetMs <= 0 ? double.infinity : budgetMs - spentMs;
    var sum = 0.0;
    final out = <int>{};
    for (final i in order) {
      if (_done.contains(i)) continue;
      final ms = _estimate(i) * _speed;
      if (sum + ms <= left) {
        sum += ms;
        out.add(i);
      }
    }
    return out;
  }

  void record(int i, int ms) {
    _done.add(i);
    spentMs += ms;
    _estimatedDone += _estimate(i);
    neural = _plan();
  }
}

/// Prepares [image] for reading (see [prepareReading]) and recognizes
/// [blocks] with [ocr]: ordinary text on the page, small text on the
/// canvases of enlarged pieces.
Future<ReadingPage> readBlocks(
  OcrEngine ocr,
  RgbImage image,
  List<TextBlock> blocks, {
  required String sourceLanguage,
  required PluginContext context,
  TextUpscaler? upscaler,
  LineDetector? lineChecker,
  int neuralBudgetMs = readingNeuralBudgetMs,
}) async {
  final sw = Stopwatch()..start();
  final reading = await prepareReading(
    image,
    blocks,
    sourceLanguageCode: Languages.byName(sourceLanguage)?.code ?? '',
    upscaler: upscaler,
    lineChecker: lineChecker,
    neuralBudgetMs: neuralBudgetMs,
    context: context,
  );
  if (reading.scaled) {
    context.log.info('text_prepared', {
      'with': upscaler!.info.id,
      'factor': reading.factor,
      'pieces': reading.pieces,
      if (reading.plainPieces > 0) 'plain': reading.plainPieces,
      'blocks': blocks.length - reading.asIs.length,
      'ms': sw.elapsedMilliseconds,
    });
  }
  try {
    if (reading.asIs.isNotEmpty) {
      await ocr.recognize(image, reading.asIs, sourceLanguage: sourceLanguage, context: context);
    }
    for (final c in reading.canvases) {
      if (c.blocks.isEmpty) continue;
      await context.cancel.checkpoint();
      await ocr.recognize(c.image, c.blocks, sourceLanguage: sourceLanguage, context: context);
    }
  } finally {
    reading.restore();
  }
  if (lineChecker != null) {
    await rereadJunk(
      ocr,
      image,
      blocks,
      lineChecker,
      context,
      sourceLanguage: sourceLanguage,
      languageCode: Languages.byName(sourceLanguage)?.code ?? '',
    );
  }
  return reading;
}

final _noContext = PluginContext(log: EventLog.silent());

/// [boxes] with every group of overlapping boxes replaced by the box around
/// it.
List<BBox> mergeOverlapping(List<BBox> boxes) {
  final out = [...boxes];
  var merged = true;
  while (merged) {
    merged = false;
    for (var i = 0; i < out.length && !merged; i++) {
      for (var j = i + 1; j < out.length; j++) {
        if (out[i].intersection(out[j]) != null) {
          out[i] = out[i].union(out[j]);
          out.removeAt(j);
          merged = true;
          break;
        }
      }
    }
  }
  return out;
}

/// Copies [piece] into [canvas] with its top left corner at [x], [y]
/// (clipped to the canvas).
void paste(RgbImage canvas, RgbImage piece, int x, int y) {
  final x1 = math.max(0, x), x2 = math.min(canvas.width, x + piece.width);
  if (x2 <= x1) return;
  for (var py = math.max(0, y); py < math.min(canvas.height, y + piece.height); py++) {
    final src = piece.offset(x1 - x, py - y);
    canvas.data.setRange(canvas.offset(x1, py), canvas.offset(x1, py) + (x2 - x1) * 3, piece.data, src);
  }
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

/// [l] moved by [dx], [dy].
TextLine translateLine(TextLine l, int dx, int dy) {
  final p = l.polygon;
  if (p != null) return TextLine.polygon([for (final q in p) Point2(q.x + dx, q.y + dy)]);
  final b = l.box!;
  return TextLine.box(BBox(b.x1 + dx, b.y1 + dy, b.x2 + dx, b.y2 + dy));
}
