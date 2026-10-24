/// Checking the lines the heuristics split comic blocks into. New in this
/// project: on dense text (a wall of text over a drawing, a screenshot of
/// prose) the heuristics of the original take several lines for one, or
/// turn horizontal text vertical; the recognizers then read a squeezed strip
/// and return a word or two.
///
/// A cheap look at the pixels picks the doubtful blocks ([doubtfulLines]);
/// on a page with any, a line detector (PP-OCR) finds the lines, and they
/// replace the heuristic ones where they are clearly more and thinner
/// ([preferFoundLines]). Blocks of ordinary comics keep their lines: on 59
/// test pages (2026-10-23) full-size comic pages read the same, small
/// screenshots and game screens better, a wall of text 0 → 83 % of words.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../imaging/mahotas.dart';
import '../imaging/py_compat.dart';
import '../detection/ppocr_det.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import '../models/model_manager.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';
import '../plugins/registry.dart';
import '../plugins/settings_schema.dart';
import '../settings/app_settings.dart';
import 'reading_scale.dart';
import 'script_fix.dart';

/// Rows with less ink than this share of the fullest one separate two bands
/// of text.
const lineGapInk = 0.15;

/// Bands shorter than this share of the tallest one are accents, dots or
/// noise, not lines.
const lineMinBand = 0.3;

/// Found lines replace the heuristic ones when they are at most this thick
/// (against the heuristic lines, measured the same way).
const lineThinner = 0.75;

/// Languages whose comics are written in vertical columns.
const _verticalLanguages = {'ja', 'zh'};

/// Bands of text across [box] of [image] (a horizontal line): rows of ink
/// separated by nearly empty rows. Ink is the less common side of the Otsu
/// threshold.
int inkBands(RgbImage image, BBox box) {
  final b = box.clampTo(image.width, image.height);
  if (b.width < 3 || b.height < 3) return 0;
  final w = b.width, h = b.height;
  final gray = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    var o = image.offset(b.x1, b.y1 + y);
    for (var x = 0; x < w; x++, o += 3) {
      final d = image.data;
      gray[y * w + x] = (d[o] * 299 + d[o + 1] * 587 + d[o + 2] * 114) ~/ 1000;
    }
  }
  final t = mahotasOtsu(gray);
  var dark = 0;
  for (final v in gray) {
    if (v <= t) dark++;
  }
  final darkInk = dark * 2 <= gray.length;
  final profile = Float64List(h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if ((gray[y * w + x] <= t) == darkInk) profile[y] += 1;
    }
  }
  final top = profile.reduce(math.max);
  if (top <= 0) return 0;
  final runs = <int>[];
  var run = 0;
  for (final v in profile) {
    if (v > lineGapInk * top) {
      run++;
    } else if (run > 0) {
      runs.add(run);
      run = 0;
    }
  }
  if (run > 0) runs.add(run);
  if (runs.isEmpty) return 0;
  final tallest = runs.reduce(math.max);
  return runs.where((r) => r >= math.max(2, lineMinBand * tallest)).length;
}

/// Why the heuristic lines of [block] look wrong ('vertical' or 'bands'),
/// or null. [languageCode]: the source language ('' when unknown).
String? doubtfulLines(RgbImage image, TextBlock block, String languageCode) {
  if (block.fixedLines || block.lines.isEmpty) return null;
  if (block.direction == TextDirection.vertical) {
    // Columns of Japanese or Chinese are left as they are: the strokes of
    // one character often look like two columns.
    return _verticalLanguages.contains(languageCode) ? null : 'vertical';
  }
  for (final l in block.lines) {
    if (inkBands(image, l.axisBox) >= 2) return 'bands';
  }
  return null;
}

/// Margin around a block cut out for the line detector (page pixels).
const lineCropMargin = 16;

/// Lines [detector] finds around [boxes] of [image] (page pixels): on
/// pieces cut around the boxes when the detector has less to look at that
/// way, else on the whole page (a large page with a doubtful bubble or two
/// took 5–7 s).
Future<List<BBox>> findLinesAround(
  RgbImage image,
  List<BBox> boxes,
  LineDetector detector,
  PluginContext context,
) async {
  final crops = mergeOverlapping([
    for (final b in boxes) b.inflate(lineCropMargin, lineCropMargin).clampTo(image.width, image.height),
  ]).where((c) => !c.isEmpty).toList();
  int cost(int w, int h) {
    final (dw, dh) = detInputSize(w, h);
    return dw * dh;
  }

  final cropCost = crops.fold(0, (n, c) => n + cost(c.width, c.height));
  // A tall narrow piece (a column of text) would be read in slices, whose
  // seams break lines: the page is read whole then.
  final tall = crops.any((c) => c.height > 3 * c.width);
  if (crops.isEmpty || tall || cropCost >= cost(image.width, image.height)) return detector.findLines(image, context);
  return [
    for (final c in crops)
      for (final l in await detector.findLines(image.crop(c), context)) l.translate(c.x1, c.y1),
  ];
}

