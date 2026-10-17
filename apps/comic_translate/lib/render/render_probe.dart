import 'dart:typed_data';
import 'dart:ui' as ui;

/// Lays out and rasterizes a short multi-script paragraph with dart:ui and
/// returns a PNG. Used by `cts selftest render` and `cts doctor` to verify
/// that the text engine works in the current process (GUI or hidden-window
/// CLI).
class RenderProbe {
  static const sampleText = 'Comic Translate Screen\nПроверка рендера · 漫画 · 만화';

  static Future<RenderProbeResult> run({double width = 480, double fontSize = 28}) async {
    final sw = Stopwatch()..start();
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: fontSize,
    ))
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
      ..addText(sampleText);
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));

    final height = paragraph.height.ceil() + 16;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawRect(ui.Rect.fromLTWH(0, 0, width, height.toDouble()),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF))
      ..drawParagraph(paragraph, const ui.Offset(0, 8));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();

    final inkPixels = rgba == null ? 0 : _countDarkPixels(rgba);
    return RenderProbeResult(
      png: png!.buffer.asUint8List(),
      width: width.ceil(),
      height: height,
      lineCount: paragraph.computeLineMetrics().length,
      inkPixels: inkPixels,
      elapsed: sw.elapsed,
    );
  }

  static int _countDarkPixels(ByteData rgba) {
    var count = 0;
    for (var i = 0; i + 3 < rgba.lengthInBytes; i += 4) {
      if (rgba.getUint8(i) < 128) count++;
    }
    return count;
  }
}

class RenderProbeResult {
  RenderProbeResult({
    required this.png,
    required this.width,
    required this.height,
    required this.lineCount,
    required this.inkPixels,
    required this.elapsed,
  });

  final Uint8List png;
  final int width;
  final int height;
  final int lineCount;

  /// Number of dark pixels; zero means nothing was actually drawn.
  final int inkPixels;
  final Duration elapsed;

  bool get ok => lineCount >= 2 && inkPixels > 100;

  Map<String, Object?> toJson() => {
        'ok': ok,
        'width': width,
        'height': height,
        'lines': lineCount,
        'ink_pixels': inkPixels,
        'elapsed_ms': elapsed.inMilliseconds,
      };
}
