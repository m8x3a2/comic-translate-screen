/// Text measurement and rasterisation with Flutter's engine (`dart:ui`), the
/// counterpart of the original's Qt text items. Used by the GUI and `cts`, so
/// both produce the same pages.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';

import 'bundled_fonts.dart';

/// Bundled default lettering font (see pubspec.yaml).
const defaultFontFamily = 'Pangolin';

/// Qt's default QTextDocument margin, included in measured sizes.
const documentMargin = 4.0;

/// Points to page pixels (96 dpi, as Qt lays out text on screen).
double ptToPx(int pt) => pt * 96 / 72;

final _loadedFontFiles = <String, String>{};

/// Resolves the font setting to a family: empty → the bundled font; a
/// `.ttf`/`.otf` path → that file, loaded once; anything else is used as an
/// installed font family.
Future<String> resolveFontFamily(String setting) async {
  final s = setting.trim();
  if (s.isEmpty) return defaultFontFamily;
  final lower = s.toLowerCase();
  if (lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc')) {
    final cached = _loadedFontFiles[s];
    if (cached != null) return cached;
    final bytes = await File(s).readAsBytes();
    final family = 'cts_${sha1.convert(bytes).toString().substring(0, 12)}';
    await ui.loadFontFromList(bytes, fontFamily: family);
    return _loadedFontFiles[s] = family;
  }
  return s;
}

/// Characters drawn rotated in vertical text (dashes, ellipses, brackets).
final _rotateInVertical = RegExp('[ー―—–~〜～…‥()（）［］\\[\\]「」『』【】〈〉《》<>-]');

/// Measures and draws text with one set of render settings.
class UiTextEngine implements TextMeasurer, LetterMetrics {
  UiTextEngine(this.settings, {required this.fontFamily, this.rtl = false, this.capHeight = 0.7, this.xHeight = 0.5})
    : _variable = bundledFont(fontFamily)?.variable ?? false;

  final RenderSettings settings;
  final String fontFamily;
  final bool rtl;

  @override
  final double capHeight;

  @override
  final double xHeight;

  /// The font's weight is an axis: bold sets it instead of thickening the
  /// letters.
  final bool _variable;
  final _cache = <String, ui.Paragraph>{};
  final _naturalRatio = <int, double>{};

  ui.TextAlign get _align => switch (settings.alignment) {
    TextAlignment.left => ui.TextAlign.left,
    TextAlignment.center => ui.TextAlign.center,
    TextAlignment.right => ui.TextAlign.right,
  };

  /// [outline] > 0: the glyph contours stroked that wide on each side, in
  /// [color], instead of filled.
  ui.TextStyle _style(int pt, {int? color, double? lineHeight, double outline = 0}) => ui.TextStyle(
    color: outline > 0 ? null : ui.Color(color ?? settings.color),
    foreground: outline > 0
        ? (ui.Paint()
            ..color = ui.Color(color ?? settings.outlineColor)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2 * outline
            ..strokeJoin = ui.StrokeJoin.round
            ..strokeCap = ui.StrokeCap.round)
        : null,
    fontFamily: fontFamily,
    fontFamilyFallback: const ['Segoe UI', 'Yu Gothic UI', 'Microsoft YaHei UI', 'Malgun Gothic', 'Noto Sans'],
    fontSize: ptToPx(pt),
    fontWeight: settings.bold && !_variable ? ui.FontWeight.bold : ui.FontWeight.normal,
    fontVariations: _variable ? [ui.FontVariation('wght', settings.bold ? 700 : 400)] : null,
    fontStyle: settings.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
    decoration: settings.underline ? ui.TextDecoration.underline : null,
    height: lineHeight,
  );

  /// Natural line height divided by the font size (Qt's 100% line height).
  double _ratio(int pt) => _naturalRatio.putIfAbsent(pt, () {
    final p = _build('Ag', pt, natural: true);
    return p.height / ptToPx(pt);
  });

