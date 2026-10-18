@TestOn('windows')
library;

import 'dart:typed_data';

import 'package:ct_ocr_windows/ct_ocr_windows.dart';
import 'package:test/test.dart';

void main() {
  test('reports installed languages', () {
    final info = WindowsOcr.info();
    expect(info.maxDimension, greaterThan(0));
    printOnFailure('languages: ${info.languages}');
  });

  test('blank image yields no lines; missing language is reported', () {
    final white = Uint8List(64 * 32 * 3)..fillRange(0, 64 * 32 * 3, 255);
    final info = WindowsOcr.info();
    if (info.languages.isNotEmpty) {
      final r = WindowsOcr.recognize(white, 64, 32, language: info.languages.first);
      expect(r.lines, isEmpty);
    }
    expect(
      () => WindowsOcr.recognize(white, 64, 32, language: 'xx-XX'),
      throwsA(isA<WindowsOcrException>()),
    );
  });
}
