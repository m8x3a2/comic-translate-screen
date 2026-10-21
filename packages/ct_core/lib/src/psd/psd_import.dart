/// Opening a PSD file as a page: the picture, the cleaned picture and the
/// text layers as translated blocks (original `psd_importer.py`).
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../image/cv_bridge.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import '../render/block_style.dart';
import '../render/font_files.dart';
import '../render/layout.dart';
import '../render/upscale.dart';
import 'page_psd.dart';
import 'psd_document.dart';
import 'psd_reader.dart';

const psdExtensions = {'.psd', '.psb'};

bool isPsdPath(String path) => psdExtensions.contains(p.extension(path).toLowerCase());

/// Name ending of text layers that continue the text of the page above
/// (webtoons); they belong to that page.
const psdFromAboveSuffix = ' (page above)';

/// The margin kept around text inside its box (Qt's document margin).
const _margin = 4.0;

/// What to tell about an opened PSD.
sealed class PsdNotice {
  const PsdNotice();
}

/// Not laid out by this program or the original one.
class PsdForeign extends PsdNotice {
  const PsdForeign();
}

/// Photoshop features that are not carried over.
class PsdUnsupported extends PsdNotice {
  const PsdUnsupported(this.features);

  final List<String> features;
}

class PsdPage {
  const PsdPage({required this.image, required this.blocks, this.clean, this.notices = const []});

  final String image;
  final String? clean;
  final List<TextBlock> blocks;
  final List<PsdNotice> notices;
}

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A block showing [t] as it is: its box, text and look; [stroke] is the
/// layer's outline style (else the text engine's outline, if any).
TextBlock blockOfText(PsdText t, {FontCatalog? fonts, PsdStroke? stroke, String targetLanguage = ''}) {
  final m = t.transform;
  final angle = math.atan2(m[1], m[0]) * 180 / math.pi;
  final ox = m[4], oy = m[5];
  // Centre of the (rotated) box.
  final cx = ox + m[0] * t.boxWidth / 2 + m[2] * t.boxHeight / 2;
  final cy = oy + m[1] * t.boxWidth / 2 + m[3] * t.boxHeight / 2;
  final hw = t.boxWidth / 2 + _margin, hh = t.boxHeight / 2 + _margin;
  final box = BBox((cx - hw).round(), (cy - hh).round(), (cx + hw).round(), (cy + hh).round());
  // Axis-aligned bounds of the rotated box: where the text is on the page.
  final a = angle * math.pi / 180;
  final ex = (hw * math.cos(a)).abs() + (hh * math.sin(a)).abs();
  final ey = (hw * math.sin(a)).abs() + (hh * math.cos(a)).abs();
  final face = fonts?.byPostScript(t.font);
  return TextBlock(
    xyxy: BBox((cx - ex).round(), (cy - ey).round(), (cx + ex).round(), (cy + ey).round()),
    translation: _flat(t.text),
    targetLang: targetLanguage,
    style: BlockStyle(
      fontFamily: face?.family,
      fontSizePt: math.max(1, (t.fontSize * 72 / 96).round()),
      color: t.color,
      // The engine's outline is centred on the letters' edges.
      outline: stroke != null || t.strokeColor != null,
      outlineColor: stroke?.color ?? t.strokeColor,
      outlineWidth: stroke?.size ?? (t.strokeColor == null ? null : t.strokeWidth / 2),
      bold: t.fauxBold || (face?.bold ?? false),
      italic: t.fauxItalic || (face?.italic ?? false),
      underline: t.underline,
      alignment: switch (t.justification) {
        PsdJustification.left => TextAlignment.left,
        PsdJustification.center => TextAlignment.center,
        PsdJustification.right => TextAlignment.right,
      },
      vertical: t.vertical ? true : null,
      angle: angle.abs() < 0.01 ? null : angle,
      textBox: box,
    ),
  );
}

/// The blocks of [c]: this program's own blocks when the file keeps them
/// (with the translations changed in Photoshop taken over, and new text
/// layers added), else one block per text layer.
List<TextBlock> psdBlocks(PsdPageContent c, int width, int height, {FontCatalog? fonts}) {
  final meta = c.meta;
  final own = <TextBlock>[];
  final mapped = <String, int>{};
  if (meta != null && meta['blocks'] is List) {
    try {
      final blocks = [for (final b in meta['blocks'] as List) TextBlock.fromJson((b as Map).cast())];
      final w = (meta['width'] as num?)?.toInt() ?? width, h = (meta['height'] as num?)?.toInt() ?? height;
      own.addAll(w == width && h == height ? blocks : scaleBlocks(blocks, w, h, width, height));
      if (meta['layers'] case final Map layers) {
        for (final MapEntry(:key, :value) in layers.entries) {
          if (value is int && value >= 0 && value < own.length) mapped['$key'] = value;
        }
      }
    } on Object {
      own.clear();
      mapped.clear();
    }
  }
  final out = [...own];
  for (final (name, t, stroke) in c.texts) {
    if (name.endsWith(psdFromAboveSuffix)) continue;
    final i = mapped[name];
    if (i != null) {
      if (_flat(t.text) != _flat(own[i].translation)) out[i] = own[i].copy()..translation = _flat(t.text);
    } else {
      out.add(blockOfText(t, fonts: fonts, stroke: stroke));
    }
  }
  return out;
}

/// Reads the PSD at [path] and writes its pictures into [dir].
Future<PsdPage> importPsdPage(String path, Directory dir, {FontCatalog? fonts}) async {
  final doc = await readPsdFile(path);
  final c = readPagePsd(doc);
  dir.createSync(recursive: true);
  final stem = p.basenameWithoutExtension(path);
  final image = p.join(dir.path, '$stem.png');
  await File(image).writeAsBytes(ImageCodec.encodePng(c.original), flush: true);
  String? clean;
  if (c.clean case final img?) {
    clean = p.join(dir.path, '${stem}_clean.png');
    await File(clean).writeAsBytes(ImageCodec.encodePng(img), flush: true);
  }
  final blocks = psdBlocks(c, doc.width, doc.height, fonts: fonts);
  // Text from other programs is drawn over the picture without it.
  if (clean == null && blocks.isNotEmpty && c.meta == null) clean = image;
  return PsdPage(
    image: image,
    clean: clean,
    blocks: blocks,
    notices: [if (!c.ours) const PsdForeign(), if (c.unsupported.isNotEmpty) PsdUnsupported(c.unsupported)],
  );
}
