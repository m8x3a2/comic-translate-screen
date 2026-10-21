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

enum TextAlignment { left, center, right }

/// Text rendering settings (`TextRenderingSettings`); defaults are the
/// original's.
class RenderSettings {
  const RenderSettings({
    this.fontFamily = '',
    this.minFontSize = 9,
    this.maxFontSize = 40,
    this.color = 0xFF000000,
    this.upperCase = false,
    this.outline = true,
    this.outlineColor = 0xFFFFFFFF,
    this.outlineWidth = 1.0,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.lineSpacing = 1.0,
    this.alignment = TextAlignment.center,
    this.placeInBlock = true,
  });

  /// Font family or font file; empty = the app's default font.
  final String fontFamily;

  /// Font sizes in points (1 pt = 4/3 px at the 96 dpi used for pages).
  final int minFontSize;
  final int maxFontSize;

  /// ARGB colours.
  final int color;
  final bool upperCase;
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

  RenderSettings copyWith({
    String? fontFamily,
    int? minFontSize,
    int? maxFontSize,
    int? color,
    bool? upperCase,
    bool? outline,
    int? outlineColor,
    double? outlineWidth,
    bool? bold,
    bool? italic,
    bool? underline,
    double? lineSpacing,
    TextAlignment? alignment,
    bool? placeInBlock,
  }) =>
      RenderSettings(
        fontFamily: fontFamily ?? this.fontFamily,
        minFontSize: minFontSize ?? this.minFontSize,
        maxFontSize: maxFontSize ?? this.maxFontSize,
        color: color ?? this.color,
        upperCase: upperCase ?? this.upperCase,
        outline: outline ?? this.outline,
        outlineColor: outlineColor ?? this.outlineColor,
        outlineWidth: outlineWidth ?? this.outlineWidth,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        alignment: alignment ?? this.alignment,
        placeInBlock: placeInBlock ?? this.placeInBlock,
      );

  Map<String, Object?> toJson() => {
        'font_family': fontFamily,
        'min_font_size': minFontSize,
        'max_font_size': maxFontSize,
        'color': _hex(color),
        'upper_case': upperCase,
        'outline': outline,
        'outline_color': _hex(outlineColor),
        'outline_width': outlineWidth,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'line_spacing': lineSpacing,
        'alignment': alignment.name,
        'place_in_block': placeInBlock,
      };

  factory RenderSettings.fromJson(Map<String, Object?> j) {
    const d = RenderSettings();
    T pick<T>(String key, T fallback) => j[key] is T ? j[key] as T : fallback;
    return RenderSettings(
      fontFamily: pick('font_family', d.fontFamily),
      minFontSize: pick<num>('min_font_size', d.minFontSize).toInt(),
      maxFontSize: pick<num>('max_font_size', d.maxFontSize).toInt(),
      color: parseColor(pick('color', '')) ?? d.color,
      upperCase: pick('upper_case', d.upperCase),
      outline: pick('outline', d.outline),
      outlineColor: parseColor(pick('outline_color', '')) ?? d.outlineColor,
      outlineWidth: pick<num>('outline_width', d.outlineWidth).toDouble(),
      bold: pick('bold', d.bold),
      italic: pick('italic', d.italic),
      underline: pick('underline', d.underline),
      lineSpacing: pick<num>('line_spacing', d.lineSpacing).toDouble(),
      alignment: TextAlignment.values.firstWhere((a) => a.name == j['alignment'], orElse: () => d.alignment),
      placeInBlock: pick('place_in_block', d.placeInBlock),
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

final _whitespace = RegExp(r'\s+');

/// `_wrap_text_greedily`: fills lines word by word; words are split only at
/// their own hyphens; a word longer than a line gets a line of its own.
String wrapTextGreedily(String text, double Function(String) measure, double maxSide) {
  final words = text.trim().isEmpty ? <String>[] : text.trim().split(_whitespace);
  final lines = <String>[];
  while (words.isNotEmpty) {
    var line = '';
    while (words.isNotEmpty) {
      final next = words.first;
      final candidate = line.isEmpty ? next : '$line $next';
      if (measure(candidate) <= maxSide) {
        line = candidate;
        words.removeAt(0);
        continue;
      }
      final split = _splitAtFittingHyphen(line, next, measure, maxSide);
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
  return lines.join('\n');
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
  FittedText(this.text, this.fontSizePt, this.width, this.height);

  final String text;
  final int fontSizePt;

  /// Size of the text without the outline (`return_metrics`).
  final double width;
  final double height;
}

/// `pyside_word_wrap`: the largest font size (binary search between the
/// limits) at which the greedily wrapped text fits the box, outline
/// included; the minimum size when nothing fits.
FittedText fitText(
  String text,
  TextMeasurer measurer,
  double roiWidth,
  double roiHeight, {
  required RenderSettings settings,
  bool vertical = false,
  bool noSpaceLanguage = false,
}) {
  final outline = settings.outline ? settings.outlineWidth : 0.0;
  ({double width, double height}) metrics(String t, int size, {bool withOutline = true}) {
    final m = measurer.measure(t, size, vertical: vertical);
    final pad = withOutline && outline > 0 ? 2 * outline : 0.0;
    return (width: m.width + pad, height: m.height + pad);
  }

  (String, double, double) wrapAndSize(int size) {
    double side(String candidate) {
      final m = metrics(candidate, size);
      return vertical ? m.height : m.width;
    }

    final maxSide = vertical ? roiHeight : roiWidth;
    String wrap(String t) =>
        noSpaceLanguage ? wrapNoSpaceTextGreedily(t, side, maxSide) : wrapTextGreedily(t, side, maxSide);
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
  return FittedText(bestText, bestSize, m.width, m.height);
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
List<TextItem> layoutPage(
  List<TextBlock> blocks,
  int imageWidth,
  int imageHeight,
  TextMeasurer measurer, {
  required RenderSettings settings,
  required String targetLanguage,
  TextMeasurer Function(RenderSettings settings)? measurerFor,
  int? areaHeight,
}) {
  final code = Languages.byName(targetLanguage)?.code ?? '';
  setUpperCase(blocks, settings.upperCase);
  final chosen = [for (final b in blocks) b.style?.textBox];
  adjustRenderAreas(blocks, imageWidth, areaHeight ?? imageHeight);
  final noSpace = _isNoSpace(code);
  final items = <TextItem>[];
  for (final (i, b) in blocks.indexed) {
    if (!hasTranslatableContent(b.translation)) continue;
    final style = b.style;
    final s = style == null ? settings : style.applyTo(settings);
    final area = chosen[i] ?? b.xyxy;
    final vertical = style?.vertical ?? isVerticalBlock(b, code);
    final fit = fitText(
      b.translation,
      style == null || measurerFor == null ? measurer : measurerFor(s),
      area.width.toDouble(),
      area.height.toDouble(),
      settings: s,
      vertical: vertical,
      noSpaceLanguage: noSpace,
    );
    var x = area.x1.toDouble(), y = area.y1.toDouble();
    if (s.placeInBlock) {
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
      settings: style == null ? null : s,
    ));
  }
  return items;
}

bool _isNoSpace(String code) {
  if (code.isEmpty) return false;
  final c = code.toLowerCase();
  if (c.contains('zh') || c.contains('ja') || c.contains('th')) return true;
  return Languages.all.any((l) => l.noSpace && l.code.toLowerCase() == c);
}
