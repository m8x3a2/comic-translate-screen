import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../cli_context.dart';

class OcrCommand extends CtsCommand {
  OcrCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addOption('blocks', help: 'Use blocks from a <name>.blocks.json of `cts detect` instead of detecting (one image only).')
      ..addOption('lang', help: 'Source language, e.g. English, Japanese (default from settings).')
      ..addOption('ocr', help: 'OCR plugin id (default from settings: ppocr).')
      ..addOption('detector', help: 'Detector plugin id (default from settings).')
      ..addFlag('gpu', help: 'Use the GPU (DirectML). Default from settings.', defaultsTo: null)
      ..addFlag('upscale',
          help: 'Enlarge pages with small text before reading (default from settings: on).', defaultsTo: null)
      ..addFlag('debug', negatable: false, help: 'Test mode: save a run folder with artifacts and timings.');
  }

  @override
  String get name => 'ocr';

  @override
  String get description => 'Recognize the text of each block; writes <name>.ocr.json and prints the text in reading order.';

  @override
  String get invocation => 'cts ocr <image>... [--lang English] [--blocks f.blocks.json] [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image.');
    final blocksPath = args.option('blocks');
    if (blocksPath != null && args.rest.length != 1) usageException('--blocks works with exactly one image.');
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final language = args.option('lang') ?? settings.sourceLanguage;
    if (language != 'Auto' && Languages.byName(language) == null) usageException('Unknown language "$language".');
    final useGpu = args.wasParsed('gpu') ? args.flag('gpu') : null;
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);

    RunRecorder? recorder;
    if (args.flag('debug')) {
      recorder = await RunRecorder.start(
        runsDir: services.paths.runs,
        redactor: services.redactor,
        environment: services.environment(),
        label: 'ocr',
      );
      ctx.say('Run folder: ${recorder.dir.path}');
    }
    final log = recorder?.log ?? services.appLog.child(stage: 'ocr');

    final OcrEngine ocr;
    TextDetector? detector;
    try {
      ocr = await services.plugin<OcrEngine>(args.option('ocr') ?? settings.ocr, settings, useGpu: useGpu, log: log);
      if (blocksPath == null) {
        detector = await services.plugin<TextDetector>(args.option('detector') ?? settings.detector, settings,
            useGpu: useGpu, log: log);
      }
    } on ModelNotInstalledException catch (e) {
      ctx.err.writeln(e);
      await recorder?.finish(success: false, summary: {'error': e.toString()});
      return ExitCodes.failure;
    }

    final results = <Map<String, Object?>>[];
    var ok = true;
    for (final input in args.rest) {
      final page = p.basename(input);
      final pageLog = log.child(page: page);
      final context = PluginContext(log: pageLog, recorder: recorder, page: page);
      try {
        final sw = Stopwatch()..start();
        final image = await ImageCodec.readFile(input);
        final List<TextBlock> blocks;
        if (blocksPath != null) {
          final json = jsonDecode(File(blocksPath).readAsStringSync()) as Map<String, Object?>;
          blocks = [for (final b in (json['blocks'] as List).cast<Map<String, Object?>>()) TextBlock.fromJson(b)];
        } else {
          blocks = await detector!.detect(image, context);
        }
        final detectMs = sw.elapsedMilliseconds;
        final reading = prepareReading(
          image,
          blocks,
          sourceLanguageCode: Languages.byName(language)?.code ?? '',
          enabled: args.wasParsed('upscale') ? args.flag('upscale') : settings.upscaleSmallText,
        );
        try {
          await ocr.recognize(reading.image, blocks, sourceLanguage: language, context: context);
        } finally {
          reading.restore();
        }
        if (settings.fixCyrillicLookalikes) fixOcrScript(blocks, Languages.byName(language)?.code ?? '');
        final ocrMs = sw.elapsedMilliseconds - detectMs;
        if (reading.scaled) pageLog.info('reading_upscaled', {'factor': reading.scaleX});
        recorder?.recordTiming('02_ocr', Duration(milliseconds: ocrMs), page: page);

        final order = sortBlocks(blocks, rightToLeft: language == 'Japanese');
        final out = {
          'image': page,
          'width': image.width,
          'height': image.height,
          'source_language': language,
          'ocr': ocr.info.id,
          'reading_scale': reading.scaleX,
          'blocks': [for (final b in blocks) b.toJson()],
          'reading_order': [for (final b in order) blocks.indexOf(b)],
        };
        final stem = p.basenameWithoutExtension(input);
        final jsonFile = File(p.join(outDir.path, '$stem.ocr.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
        await recorder?.writeJsonArtifact('02_ocr', 'blocks.json', out, page: page);
        pageLog.log(LogLevel.info, 'ocr_done', durMs: ocrMs, data: {'blocks': blocks.length});

        results.add({
          'image': input,
          'blocks': blocks.length,
          'ocr_ms': ocrMs,
          'json': jsonFile.path,
          'texts': [for (final b in order) b.text],
        });
        final scaleNote = reading.scaled ? ' (small text, read at ×${reading.scaleX.toStringAsFixed(1)})' : '';
        ctx.say('$page: ${blocks.length} block(s), OCR $ocrMs ms$scaleNote → ${jsonFile.path}');
        for (final b in order) {
          ctx.say('  ${b.text}');
        }
      } catch (e, st) {
        ok = false;
        pageLog.error('ocr_failed', e, st);
        results.add({'image': input, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
      }
    }
    await recorder?.finish(success: ok, summary: {'pages': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
