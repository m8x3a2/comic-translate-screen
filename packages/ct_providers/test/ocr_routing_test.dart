import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  test('PP-OCR language per source language (original factory)', () {
    expect(ppocrLanguageFor('English'), 'en');
    expect(ppocrLanguageFor('Russian'), 'ru');
    expect(ppocrLanguageFor('Korean'), 'ko');
    expect(ppocrLanguageFor('Chinese'), 'ch');
    expect(ppocrLanguageFor('Japanese'), 'ja');
    for (final l in ['French', 'German', 'Spanish', 'Italian', 'Dutch']) {
      expect(ppocrLanguageFor(l), 'latin');
    }
    expect(() => ppocrLanguageFor('Auto'), throwsUnsupportedError);
    for (final l in Languages.all.where((l) => l.source)) {
      expect(ppocrRecModels.containsKey(ppocrLanguageFor(l.name)), isTrue, reason: l.name);
    }
  });

  test('large free-text blocks go to PaddleOCR for Japanese', () {
    TextBlock block(BBox box, TextClass cls) => TextBlock(xyxy: box, textClass: cls);
    expect(shouldOverrideToPpocr(block(const BBox(0, 0, 100, 400), TextClass.free), 1000, 1000), isTrue);
    expect(shouldOverrideToPpocr(block(const BBox(0, 0, 600, 50), TextClass.free), 1000, 1000), isTrue);
    expect(shouldOverrideToPpocr(block(const BBox(0, 0, 100, 400), TextClass.bubble), 1000, 1000), isFalse);
    expect(shouldOverrideToPpocr(block(const BBox(0, 0, 100, 100), TextClass.free), 1000, 1000), isFalse);
  });

  test('Windows OCR language tags', () {
    const installed = ['en-US', 'ru', 'zh-Hans-CN', 'ja'];
    expect(windowsOcrLanguageTag('English', installed), 'en-US');
    expect(windowsOcrLanguageTag('Russian', installed), 'ru');
    expect(windowsOcrLanguageTag('Chinese', installed), 'zh-Hans-CN');
    expect(windowsOcrLanguageTag('Japanese', installed), 'ja');
    expect(windowsOcrLanguageTag('Korean', installed), isNull);
    expect(windowsOcrInstallHint('Korean'), contains('Language.OCR~~~ko-KR~0.0.1.0'));
  });

  test('registry has the OCR plugins', () {
    final r = builtInRegistry();
    for (final id in ['default', 'ppocr', 'manga_ocr', 'windows_ocr']) {
      expect(r.all.map((i) => i.id), contains(id));
    }
  });
}
