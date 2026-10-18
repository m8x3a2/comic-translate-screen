/// The original's "Default" OCR: manga-ocr for Japanese, PaddleOCR for every
/// other language. Port of the routing in `modules/ocr/factory.py` and
/// `modules/ocr/processor.py`.
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

import 'manga_ocr.dart';
import 'ppocr.dart';

const defaultOcrInfo = PluginInfo(
  id: 'default',
  displayName: 'Default (PaddleOCR, manga-ocr for Japanese)',
  description: 'Picks the best local OCR model for the source language.',
  kind: PluginKind.ocr,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['ppocr-v5-rec-en'],
);

final defaultOcrFactory = PluginFactory<OcrEngine>(defaultOcrInfo, (config, env) async {
  final device = env.useGpu ? OrtDevice.directml : OrtDevice.cpu;
  return DefaultOcrEngine(
    PpocrEngine(env.models, device: device, log: env.log),
    MangaOcrEngine(env.models, log: env.log),
  );
});

/// `_should_override_to_ppocr`: large free-text blocks (titles, captions
/// spanning the page) are read by PaddleOCR even for Japanese.
bool shouldOverrideToPpocr(TextBlock block, int imageWidth, int imageHeight) {
  if (block.textClass != TextClass.free) return false;
  final b = block.xyxy;
  return b.height / imageHeight > 0.30 || b.width / imageWidth > 0.50;
}

class DefaultOcrEngine implements OcrEngine {
  DefaultOcrEngine(this.ppocr, this.mangaOcr);

  final PpocrEngine ppocr;
  final MangaOcrEngine mangaOcr;

  @override
  PluginInfo get info => defaultOcrInfo;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    if (sourceLanguage != 'Japanese') {
      return ppocr.recognize(image, blocks, sourceLanguage: sourceLanguage, context: context);
    }
    applySourceLanguage(blocks, sourceLanguage);
    final override = [for (final b in blocks) if (shouldOverrideToPpocr(b, image.width, image.height)) b];
    final normal = [for (final b in blocks) if (!override.contains(b)) b];
    if (override.isNotEmpty) {
      (await ppocr.recognizer('ja')).recognizeBlocks(image, override);
    }
    if (normal.isNotEmpty) {
      await mangaOcr.recognize(image, normal, sourceLanguage: sourceLanguage, context: context);
    }
  }

  @override
  Future<void> dispose() async {
    await ppocr.dispose();
    await mangaOcr.dispose();
  }
}
