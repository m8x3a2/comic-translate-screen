/// The whole translation pipeline for one page, shared by `cts process`,
/// `cts golden`, `cts bench` and (later) the GUI. Step order follows the
/// original's batch run.
library;

import 'package:ct_core/ct_core.dart';

import '../bootstrap.dart';
import '../render/text_renderer.dart';

/// Lays out and draws translations over [page] with the render settings.
Future<(RgbImage, List<TextItem>)> renderPage(
  RgbImage page,
  List<TextBlock> blocks,
  AppSettings settings, {
  required String targetLanguage,
}) async {
  final family = await resolveFontFamily(settings.render.fontFamily);
  final engine = UiTextEngine(settings.render, fontFamily: family, rtl: Languages.isRtlName(targetLanguage));
  final items = layoutPage(blocks, page.width, page.height, engine, settings: settings.render, targetLanguage: targetLanguage);
  return (await renderTextOnPage(page, items, engine), items);
}

/// Everything one page run produced.
class PageResult {
  PageResult({
    required this.blocks,
    required this.mask,
    required this.clean,
    required this.rendered,
    required this.items,
    required this.inpaintReport,
    required this.timingsMs,
  });

  final List<TextBlock> blocks;
  final GrayImage mask;
  final RgbImage clean;
  final RgbImage rendered;
  final List<TextItem> items;
  final InpaintReport inpaintReport;

  /// Stage name (`01_detect` …) → milliseconds.
  final Map<String, int> timingsMs;

  int get totalMs => timingsMs.values.fold(0, (a, b) => a + b);

  Map<String, Object?> toJson({required String image, required String source, required String target}) => {
        'image': image,
        'source_language': source,
        'target_language': target,
        'blocks': [for (final b in blocks) b.toJson()],
        'items': [for (final i in items) i.toJson()],
        'timings_ms': timingsMs,
      };
}

/// Loaded plugins plus the settings of one run.
class PagePipeline {
  PagePipeline({
    required this.settings,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.detector,
    required this.ocr,
    required this.translator,
    required this.inpainter,
  });

  final AppSettings settings;
  final String sourceLanguage;
  final String targetLanguage;
  final TextDetector detector;
  final OcrEngine ocr;
  final Translator translator;
  final Inpainter inpainter;

  /// Creates the plugins chosen in [settings] ([translatorId] overrides the
  /// translator). Throws [ModelNotInstalledException] for missing models.
  static Future<PagePipeline> load(
    AppServices services,
    AppSettings settings, {
    required String sourceLanguage,
    required String targetLanguage,
    String? translatorId,
    bool? useGpu,
    EventLog? log,
  }) async =>
      PagePipeline(
        settings: settings,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        detector: await services.plugin<TextDetector>(settings.detector, settings, useGpu: useGpu, log: log),
        ocr: await services.plugin<OcrEngine>(settings.ocr, settings, useGpu: useGpu, log: log),
        translator: await services.plugin<Translator>(translatorId ?? settings.translator, settings, log: log),
        inpainter: await services.plugin<Inpainter>(settings.inpainter, settings, useGpu: useGpu, log: log),
      );

  String get _sourceCode => Languages.byName(sourceLanguage)?.code ?? '';

  /// Runs every step on [image]. Stage artifacts go to the context's
  /// recorder (test mode).
  Future<PageResult> run(RgbImage image, PluginContext context) async {
    final recorder = context.recorder;
    final page = context.page;
    final timings = <String, int>{};
    final sw = Stopwatch()..start();
    void lap(String stage) {
      timings[stage] = sw.elapsedMilliseconds;
      recorder?.recordTiming(stage, Duration(milliseconds: sw.elapsedMilliseconds), page: page);
      sw.reset();
    }

    var blocks = await detector.detect(image, context);
    lap('01_detect');
    await recorder?.writeJsonArtifact('01_detect', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

    final reading = prepareReading(image, blocks, sourceLanguageCode: _sourceCode, enabled: settings.upscaleSmallText);
    try {
      await ocr.recognize(reading.image, blocks, sourceLanguage: sourceLanguage, context: context);
    } finally {
      reading.restore();
    }
    if (settings.fixCyrillicLookalikes) fixOcrScript(blocks, _sourceCode);
    blocks = sortBlocks(blocks, rightToLeft: sourceLanguage == 'Japanese');
    lap('02_ocr');
    await recorder?.writeJsonArtifact('02_ocr', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

    await translateBlocks(
      translator,
      TranslationRequest(
        blocks: blocks,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        pageImage: settings.sendPageImage ? image : null,
        extraContext: settings.extraContext,
      ),
      context,
    );
    lap('03_translate');

    final inpaintBlocks = selectInpaintBlocks(blocks);
    final mask = generateMask(image, inpaintBlocks);
    lap('04_mask');
    await recorder?.writeArtifact('04_mask', 'mask.png', ImageCodec.encodeGrayPng(mask), page: page);

    final report = InpaintReport();
    final clean = await inpaintPage(
      image,
      mask,
      settings.inpaint,
      (img, m) => inpainter.inpaint(img, m, settings.inpaint, context),
      blocks: inpaintBlocks,
      report: report,
    );
    lap('05_inpaint');
    await recorder?.writeArtifact('05_inpaint', 'clean.png', ImageCodec.encodePng(clean), page: page);

    final (rendered, items) = await renderPage(clean, blocks, settings, targetLanguage: targetLanguage);
    lap('06_render');
    if (recorder != null) {
      await recorder.writeArtifact('06_render', 'final.png', ImageCodec.encodePng(rendered), page: page);
      await recorder.writeJsonArtifact('06_render', 'layout.json', [for (final i in items) i.toJson()], page: page);
    }
    return PageResult(
      blocks: blocks,
      mask: mask,
      clean: clean,
      rendered: rendered,
      items: items,
      inpaintReport: report,
      timingsMs: timings,
    );
  }
}
