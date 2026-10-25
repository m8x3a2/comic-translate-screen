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
import 'word_list.dart';

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

/// A bubble styled by hand that does not fit is the user's choice: it does
/// not enlarge the page, which would resize every other bubble. Lines along
/// the bubble's oval may be wider than the text box: they are measured
/// against the bubble.
bool _overflows(TextItem i, RenderSettings base) {
  if (i.block.style != null) return false;
  final bubble = i.block.bubbleXyxy;
  final box = (i.settings ?? base).shapeFit && bubble != null ? bubble : i.block.xyxy;
  return i.width > box.width + 0.5 || i.height > box.height + 0.5;
}

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
/// smallest font size), or by [scale] when given. [blocks] are not changed.
///
/// Blocks of a webtoon page may reach below its bottom (a bubble cut by the
/// edge between two pages); their text is laid out in full there.
RenderLayout layoutRender(
  int width,
  int height,
  List<TextBlock> blocks,
  AppSettings settings,
  TextEngines engines, {
  required String targetLanguage,
  LayoutCache? cache,
  double? scale,
}) {
  final w0 = width, h0 = height;
  final reach = h0 + overflowOf(blocks, h0);
  (int, int) sizeAt(double f) => (((w0 * f).round()), ((h0 * f).round()));
  // Bold blocks are told from the whole page, also when laid out one by one.
  final lettering = PageLettering.of(blocks);
  List<TextItem> layoutBlocks(List<TextBlock> copies, int w, int h, int areaHeight) => layoutPage(
    copies,
    w,
    h,
    engines.main,
    settings: settings.render,
    targetLanguage: targetLanguage,
    measurerFor: engines.of,
    areaHeight: areaHeight,
    lettering: lettering,
  );
  List<TextItem> layoutAt(double f) {
    final (w, h) = sizeAt(f);
    final area = (reach * f).round();
    final copies = f == 1.0 ? [for (final b in blocks) b.copy()] : scaleBlocks(blocks, w0, h0, w, h);
    if (cache == null || copies.isEmpty) return layoutBlocks(copies, w, h, area);
    // Block by block: the page's first block decides the render areas.
    final first = copies.first.sourceLang;
    final prefix = '$w|$h|$area|$first|$targetLanguage|$lettering|${jsonEncode(settings.render.toJson())}|';
    return [
      for (final c in copies)
        ?cache._lookup('$prefix${jsonEncode(c.toJson())}', () {
          final one = layoutBlocks([c..sourceLang = first], w, h, area);
          return one.isEmpty ? null : one.single;
        }),
    ];
  }

  final upscale = settings.upscale;
  final fixed = scale != null;
  var f =
      scale ??
      (upscale.mode == UpscaleMode.auto ? autoUpscaleFactor(blocks, w0, h0) : fixedUpscaleFactor(upscale, w0, h0));
  var items = layoutAt(f);
  if (!fixed && upscale.mode == UpscaleMode.auto && items.isNotEmpty) {
    final limit = (items.length * _overflowShare).ceil();
    for (final more in const [1.5, 2.0]) {
      if (items.where((i) => _overflows(i, settings.render)).length < limit) break;
      final next = limitUpscaleFactor(f * more, w0, h0);
      if (next <= f) break;
      f = next;
      items = layoutAt(f);
    }
  }
  final index = [
    for (final (i, b) in blocks.indexed)
      if (hasTranslatableContent(b.translation)) i,
  ];
  return RenderLayout(f, items, index.length == items.length ? index : const []);
}

/// The page above a webtoon page, for drawing what of it reaches into this
/// page: the translation of its blocks cut by the edge, over its cleaned
/// patch.
class PageAbove {
  const PageAbove({
    required this.width,
    required this.height,
    required this.blocks,
    required this.targetLanguage,
    this.patch,
  });

  final int width;
  final int height;
  final List<TextBlock> blocks;
  final String targetLanguage;
  final SeamPatch? patch;

