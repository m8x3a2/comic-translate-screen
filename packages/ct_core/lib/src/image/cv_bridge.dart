import 'dart:io';
import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

import 'raster.dart';

/// Conversions between [RgbImage]/[GrayImage] and OpenCV `Mat`s.
///
/// Mats own native memory: callers should `dispose()` them when done instead
/// of waiting for the finalizer, pages can be tens of megabytes.
abstract final class CvBridge {
  /// RGB `CV_8UC3` Mat with a copy of [image].
  static cv.Mat rgbToMat(RgbImage image) {
    final mat = cv.Mat.create(rows: image.height, cols: image.width, type: cv.MatType.CV_8UC3);
    mat.data.setAll(0, image.data);
    return mat;
  }

  /// `CV_8UC1` Mat with a copy of [image].
  static cv.Mat grayToMat(GrayImage image) {
    final mat = cv.Mat.create(rows: image.height, cols: image.width, type: cv.MatType.CV_8UC1);
    mat.data.setAll(0, image.data);
    return mat;
  }

  /// Copies an RGB `CV_8UC3` Mat into an [RgbImage].
  static RgbImage matToRgb(cv.Mat mat) {
    _expect(mat, cv.MatType.CV_8UC3);
    final src = mat.isContinuous ? mat : mat.clone();
    try {
      return RgbImage(src.cols, src.rows, Uint8List.fromList(src.data));
    } finally {
      if (!identical(src, mat)) src.dispose();
    }
  }

  /// Copies a `CV_8UC1` Mat into a [GrayImage].
  static GrayImage matToGray(cv.Mat mat) {
    _expect(mat, cv.MatType.CV_8UC1);
    final src = mat.isContinuous ? mat : mat.clone();
    try {
      return GrayImage(src.cols, src.rows, Uint8List.fromList(src.data));
    } finally {
      if (!identical(src, mat)) src.dispose();
    }
  }

  static void _expect(cv.Mat mat, cv.MatType type) {
    if (mat.type != type) {
      throw ArgumentError('Expected Mat of type ${type.asString()}, got ${mat.type.asString()}');
    }
  }
}

class ImageDecodeException implements Exception {
  ImageDecodeException(this.message);

  final String message;

  @override
  String toString() => 'ImageDecodeException: $message';
}

/// Image file decoding/encoding through OpenCV's codecs (PNG, JPEG, WebP,
/// BMP, TIFF). Decoded images are RGB; alpha is dropped like PIL's
/// `convert('RGB')` in the original. EXIF orientation is applied.
abstract final class ImageCodec {
  static RgbImage decode(Uint8List bytes) {
    if (bytes.isEmpty) throw ImageDecodeException('empty input');
    final bgr = cv.imdecode(bytes, cv.IMREAD_COLOR);
    try {
      if (bgr.isEmpty) throw ImageDecodeException('unsupported or corrupt image data');
      final rgb = cv.cvtColor(bgr, cv.COLOR_BGR2RGB);
      try {
        return CvBridge.matToRgb(rgb);
      } finally {
        rgb.dispose();
      }
    } finally {
      bgr.dispose();
    }
  }

  static GrayImage decodeGray(Uint8List bytes) {
    if (bytes.isEmpty) throw ImageDecodeException('empty input');
    final gray = cv.imdecode(bytes, cv.IMREAD_GRAYSCALE);
    try {
      if (gray.isEmpty) throw ImageDecodeException('unsupported or corrupt image data');
      return CvBridge.matToGray(gray);
    } finally {
      gray.dispose();
    }
  }

  static Future<RgbImage> readFile(String path) async => decode(await File(path).readAsBytes());

  /// Encodes as PNG (lossless).
  static Uint8List encodePng(RgbImage image) => _encodeRgb('.png', image);

  /// Encodes as JPEG with [quality] 0–100.
  static Uint8List encodeJpeg(RgbImage image, {int quality = 95}) =>
      _encodeRgb('.jpg', image, params: [cv.IMWRITE_JPEG_QUALITY, quality]);