/// [lines] given to the smallest block of [blocks] their centre falls in
/// (with a 4 px margin), clipped to it.
List<List<BBox>> assignLines(List<TextBlock> blocks, List<BBox> lines) {
  final out = [for (final _ in blocks) <BBox>[]];
  for (final l in lines) {
    final c = l.center;
    int? best;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i].xyxy.inflate(4, 4);
      if (c.x < b.x1 || c.x > b.x2 || c.y < b.y1 || c.y > b.y2) continue;
      if (best == null || blocks[i].xyxy.area < blocks[best].xyxy.area) best = i;
    }
    if (best == null) continue;
    final b = blocks[best].xyxy.inflate(4, 4);
    final clipped = BBox(math.max(l.x1, b.x1), math.max(l.y1, b.y1), math.min(l.x2, b.x2), math.min(l.y2, b.y2));
    if (clipped.width > 3 && clipped.height > 3) out[best].add(clipped);
  }
  return out;
}

bool _verticalLines(List<BBox> lines) => lines.where((l) => l.height > 1.25 * l.width).length * 2 > lines.length;

/// The [found] lines are better than the heuristic lines of [block]: there
/// are more of them, and they are thinner across their own direction (a
/// heuristic "line" holding several found lines is that much thicker).
bool preferFoundLines(TextBlock block, List<BBox> found) {
  if (found.length < 2 || found.length <= block.lines.length) return false;
  final vertical = _verticalLines(found);
  int across(BBox b) => vertical ? b.width : b.height;
  final heuristic = npMedian([for (final l in block.lines) across(l.axisBox)]);
  return npMedian(found.map(across)) <= lineThinner * heuristic;
}

/// [block] with the [found] lines, in reading order, kept as they are from
/// now on (`TextBlock.fixedLines`).
void useFoundLines(TextBlock block, List<BBox> found) {
  final vertical = _verticalLines(found);
  final sorted = [...found]
    ..sort(
      vertical ? (a, b) => b.x1.compareTo(a.x1) : (a, b) => a.y1 != b.y1 ? a.y1.compareTo(b.y1) : a.x1.compareTo(b.x1),
    );
  block.lines = [for (final l in sorted) TextLine.box(l)];
  block.direction = vertical ? TextDirection.vertical : TextDirection.horizontal;
  block.fixedLines = true;
}

// The safety net: text that came out as junk is read again.

