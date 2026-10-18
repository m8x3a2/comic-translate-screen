/// Windows' built-in OCR (Windows.Media.Ocr): a light alternative that needs
/// no model download. New in this project (the original has no system OCR).
library;

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:ct_ocr_windows/ct_ocr_windows.dart';

import 'ppocr.dart' show applySourceLanguage;

const windowsOcrInfo = PluginInfo(
  id: 'windows_ocr',
  displayName: 'Windows OCR (built in)',
  description: 'Uses the OCR built into Windows; nothing to download. Less accurate than PaddleOCR on stylised '
      'fonts and cannot read vertical text. Needs the Windows OCR pack of the source language.',
  kind: PluginKind.ocr,
  privacy: Privacy.local,
  platforms: {PlatformId.windows},
  settings: [
    IntSetting(
      key: 'min_text_height',
      label: 'Upscale text smaller than (px)',
      help: 'Small text is enlarged before recognition; Windows OCR reads poorly below about 20 px.',
      defaultValue: 40,
      min: 10,
      max: 120,
    ),
  ],
);

final windowsOcrFactory = PluginFactory<OcrEngine>(windowsOcrInfo, (config, env) async {
  return WindowsOcrEngine(minTextHeight: config.value<int>('min_text_height'));
});

/// Installed Windows OCR language tag for a source language, or null.
String? windowsOcrLanguageTag(String sourceLanguage, List<String> installed) {
  final code = Languages.byName(sourceLanguage)?.code.toLowerCase();
  if (code == null) return null;
  final base = code.split('-').first;
  for (final tag in installed) {
    final t = tag.toLowerCase();
    if (t == code || t.startsWith('$code-')) return tag;
  }
  for (final tag in installed) {
    final t = tag.toLowerCase();
    if (t == base || t.startsWith('$base-')) return tag;
  }
  return null;
}

/// How to install the OCR pack for [code] (shown in errors and `cts doctor`).
String windowsOcrInstallHint(String sourceLanguage) {
  final code = Languages.byName(sourceLanguage)?.code ?? 'en';
  final tag = switch (code) {
    'en' => 'en-US',
    'ja' => 'ja-JP',
    'ko' => 'ko-KR',
    'zh' => 'zh-CN',
    'ru' => 'ru-RU',
    'fr' => 'fr-FR',
    'de' => 'de-DE',
    'es' => 'es-ES',
    'it' => 'it-IT',
    'nl' => 'nl-NL',
    _ => code,
  };
  return 'Install it in Settings → Time & language → Language & region → Add a language ($sourceLanguage, '
      'with "Optical character recognition"), or in PowerShell as administrator: '
      'Add-WindowsCapability -Online -Name "Language.OCR~~~$tag~0.0.1.0"';
}

class WindowsOcrEngine implements OcrEngine {
  WindowsOcrEngine({this.minTextHeight = 40});

  final int minTextHeight;

  @override
  PluginInfo get info => windowsOcrInfo;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    applySourceLanguage(blocks, sourceLanguage);
    final info = WindowsOcr.info();
    final tag = windowsOcrLanguageTag(sourceLanguage, info.languages);
    if (tag == null) {
      throw StateError('Windows OCR has no "$sourceLanguage" language pack '
          '(installed: ${info.languages.join(', ')}). ${windowsOcrInstallHint(sourceLanguage)}');
    }
    final noSpace = isNoSpaceLanguageCode(Languages.byName(sourceLanguage)?.code ?? '');
    for (final block in blocks) {
      context.cancel.throwIfCancelled();
      final crop = _prepare(image, block, info.maxDimension);
      if (crop == null) {
        block.texts = [];
        block.text = '';
        continue;
      }
      final result = WindowsOcr.recognize(crop.data, crop.width, crop.height, language: tag);
      block.texts = [for (final l in result.lines) if (l.text.trim().isNotEmpty) l.text.trim()];
      block.text = noSpace ? block.texts.join() : block.texts.join(' ');
    }
  }

  /// The block with a small margin, enlarged so that its text is at least
  /// [minTextHeight] pixels tall.
  RgbImage? _prepare(RgbImage image, TextBlock block, int maxDimension) {
    const margin = 6;
    final b = block.xyxy;
    final box = BBox(b.x1 - margin, b.y1 - margin, b.x2 + margin, b.y2 + margin).clampTo(image.width, image.height);
    if (box.isEmpty) return null;
    final crop = image.crop(box);

    final vertical = block.direction == TextDirection.vertical;
    final thickness = [
      for (final l in block.lines)
        () {
          final a = l.axisBox;
          return (vertical ? a.x2 - a.x1 : a.y2 - a.y1).abs() + 1;
        }(),
    ];
    final textHeight = thickness.isEmpty ? crop.height.toDouble() : npMedian(thickness);
    var scale = (minTextHeight / math.max(1.0, textHeight)).clamp(1.0, 4.0);
    scale = math.min(scale, maxDimension / math.max(crop.width, crop.height));
    if (scale <= 1.0) return crop;
    return pilResize(crop, (crop.width * scale).round(), (crop.height * scale).round());
  }

  @override
  Future<void> dispose() async {}
}
