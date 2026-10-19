/// The whole translation pipeline for one page, shared by `cts process`,
/// `cts golden`, `cts bench` and the GUI. Step order follows the original's
/// batch run.
///
/// [PagePipeline.prepare] does the heavy part (detection, OCR, translation,
/// cleaning) and runs in a background isolate in the GUI; [renderPage] draws
/// the translation with dart:ui and stays on the main isolate.
library;

import 'package:ct_core/ct_core.dart';

import '../bootstrap.dart';
import '../render/text_renderer.dart';

/// What [renderPage] drew.
class RenderedPage {
  RenderedPage(this.image, this.items, this.scale);

  final RgbImage image;

  /// Laid-out text, in [image] coordinates.
  final List<TextItem> items;

  /// How much the cleaned page was enlarged before drawing (1 = not).
  final double scale;
}

/// Share of text items that may not fit at the smallest font size before the
/// auto mode enlarges the page further.
const _overflowShare = 0.2;

bool _overflows(TextItem i) => i.width > i.block.xyxy.width + 0.5 || i.height > i.block.xyxy.height + 0.5;

/// Lays out and draws translations over [clean]. The page is enlarged first
/// when [AppSettings.upscale] asks for it (auto: small source text, or many
/// translations that do not fit even at the smallest font size).
///
/// As in the original, [blocks] end up with their render areas and the
/// case-adjusted translations, in [clean] coordinates.
Future<RenderedPage> renderPage(
  RgbImage clean,
  List<TextBlock> blocks,
  AppSettings settings, {
  required String targetLanguage,
}) async {
  final family = await resolveFontFamily(settings.render.fontFamily);
  final engine = UiTextEngine(settings.render, fontFamily: family, rtl: Languages.isRtlName(targetLanguage));
  final w0 = clean.width, h0 = clean.height;
  (int, int) sizeAt(double f) => (((w0 * f).round()), ((h0 * f).round()));
  List<TextItem> layoutAt(double f) {
    final (w, h) = sizeAt(f);
    final copies = f == 1.0 ? [for (final b in blocks) b.copy()] : scaleBlocks(blocks, w0, h0, w, h);
    return layoutPage(copies, w, h, engine, settings: settings.render, targetLanguage: targetLanguage);
  }

  final upscale = settings.upscale;
  var scale = upscale.mode == UpscaleMode.auto ? autoUpscaleFactor(blocks, w0, h0) : fixedUpscaleFactor(upscale, w0, h0);
  var items = layoutAt(scale);
  if (upscale.mode == UpscaleMode.auto && items.isNotEmpty) {
    final limit = (items.length * _overflowShare).ceil();
    for (final more in const [1.5, 2.0]) {
      if (items.where(_overflows).length < limit) break;
      final next = limitUpscaleFactor(scale * more, w0, h0);
      if (next <= scale) break;
      scale = next;
      items = layoutAt(scale);
    }
  }
  setUpperCase(blocks, settings.render.upperCase);
  adjustRenderAreas(blocks, w0, h0);

  final page = scale == 1.0 ? clean : upscaleImage(clean, scale, method: upscale.method);
  return RenderedPage(await renderTextOnPage(page, items, engine), items, scale);
}

/// The page after the heavy steps: blocks with text and translation, and the
/// cleaned image.
class CleanPage {
  CleanPage({
    required this.blocks,
    required this.mask,
    required this.clean,
    required this.inpaintReport,
    required this.timingsMs,
  });

  final List<TextBlock> blocks;
  final GrayImage mask;
  final RgbImage clean;
  final InpaintReport inpaintReport;

  /// Stage name (`01_detect` … `05_inpaint`) → milliseconds.
  final Map<String, int> timingsMs;
}

/// Everything one page run produced.
class PageResult {
  PageResult({
    required this.blocks,
    required this.mask,
    required this.clean,
    required this.rendered,
    required this.items,
    required this.renderScale,
    required this.inpaintReport,
    required this.timingsMs,
  });

  PageResult.of(CleanPage page, RenderedPage render, int renderMs)
      : this(
          blocks: page.blocks,
          mask: page.mask,
          clean: page.clean,
          rendered: render.image,
          items: render.items,
          renderScale: render.scale,
          inpaintReport: page.inpaintReport,
          timingsMs: {...page.timingsMs, '06_render': renderMs},
        );

  final List<TextBlock> blocks;
  final GrayImage mask;
  final RgbImage clean;
  final RgbImage rendered;
  final List<TextItem> items;
  final double renderScale;
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
        'render_scale': renderScale,
        'timings_ms': timingsMs,
      };
}

