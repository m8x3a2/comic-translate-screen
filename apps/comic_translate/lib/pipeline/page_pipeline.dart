/// The whole translation pipeline for one page, shared by `cts process`,
/// `cts golden`, `cts bench` and the GUI. Step order follows the original's
/// batch run.
///
/// [PagePipeline.prepare] does the heavy part (detection, OCR, translation,
/// cleaning) and runs in a background isolate in the GUI; [renderPage] draws
/// the translation with dart:ui and stays on the main isolate.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
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

/// Where the translations go on a page and how much it is enlarged first.
class RenderLayout {
  RenderLayout(this.scale, this.items, [this.blockIndex = const []]);

  /// Enlargement of the page (1 = none).
  final double scale;

  /// Laid-out text, in enlarged page coordinates.
  final List<TextItem> items;

  /// The block of each item (index into the laid-out blocks).
  final List<int> blockIndex;
}

/// Laid-out text of single blocks, kept between edits so that the editor
/// lays out only the blocks that changed.
class LayoutCache {
  final _items = <String, TextItem?>{};

  TextItem? _lookup(String key, TextItem? Function() make) {
    if (_items.containsKey(key)) return _items[key];
    if (_items.length > 2000) _items.clear();
    return _items[key] = make();
  }

  void clear() => _items.clear();
}

/// The text engines for drawing [blocks] (their fonts loaded).
Future<TextEngines> loadTextEngines(AppSettings settings, String targetLanguage, Iterable<TextBlock> blocks) =>
    TextEngines.load(settings.render, rtl: Languages.isRtlName(targetLanguage), blocks: blocks);

/// Lays out the translations of [blocks] on a [width]×[height] page. The
/// page is enlarged first when [AppSettings.upscale] asks for it (auto:
/// small source text, or many translations that do not fit even at the
/// smallest font size). [blocks] are not changed.
RenderLayout layoutRender(
  int width,
  int height,
  List<TextBlock> blocks,
  AppSettings settings,
  TextEngines engines, {
  required String targetLanguage,
  LayoutCache? cache,
}) {
  final w0 = width, h0 = height;
  (int, int) sizeAt(double f) => (((w0 * f).round()), ((h0 * f).round()));
  List<TextItem> layoutBlocks(List<TextBlock> copies, int w, int h) => layoutPage(
    copies,
    w,
    h,
    engines.main,
    settings: settings.render,
    targetLanguage: targetLanguage,
    measurerFor: engines.of,
  );
  List<TextItem> layoutAt(double f) {
    final (w, h) = sizeAt(f);
    final copies = f == 1.0 ? [for (final b in blocks) b.copy()] : scaleBlocks(blocks, w0, h0, w, h);
    if (cache == null || copies.isEmpty) return layoutBlocks(copies, w, h);
    // Block by block: the page's first block decides the render areas.
    final first = copies.first.sourceLang;
    final prefix = '$w|$h|$first|$targetLanguage|${jsonEncode(settings.render.toJson())}|';
    return [
      for (final c in copies)
        ?cache._lookup('$prefix${jsonEncode(c.toJson())}', () {
          final one = layoutBlocks([c..sourceLang = first], w, h);
          return one.isEmpty ? null : one.single;
        }),
    ];
  }

  final upscale = settings.upscale;
  var scale = upscale.mode == UpscaleMode.auto
      ? autoUpscaleFactor(blocks, w0, h0)
      : fixedUpscaleFactor(upscale, w0, h0);
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
  final index = [
    for (final (i, b) in blocks.indexed)
      if (hasTranslatableContent(b.translation)) i,
  ];
  return RenderLayout(scale, items, index.length == items.length ? index : const []);
}

