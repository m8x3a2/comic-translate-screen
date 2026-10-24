/// Text layout for the translated text: where it goes, how it wraps and at
/// which size it fits. Port of `modules/rendering/render.py`
/// (`pyside_word_wrap`, the greedy wrappers, `get_best_render_area`) and the
/// batch rendering step of `pipeline/batch_processor.py`.
///
/// Measuring text needs a font engine, so it is abstracted as
/// [TextMeasurer]; the app implements it with Flutter's `dart:ui`.
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import '../model/language.dart';
import '../model/text_block.dart';
import '../translation/llm_protocol.dart';
import 'hyphenation.dart';
import 'source_style.dart';
import 'text_case.dart';

enum TextAlignment { left, center, right }

/// Text rendering settings (`TextRenderingSettings`); defaults are the
/// original's.
class RenderSettings {
  const RenderSettings({
    this.fontFamily = '',
    this.minFontSize = 9,
    this.maxFontSize = 40,
    this.color = 0xFF000000,
    this.textCase = TextCase.source,
    this.outline = true,
    this.outlineColor = 0xFFFFFFFF,
    this.outlineWidth = 1.0,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.lineSpacing = 1.0,
    this.alignment = TextAlignment.center,
    this.placeInBlock = true,
    this.matchSource = true,
    this.hyphenate = true,
    this.shapeFit = false,
  });

  /// Font family or font file; empty = the app's default font.
  final String fontFamily;

  /// Font sizes in points (1 pt = 4/3 px at the 96 dpi used for pages).
  final int minFontSize;
  final int maxFontSize;

  /// ARGB colours.
  final int color;
  final TextCase textCase;
  final bool outline;
  final int outlineColor;
  final double outlineWidth;
  final bool bold;
  final bool italic;
  final bool underline;
  final double lineSpacing;
  final TextAlignment alignment;

  /// Places the fitted text inside its area: horizontally by [alignment],
  /// vertically centred. The original puts it at the area's top-left corner
  /// (false), which leaves short lines off-centre in their bubbles.
  final bool placeInBlock;

  /// Outline, bold and italic as the source lettering has them (see
  /// [SourceStyle]). Not in the original.
  final bool matchSource;

  /// Russian words may be broken by syllables where that lets the text be
  /// much larger. Not in the original.
  final bool hyphenate;

  /// Lines follow the oval of the speech bubble. Not in the original.
  final bool shapeFit;

  RenderSettings copyWith({
    String? fontFamily,
    int? minFontSize,
    int? maxFontSize,
    int? color,
    TextCase? textCase,
    bool? outline,
    int? outlineColor,
    double? outlineWidth,
    bool? bold,
    bool? italic,
    bool? underline,
    double? lineSpacing,
    TextAlignment? alignment,
    bool? placeInBlock,
    bool? matchSource,
    bool? hyphenate,
    bool? shapeFit,
  }) =>
      RenderSettings(
        fontFamily: fontFamily ?? this.fontFamily,
        minFontSize: minFontSize ?? this.minFontSize,
        maxFontSize: maxFontSize ?? this.maxFontSize,
        color: color ?? this.color,
        textCase: textCase ?? this.textCase,
        outline: outline ?? this.outline,
        outlineColor: outlineColor ?? this.outlineColor,
        outlineWidth: outlineWidth ?? this.outlineWidth,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        alignment: alignment ?? this.alignment,
        placeInBlock: placeInBlock ?? this.placeInBlock,
        matchSource: matchSource ?? this.matchSource,
        hyphenate: hyphenate ?? this.hyphenate,
        shapeFit: shapeFit ?? this.shapeFit,
      );

  Map<String, Object?> toJson() => {
        'font_family': fontFamily,
        'min_font_size': minFontSize,
        'max_font_size': maxFontSize,
        'color': _hex(color),
        'text_case': textCase.name,
        'outline': outline,
        'outline_color': _hex(outlineColor),
        'outline_width': outlineWidth,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'line_spacing': lineSpacing,
        'alignment': alignment.name,
        'place_in_block': placeInBlock,
        'match_source': matchSource,
        'hyphenate': hyphenate,
        'shape_fit': shapeFit,
      };

