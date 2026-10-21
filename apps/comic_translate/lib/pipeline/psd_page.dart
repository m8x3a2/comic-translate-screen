/// A page as a layered Photoshop file: laid out and drawn as [renderPage]
/// does, with every translation as an editable text layer.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../render/text_renderer.dart';
import 'page_pipeline.dart';

/// PostScript name of the bundled lettering font.
const _defaultPostScript = 'Pangolin-Regular';

/// Whether text layers of [doc] use the bundled font.
bool usesBundledFont(PsdDocument doc) => doc.flatLayers().any((e) => e.$1.text?.font == _defaultPostScript);

/// The bundled font and its licence, to put beside PSD files that use it
/// (Photoshop needs the font installed to show the text as drawn here):
/// path in the export → file. Empty when the files are not found.
Map<String, String> bundledFontFiles() {
  final dir = p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', 'assets', 'fonts');
  final files = {
    'fonts/Pangolin-Regular.ttf': p.join(dir, 'Pangolin-Regular.ttf'),
    'fonts/Pangolin-OFL.txt': p.join(dir, 'Pangolin-OFL.txt'),
  };
  return files.values.every((f) => File(f).existsSync()) ? files : const {};
}

Future<FontCatalog>? _fonts;

/// Installed fonts, read once in the background.
Future<FontCatalog> installedFonts() => _fonts ??= Isolate.run(FontCatalog.scan);

/// The face [setting] names (see [RenderSettings.fontFamily]) and whether
/// bold or italic must be imitated because it has no such face.
(String, bool, bool) _font(RenderSettings s, FontCatalog fonts) {
  final setting = s.fontFamily.trim();
  FontFace? face;
  if (setting.isEmpty) return (_defaultPostScript, s.bold, s.italic);
  final lower = setting.toLowerCase();
  if (lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc')) {
    face = readFontFaces(setting).firstOrNull;
  } else {
    face = fonts.face(setting, bold: s.bold, italic: s.italic);
  }
  if (face == null) {
    final suffix = s.bold && s.italic ? '-BoldItalic' : (s.bold ? '-Bold' : (s.italic ? '-Italic' : ''));
    return ('${setting.replaceAll(' ', '')}$suffix', false, false);
  }
  return (face.postScript, s.bold && !face.bold, s.italic && !face.italic);
}

/// The text layer of [item]: the box without the margin the program keeps
/// around text, a little wider and taller, as Photoshop measures letters
/// slightly differently and hides what does not fit.
PsdText psdTextOf(TextItem item, TextEngines engines, FontCatalog fonts) {
  final s = item.settings ?? engines.base;
  final engine = engines.of(s);
  final (font, fauxBold, fauxItalic) = _font(s, fonts);
  final leading = engine.lineHeightPx(item.fontSizePt);
  final innerW = math.max(1.0, item.width - 2 * documentMargin);
  final innerH = math.max(1.0, item.height - 2 * documentMargin);
  final slack = math.max(4.0, innerW * 0.06);
  final shift = switch (s.alignment) {
    TextAlignment.left => 0.0,
    TextAlignment.center => slack / 2,
    TextAlignment.right => slack,
  };
  final cx = item.x + item.width / 2, cy = item.y + item.height / 2;
  final dx = item.x + documentMargin - shift - cx, dy = item.y + documentMargin - cy;
  final a = item.angle * math.pi / 180, c = math.cos(a), sn = math.sin(a);
  final color = item.color >>> 24 == 0 ? item.color | 0xFF000000 : item.color;
  return PsdText(
    text: item.text,
    font: font,
    fontSize: ptToPx(item.fontSizePt),
    transform: [c, sn, -sn, c, cx + c * dx - sn * dy, cy + sn * dx + c * dy],
    boxWidth: innerW + slack,
    boxHeight: innerH + leading * 1.5,
    color: color,
    fauxBold: fauxBold,
    fauxItalic: fauxItalic,
    underline: s.underline,
    justification: switch (s.alignment) {
      TextAlignment.left => PsdJustification.left,
      TextAlignment.center => PsdJustification.center,
      TextAlignment.right => PsdJustification.right,
    },
    leading: leading,
  );
}

/// The outline as the layer style "Stroke", outside the letters: Photoshop
/// and Krita draw it alike (the text engine's own outline is drawn over or
/// under the letters depending on the program).
PsdStroke? _stroke(RenderSettings s) =>
    s.outline && s.outlineWidth > 0 ? PsdStroke(s.outlineColor | 0xFF000000, s.outlineWidth) : null;

/// Text layers of [items] (vertical text as pixels only), named from
/// [first] on; [suffix] marks the text continued from the page above.
Future<List<PageTextLayer>> _textLayers(
  List<TextItem> items,
  TextEngines engines,
  FontCatalog fonts, {
  int first = 1,
  String suffix = '',
}) async => [
  for (final (i, item) in items.indexed)
    PageTextLayer(
      'Text ${first + i}$suffix',
      await renderItemAlone(item, engines),
      item.vertical ? null : psdTextOf(item, engines, fonts),
      stroke: item.vertical ? null : _stroke(item.settings ?? engines.base),
    ),
];

/// The page document of [original] cleaned into [clean], with [blocks]
/// translated (see [renderPage]).
Future<PsdDocument> buildPagePsd(
  RgbImage original,
  RgbImage clean,
  List<TextBlock> blocks,
  AppSettings settings, {
  required String targetLanguage,
  PageAbove? above,
}) async {
  final fonts = await installedFonts();
  final patch = above?.patch;
  final base = patch == null ? clean : applyPatch(clean, patch, above!.width);
  final engines = await loadTextEngines(settings, targetLanguage, blocks);
  final layout = layoutRender(base.width, base.height, blocks, settings, engines, targetLanguage: targetLanguage);
  final scale = layout.scale;
  RgbImage up(RgbImage i) => scale == 1.0 ? i : upscaleImage(i, scale, method: settings.upscale.method);
  final page = up(base), raw = up(original);
  var composite = await renderTextOnPage(page, layout.items, engines);
  final texts = await _textLayers(layout.items, engines, fonts);
  if (above != null) {
    final upper = await itemsFromAbove(above, base.width, settings, scale);
    if (upper != null) {
      composite = await renderTextOnPage(composite, upper.$1, upper.$2);
      texts.addAll(await _textLayers(upper.$1, upper.$2, fonts, first: texts.length + 1, suffix: psdFromAboveSuffix));
    }
  }
  return pagePsd(
    raw: raw,
    clean: page,
    composite: composite,
    texts: texts,
    meta: {
      'scale': scale,
      'width': base.width,
      'height': base.height,
      'target_language': targetLanguage,
      'blocks': [for (final b in blocks) b.toJson()],
      // Text layer → block it shows.
      'layers': {for (var i = 0; i < layout.items.length; i++) 'Text ${i + 1}': layout.blockIndex.elementAtOrNull(i)},
    },
  );
}