/// Lays out and draws the translations of [blocks] over [clean] (see
/// [layoutRender]). Unlike the original, [blocks] keep their detected boxes
/// and the translations as written, so the page can be edited and drawn
/// again.
Future<RenderedPage> renderPage(
  RgbImage clean,
  List<TextBlock> blocks,
  AppSettings settings, {
  required String targetLanguage,
}) async {
  final engines = await loadTextEngines(settings, targetLanguage, blocks);
  final layout = layoutRender(clean.width, clean.height, blocks, settings, engines, targetLanguage: targetLanguage);
  final scale = layout.scale;
  final page = scale == 1.0 ? clean : upscaleImage(clean, scale, method: settings.upscale.method);
  return RenderedPage(await renderTextOnPage(page, layout.items, engines), layout.items, scale);
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

  /// Changes when the plugins or their configuration change (not with the
  /// languages, which every job brings). A hash, so secrets never show.
  String get fingerprint {
    final s = settings.toJson()
      ..remove('languages')
      ..remove('render')
      ..remove('upscale')
      ..remove('export')
      ..remove('ui')
      ..remove('approved_network_plugins');
    final configs = {
      for (final e in this.configs.entries) e.key: {'values': e.value.values, 'secrets': e.value.secrets},
    };
    final text = jsonEncode({
      'settings': s,
      'translator': translatorId,
      'gpu': useGpu,
      'configs': configs,
    }, toEncodable: (o) => o.toString());
    return sha256.convert(utf8.encode(text)).toString();
  }

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
    final spec = await PipelineSpec.resolve(
      services,
      settings,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      translatorId: translatorId,
      useGpu: useGpu,
    );
    return create(services.registry, services.models, spec, log ?? services.appLog);
  }

  /// Creates the plugins of [spec] from [registry] (any isolate).
  static Future<PagePipeline> create(
    PluginRegistry registry,
    ModelManager models,
    PipelineSpec spec,
    EventLog log,
  ) async {
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
    await recognizeBlocks(ocr, image, blocks, settings, context, sourceLanguage: sourceLanguage);
    blocks = sortBlocks(blocks, rightToLeft: sourceLanguage == 'Japanese');
    lap('02_ocr');
    await recorder?.writeJsonArtifact('02_ocr', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

    start('03_translate');
    await translatePageBlocks(
      translator,
      image,
      blocks,
      settings,
      context,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
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

// Single steps, shared by the batch run and the manual steps of the editor
// (original `manual_workflow.py`).

/// OCR of [blocks] on [image] (small text enlarged first when the setting
/// asks for it).
Future<void> recognizeBlocks(
  OcrEngine ocr,
  RgbImage image,
  List<TextBlock> blocks,
  AppSettings settings,
  PluginContext context, {
  required String sourceLanguage,
}) async {
  final code = Languages.byName(sourceLanguage)?.code ?? '';
  final reading = prepareReading(image, blocks, sourceLanguageCode: code, enabled: settings.upscaleSmallText);
  try {
    await ocr.recognize(reading.image, blocks, sourceLanguage: sourceLanguage, context: context);
  } finally {
    reading.restore();
  }
  if (settings.fixCyrillicLookalikes) fixOcrScript(blocks, code);
}

/// Translation of [blocks] (the page image goes along when the setting
/// allows it).
Future<void> translatePageBlocks(
  Translator translator,
  RgbImage image,
  List<TextBlock> blocks,
  AppSettings settings,
  PluginContext context, {
  required String sourceLanguage,
  required String targetLanguage,
}) => translateBlocks(
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

/// The plugins of a [PipelineSpec], created when first needed and kept.
class LazyPlugins {
  LazyPlugins(this.registry, this.models, this.spec, this.log);

  final PluginRegistry registry;
  final ModelManager models;
  final PipelineSpec spec;
  final EventLog log;
  final _made = <String, Future<Plugin>>{};

  Future<T> _make<T extends Plugin>(String id) {
    final made = _made[id] ??= registry.instance<T>(
      id,
      spec.configs[id] ?? PluginConfig(),
      PluginEnvironment(models: models, log: log, useGpu: spec.useGpu),
    );
    // A failure (model not downloaded yet) is not kept: the next call tries
    // again.
    return made.then(
      (p) => p as T,
      onError: (Object e, StackTrace st) {
        if (identical(_made[id], made)) _made.remove(id);
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  Future<TextDetector> get detector => _make(spec.settings.detector);
  Future<OcrEngine> get ocr => _make(spec.settings.ocr);
  Future<Translator> get translator => _make(spec.translatorId);
  Future<Inpainter> get inpainter => _make(spec.settings.inpainter);

  /// Every plugin, for whole-page runs.
  Future<PagePipeline> pipeline(String source, String target) async => PagePipeline(
    settings: spec.settings,
    sourceLanguage: source,
    targetLanguage: target,
    detector: await detector,
    ocr: await ocr,
    translator: await translator,
    inpainter: await inpainter,
  );
}
