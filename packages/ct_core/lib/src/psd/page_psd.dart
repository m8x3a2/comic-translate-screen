/// One translated page as a PSD file, laid out like the original program's
/// export (`psd_exporter.py`), so files go both ways between the two: top to
/// bottom the group "Editable Text" (text layers), the group "Inpaint
/// Patches" (the cleaned places) and the layer "Raw Image" (the page as it
/// was). Unlike the original, the merged picture is written too, and the
/// page's blocks are kept in an image resource for an exact import.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../image/raster.dart';
import '../model/geometry.dart';
import 'psd_document.dart';

const psdTextGroup = 'Editable Text';
const psdPatchGroup = 'Inpaint Patches';
const psdRawLayer = 'Raw Image';

/// Image resource with this program's page data (JSON; first of the
/// plug-in range).
const psdPageResource = 4000;
const _app = 'comic-translate-screen';

/// Rectangles of [tile]-pixel squares where [a] and [b] differ, joined when
/// they touch.
List<BBox> changedRegions(RgbImage a, RgbImage b, {int tile = 32, int threshold = 10}) {
  if (a.width != b.width || a.height != b.height) {
    throw ArgumentError('pictures of different sizes');
  }
  final w = a.width, h = a.height;
  final cols = (w + tile - 1) ~/ tile, rows = (h + tile - 1) ~/ tile;
  final marked = Uint8List(cols * rows);
  for (var y = 0; y < h; y++) {
    final row = (y ~/ tile) * cols;
    for (var x = 0, i = y * w * 3; x < w; x++, i += 3) {
      if ((a.data[i] - b.data[i]).abs() > threshold ||
          (a.data[i + 1] - b.data[i + 1]).abs() > threshold ||
          (a.data[i + 2] - b.data[i + 2]).abs() > threshold) {
        marked[row + x ~/ tile] = 1;
      }
    }
  }
  final out = <BBox>[];
  final seen = Uint8List(cols * rows);
  for (var start = 0; start < marked.length; start++) {
    if (marked[start] == 0 || seen[start] == 1) continue;
    var x0 = cols, y0 = rows, x1 = -1, y1 = -1;
    final stack = [start];
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      final cx = c % cols, cy = c ~/ cols;
      x0 = math.min(x0, cx);
      x1 = math.max(x1, cx);
      y0 = math.min(y0, cy);
      y1 = math.max(y1, cy);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = cx + dx, ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
          final n = ny * cols + nx;
          if (marked[n] == 1 && seen[n] == 0) {
            seen[n] = 1;
            stack.add(n);
          }
        }
      }
    }
    out.add(BBox(x0 * tile, y0 * tile, math.min(w, (x1 + 1) * tile), math.min(h, (y1 + 1) * tile)));
  }
  return out;
}

/// A text layer to put in the page's file: [text] null = pixels only
/// (vertical text, which other programs' files may break on).
class PageTextLayer {
  const PageTextLayer(this.name, this.pixels, this.text, {this.stroke});

  final String name;
  final PsdPixels? pixels;
  final PsdText? text;
  final PsdStroke? stroke;
}

/// The page's document: [raw] (the page before cleaning), the places where
/// [clean] differs from it as patches, [texts] over them, [composite] as the
/// merged picture. All the same size. [meta] goes into [psdPageResource].
PsdDocument pagePsd({
  required RgbImage raw,
  required RgbImage clean,
  required RgbImage composite,
  required List<PageTextLayer> texts,
  Map<String, Object?>? meta,
}) {
  final patches = [
    for (final (i, r) in changedRegions(raw, clean).indexed)
      PsdLayer(
        'Patch ${i + 1}',
        pixels: PsdPixels.opaque(clean.crop(r), left: r.x1, top: r.y1),
      ),
  ];
  return PsdDocument(
    width: raw.width,
    height: raw.height,
    composite: composite,
    layers: [
      PsdGroup(psdTextGroup, [
        for (final t in texts) PsdLayer(t.name, pixels: t.pixels, text: t.text, stroke: t.stroke),
      ]),
      PsdGroup(psdPatchGroup, patches),
      PsdLayer(psdRawLayer, pixels: PsdPixels.opaque(raw)),
    ],
    resources: {
      if (meta != null) psdPageResource: utf8.encode(jsonEncode({'app': _app, 'version': 1, ...meta})),
    },
  );
}

/// What a PSD gives for one page.
class PsdPageContent {
  PsdPageContent({
    required this.original,
    required this.clean,
    required this.texts,
    required this.meta,
    required this.ours,
    required this.unsupported,
  });

