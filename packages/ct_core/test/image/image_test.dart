import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

RgbImage gradient(int w, int h) {
  final data = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 3;
      data[o] = (x * 255 ~/ (w - 1));
      data[o + 1] = (y * 255 ~/ (h - 1));
      data[o + 2] = 128;
    }
  }
  return RgbImage(w, h, data);
}

void main() {
  group('RgbImage', () {
    test('rejects wrong buffer sizes', () {
      expect(() => RgbImage(2, 2, Uint8List(11)), throwsArgumentError);
      expect(() => GrayImage(0, 2, Uint8List(0)), throwsArgumentError);
    });

    test('crop copies the clamped region', () {
      final img = gradient(10, 8);
      final c = img.crop(const BBox(2, 3, 5, 20));
      expect([c.width, c.height], [3, 5]);
      expect(c.data.sublist(0, 3), img.data.sublist(img.offset(2, 3), img.offset(2, 3) + 3));
    });
  });

  group('ImageCodec (OpenCV)', () {
    test('PNG round trip is lossless and keeps RGB order', () {
      final img = gradient(37, 21);
      final decoded = ImageCodec.decode(ImageCodec.encodePng(img));
      expect([decoded.width, decoded.height], [37, 21]);
      expect(decoded.data, img.data);
    });

    test('JPEG round trip is close', () {
      final img = RgbImage.filled(16, 16, 200, 30, 60);
      final decoded = ImageCodec.decode(ImageCodec.encodeJpeg(img, quality: 98));
      expect((decoded.data[0] - 200).abs(), lessThan(6));
      expect((decoded.data[1] - 30).abs(), lessThan(6));
      expect((decoded.data[2] - 60).abs(), lessThan(6));
    });

    test('gray PNG round trip', () {
      final mask = GrayImage.zeros(5, 4)..data[7] = 255;
      final decoded = ImageCodec.decodeGray(ImageCodec.encodeGrayPng(mask));
      expect(decoded.data, mask.data);
      expect(decoded.countNonZero(), 1);
    });

    test('corrupt data raises ImageDecodeException', () {
      expect(() => ImageCodec.decode(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<ImageDecodeException>()));
    });
  });
}
