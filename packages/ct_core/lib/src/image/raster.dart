import 'dart:typed_data';

import '../model/geometry.dart';

/// 8-bit RGB image, rows top to bottom, pixels interleaved `R G B`.
///
/// The pipeline works in RGB like the original (`imkit` reads images as
/// RGB numpy arrays). Conversion to/from OpenCV lives in `cv_bridge.dart`.
class RgbImage {
  RgbImage(this.width, this.height, this.data) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image size must be positive: ${width}x$height');
    }
    if (data.length != width * height * 3) {
      throw ArgumentError('Expected ${width * height * 3} bytes, got ${data.length}');
    }
  }

  factory RgbImage.filled(int width, int height, int r, int g, int b) {
    final data = Uint8List(width * height * 3);
    for (var i = 0; i < data.length; i += 3) {
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
    }
    return RgbImage(width, height, data);
  }

  final int width;
  final int height;
  final Uint8List data;

  int offset(int x, int y) => (y * width + x) * 3;

  /// Copy of the region [box] (clamped to the image).
  RgbImage crop(BBox box) {
    final b = box.clampTo(width, height);
    if (b.isEmpty) throw ArgumentError('Empty crop $box for ${width}x$height image');
    final out = Uint8List(b.width * b.height * 3);
    final rowBytes = b.width * 3;
    for (var y = 0; y < b.height; y++) {
      final src = offset(b.x1, b.y1 + y);
      out.setRange(y * rowBytes, (y + 1) * rowBytes, data, src);
    }
    return RgbImage(b.width, b.height, out);
  }

  RgbImage clone() => RgbImage(width, height, Uint8List.fromList(data));

  @override
  String toString() => 'RgbImage(${width}x$height)';
}

/// 8-bit single-channel image: masks (0 or 255) and grayscale.
class GrayImage {
  GrayImage(this.width, this.height, this.data) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image size must be positive: ${width}x$height');
    }
    if (data.length != width * height) {
      throw ArgumentError('Expected ${width * height} bytes, got ${data.length}');
    }
  }

  GrayImage.zeros(this.width, this.height) : data = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List data;

  int at(int x, int y) => data[y * width + x];

  GrayImage crop(BBox box) {
    final b = box.clampTo(width, height);
    if (b.isEmpty) throw ArgumentError('Empty crop $box for ${width}x$height image');
    final out = Uint8List(b.width * b.height);
    for (var y = 0; y < b.height; y++) {
      final src = (b.y1 + y) * width + b.x1;
      out.setRange(y * b.width, (y + 1) * b.width, data, src);
    }
    return GrayImage(b.width, b.height, out);
  }

  int countNonZero() {
    var n = 0;
    for (final v in data) {
      if (v != 0) n++;
    }
    return n;
  }

  GrayImage clone() => GrayImage(width, height, Uint8List.fromList(data));

  @override
  String toString() => 'GrayImage(${width}x$height)';
}
