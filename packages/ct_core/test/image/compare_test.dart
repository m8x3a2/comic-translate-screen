import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

RgbImage solid(int w, int h, int v) => RgbImage(w, h, Uint8List(w * h * 3)..fillRange(0, w * h * 3, v));

void main() {
  test('identical images: infinite PSNR, nothing changed', () {
    final d = compareImages(solid(4, 4, 100), solid(4, 4, 100));
    expect(d.identical, isTrue);
    expect(d.psnr, double.infinity);
    expect(d.changedFraction, 0);
  });

  test('PSNR, max diff and changed share', () {
    final a = solid(2, 1, 0);
    final b = solid(2, 1, 0)..data[0] = 50;
    final d = compareImages(a, b, threshold: 10);
    expect(d.maxDiff, 50);
    expect(d.changedFraction, 0.5);
    expect(d.meanAbsDiff, closeTo(50 / 6, 1e-9));
    // MSE = 2500 / 6 → PSNR = 10·log10(65025 / 416.67) ≈ 21.93 dB.
    expect(d.psnr, closeTo(21.933, 0.001));
    final pic = diffImage(a, b, threshold: 10);
    expect(pic.data.sublist(0, 3), [255, 0, 0]);
    expect(pic.data[3], pic.data[4]);
  });

  test('different sizes are an error; fitWithin keeps the aspect', () {
    expect(() => compareImages(solid(2, 2, 0), solid(3, 2, 0)), throwsArgumentError);
    final small = fitWithin(solid(400, 200, 7), 100);
    expect((small.width, small.height), (100, 50));
    expect(small.data.every((v) => v == 7), isTrue);
    expect(identical(fitWithin(small, 100), small), isTrue);
  });
}
