import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  TextBlock blockWithLines(int lineHeight, {int x = 0}) => TextBlock(
        xyxy: BBox(x, 0, x + 200, 100),
        bubbleXyxy: BBox(x, 0, x + 220, 110),
        lines: [for (var i = 0; i < 3; i++) TextLine.box(BBox(x, i * 30, x + 200, i * 30 + lineHeight - 1))],
      );

  group('auto upscale', () {
    test('ordinary text is left alone', () {
      expect(autoUpscaleFactor([blockWithLines(24)], 1600, 2400), 1.0);
      expect(autoUpscaleFactor([], 400, 600), 1.0);
    });

    test('small text is enlarged to about 32 px lines, at most 4×', () {
      expect(autoUpscaleFactor([blockWithLines(10)], 400, 600), closeTo(3.2, 1e-9));
      expect(autoUpscaleFactor([blockWithLines(16)], 400, 600), closeTo(2.0, 1e-9));
      expect(autoUpscaleFactor([blockWithLines(4)], 400, 600), 4.0);
    });

    test('huge pages are capped by the pixel limit', () {
      final f = autoUpscaleFactor([blockWithLines(8)], 4000, 6000);
      expect(f, closeTo(1.2910, 1e-3));
      expect(4000 * f * 6000 * f, lessThanOrEqualTo(upscaleMaxPixels + 1));
    });
  });

  test('fixed modes', () {
    double f(UpscaleMode mode, int w) => fixedUpscaleFactor(UpscaleSettings(mode: mode, targetWidth: 1080), w, w * 3 ~/ 2);
    expect(f(UpscaleMode.off, 300), 1.0);
    expect(f(UpscaleMode.auto, 300), 1.0);
    expect(f(UpscaleMode.x2, 300), 2.0);
    expect(f(UpscaleMode.x3, 300), 3.0);
    expect(f(UpscaleMode.width, 360), 3.0);
    expect(f(UpscaleMode.width, 1600), 1.0, reason: 'wide pages are never shrunk');
  });

  test('settings round-trip and tolerate bad values', () {
    const s = UpscaleSettings(mode: UpscaleMode.width, targetWidth: 1440);
    final back = UpscaleSettings.fromJson(s.toJson());
    expect(back.mode, UpscaleMode.width);
    expect(back.targetWidth, 1440);
    final bad = UpscaleSettings.fromJson({'mode': 'huge', 'target_width': 3, 'method': 'magic'});
    expect(bad.mode, UpscaleMode.auto);
    expect(bad.targetWidth, 1080);
    expect(bad.method, UpscaleMethod.fast);
    expect(AppSettings.fromJson(AppSettings(upscale: s).toJson()).upscale.targetWidth, 1440);
  });

  test('blocks are copied and scaled with the page', () {
    final b = blockWithLines(10, x: 10)..translation = 'Hi';
    final scaled = scaleBlocks([b], 400, 600, 1200, 1800).single;
    expect(scaled.xyxy, const BBox(30, 0, 630, 300));
    expect(scaled.bubbleXyxy, const BBox(30, 0, 690, 330));
    expect(scaled.lines.first.box, const BBox(30, 0, 630, 27));
    expect(scaled.translation, 'Hi');
    expect(b.xyxy, const BBox(10, 0, 210, 100), reason: 'the original block is untouched');
  });

  test('images are enlarged with Lanczos', () {
    final img = RgbImage.filled(10, 6, 200, 100, 50);
    final big = upscaleImage(img, 3);
    expect([big.width, big.height], [30, 18]);
    expect(big.data.sublist(0, 3), [200, 100, 50]);
  });
}
