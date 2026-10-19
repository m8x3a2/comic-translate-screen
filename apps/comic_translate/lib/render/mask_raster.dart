/// The manual text-removal mask with dart:ui: the generated mask with the
/// brush and eraser strokes drawn over it (original
/// `generate_mask_from_strokes`).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ct_core/ct_core.dart';

/// Tallest strip drawn at once (GPU texture limits).
const _maxStrip = 4096;

/// [mask] as an image whose alpha is the mask and colour is [argb].
Future<ui.Image> maskToUiImage(GrayImage mask, int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final rgba = Uint8List(mask.width * mask.height * 4);
  for (var i = 0, j = 0; i < mask.data.length; i++, j += 4) {
    if (mask.data[i] == 0) continue;
    rgba[j] = r;
    rgba[j + 1] = g;
    rgba[j + 2] = b;
    rgba[j + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, mask.width, mask.height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// Draws [strokes] in order: the brush paints, the eraser clears. Brush
/// strokes get a one-pixel halo, as the original dilates hand-drawn strokes
/// by one pixel before cleaning.
void paintStrokes(ui.Canvas canvas, List<MaskStroke> strokes, ui.Color color, {double halo = 0}) {
  for (final s in strokes) {
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..strokeWidth = s.width + (s.erase ? 0 : 2 * halo)
      ..color = color
      ..blendMode = s.erase ? ui.BlendMode.clear : ui.BlendMode.srcOver;
    if (s.points.length == 1) {
      final p = s.points.single;
      canvas.drawCircle(ui.Offset(p.x, p.y), paint.strokeWidth / 2, paint..style = ui.PaintingStyle.fill);
      continue;
    }
    final path = ui.Path();
    for (final (i, p) in s.points.indexed) {
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    canvas.drawPath(path, paint);
  }
}

/// The mask to clean a [width]×[height] page with: [base] (the generated
/// mask) plus [strokes]; 255 = remove.
Future<GrayImage> rasterizeMask(int width, int height, {GrayImage? base, List<MaskStroke> strokes = const []}) async {
  final out = Uint8List(width * height);
  final baseImage = base == null ? null : await maskToUiImage(base, 0xFFFFFFFF);
  try {
    for (var top = 0; top < height; top += _maxStrip) {
      final h = math.min(_maxStrip, height - top);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.saveLayer(ui.Rect.fromLTWH(0, 0, width.toDouble(), h.toDouble()), ui.Paint());
      canvas.translate(0, -top.toDouble());
      if (baseImage != null) canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
      paintStrokes(canvas, strokes, const ui.Color(0xFFFFFFFF), halo: 1);
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, h);
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
      picture.dispose();
      final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
      final o = top * width;
      for (var i = 0, j = 3; j < bytes.length; i++, j += 4) {
        if (bytes[j] >= 128) out[o + i] = 255;
      }
    }
  } finally {
    baseImage?.dispose();
  }
  return GrayImage(width, height, out);
}

/// Width and height of the image file at [path], without decoding it.
Future<(int, int)> imageFileSize(String path) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (descriptor.width, descriptor.height);
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
