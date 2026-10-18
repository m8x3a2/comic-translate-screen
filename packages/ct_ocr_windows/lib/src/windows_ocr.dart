import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

@ffi.Native<ffi.Pointer<Utf8> Function()>(symbol: 'cts_wocr_info', assetId: 'package:ct_ocr_windows/ct_ocr_windows')
external ffi.Pointer<Utf8> _info();

@ffi.Native<ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.Int32, ffi.Pointer<Utf8>)>(
    symbol: 'cts_wocr_recognize', assetId: 'package:ct_ocr_windows/ct_ocr_windows')
external ffi.Pointer<Utf8> _recognize(ffi.Pointer<ffi.Uint8> rgb, int width, int height, ffi.Pointer<Utf8> language);

@ffi.Native<ffi.Void Function(ffi.Pointer<Utf8>)>(symbol: 'cts_wocr_free', assetId: 'package:ct_ocr_windows/ct_ocr_windows')
external void _free(ffi.Pointer<Utf8> p);

Map<String, Object?> _take(ffi.Pointer<Utf8> p) {
  if (p == ffi.nullptr) throw StateError('Windows OCR: out of memory');
  try {
    return (jsonDecode(p.toDartString()) as Map).cast<String, Object?>();
  } finally {
    _free(p);
  }
}

/// A word with its box in image pixels.
class WindowsOcrWord {
  const WindowsOcrWord(this.text, this.x, this.y, this.width, this.height);

  final String text;
  final double x, y, width, height;
}

class WindowsOcrLine {
  const WindowsOcrLine(this.text, this.words);

  final String text;
  final List<WindowsOcrWord> words;
}

class WindowsOcrResult {
  const WindowsOcrResult(this.language, this.lines, this.angle);

  /// Tag of the recognizer that was used, e.g. `en-US`.
  final String language;
  final List<WindowsOcrLine> lines;

  /// Detected text angle in degrees, if any.
  final double? angle;
}

class WindowsOcrException implements Exception {
  WindowsOcrException(this.message, {this.language, this.hresult});

  final String message;
  final String? language;
  final String? hresult;

  bool get languageNotInstalled => message == 'language not installed';

  @override
  String toString() => 'WindowsOcrException: $message${language != null ? ' ($language)' : ''}'
      '${hresult != null ? ' [$hresult]' : ''}';
}

/// Static access to Windows.Media.Ocr. Calls block until recognition ends
/// (the native side runs them on a worker thread).
abstract final class WindowsOcr {
  /// BCP-47 tags of the installed OCR languages and the largest supported
  /// image side.
  static ({List<String> languages, int maxDimension}) info() {
    final r = _take(_info());
    if (r['error'] != null) throw WindowsOcrException(r['error'] as String, hresult: r['hresult'] as String?);
    return (
      languages: (r['languages'] as List).cast<String>(),
      maxDimension: (r['max_dimension'] as num).toInt(),
    );
  }

  /// Recognizes an RGB image (3 bytes per pixel). An empty [language] uses
  /// the user's profile languages.
  static WindowsOcrResult recognize(Uint8List rgb, int width, int height, {String language = ''}) {
    if (rgb.length != width * height * 3) throw ArgumentError('rgb has ${rgb.length} bytes, expected ${width * height * 3}');
    final buffer = malloc<ffi.Uint8>(rgb.length);
    final tag = language.toNativeUtf8();
    try {
      buffer.asTypedList(rgb.length).setAll(0, rgb);
      final r = _take(_recognize(buffer, width, height, tag));
      if (r['error'] != null) {
        throw WindowsOcrException(r['error'] as String, language: r['language'] as String?, hresult: r['hresult'] as String?);
      }
      return WindowsOcrResult(
        r['language'] as String,
        [
          for (final l in (r['lines'] as List).cast<Map>())
            WindowsOcrLine(l['text'] as String, [
              for (final w in (l['words'] as List).cast<Map>())
                WindowsOcrWord(w['text'] as String, (w['x'] as num).toDouble(), (w['y'] as num).toDouble(),
                    (w['w'] as num).toDouble(), (w['h'] as num).toDouble()),
            ]),
        ],
        (r['angle'] as num?)?.toDouble(),
      );
    } finally {
      malloc.free(buffer);
      malloc.free(tag);
    }
  }
}