  /// Something of the page above shows on this page.
  bool get reaches => patch != null || overflowOf(blocks, height) > 0;
}

/// The blocks of [above] that reach below it, laid out at [scale] and moved
/// into the page below ([lowerWidth] wide); with their text engines.
Future<(List<TextItem>, TextEngines)?> itemsFromAbove(
  PageAbove above,
  int lowerWidth,
  AppSettings settings,
  double scale, {
  TextEngines? engines,
}) async {
  if (overflowOf(above.blocks, above.height) <= 0) return null;
  final e = engines ?? await loadTextEngines(settings, above.targetLanguage, above.blocks);
  final layout = layoutRender(
    above.width,
    above.height,
    above.blocks,
    settings,
    e,
    targetLanguage: above.targetLanguage,
    scale: scale,
  );
  final dx = -seamDx(above.width, lowerWidth) * scale, dy = -above.height * scale;
  final items = [
    for (final i in layout.items)
      if (i.y + i.height > above.height * scale) i.shifted(dx, dy),
  ];
  return items.isEmpty ? null : (items, e);
}

/// Lays out and draws the translations of [blocks] over [clean] (see
/// [layoutRender]). Unlike the original, [blocks] keep their detected boxes
/// and the translations as written, so the page can be edited and drawn
/// again. On a webtoon page, what reaches into it from the page [above] is
/// drawn too.
Future<RenderedPage> renderPage(
  RgbImage clean,
  List<TextBlock> blocks,
  AppSettings settings, {
  required String targetLanguage,
  PageAbove? above,
}) async {
  final patch = above?.patch;
  final base = patch == null ? clean : applyPatch(clean, patch, above!.width);
  final engines = await loadTextEngines(settings, targetLanguage, blocks);
  final layout = layoutRender(base.width, base.height, blocks, settings, engines, targetLanguage: targetLanguage);
  final scale = layout.scale;
  final page = scale == 1.0 ? base : upscaleImage(base, scale, method: settings.upscale.method);
  var image = await renderTextOnPage(page, layout.items, engines);
  if (above != null) {
    final upper = await itemsFromAbove(above, base.width, settings, scale);
    if (upper != null) image = await renderTextOnPage(image, upper.$1, upper.$2);
  }
  return RenderedPage(image, layout.items, scale);
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
    this.overflow,
  });

  final List<TextBlock> blocks;
  final GrayImage mask;
  final RgbImage clean;
  final InpaintReport inpaintReport;

  /// Webtoon pages: the cleaned part of the next page that blocks reach into.
  final SeamPatch? overflow;

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
      ..remove('exchange')
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
        for (final id in {settings.activeDetector, settings.ocr, translator, settings.inpainter})
          id: await services.pluginConfig(id, settings),
        // An unknown text preparation (a newer settings file) gives way to plain ×2.
        if (services.registry.contains(settings.activeTextPrep))
          settings.activeTextPrep: await services.pluginConfig(settings.activeTextPrep, settings),
        if (settings.checksLines && services.registry.contains(lineCheckerId))
          lineCheckerId: await services.pluginConfig(lineCheckerId, settings),
        if (services.registry.contains(settings.textMask))
          settings.textMask: await services.pluginConfig(settings.textMask, settings),
        for (final id in settings.activeReadLevel.readers)
          if (services.registry.contains(id)) id: await services.pluginConfig(id, settings),
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
    this.textPrep,
    this.lineChecker,
    this.textMasker,
  });

  final AppSettings settings;
  final String sourceLanguage;
  final String targetLanguage;
  final TextDetector detector;
  final OcrEngine ocr;
  final Translator translator;
  final Inpainter inpainter;

  /// Prepares small text for reading; null: it is read as it is.
  final TextUpscaler? textPrep;

  /// Checks the lines of comic blocks before reading; null: not checked.
  final LineDetector? lineChecker;

  /// Finds the letters for the inpainting network; null: the original's
  /// mask alone (cleaning level "Simple", or its model is missing).
  final TextMasker? textMasker;

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
      detector: await make<TextDetector>(s.activeDetector),
      ocr: await withReadLevel(
        registry,
        s.activeReadLevel,
        await make<OcrEngine>(s.ocr),
        await loadEnglishWords(),
        env,
        configs: spec.configs,
      ),
      translator: await make<Translator>(spec.translatorId),
      inpainter: await make<Inpainter>(s.inpainter),
      textPrep: await loadTextPrep(registry, s.activeTextPrep, spec.configs[s.activeTextPrep], env),
      lineChecker: await loadLineChecker(registry, s, spec.configs[lineCheckerId], env),
      textMasker: await loadTextMasker(registry, s, spec.configs[s.textMask], env),
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
    textPrep: textPrep,
    lineChecker: lineChecker,
    textMasker: textMasker,
  );

  /// Detection, OCR, translation and cleaning of [image]. [onStage] is called
  /// as each stage starts. Stage artifacts go to the context's recorder (test
  /// mode).
  ///
  /// Webtoon pages: [next] is the page below, so that a bubble cut by the
  /// edge between them is found, read and cleaned whole (see `seams.dart`);
  /// [covered] are the parts of this page that blocks of the page above
  /// reach into (not detected again here).
  ///
  /// [blocks]: found already (the exchange with a chat), so not detected
  /// again; with [read] false their text is kept as it is too.
  Future<CleanPage> prepare(
    RgbImage image,
    PluginContext context, {
    void Function(String stage)? onStage,
    RgbImage? next,
    List<BBox> covered = const [],
    List<TextBlock>? blocks,
    bool read = true,
  }) async {
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
    var found = blocks ?? await detectOnStrip(detector, image, context, next: next, covered: covered);
    lap('01_detect');
    await recorder?.writeJsonArtifact('01_detect', 'blocks.json', [for (final b in found) b.toJson()], page: page);

    // The page with the rows of the next one that its blocks reach into.
    final rows = next == null ? 0 : seamRows(found, image.height, next.height);
    final work = rows > 0 ? extendBelow(image, next!, rows) : image;

    if (read) {
      start('02_ocr');
      await recognizeBlocks(
        ocr,
        work,
        found,
        settings,
        context,
        sourceLanguage: sourceLanguage,
        textPrep: textPrep,
        lineChecker: lineChecker,
      );
      // "Auto": read right to left when the page turned out to be Japanese.
      found = sortBlocks(found, rightToLeft: resolveAutoSourceLanguage(found, sourceLanguage) == 'Japanese');
      lap('02_ocr');
      await recorder?.writeJsonArtifact('02_ocr', 'blocks.json', [for (final b in found) b.toJson()], page: page);
    }
    blocks = found;

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
    final letters = await textMasker?.letters(work, context);
    final mask = generateMask(work, inpaintBlocks, letters: letters);
    lap('04_mask');
    await recorder?.writeArtifact('04_mask', 'mask.png', ImageCodec.encodeGrayPng(mask), page: page);

    start('05_inpaint');
    final report = InpaintReport();
    final cleaned = await inpaintPage(
      work,
      mask,
      settings.inpaint,
      (img, m) => inpainter.inpaint(img, m, settings.inpaint, context),
      blocks: inpaintBlocks,
      report: report,
    );
    final (clean, overflow) = splitBelow(cleaned, mask, image.height);
    lap('05_inpaint');
    await recorder?.writeArtifact('05_inpaint', 'clean.png', ImageCodec.encodePng(clean), page: page);
    return CleanPage(
      blocks: blocks,
      mask: mask,
      clean: clean,
      inpaintReport: report,
      timingsMs: timings,
      overflow: overflow,
    );
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

/// Detection on a webtoon page: with the top of the [next] page below it, so
/// that a bubble cut by the edge is found whole; blocks starting on the next
/// page are left to it, and those in [covered] (reached into by blocks of
/// the page above) are dropped. Without [next] and [covered]: plain
/// detection.
Future<List<TextBlock>> detectOnStrip(
  TextDetector detector,
  RgbImage image,
  PluginContext context, {
  RgbImage? next,
  List<BBox> covered = const [],
}) async {
  final strip = next == null ? image : extendBelow(image, next, detectionReach(image.width, next.height));
  var found = await detector.detect(strip, context);
  if (next != null) found = ownBlocks(found, image.height);
  return covered.isEmpty ? found : withoutCovered(found, covered);
}

/// OCR of [blocks] on [image]; small text is enlarged first by [textPrep]
/// (read as it is without one), the lines of comic blocks are checked first
/// by [lineChecker].
Future<void> recognizeBlocks(
  OcrEngine ocr,
  RgbImage image,
  List<TextBlock> blocks,
  AppSettings settings,
  PluginContext context, {
  required String sourceLanguage,
  TextUpscaler? textPrep,
  LineDetector? lineChecker,
}) async {
  final code = Languages.byName(sourceLanguage)?.code ?? '';
  await readBlocks(
    ocr,
    image,
    blocks,
    sourceLanguage: sourceLanguage,
    context: context,
    upscaler: textPrep,
    lineChecker: lineChecker,
    neuralBudgetMs: settings.textPrepSeconds * 1000,
  );
  if (settings.fixCyrillicLookalikes) {
    // "Auto": each block has the language of its script.
    for (final b in blocks) {
      fixOcrScript([b], code.isEmpty ? b.sourceLang : code);
    }
  }
  if (settings.splitGluedWords) (await loadGluedWords())?.splitBlocks(blocks, sourceLanguage: sourceLanguage);
}

/// Told to the translator when some of the text was read from very small
/// letters (see [isSmallText]).
const smallTextTranslatorNote =
    'Some of the source text was recognized from very small letters: words may be glued together and letters '
    'misread. Translate what was most likely meant.';

/// Translation of [blocks] (the page image goes along when the setting
/// allows it). Blocks of very small text add [smallTextTranslatorNote] to
/// the context.
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
    extraContext: blocks.any(isSmallText)
        ? [settings.extraContext, smallTextTranslatorNote].where((s) => s.trim().isNotEmpty).join('\n')
        : settings.extraContext,
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

  Future<TextDetector> get detector => _make(spec.settings.activeDetector);
  Future<OcrEngine> get ocr async => withReadLevel(
    registry,
    spec.settings.activeReadLevel,
    await _make<OcrEngine>(spec.settings.ocr),
    await loadEnglishWords(),
    PluginEnvironment(models: models, log: log, useGpu: spec.useGpu),
    configs: spec.configs,
  );
  Future<Translator> get translator => _make(spec.translatorId);
  Future<Inpainter> get inpainter => _make(spec.settings.inpainter);
  Future<TextUpscaler> get textPrep => loadTextPrep(
    registry,
    spec.settings.activeTextPrep,
    spec.configs[spec.settings.activeTextPrep],
    PluginEnvironment(models: models, log: log, useGpu: spec.useGpu),
  );
  Future<LineDetector?> get lineChecker => loadLineChecker(
    registry,
    spec.settings,
    spec.configs[lineCheckerId],
    PluginEnvironment(models: models, log: log, useGpu: spec.useGpu),
  );
  Future<TextMasker?> get textMasker => loadTextMasker(
    registry,
    spec.settings,
    spec.configs[spec.settings.textMask],
    PluginEnvironment(models: models, log: log, useGpu: spec.useGpu),
  );

  /// Every plugin, for whole-page runs.
  Future<PagePipeline> pipeline(String source, String target) async => PagePipeline(
    settings: spec.settings,
    sourceLanguage: source,
    targetLanguage: target,
    detector: await detector,
    ocr: await ocr,
    translator: await translator,
    inpainter: await inpainter,
    textPrep: await textPrep,
    lineChecker: await lineChecker,
    textMasker: await textMasker,
  );
}