  factory RenderSettings.fromJson(Map<String, Object?> j) {
    const d = RenderSettings();
    T pick<T>(String key, T fallback) => j[key] is T ? j[key] as T : fallback;
    return RenderSettings(
      fontFamily: pick('font_family', d.fontFamily),
      minFontSize: pick<num>('min_font_size', d.minFontSize).toInt(),
      maxFontSize: pick<num>('max_font_size', d.maxFontSize).toInt(),
      color: parseColor(pick('color', '')) ?? d.color,
      // Older settings had one switch: on = all capitals.
      textCase: TextCase.values.asNameMap()[j['text_case']] ??
          (j['upper_case'] == true ? TextCase.upper : d.textCase),
      outline: pick('outline', d.outline),
      outlineColor: parseColor(pick('outline_color', '')) ?? d.outlineColor,
      outlineWidth: pick<num>('outline_width', d.outlineWidth).toDouble(),
      bold: pick('bold', d.bold),
      italic: pick('italic', d.italic),
      underline: pick('underline', d.underline),
      lineSpacing: pick<num>('line_spacing', d.lineSpacing).toDouble(),
      alignment: TextAlignment.values.firstWhere((a) => a.name == j['alignment'], orElse: () => d.alignment),
      placeInBlock: pick('place_in_block', d.placeInBlock),
      matchSource: pick('match_source', d.matchSource),
      hyphenate: pick('hyphenate', d.hyphenate),
      shapeFit: pick('shape_fit', d.shapeFit),
    );
  }
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Parses `#rrggbb` / `#aarrggbb` into ARGB; null when invalid.
int? parseColor(String s) {
  final h = s.trim().replaceFirst('#', '');
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return h.length == 6 ? 0xFF000000 | v : v;
}

/// Measures laid-out text: `QTextDocument.size()` of the original, i.e. the
/// text box including the document margin, for text whose lines are already
/// broken with `\n`.
abstract interface class TextMeasurer {
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical});
}

/// Ink heights of a font's letters per pixel of font size: of a capital
/// (H) and of a small letter (x). A [TextMeasurer] that knows them lets the
/// translation take the size of the source letters.
abstract interface class LetterMetrics {
  double get capHeight;
  double get xHeight;
}

/// Typical ink heights when the font's are unknown.
const _defaultCapHeight = 0.7, _defaultXHeight = 0.5;

/// One piece of text to draw on a page.
class TextItem {
  TextItem({
    required this.text,
    required this.fontSizePt,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.vertical,
    required this.block,
    this.angle = 0,
    this.settings,
  });

  final String text;
  final int fontSizePt;

  /// Top-left corner and size of the text box, in page pixels.
  final double x;
  final double y;
  final double width;
  final double height;
  final int color;
  final bool vertical;
  final TextBlock block;

  /// Rotation in degrees (clockwise) around the box centre.
  final double angle;

  /// Font, outline and spacing of this item when its block has its own
  /// style; null = the page's render settings.
  final RenderSettings? settings;

  /// The same text moved by ([dx], [dy]).
  TextItem shifted(double dx, double dy) => TextItem(
    text: text,
    fontSizePt: fontSizePt,
    x: x + dx,
    y: y + dy,
    width: width,
    height: height,
    color: color,
    vertical: vertical,
    block: block,
    angle: angle,
    settings: settings,
  );

  Map<String, Object?> toJson() => {
        'text': text,
        'font_size_pt': fontSizePt,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'color': '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'vertical': vertical,
        if (angle != 0) 'angle': angle,
      };
}

/// `_split_at_fitting_hyphen`: the longest prefix ending at a hyphen inside
/// [word] that still fits after [line].
(String, String)? _splitAtFittingHyphen(String line, String word, double Function(String) measure, double maxSide) {
  (String, String)? best;
  for (var i = 0; i < word.length; i++) {
    if (word[i] != '-' || i <= 0 || i >= word.length - 1) continue;
    final prefix = word.substring(0, i + 1);
    final candidate = line.isEmpty ? prefix : '$line $prefix';
    if (measure(candidate) <= maxSide) best = (prefix, word.substring(i + 1));
  }
  return best;
}

/// The longest start of [word] up to one of its syllable breaks that still
/// fits after [line] with a hyphen; null when none does.
(String, String)? _splitAtFittingSyllable(String line, String word, double Function(String) measure, double maxSide) {
  for (final i in hyphenationPoints(word).reversed) {
    final prefix = '${word.substring(0, i)}-';
    final candidate = line.isEmpty ? prefix : '$line $prefix';
    if (measure(candidate) <= maxSide) return (prefix, word.substring(i));
  }
  return null;
}

final _whitespace = RegExp(r'\s+');