  /// The page without the editable text, and with the cleaned places (null
  /// when the file has no patches: the page has not been cleaned).
  final RgbImage original;
  final RgbImage? clean;

  /// Visible text layers, top to bottom: name, text, outline style.
  final List<(String, PsdText, PsdStroke?)> texts;

  /// This program's page data, when the file has it.
  final Map<String, Object?>? meta;

  /// Laid out as exported by this program or the original one.
  final bool ours;

  /// Photoshop features the import does not reproduce (smart objects,
  /// masks, blend modes …), for a warning.
  final List<String> unsupported;
}

/// Draws [px] over [canvas] (straight alpha, [opacity] 0–255).
void _blend(RgbImage canvas, PsdPixels px, {int opacity = 255}) {
  for (var y = 0; y < px.height; y++) {
    final cy = px.top + y;
    if (cy < 0 || cy >= canvas.height) continue;
    for (var x = 0; x < px.width; x++) {
      final cx = px.left + x;
      if (cx < 0 || cx >= canvas.width) continue;
      final s = (y * px.width + x) * 4;
      final a = px.rgba[s + 3] * opacity ~/ 255;
      if (a == 0) continue;
      final d = (cy * canvas.width + cx) * 3;
      for (var c = 0; c < 3; c++) {
        canvas.data[d + c] = a == 255 ? px.rgba[s + c] : (px.rgba[s + c] * a + canvas.data[d + c] * (255 - a)) ~/ 255;
      }
    }
  }
}

/// Reads one page from [doc] (original `psd_importer.py`): a file laid out
/// by this program or the original gives the raw page, the patches and the
/// text; any other file gives its visible picture layers flattened (or its
/// merged picture) and its text layers.
PsdPageContent readPagePsd(PsdDocument doc) {
  Map<String, Object?>? meta;
  if (doc.resources[psdPageResource] case final bytes?) {
    try {
      final m = jsonDecode(utf8.decode(bytes));
      if (m is Map<String, Object?> && m['app'] == _app) meta = m;
    } on FormatException {
      meta = null;
    }
  }
  final layers = doc.flatLayers().toList();
  bool inGroup(List<String> path, String name) => path.isNotEmpty && path.first == name;
  final ours =
      layers.any((e) => e.$1.name == psdRawLayer && e.$1.text == null) ||
      doc.layers.any((n) => n is PsdGroup && (n.name == psdTextGroup || n.name == psdPatchGroup));

  final unsupported = <String>{};
  for (final (l, _) in layers) {
    if (l.hidden) continue;
    if (l.isSmartObject) unsupported.add('smart objects');
    if (l.hasMask) unsupported.add('masks');
    if (l.clipping) unsupported.add('clipping masks');
    if (l.isAdjustment) unsupported.add('adjustment layers');
    if (l.blendMode != 'norm' && l.blendMode != 'pass') unsupported.add('blend modes');
    if (l.opacity != 255) unsupported.add('layer opacity');
  }

  final white = RgbImage.filled(doc.width, doc.height, 255, 255, 255);
  final RgbImage original;
  RgbImage? clean;
  if (ours) {
    original = white;
    final raw = layers.where((e) => e.$1.name == psdRawLayer && e.$1.text == null).firstOrNull;
    if (raw?.$1.pixels case final px?) {
      _blend(original, px);
    } else if (doc.composite case final c?) {
      original.data.setAll(0, c.data);
    }
    final patches = [
      for (final (l, path) in layers)
        if (inGroup(path, psdPatchGroup) && !l.hidden && l.text == null) ?l.pixels,
    ];
    if (patches.isNotEmpty) {
      clean = RgbImage(doc.width, doc.height, Uint8List.fromList(original.data));
      for (final px in patches.reversed) {
        _blend(clean, px);
      }
    }
  } else {
    final pictures = [
      for (final (l, _) in layers)
        if (!l.hidden && l.text == null && !l.isAdjustment && l.pixels != null) l,
    ];
    if (pictures.isEmpty && doc.composite != null) {
      original = RgbImage(doc.width, doc.height, Uint8List.fromList(doc.composite!.data));
    } else {
      original = white;
      for (final l in pictures.reversed) {
        _blend(original, l.pixels!, opacity: l.opacity);
      }
    }
  }
  final texts = [
    for (final (l, _) in layers)
      if (!l.hidden && l.text != null && l.text!.text.trim().isNotEmpty) (l.name, l.text!, l.stroke),
  ];
  return PsdPageContent(
    original: original,
    clean: clean,
    texts: texts,
    meta: meta,
    ours: ours,
    unsupported: unsupported.toList(),
  );
}
