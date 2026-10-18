import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../render/text_renderer.dart';
import '../cli.dart';
import '../cli_context.dart';
import 'inpaint_command.dart' show loadBlocksJson;
import 'translate_command.dart' show checkTranslatorNetwork;

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

/// `cts render`: draws translations onto a (cleaned) page.
class RenderCommand extends CtsCommand {
  RenderCommand(super.holder) {
    argParser
      ..addOption('blocks', help: 'Blocks with translations: <name>.translated.json from cts translate (required).')
      ..addOption('to', help: 'Target language (default: from the blocks file, else settings).')
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out');
  }

  @override
  String get name => 'render';

  @override
  String get description => 'Draw the translations onto a page (use the cleaned page from cts inpaint); writes '
      '<name>.rendered.png and <name>.layout.json.';

  @override
  String get invocation => 'cts render <page.png> --blocks name.translated.json [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Give exactly one image.');
    final blocksPath = args.option('blocks');
    if (blocksPath == null) usageException('--blocks is required.');
    final settings = await ctx.services.settingsStore.load();
    final json = jsonDecode(File(blocksPath).readAsStringSync()) as Map<String, Object?>;
    final target = args.option('to') ?? (json['target_language'] as String?) ?? settings.targetLanguage;
    final input = args.rest.single;
    final page = await ImageCodec.readFile(input);
    final blocks = loadBlocksJson(blocksPath);
    final sw = Stopwatch()..start();
    final (rendered, items) = await renderPage(page, blocks, settings, targetLanguage: target);
    final ms = sw.elapsedMilliseconds;
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final stem = p.basenameWithoutExtension(input).replaceAll(RegExp(r'\.clean$'), '');
    final png = File(p.join(outDir.path, '$stem.rendered.png'))..writeAsBytesSync(ImageCodec.encodePng(rendered));
    final layout = File(p.join(outDir.path, '$stem.layout.json'))
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'items': [for (final i in items) i.toJson()]}));
    ctx.say('${p.basename(input)}: ${items.length} text item(s), $ms ms → ${png.path}');
    if (ctx.json) ctx.printJson({'ok': true, 'image': png.path, 'layout': layout.path, 'items': items.length, 'ms': ms});
    return ExitCodes.ok;
  }
}