/// `_wrap_text_greedily`: fills lines word by word; words are split only at
/// their own hyphens; a word longer than a line gets a line of its own.
/// With [hyphenate], Russian words are also broken by syllables (see
/// `hyphenation.dart`) where a line still has room.
String wrapTextGreedily(String text, double Function(String) measure, double maxSide, {bool hyphenate = false}) =>
    _wrapWords(text, measure, (_) => maxSide, hyphenate: hyphenate).join('\n');

/// [wrapTextGreedily] with a width of its own for each line.
List<String> _wrapWords(
  String text,
  double Function(String) measure,
  double Function(int line) maxSideOf, {
  bool hyphenate = false,
}) {
  final words = text.trim().isEmpty ? <String>[] : text.trim().split(_whitespace);
  final lines = <String>[];
  while (words.isNotEmpty) {
    final maxSide = maxSideOf(lines.length);
    var line = '';
    while (words.isNotEmpty) {
      final next = words.first;
      final candidate = line.isEmpty ? next : '$line $next';
      if (measure(candidate) <= maxSide) {
        line = candidate;
        words.removeAt(0);
        continue;
      }
      final split =
          _splitAtFittingHyphen(line, next, measure, maxSide) ??
          (hyphenate ? _splitAtFittingSyllable(line, next, measure, maxSide) : null);
      if (split != null) {
        line = line.isEmpty ? split.$1 : '$line ${split.$1}';
        words[0] = split.$2;
        break;
      }
      if (line.isNotEmpty) break;
      line = words.removeAt(0);
      break;
    }
    lines.add(line);
  }
  return lines;
}

/// `_wrap_no_space_text_greedily`: character-by-character wrapping for
/// languages written without spaces.
String wrapNoSpaceTextGreedily(String text, double Function(String) measure, double maxSide) {
  final paragraphs = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final out = <String>[];
  for (final paragraph in paragraphs) {
    final chars = paragraph.runes.where((r) => r != 0x20).map(String.fromCharCode).toList();
    if (chars.isEmpty) {
      out.add('');
      continue;
    }
    final lines = <String>[];
    var line = '';
    for (final ch in chars) {
      final candidate = '$line$ch';
      if (line.isEmpty || measure(candidate) <= maxSide) {
        line = candidate;
        continue;
      }
      lines.add(line);
      line = ch;
    }
    if (line.isNotEmpty) lines.add(line);
    out.add(lines.join('\n'));
  }
  return out.join('\n');
}

/// Result of [fitText].
class FittedText {
  FittedText(this.text, this.fontSizePt, this.width, this.height, {this.fits = true});

  final String text;
  final int fontSizePt;

  /// Size of the text without the outline (`return_metrics`).
  final double width;
  final double height;

  /// False: the text does not fit even at the smallest size.
  final bool fits;
}

/// How much larger hyphenated text must get to be chosen over unbroken
/// words.
const _hyphenGain = 1.12;

/// Share of the largest size from which text is large enough without
/// hyphenation.
const _largeEnough = 0.8;

/// `pyside_word_wrap`: the largest font size (binary search between the
/// limits) at which the greedily wrapped text fits the box, outline
/// included; the minimum size when nothing fits.
///
/// With [RenderSettings.hyphenate], Russian words may be broken by syllables
/// when that makes the text clearly larger (or lets it fit at all). With
/// [ellipse] (semi-axes, in pixels) the lines follow that oval instead of
/// the box.
FittedText fitText(
  String text,
  TextMeasurer measurer,
  double roiWidth,
  double roiHeight, {
  required RenderSettings settings,
  bool vertical = false,
  bool noSpaceLanguage = false,
  ({double a, double b})? ellipse,
}) {
  FittedText fit(bool hyphenate) {
    if (ellipse != null && !vertical && !noSpaceLanguage && !text.contains('\n')) {
      final oval = _fitInEllipse(text, measurer, ellipse.a, ellipse.b, settings, hyphenate: hyphenate);
      if (oval != null) return oval;
    }
    return _fitInBox(
      text,
      measurer,
      roiWidth,
      roiHeight,
      settings: settings,
      vertical: vertical,
      noSpaceLanguage: noSpaceLanguage,
      hyphenate: hyphenate,
    );
  }

  final plain = fit(false);
  if (!settings.hyphenate || vertical || noSpaceLanguage || !text.split(_whitespace).any(_breakable)) return plain;
  // Large enough already: words stay whole.
  if (plain.fits && plain.fontSizePt >= settings.maxFontSize * _largeEnough) return plain;
  final broken = fit(true);
  if (broken.fits && !plain.fits) return broken;
  return broken.fits && broken.fontSizePt > plain.fontSizePt && broken.fontSizePt >= plain.fontSizePt * _hyphenGain
      ? broken
      : plain;
}

