/// A layered Photoshop document as this program writes and reads it: RGB,
/// 8 bits, layers and groups, editable text layers and the merged picture.
library;

import 'dart:typed_data';

import '../image/raster.dart';

/// Pixels of a layer: [width] × [height] RGBA at ([left], [top]) of the
/// canvas (may reach outside it).
class PsdPixels {
  PsdPixels(this.left, this.top, this.width, this.height, this.rgba) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('Expected ${width * height * 4} bytes, got ${rgba.length}');
    }
  }

  /// An opaque layer from [image] at ([left], [top]).
  factory PsdPixels.opaque(RgbImage image, {int left = 0, int top = 0}) {
    final n = image.width * image.height;
    final rgba = Uint8List(n * 4);
    final s = image.data;
    for (var i = 0, j = 0; i < n * 3; i += 3, j += 4) {
      rgba[j] = s[i];
      rgba[j + 1] = s[i + 1];
      rgba[j + 2] = s[i + 2];
      rgba[j + 3] = 255;
    }
    return PsdPixels(left, top, image.width, image.height, rgba);
  }

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint8List rgba;

  bool get isEmpty => width <= 0 || height <= 0;

  /// The pixels without the fully transparent border (null when nothing is
  /// visible).
  PsdPixels? trimmed() {
    var x0 = width, y0 = height, x1 = -1, y1 = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0, i = y * width * 4 + 3; x < width; x++, i += 4) {
        if (rgba[i] == 0) continue;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
    if (x1 < 0) return null;
    if (x0 == 0 && y0 == 0 && x1 == width - 1 && y1 == height - 1) return this;
    final w = x1 - x0 + 1, h = y1 - y0 + 1;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final from = ((y0 + y) * width + x0) * 4;
      out.setRange(y * w * 4, (y + 1) * w * 4, rgba, from);
    }
    return PsdPixels(left + x0, top + y0, w, h, out);
  }
}

enum PsdJustification { left, right, center }

/// An editable text layer: Photoshop draws it again from these values when
/// the file is opened; the layer's pixels show it in other programs.
class PsdText {
  const PsdText({
    required this.text,
    required this.font,
    required this.fontSize,
    required this.transform,
    required this.boxWidth,
    required this.boxHeight,
    this.color = 0xFF000000,
    this.fauxBold = false,
    this.fauxItalic = false,
    this.underline = false,
    this.strokeColor,
    this.strokeWidth = 0,
    this.justification = PsdJustification.center,
    this.leading,
    this.vertical = false,
  });

  /// Lines separated by `\n`.
  final String text;

  /// PostScript name of the font face (`ArialMT`, `Pangolin-Regular`).
  final String font;

  /// Size in pixels (the document is saved at 72 dpi, so points = pixels).
  final double fontSize;

  /// `xx xy yx yy tx ty`: the box's top-left corner at (tx, ty), rotated.
  final List<double> transform;
  final double boxWidth;
  final double boxHeight;

  /// ARGB.
  final int color;
  final bool fauxBold;
  final bool fauxItalic;
  final bool underline;

  /// Outline drawn under the letters ([strokeWidth] pixels across).
  final int? strokeColor;
  final double strokeWidth;
  final PsdJustification justification;

  /// Line distance in pixels; null = automatic.
  final double? leading;
  final bool vertical;
}

/// The layer style "Stroke", outside the layer's shapes: how comic
/// letterers outline text, and drawn alike by Photoshop and Krita.
class PsdStroke {
  const PsdStroke(this.color, this.size);

  /// ARGB.
  final int color;

  /// Pixels.
  final double size;
}

sealed class PsdNode {
  PsdNode(this.name, {this.hidden = false});

  final String name;
  final bool hidden;
}

class PsdLayer extends PsdNode {
  PsdLayer(
    super.name, {
    this.pixels,
    this.text,
    this.stroke,
    super.hidden,
    this.opacity = 255,
    this.blendMode = 'norm',
    this.clipping = false,
    this.hasMask = false,
    this.isSmartObject = false,
    this.isAdjustment = false,
  });

  final PsdPixels? pixels;
  final PsdText? text;
  final PsdStroke? stroke;

  /// 0–255.
  final int opacity;

  /// Four-letter blend key (`norm`, `mul `, …).
  final String blendMode;

  // Read only: features this program does not edit (import warnings).
  final bool clipping;
  final bool hasMask;
  final bool isSmartObject;
  final bool isAdjustment;
}

class PsdGroup extends PsdNode {
  PsdGroup(super.name, this.children, {super.hidden, this.open = true});

  /// Top to bottom.
  final List<PsdNode> children;
  final bool open;
}

class PsdDocument {
  PsdDocument({
    required this.width,
    required this.height,
    required this.layers,
    this.composite,
    Map<int, Uint8List>? resources,
  }) : resources = resources ?? {};

  final int width;
  final int height;

  /// Top to bottom.
  final List<PsdNode> layers;

  /// The merged picture (what viewers show); none in some files.
  final RgbImage? composite;

  /// Image resources by id (besides resolution and version, which are
  /// written by the writer).
  final Map<int, Uint8List> resources;

  /// Too large for PSD (30 000 px): written as PSB.
  bool get large => width > 30000 || height > 30000;

  /// Every layer (not groups), top to bottom, with the names of its groups.
  Iterable<(PsdLayer, List<String>)> flatLayers() sync* {
    Iterable<(PsdLayer, List<String>)> walk(List<PsdNode> nodes, List<String> path) sync* {
      for (final n in nodes) {
        switch (n) {
          case PsdLayer():
            yield (n, path);
          case PsdGroup():
            yield* walk(n.children, [...path, n.name]);
        }
      }
    }

    yield* walk(layers, const []);
  }
}
