/// Text measurement and rasterisation with Flutter's engine (`dart:ui`), the
/// counterpart of the original's Qt text items. Used by the GUI and `cts`, so
/// both produce the same pages.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';

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
class UiTextEngine implements TextMeasurer {
  UiTextEngine(this.settings, {required this.fontFamily, this.rtl = false});

  final RenderSettings settings;
  final String fontFamily;
  final bool rtl;
  final _cache = <String, ui.Paragraph>{};
  final _naturalRatio = <int, double>{};

  ui.TextAlign get _align => switch (settings.alignment) {
        TextAlignment.left => ui.TextAlign.left,
        TextAlignment.center => ui.TextAlign.center,
        TextAlignment.right => ui.TextAlign.right,
      };

  ui.TextStyle _style(int pt, {int? color, double? lineHeight}) => ui.TextStyle(
        color: ui.Color(color ?? settings.color),
        fontFamily: fontFamily,
        fontFamilyFallback: const ['Segoe UI', 'Yu Gothic UI', 'Microsoft YaHei UI', 'Malgun Gothic', 'Noto Sans'],
        fontSize: ptToPx(pt),
        fontWeight: settings.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
        fontStyle: settings.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
        decoration: settings.underline ? ui.TextDecoration.underline : null,
        height: lineHeight,
      );

  /// Natural line height divided by the font size (Qt's 100% line height).
  double _ratio(int pt) => _naturalRatio.putIfAbsent(pt, () {
        final p = _build('Ag', pt, natural: true);
        return p.height / ptToPx(pt);
      });

  ui.Paragraph _build(String text, int pt, {int? color, bool natural = false, double width = double.infinity}) {
    final spacing = settings.lineSpacing;
    final lineHeight = natural || spacing == 1.0 ? null : _ratio(pt) * spacing;
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: _align,
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    ))
      ..pushStyle(_style(pt, color: color, lineHeight: lineHeight))
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

  /// Draws [item] (with its outline) on [canvas].
  void draw(ui.Canvas canvas, TextItem item) {
    final outline = settings.outline && settings.outlineWidth > 0;
    final w = settings.outlineWidth;
    final offsets = outline
        ? [
            for (final dx in [-w, 0.0, w])
              for (final dy in [-w, 0.0, w])
                if (dx != 0 || dy != 0) ui.Offset(dx, dy),
          ]
        : const <ui.Offset>[];
    if (item.vertical) {
      for (final o in offsets) {
        _drawVertical(canvas, item, settings.outlineColor, o);
      }
      _drawVertical(canvas, item, item.color, ui.Offset.zero);
      return;
    }
    final layoutWidth = math.max(1.0, item.width - 2 * documentMargin) + 0.5;
    final origin = ui.Offset(item.x + documentMargin, item.y + documentMargin);
    for (final o in offsets) {
      canvas.drawParagraph(_build(item.text, item.fontSizePt, color: settings.outlineColor, width: layoutWidth), origin + o);
    }
    canvas.drawParagraph(_build(item.text, item.fontSizePt, color: item.color, width: layoutWidth), origin);
  }

  /// Columns right to left, characters top to bottom.
  void _drawVertical(ui.Canvas canvas, TextItem item, int color, ui.Offset shift) {
    final pt = item.fontSizePt;
    final cell = _cell(pt), advance = _columnAdvance(pt);
    final columns = item.text.split('\n');
    final right = item.x + item.width - documentMargin;
    for (final (ci, column) in columns.indexed) {
      final cx = right - (ci + 0.5) * advance;
      var y = item.y + documentMargin;
      for (final r in column.runes) {
        final ch = String.fromCharCode(r);
        final p = _build(ch, pt, color: color, natural: true);
        final rotate = _rotateInVertical.hasMatch(ch);
        canvas.save();
        canvas.translate(cx + shift.dx, y + cell / 2 + shift.dy);
        if (rotate) canvas.rotate(math.pi / 2);
        canvas.drawParagraph(p, ui.Offset(-p.maxIntrinsicWidth / 2, -p.height / 2));
        canvas.restore();
        y += cell;
      }
    }
  }
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

/// Tallest strip drawn at once (GPU texture limits; long webtoon pages are
/// drawn in strips).
const _maxStrip = 4096;

/// Draws [items] over [page] and returns the result.
Future<RgbImage> renderTextOnPage(RgbImage page, List<TextItem> items, UiTextEngine engine) async {
  final out = Uint8List(page.data.length);
  for (var top = 0; top < page.height; top += _maxStrip) {
    final h = math.min(_maxStrip, page.height - top);
    final strip = page.crop(BBox(0, top, page.width, top + h));
    final base = await toUiImage(strip);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..drawImage(base, ui.Offset.zero, ui.Paint());
    canvas.translate(0, -top.toDouble());
    for (final item in items) {
      if (item.y > top + h + 200 || item.y + item.height < top - 200) continue;
      engine.draw(canvas, item);
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