  static Uint8List encodeGrayPng(GrayImage image) {
    final mat = CvBridge.grayToMat(image);
    try {
      final (ok, bytes) = cv.imencode('.png', mat);
      if (!ok) throw StateError('PNG encoding failed');
      return bytes;
    } finally {
      mat.dispose();
    }
  }

  /// Encodes [image] with [alpha] as a transparent PNG.
  static Uint8List encodeRgbaPng(RgbImage image, GrayImage alpha) {
    if (alpha.width != image.width || alpha.height != image.height) throw ArgumentError('alpha size differs');
    final n = image.width * image.height;
    final mat = cv.Mat.create(rows: image.height, cols: image.width, type: cv.MatType.CV_8UC4);
    try {
      final bgra = Uint8List(n * 4);
      final rgb = image.data, a = alpha.data;
      for (var i = 0; i < n; i++) {
        bgra[i * 4] = rgb[i * 3 + 2];
        bgra[i * 4 + 1] = rgb[i * 3 + 1];
        bgra[i * 4 + 2] = rgb[i * 3];
        bgra[i * 4 + 3] = a[i];
      }
      mat.data.setAll(0, bgra);
      final (ok, bytes) = cv.imencode('.png', mat);
      if (!ok) throw StateError('PNG encoding failed');
      return bytes;
    } finally {
      mat.dispose();
    }
  }

  /// Decodes an image with its alpha (255 everywhere when it has none).
  static (RgbImage, GrayImage) decodeRgba(Uint8List bytes) {
    if (bytes.isEmpty) throw ImageDecodeException('empty input');
    final mat = cv.imdecode(bytes, cv.IMREAD_UNCHANGED);
    try {
      if (mat.isEmpty) throw ImageDecodeException('unsupported or corrupt image data');
      if (mat.type != cv.MatType.CV_8UC4) {
        final rgb = decode(bytes);
        return (rgb, GrayImage(rgb.width, rgb.height, Uint8List(rgb.width * rgb.height)..fillRange(0, rgb.width * rgb.height, 255)));
      }
      final src = mat.isContinuous ? mat.data : mat.clone().data;
      final n = mat.rows * mat.cols;
      final rgb = Uint8List(n * 3), a = Uint8List(n);
      for (var i = 0; i < n; i++) {
        rgb[i * 3] = src[i * 4 + 2];
        rgb[i * 3 + 1] = src[i * 4 + 1];
        rgb[i * 3 + 2] = src[i * 4];
        a[i] = src[i * 4 + 3];
      }
      return (RgbImage(mat.cols, mat.rows, rgb), GrayImage(mat.cols, mat.rows, a));
    } finally {
      mat.dispose();
    }
  }

  /// Encodes by file extension (`.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`).
  static Uint8List encodeByExtension(RgbImage image, String extension) {
    final ext = extension.toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => encodeJpeg(image),
      '.png' || '.webp' || '.bmp' || '.tif' || '.tiff' => _encodeRgb(ext, image),
      _ => throw ArgumentError('Unsupported image extension: $extension'),
    };
  }

  static Future<void> writeFile(String path, RgbImage image) async {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '.png' : path.substring(dot);
    await File(path).writeAsBytes(encodeByExtension(image, ext), flush: true);
  }

  static Uint8List _encodeRgb(String ext, RgbImage image, {List<int>? params}) {
    final rgb = CvBridge.rgbToMat(image);
    final bgr = cv.cvtColor(rgb, cv.COLOR_RGB2BGR);
    final p = params == null ? null : cv.VecI32.fromList(params);
    try {
      final (ok, bytes) = cv.imencode(ext, bgr, params: p);
      if (!ok) throw StateError('Encoding to $ext failed');
      return bytes;
    } finally {
      rgb.dispose();
      bgr.dispose();
      p?.dispose();
    }
  }
}