  ui.Paragraph _build(
    String text,
    int pt, {
    int? color,
    bool natural = false,
    double width = double.infinity,
    double outline = 0,
  }) {
    final spacing = settings.lineSpacing;
    final lineHeight = natural || spacing == 1.0 ? null : _ratio(pt) * spacing;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: _align, textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr),
          )
          ..pushStyle(_style(pt, color: color, lineHeight: lineHeight, outline: outline))
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }

  ui.Paragraph _measured(String text, int pt) {
    final key = '$pt\u0000$text';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final p = _build(text, pt);
    _cache[key] = p;
    if (_cache.length > 2000) _cache.remove(_cache.keys.first);
    return p;
  }

  /// Distance between lines, in pixels.
  double lineHeightPx(int pt) => ptToPx(pt) * _ratio(pt) * settings.lineSpacing;

  double _cell(int pt) => ptToPx(pt);
  double _columnAdvance(int pt) => ptToPx(pt) * _ratio(pt) * settings.lineSpacing;

  @override
  ({double width, double height}) measure(String text, int fontSizePt, {required bool vertical}) {
    if (vertical) {
      final columns = text.split('\n');
      final longest = columns.map((c) => c.runes.length).fold(0, math.max);
      return (
        width: columns.length * _columnAdvance(fontSizePt) + 2 * documentMargin,
        height: longest * _cell(fontSizePt) + 2 * documentMargin,
      );
    }
    final p = _measured(text, fontSizePt);
    return (width: p.longestLine + 2 * documentMargin, height: p.height + 2 * documentMargin);
  }

  /// Draws [item] (with its outline) on [canvas], rotated by its angle
  /// around the box centre.
  void draw(ui.Canvas canvas, TextItem item) {
    if (item.angle == 0) return _draw(canvas, item);
    final c = ui.Offset(item.x + item.width / 2, item.y + item.height / 2);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(item.angle * math.pi / 180)
      ..translate(-c.dx, -c.dy);
    _draw(canvas, item);
    canvas.restore();
  }

  /// The outline is the glyph contours stroked under the text. (The original
  /// draws the text eight more times, shifted by the width: at wide outlines
  /// the copies show as smeared letters.)
  void _draw(ui.Canvas canvas, TextItem item) {
    final w = settings.outline ? settings.outlineWidth : 0.0;
    if (item.vertical) {
      if (w > 0) _drawVertical(canvas, item, settings.outlineColor, outline: w);
      _drawVertical(canvas, item, item.color);
      return;
    }
    final layoutWidth = math.max(1.0, item.width - 2 * documentMargin) + 0.5;
    final origin = ui.Offset(item.x + documentMargin, item.y + documentMargin);
    if (w > 0) {
      canvas.drawParagraph(
        _build(item.text, item.fontSizePt, color: settings.outlineColor, width: layoutWidth, outline: w),
        origin,
      );
    }
    canvas.drawParagraph(_build(item.text, item.fontSizePt, color: item.color, width: layoutWidth), origin);
  }

  /// Columns right to left, characters top to bottom.
  void _drawVertical(ui.Canvas canvas, TextItem item, int color, {double outline = 0}) {
    final pt = item.fontSizePt;
    final cell = _cell(pt), advance = _columnAdvance(pt);
    final columns = item.text.split('\n');
    final right = item.x + item.width - documentMargin;
    for (final (ci, column) in columns.indexed) {
      final cx = right - (ci + 0.5) * advance;
      var y = item.y + documentMargin;
      for (final r in column.runes) {
        final ch = String.fromCharCode(r);
        final p = _build(ch, pt, color: color, natural: true, outline: outline);
        final rotate = _rotateInVertical.hasMatch(ch);
        canvas.save();
        canvas.translate(cx, y + cell / 2);
        if (rotate) canvas.rotate(math.pi / 2);
        canvas.drawParagraph(p, ui.Offset(-p.maxIntrinsicWidth / 2, -p.height / 2));
        canvas.restore();
        y += cell;
      }
    }
  }
}

/// Text engines of one page: the render settings and every block style's
/// variant of them. Fonts are loaded by [TextEngines.load].
class TextEngines {
  TextEngines._(this.base, this.rtl, this._families, this._letters);

  final RenderSettings base;
  final bool rtl;

  /// Font setting → family.
  final Map<String, String> _families;

  /// Family → ink heights of its capitals and small letters.
  final Map<String, (double, double)> _letters;
  final _engines = <String, UiTextEngine>{};

  /// Loads the fonts of [base] and of the styles of [blocks]. A font file
  /// that cannot be read falls back to the bundled font.
  static Future<TextEngines> load(
    RenderSettings base, {
    bool rtl = false,
    Iterable<TextBlock> blocks = const [],
  }) async {
    final families = <String, String>{};
    for (final setting in {base.fontFamily, for (final b in blocks) ?b.style?.fontFamily}) {
      try {
        families[setting] = await resolveFontFamily(setting);
      } on FileSystemException {
        families[setting] = defaultFontFamily;
      }
    }
    final letters = {for (final family in families.values.toSet()) family: await _letterHeights(family)};
    return TextEngines._(base, rtl, families, letters);
  }

  /// Whether the fonts of [blocks] are loaded.
  bool covers(Iterable<TextBlock> blocks) => blocks.every((b) => _families.containsKey(b.style?.fontFamily ?? ''));

  UiTextEngine get main => of(base);

  UiTextEngine of(RenderSettings s) => _engines.putIfAbsent(jsonEncode(s.toJson()), () {
    final family = _families[s.fontFamily] ?? defaultFontFamily;
    final letters = _letters[family];
    return UiTextEngine(s, fontFamily: family, rtl: rtl, capHeight: letters?.$1 ?? 0.7, xHeight: letters?.$2 ?? 0.5);
  });

  /// Draws [item] with its own settings.
  void draw(ui.Canvas canvas, TextItem item) => of(item.settings ?? base).draw(canvas, item);
}

final _letterCache = <String, (double, double)>{};