/// `cts process`: the whole pipeline, page by page.
class ProcessCommand extends CtsCommand {
  ProcessCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addOption('from', help: 'Source language (default from settings).')
      ..addOption('to', help: 'Target language (default from settings).')
      ..addOption('translator', help: 'Translator plugin id (default from settings).')
      ..addFlag('allow-network', negatable: false, help: 'Allow this run to send the text to the configured translator.')
      ..addFlag('remember', negatable: false, help: 'With --allow-network: remember the approval for this server.')
      ..addFlag('gpu', help: 'Use the GPU (DirectML). Default from settings.', defaultsTo: null)
      ..addFlag('debug', negatable: false, help: 'Test mode: save every stage (blocks, masks, images, timings).');
  }

  @override
  String get name => 'process';

  @override
  String get description => 'Translate pages end to end: detect, OCR, translate, remove text, draw the translation. '
      'Writes <name>.translated.png and <name>.json.';

  @override
  String get invocation => 'cts process <image>... [--to Russian] [--translator mock] [--allow-network] [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image.');
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final source = args.option('from') ?? settings.sourceLanguage;
    final target = args.option('to') ?? settings.targetLanguage;
    if (Languages.byName(target) == null) usageException('Unknown target language "$target".');
    if (source != 'Auto' && Languages.byName(source) == null) usageException('Unknown source language "$source".');
    final translatorId = args.option('translator') ?? settings.translator;
    final useGpu = args.wasParsed('gpu') ? args.flag('gpu') : null;
    if (!await checkTranslatorNetwork(ctx, translatorId, settings,
        allowNetwork: args.flag('allow-network'), remember: args.flag('remember'), usageException: usageException)) {
      return ExitCodes.failure;
    }

    RunRecorder? recorder;
    if (args.flag('debug') || settings.testMode) {
      recorder = await RunRecorder.start(
        runsDir: services.paths.runs,
        redactor: services.redactor,
        environment: services.environment(),
        label: 'process',
      );
      ctx.say('Run folder: ${recorder.dir.path}');
    }
    final log = recorder?.log ?? services.appLog.child(stage: 'process');

    final TextDetector detector;
    final OcrEngine ocr;
    final Translator translator;
    final Inpainter inpainter;
    try {
      detector = await services.plugin<TextDetector>(settings.detector, settings, useGpu: useGpu, log: log);
      ocr = await services.plugin<OcrEngine>(settings.ocr, settings, useGpu: useGpu, log: log);
      translator = await services.plugin<Translator>(translatorId, settings, log: log);
      inpainter = await services.plugin<Inpainter>(settings.inpainter, settings, useGpu: useGpu, log: log);
    } on ModelNotInstalledException catch (e) {
      ctx.err.writeln(e);
      await recorder?.finish(success: false, summary: {'error': e.toString()});
      return ExitCodes.failure;
    }

    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final results = <Map<String, Object?>>[];
    var ok = true;
    for (final input in args.rest) {
      final page = p.basename(input);
      final pageLog = log.child(page: page);
      final context = PluginContext(log: pageLog, recorder: recorder, page: page);
      final timings = <String, int>{};
      final sw = Stopwatch()..start();
      void lap(String stage) {
        timings[stage] = sw.elapsedMilliseconds;
        recorder?.recordTiming(stage, Duration(milliseconds: sw.elapsedMilliseconds), page: page);
        sw.reset();
      }

      try {
        final image = await ImageCodec.readFile(input);
        lap('00_decode');

        var blocks = await detector.detect(image, context);
        lap('01_detect');
        await recorder?.writeJsonArtifact('01_detect', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

        final reading = prepareReading(image, blocks,
            sourceLanguageCode: Languages.byName(source)?.code ?? '', enabled: settings.upscaleSmallText);
        try {
          await ocr.recognize(reading.image, blocks, sourceLanguage: source, context: context);
        } finally {
          reading.restore();
        }
        if (settings.fixCyrillicLookalikes) fixOcrScript(blocks, Languages.byName(source)?.code ?? '');
        blocks = sortBlocks(blocks, rightToLeft: source == 'Japanese');
        lap('02_ocr');
        await recorder?.writeJsonArtifact('02_ocr', 'blocks.json', [for (final b in blocks) b.toJson()], page: page);

        await translateBlocks(
          translator,
          TranslationRequest(
            blocks: blocks,
            sourceLanguage: source,
            targetLanguage: target,
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

        final (rendered, items) = await renderPage(clean, blocks, settings, targetLanguage: target);
        lap('06_render');

        final stem = p.basenameWithoutExtension(input);
        final png = ImageCodec.encodePng(rendered);
        await recorder?.writeArtifact('06_render', 'final.png', png, page: page);
        await recorder?.writeJsonArtifact('06_render', 'layout.json', [for (final i in items) i.toJson()], page: page);
        final outPng = File(p.join(outDir.path, '$stem.translated.png'))..writeAsBytesSync(png);
        final outJson = File(p.join(outDir.path, '$stem.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
            'image': page,
            'source_language': source,
            'target_language': target,
            'blocks': [for (final b in blocks) b.toJson()],
            'timings_ms': timings,
          }));
        final total = timings.values.fold(0, (a, b) => a + b);
        pageLog.log(LogLevel.info, 'process_done', durMs: total, data: {'blocks': blocks.length, 'timings': timings});
        results.add({'image': input, 'output': outPng.path, 'json': outJson.path, 'blocks': blocks.length, 'timings_ms': timings});
        ctx.say('$page: ${blocks.length} block(s), ${report.fastFilledBlocks} bubble(s) flat-filled, '
            '${items.length} text item(s), $total ms → ${outPng.path}');
      } catch (e, st) {
        ok = false;
        pageLog.error('process_failed', e, st);
        results.add({'image': input, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
      }
    }
    await recorder?.finish(success: ok, summary: {'pages': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