final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
// Cyrillic text: Latin letters too, the recognizers mix in look-alikes ("HET").
final _cyrillic = RegExp(r'[\p{Script=Cyrillic}\p{Script=Latin}]', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\p{Nd}', unicode: true);
final _space = RegExp(r'\s', unicode: true);
const _punctuation = '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~«»“”„‘’…—–•';

/// Share of the characters of [text] (spaces aside) that cannot be text in
/// the source language [languageCode]: symbols (①, √, ∏, ₿, ¼) and letters
/// of another script (Greek θ in English). Digits and ordinary punctuation
/// are fine; with no language, or Japanese, Chinese or Korean, any letter.
double junkShare(String text, String languageCode) {
  final code = languageCode.toLowerCase();
  final RegExp? script = cyrillicLanguageCodes.contains(code)
      ? _cyrillic
      : code.isEmpty || const {'ja', 'zh', 'zh-cn', 'zh-tw', 'ko', 'th'}.contains(code)
      ? null
      : _latin;
  var all = 0, junk = 0;
  for (final r in text.runes) {
    final c = String.fromCharCode(r);
    if (_space.hasMatch(c)) continue;
    all++;
    final ok =
        _digit.hasMatch(c) ||
        _punctuation.contains(c) ||
        (_letter.hasMatch(c) && (script == null || script.hasMatch(c)));
    if (!ok) junk++;
  }
  return all == 0 ? 0 : junk / all;
}

/// The recognized [text] is mostly junk: at least six characters, a fifth of
/// them junk (see [junkShare]).
bool looksLikeJunk(String text, String languageCode) =>
    text.replaceAll(_space, '').length >= 6 && junkShare(text, languageCode) >= 0.2;

/// [block] of [image] came out empty though it holds lines of ink (two
/// bands or more, see [inkBands]): its lines were most likely wrong (a
/// column of English prose split into two "vertical" strips on an enlarged
/// copy, after [checkBlockLines] had looked).
bool readNothing(RgbImage image, TextBlock block) => block.text.trim().isEmpty && inkBands(image, block.xyxy) >= 2;

/// Blocks of [blocks] read as junk (see [looksLikeJunk]) or as nothing (see
/// [readNothing]) get the lines [detector] finds and are read again with
/// [ocr] on [image]; the new reading stays when it holds less junk (for an
/// empty block: when it has letters and is not junk). Catches what
/// [checkBlockLines] let through. Returns how many blocks got a better
/// reading.
Future<int> rereadJunk(
  OcrEngine ocr,
  RgbImage image,
  List<TextBlock> blocks,
  LineDetector detector,
  PluginContext context, {
  required String sourceLanguage,
  String languageCode = '',
}) async {
  final junk = [
    for (final b in blocks)
      if (!b.fixedLines && (looksLikeJunk(b.text, languageCode) || readNothing(image, b))) b,
  ];
  if (junk.isEmpty) return 0;
  final sw = Stopwatch()..start();
  await context.cancel.checkpoint();
  final found = assignLines(junk, await findLinesAround(image, [for (final b in junk) b.xyxy], detector, context));
  final again = <TextBlock, TextBlock>{};
  for (final (i, b) in junk.indexed) {
    if (found[i].isEmpty) continue;
    final c = again[b] = b.copy();
    useFoundLines(c, found[i]);
  }
  if (again.isEmpty) return 0;
  await context.cancel.checkpoint();
  await ocr.recognize(image, again.values.toList(), sourceLanguage: sourceLanguage, context: context);
  var better = 0;
  for (final MapEntry(key: b, value: c) in again.entries) {
    final gained = b.text.trim().isEmpty
        ? _letter.hasMatch(c.text) && !looksLikeJunk(c.text, languageCode)
        : junkShare(c.text, languageCode) < junkShare(b.text, languageCode);
    if (!gained) continue;
    b
      ..lines = c.lines
      ..direction = c.direction
      ..fixedLines = true
      ..text = c.text
      ..texts = c.texts
      ..linePx = npPercentile(lineThicknesses([c]), 50);
    better++;
  }
  context.log.info('junk_reread', {'blocks': junk.length, 'better': better, 'ms': sw.elapsedMilliseconds});
  return better;
}

/// The plugin that checks the lines (`ppocr_lines`).
const lineCheckerId = 'ppocr_lines';

/// The line detector that checks the lines of comic blocks, or null: the
/// check is off, the pages are not comics, or its model is not downloaded
/// (the heuristic lines are then read as they are).
Future<LineDetector?> loadLineChecker(
  PluginRegistry registry,
  AppSettings settings,
  PluginConfig? config,
  PluginEnvironment env,
) async {
  if (!settings.checksLines || !registry.contains(lineCheckerId)) return null;
  try {
    return await registry.instance<LineDetector>(lineCheckerId, config ?? PluginConfig(), env);
  } on ModelNotInstalledException catch (e) {
    env.log.warn('line_checker_model_missing', {'error': e.toString()});
    return null;
  }
}

/// Checks the heuristic lines of [blocks] on [image] and replaces the wrong
/// ones with lines found by [detector]; it runs only on a page with doubtful
/// blocks. Returns how many blocks got new lines.
Future<int> checkBlockLines(
  RgbImage image,
  List<TextBlock> blocks,
  LineDetector detector,
  PluginContext context, {
  String languageCode = '',
}) async {
  final sw = Stopwatch()..start();
  final doubtful = <int, String>{for (final (i, b) in blocks.indexed) i: ?doubtfulLines(image, b, languageCode)};
  if (doubtful.isEmpty) return 0;
  await context.cancel.checkpoint();
  final found = assignLines(
    blocks,
    await findLinesAround(image, [for (final i in doubtful.keys) blocks[i].xyxy], detector, context),
  );
  var replaced = 0;
  for (final i in doubtful.keys) {
    if (preferFoundLines(blocks[i], found[i])) {
      useFoundLines(blocks[i], found[i]);
      replaced++;
    }
  }
  context.log.info('lines_checked', {
    'blocks': blocks.length,
    'doubtful': doubtful.length,
    'vertical': doubtful.values.where((w) => w == 'vertical').length,
    'replaced': replaced,
    'ms': sw.elapsedMilliseconds,
  });
  return replaced;
}