/// Ink heights of "H" and "x" in [family] per pixel of font size, drawn at
/// 100 px (once per family).
Future<(double, double)> _letterHeights(String family) async {
  if (_letterCache[family] case final known?) return known;
  const size = 100.0;
  Future<double> ink(String letter) async {
    final paragraph =
        (ui.ParagraphBuilder(ui.ParagraphStyle())
              ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000), fontFamily: family, fontSize: size))
              ..addText(letter))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 1000));
    final w = paragraph.maxIntrinsicWidth.ceil() + 8, h = paragraph.height.ceil() + 8;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawParagraph(paragraph, const ui.Offset(4, 4));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    picture.dispose();
    var first = -1, last = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (data.getUint8((y * w + x) * 4 + 3) >= 128) {
          if (first < 0) first = y;
          last = y;
          break;
        }
      }
    }
    return first < 0 ? 0 : (last - first + 1) / size;
  }

  final cap = await ink('H'), x = await ink('x');
  return _letterCache[family] = (cap > 0.2 ? cap : 0.7, x > 0.2 ? x : 0.5);
}

/// [text] in black on white in [family], one line at [size] pixels (to
/// measure how the font's letters look); null when nothing shows.
Future<RgbImage?> renderSample(String text, String family, {double size = 64}) async {
  final paragraph =
      (ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000), fontFamily: family, fontSize: size))
            ..addText(text))
          .build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
  final pad = (size / 4).ceil();
  final w = paragraph.maxIntrinsicWidth.ceil() + 2 * pad, h = paragraph.height.ceil() + 2 * pad;
  if (w <= 2 * pad || w > 16384) return null;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
    ..drawParagraph(paragraph, ui.Offset(pad.toDouble(), pad.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  final rgb = Uint8List(w * h * 3);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgb[i] = data.getUint8(j);
    rgb[i + 1] = data.getUint8(j + 1);
    rgb[i + 2] = data.getUint8(j + 2);
  }
  return RgbImage(w, h, rgb);
}

/// Converts an [RgbImage] to a `dart:ui` image.
Future<ui.Image> toUiImage(RgbImage image) {
  final rgba = Uint8List(image.width * image.height * 4);
  for (var i = 0, j = 0; i < image.data.length; i += 3, j += 4) {
    rgba[j] = image.data[i];
    rgba[j + 1] = image.data[i + 1];
    rgba[j + 2] = image.data[i + 2];
    rgba[j + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, image.width, image.height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// [item] drawn alone on a transparent background, as the pixels of a PSD
/// text layer (null when nothing shows).
Future<PsdPixels?> renderItemAlone(TextItem item, TextEngines engines) async {
  final s = item.settings ?? engines.base;
  final pad = (s.outline ? s.outlineWidth : 0) + ptToPx(item.fontSizePt) + 4;
  final half = item.angle == 0
      ? (item.width / 2, item.height / 2)
      : (
          (item.width * math.cos(item.angle * math.pi / 180)).abs() / 2 +
              (item.height * math.sin(item.angle * math.pi / 180)).abs() / 2,
          (item.width * math.sin(item.angle * math.pi / 180)).abs() / 2 +
              (item.height * math.cos(item.angle * math.pi / 180)).abs() / 2,
        );
  final cx = item.x + item.width / 2, cy = item.y + item.height / 2;
  final left = (cx - half.$1 - pad).floor(), top = (cy - half.$2 - pad).floor();
  final w = (cx + half.$1 + pad).ceil() - left, h = (cy + half.$2 + pad).ceil() - top;
  if (w <= 0 || h <= 0 || w > 16384 || h > 16384) return null;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..translate(-left.toDouble(), -top.toDouble());
  engines.draw(canvas, item);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  image.dispose();
  picture.dispose();
  return PsdPixels(
    left,
    top,
    w,
    h,
    Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)),
  ).trimmed();
}

/// Tallest strip drawn at once (GPU texture limits; long webtoon pages are
/// drawn in strips).
const _maxStrip = 4096;

/// Draws [items] over [page] and returns the result.
Future<RgbImage> renderTextOnPage(RgbImage page, List<TextItem> items, TextEngines engines) async {
  final out = Uint8List(page.data.length);
  for (var top = 0; top < page.height; top += _maxStrip) {
    final h = math.min(_maxStrip, page.height - top);
    final strip = page.crop(BBox(0, top, page.width, top + h));
    final base = await toUiImage(strip);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..drawImage(base, ui.Offset.zero, ui.Paint());
    canvas.translate(0, -top.toDouble());
    for (final item in items) {
      // A rotated box reaches at most half its diagonal from the centre.
      final reach = item.angle == 0
          ? item.height / 2
          : math.sqrt(item.width * item.width + item.height * item.height) / 2;
      final cy = item.y + item.height / 2;
      if (cy - reach > top + h + 200 || cy + reach < top - 200) continue;
      engines.draw(canvas, item);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(page.width, h);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    picture.dispose();
    base.dispose();
    final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
    final o = top * page.width * 3;
    for (var i = 0, j = 0; j < bytes.length; i += 3, j += 4) {
      out[o + i] = bytes[j];
      out[o + i + 1] = bytes[j + 1];
      out[o + i + 2] = bytes[j + 2];
    }
  }
  return RgbImage(page.width, page.height, out);
}