bool _breakable(String word) => hyphenationPoints(word).isNotEmpty;

/// Width and height of [t] at [size] with the outline around it (or
/// without).
({double width, double height}) _metrics(
  TextMeasurer measurer,
  RenderSettings settings,
  String t,
  int size, {
  bool vertical = false,
  bool withOutline = true,
}) {
  final outline = settings.outline ? settings.outlineWidth : 0.0;
  final m = measurer.measure(t, size, vertical: vertical);
  final pad = withOutline && outline > 0 ? 2 * outline : 0.0;
  return (width: m.width + pad, height: m.height + pad);
}

FittedText _fitInBox(
  String text,
  TextMeasurer measurer,
  double roiWidth,
  double roiHeight, {
  required RenderSettings settings,
  required bool vertical,
  required bool noSpaceLanguage,
  required bool hyphenate,
}) {
  ({double width, double height}) metrics(String t, int size, {bool withOutline = true}) =>
      _metrics(measurer, settings, t, size, vertical: vertical, withOutline: withOutline);

  (String, double, double) wrapAndSize(int size) {
    double side(String candidate) {
      final m = metrics(candidate, size);
      return vertical ? m.height : m.width;
    }

    final maxSide = vertical ? roiHeight : roiWidth;
    String wrap(String t) => noSpaceLanguage
        ? wrapNoSpaceTextGreedily(t, side, maxSide)
        : wrapTextGreedily(t, side, maxSide, hyphenate: hyphenate);
    // Line breaks typed by the user are kept (the original wraps them away).
    final wrapped = !noSpaceLanguage && text.contains('\n')
        ? text.replaceAll('\r\n', '\n').split('\n').map(wrap).join('\n')
        : wrap(text);
    final m = metrics(wrapped, size);
    return (wrapped, m.width, m.height);
  }

  var bestText = text;
  var bestSize = settings.maxFontSize;
  var found = false;
  var lo = settings.minFontSize, hi = settings.maxFontSize;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final (wrapped, w, h) = wrapAndSize(mid);
    if (w <= roiWidth && h <= roiHeight) {
      found = true;
      bestText = wrapped;
      bestSize = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (!found) {
    bestText = wrapAndSize(settings.minFontSize).$1;
    bestSize = settings.minFontSize;
  }
  final m = metrics(bestText, bestSize, withOutline: false);
  return FittedText(bestText, bestSize, m.width, m.height, fits: found);
}

/// The largest size at which [text] fits an oval with semi-axes [a]×[b]:
/// lines are centred on top of each other, each as wide as the oval is at
/// its height. Null when it does not fit even at the smallest size.
FittedText? _fitInEllipse(
  String text,
  TextMeasurer measurer,
  double a,
  double b,
  RenderSettings settings, {
  required bool hyphenate,
}) {
  String? wrapAt(int size) {
    final one = _metrics(measurer, settings, 'Ag', size);
    final pitch = _metrics(measurer, settings, 'Ag\nAg', size).height - one.height;
    if (one.height > 2 * b || pitch <= 0) return null;
    double side(String candidate) => _metrics(measurer, settings, candidate, size).width;
    for (var n = 1; one.height + (n - 1) * pitch <= 2 * b; n++) {
      final total = one.height + (n - 1) * pitch;
      double widthOf(int k) {
        if (k >= n) return 0;
        final top = -total / 2 + k * pitch, bottom = top + one.height;
        final y = math.max(top.abs(), bottom.abs());
        return y >= b ? 0 : 2 * a * math.sqrt(1 - (y / b) * (y / b));
      }

      final lines = _wrapWords(text, side, widthOf, hyphenate: hyphenate);
      var ok = lines.length <= n;
      for (var k = 0; ok && k < lines.length; k++) {
        ok = side(lines[k]) <= widthOf(k);
      }
      if (ok) return lines.join('\n');
    }
    return null;
  }

  String? best;
  var bestSize = 0;
  var lo = settings.minFontSize, hi = settings.maxFontSize;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final wrapped = wrapAt(mid);
    if (wrapped != null) {
      best = wrapped;
      bestSize = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (best == null) return null;
  final m = _metrics(measurer, settings, best, bestSize, withOutline: false);
  return FittedText(best, bestSize, m.width, m.height);
}

/// `get_best_render_area`: blocks shrink by 5% (except Korean and Chinese
/// sources, judged by the first block). The original's vertical-text branch
/// never runs (it compares with a value the property never returns), so it
/// is not ported.
void adjustRenderAreas(List<TextBlock> blocks, int imageWidth, int imageHeight) {
  if (blocks.isEmpty || const {'ko', 'zh'}.contains(blocks.first.sourceLang)) return;
  for (final b in blocks) {
    final x = b.xyxy;
    final dx = (x.width * -5 / 100 / 2).truncate();
    final dy = (x.height * -5 / 100 / 2).truncate();
    b.xyxy = BBox(
      math.max(x.x1 - dx, 0),
      math.max(x.y1 - dy, 0),
      math.min(x.x2 + dx, imageWidth),
      math.min(x.y2 + dy, imageHeight),
    );
  }
}

/// Where the translation of `blocks[index]` goes: the text box chosen by
/// hand, else the block's box as [adjustRenderAreas] shrinks it for the page.
BBox textAreaOf(List<TextBlock> blocks, int index, int imageWidth, int imageHeight) {
  final b = blocks[index];
  if (b.style?.textBox case final box?) return box;
  final one = [b.copy()..sourceLang = blocks.first.sourceLang];
  adjustRenderAreas(one, imageWidth, imageHeight);
  return one.single.xyxy;
}

/// `is_vertical_block`: vertical source text rendered vertically when the
/// target language is written vertically.
bool isVerticalBlock(TextBlock block, String targetLanguageCode) =>
    block.direction == TextDirection.vertical && isVerticalLanguageCode(targetLanguageCode);

/// `is_vertical_language_code`.
bool isVerticalLanguageCode(String code) {
  final c = code.toLowerCase();
  if (const {'zh-cn', 'zh-tw', 'ja'}.contains(c)) return true;
  return Languages.all.any((l) => l.vertical && l.code.toLowerCase() == c);
}

/// `get_smart_text_color`: the colour detected in the block, else the
/// setting.
int smartTextColor(List<int>? detected, int settingColor) {
  if (detected == null || detected.length < 3) return settingColor;
  final a = detected.length >= 4 ? detected[3] : 255;
  return (a & 0xFF) << 24 | (detected[0] & 0xFF) << 16 | (detected[1] & 0xFF) << 8 | (detected[2] & 0xFF);
}

/// The text-rendering step of the original batch run: upper case, render
/// areas, fitting and colours. [blocks] are modified (translation case,
/// render area); returns what to draw.
///
/// Blocks with a [BlockStyle] get their own font, size, colours and text
/// box; [measurerFor] measures text in such a block's settings (default:
/// [measurer]).
///
/// [areaHeight] (default: [imageHeight]) is how far down text areas may go:
/// on webtoon pages, blocks reach into the page below.
///
/// Not in the original: the letter case follows [RenderSettings.textCase]
/// and each block's own choice; with [RenderSettings.matchSource] a block
/// takes the outline, bold and italic of its source lettering ([lettering]
/// tells the page's usual weight; default: from [blocks]); a block style's
/// [BlockStyle.sourceSizePx] gives the size of the source letters; with
/// [RenderSettings.shapeFit] the lines follow the oval of the speech bubble.
List<TextItem> layoutPage(
  List<TextBlock> blocks,
  int imageWidth,
  int imageHeight,
  TextMeasurer measurer, {
  required RenderSettings settings,
  required String targetLanguage,
  TextMeasurer Function(RenderSettings settings)? measurerFor,
  int? areaHeight,
  PageLettering? lettering,
}) {
  final code = Languages.byName(targetLanguage)?.code ?? '';
  final page = lettering ?? PageLettering.of(blocks);
  for (final b in blocks) {
    b.translation = casedTranslation(b, settings.textCase, upperCase: b.style?.upperCase);
  }
  final chosen = [for (final b in blocks) b.style?.textBox];
  adjustRenderAreas(blocks, imageWidth, areaHeight ?? imageHeight);
  final noSpace = _isNoSpace(code);
  final items = <TextItem>[];
  for (final (i, b) in blocks.indexed) {
    if (!hasTranslatableContent(b.translation)) continue;
    final style = b.style;
    var s = blockRenderSettings(b, settings, page);
    final m = identical(s, settings) || measurerFor == null ? measurer : measurerFor(s);
    if (style?.sourceSizePx case final px?) {
      final pt = sourceSizePt(px, b, m);
      s = s.copyWith(minFontSize: math.min(s.minFontSize, pt), maxFontSize: pt);
    }
    final area = chosen[i] ?? b.xyxy;
    final vertical = style?.vertical ?? isVerticalBlock(b, code);
    final oval = s.shapeFit && chosen[i] == null && !vertical ? _bubbleOval(b, area) : null;
    final fit = fitText(
      b.translation,
      m,
      area.width.toDouble(),
      area.height.toDouble(),
      settings: s,
      vertical: vertical,
      noSpaceLanguage: noSpace,
      ellipse: oval == null ? null : (a: oval.a, b: oval.b),
    );
    var x = area.x1.toDouble(), y = area.y1.toDouble();
    if (oval != null && fit.fits) {
      x = oval.cx - fit.width / 2;
      y = oval.cy - fit.height / 2;
    } else if (s.placeInBlock) {
      final spareW = math.max(0.0, area.width - fit.width);
      final spareH = math.max(0.0, area.height - fit.height);
      x += switch (s.alignment) {
        TextAlignment.left => 0.0,
        TextAlignment.center => spareW / 2,
        TextAlignment.right => spareW,
      };
      y += spareH / 2;
    }
    items.add(TextItem(
      text: fit.text,
      fontSizePt: fit.fontSizePt,
      x: x,
      y: y,
      width: fit.width,
      height: fit.height,
      color: style?.color ?? smartTextColor(b.fontColor, settings.color),
      vertical: vertical,
      block: b,
      angle: style?.angle ?? b.angle,
      settings: identical(s, settings) ? null : s,
    ));
  }
  return items;
}

/// [settings] for drawing [block]: with [RenderSettings.matchSource], the
/// outline, bold and italic of its source lettering ([page] tells which
/// blocks are bold), then its own style.
RenderSettings blockRenderSettings(TextBlock block, RenderSettings settings, PageLettering page) {
  var s = settings;
  final source = block.sourceStyle;
  if (settings.matchSource && source != null) {
    if (page.isBold(source) && !s.bold) s = s.copyWith(bold: true);
    if (source.italic && !s.italic) s = s.copyWith(italic: true);
    if (source.hasOutline) {
      s = s.copyWith(
        outline: true,
        outlineColor: 0xFF000000 | source.outlineColor!,
        outlineWidth: source.outlinePx.clamp(1.0, 8.0),
      );
    }
  }
  return block.style?.applyTo(s) ?? s;
}

/// The font size in points at which [measurer]'s letters are [px] high
/// (cap height for source text in capitals, else x-height, as
/// [SourceStyle.letterPx] measures them).
int sourceSizePt(double px, TextBlock block, TextMeasurer measurer) {
  final metrics = measurer is LetterMetrics ? measurer as LetterMetrics : null;
  final ratio = isMostlyUpperCase(block.text)
      ? metrics?.capHeight ?? _defaultCapHeight
      : metrics?.xHeight ?? _defaultXHeight;
  final fontPx = px / (ratio > 0.1 ? ratio : _defaultCapHeight);
  return (fontPx * 72 / 96).round().clamp(4, 200);
}

/// Share of the speech bubble's half-sizes that the lines may use.
const _ovalShare = 0.86;

/// The oval of [block]'s speech bubble (centre and semi-axes) when the
/// bubble is around [area]'s centre: a bubble holding several blocks is
/// left to their boxes.
({double cx, double cy, double a, double b})? _bubbleOval(TextBlock block, BBox area) {
  final bubble = block.bubbleXyxy;
  if (bubble == null || bubble.width < 8 || bubble.height < 8) return null;
  final c = bubble.center, t = area.center;
  if ((c.x - t.x).abs() > bubble.width * 0.15 || (c.y - t.y).abs() > bubble.height * 0.15) return null;
  return (cx: c.x, cy: c.y, a: bubble.width / 2 * _ovalShare, b: bubble.height / 2 * _ovalShare);
}

bool _isNoSpace(String code) {
  if (code.isEmpty) return false;
  final c = code.toLowerCase();
  if (c.contains('zh') || c.contains('ja') || c.contains('th')) return true;
  return Languages.all.any((l) => l.noSpace && l.code.toLowerCase() == c);
}