/// Saves the render step of [page] in test mode.
Future<void> recordRender(RunRecorder? recorder, String? page, RgbImage rendered, List<TextItem> items, int ms) async {
  if (recorder == null) return;
  recorder.recordTiming('06_render', Duration(milliseconds: ms), page: page);
  await recorder.writeArtifact('06_render', 'final.png', ImageCodec.encodePng(rendered), page: page);
  await recorder.writeJsonArtifact('06_render', 'layout.json', [for (final i in items) i.toJson()], page: page);
}

/// Which plugins a pipeline uses and how they are configured, resolved on the
/// main isolate (secrets come from the OS secure storage) so that a
/// background isolate can create the plugins.
class PipelineSpec {
  PipelineSpec({
    required this.settings,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translatorId,
    required this.useGpu,
    required this.configs,
  });

  final AppSettings settings;
  final String sourceLanguage;
  final String targetLanguage;
  final String translatorId;
  final bool useGpu;

  /// Plugin id → resolved configuration (secrets included; never logged).
  final Map<String, PluginConfig> configs;

  static Future<PipelineSpec> resolve(
    AppServices services,
    AppSettings settings, {
    required String sourceLanguage,
    required String targetLanguage,
    String? translatorId,
    bool? useGpu,
  }) async {
    final translator = translatorId ?? settings.translator;
    return PipelineSpec(
      settings: settings,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      translatorId: translator,
      useGpu: useGpu ?? settings.useGpu,
      configs: {
        for (final id in {settings.detector, settings.ocr, translator, settings.inpainter})
          id: await services.pluginConfig(id, settings),
      },
    );
  }
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
  }) async {
    final spec = await PipelineSpec.resolve(services, settings,
        sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, translatorId: translatorId, useGpu: useGpu);
    return create(services.registry, services.models, spec, log ?? services.appLog);
  }

  /// Creates the plugins of [spec] from [registry] (any isolate).
  static Future<PagePipeline> create(PluginRegistry registry, ModelManager models, PipelineSpec spec, EventLog log) async {
    final env = PluginEnvironment(models: models, log: log, useGpu: spec.useGpu);
    final s = spec.settings;
    Future<T> make<T extends Plugin>(String id) => registry.instance<T>(id, spec.configs[id]!, env);
    return PagePipeline(
      settings: s,
      sourceLanguage: spec.sourceLanguage,
      targetLanguage: spec.targetLanguage,
      detector: await make<TextDetector>(s.detector),
      ocr: await make<OcrEngine>(s.ocr),
      translator: await make<Translator>(spec.translatorId),
      inpainter: await make<Inpainter>(s.inpainter),
    );
  }

  /// The same plugins with other page languages.
  PagePipeline withLanguages(String source, String target) => PagePipeline(
        settings: settings,
        sourceLanguage: source,
        targetLanguage: target,
        detector: detector,
        ocr: ocr,
        translator: translator,
        inpainter: inpainter,
      );

  String get _sourceCode => Languages.byName(sourceLanguage)?.code ?? '';

  /// Detection, OCR, translation and cleaning of [image]. [onStage] is called
  /// as each stage starts. Stage artifacts go to the context's recorder (test
  /// mode).
  Future<CleanPage> prepare(RgbImage image, PluginContext context, {void Function(String stage)? onStage}) async {
    final recorder = context.recorder;
    final page = context.page;
    final timings = <String, int>{};
    final sw = Stopwatch()..start();
    void lap(String stage) {
      timings[stage] = sw.elapsedMilliseconds;
      recorder?.recordTiming(stage, Duration(milliseconds: sw.elapsedMilliseconds), page: page);
      sw.reset();
    }

    void start(String stage) {
      context.cancel.throwIfCancelled();
      onStage?.call(stage);
    }

    start('01_detect');
    var blocks = await detector.detect(image, context);
    lap('01_detect');
    await recorder?.writeJsonArtifact('01_detect', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

    start('02_ocr');
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

    start('03_translate');
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

    start('04_mask');
    final inpaintBlocks = selectInpaintBlocks(blocks);
    final mask = generateMask(image, inpaintBlocks);
    lap('04_mask');
    await recorder?.writeArtifact('04_mask', 'mask.png', ImageCodec.encodeGrayPng(mask), page: page);

    start('05_inpaint');
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
    return CleanPage(blocks: blocks, mask: mask, clean: clean, inpaintReport: report, timingsMs: timings);
  }

  /// Every step on [image], drawing included.
  Future<PageResult> run(RgbImage image, PluginContext context, {void Function(String stage)? onStage}) async {
    final cleaned = await prepare(image, context, onStage: onStage);
    context.cancel.throwIfCancelled();
    onStage?.call('06_render');
    final sw = Stopwatch()..start();
    final render = await renderPage(cleaned.clean, cleaned.blocks, settings, targetLanguage: targetLanguage);
    final ms = sw.elapsedMilliseconds;
    await recordRender(context.recorder, context.page, render.image, render.items, ms);
    return PageResult.of(cleaned, render, ms);
  }
}
