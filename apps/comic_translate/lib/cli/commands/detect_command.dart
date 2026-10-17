import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../cli_context.dart';

class DetectCommand extends CtsCommand {
  DetectCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addOption('detector', help: 'Detector plugin id.', defaultsTo: 'rtdetr_v2')
      ..addOption('confidence', help: 'Confidence threshold (default from settings: 0.3).')
      ..addFlag('gpu', help: 'Use the GPU (DirectML). Default from settings.', defaultsTo: null)
      ..addFlag('debug', negatable: false, help: 'Test mode: save a run folder with artifacts and timings.');
  }

  @override
  String get name => 'detect';

  @override
  String get description =>
      'Detect text blocks and speech bubbles; writes <name>.blocks.json and <name>.overlay.png.';

  @override
  String get invocation => 'cts detect <image>... [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image.');
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final confidence = args.option('confidence');

    RunRecorder? recorder;
    if (args.flag('debug')) {
      recorder = await RunRecorder.start(
        runsDir: services.paths.runs,
        redactor: services.redactor,
        environment: services.environment(),
        label: 'detect',
      );
      ctx.say('Run folder: ${recorder.dir.path}');
    }
    final log = recorder?.log ?? services.appLog.child(stage: 'detect');

    final TextDetector detector;
    try {
      detector = await services.plugin<TextDetector>(
        args.option('detector')!,
        settings,
        overrides: {if (confidence != null) 'confidence': double.parse(confidence)},
        useGpu: args.wasParsed('gpu') ? args.flag('gpu') : null,
        log: log,
      );
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
      try {
        final sw = Stopwatch()..start();
        final image = await ImageCodec.readFile(input);
        final decodeMs = sw.elapsedMilliseconds;
        final blocks = await detector.detect(image, PluginContext(log: pageLog, recorder: recorder, page: page));
        final detectMs = sw.elapsedMilliseconds - decodeMs;
        final order = sortBlocks(blocks);
        recorder?.recordTiming('01_detect', Duration(milliseconds: detectMs), page: page);

        final blocksJson = {
          'image': p.basename(input),
          'width': image.width,
          'height': image.height,
          'blocks': [for (final b in blocks) b.toJson()],
          'reading_order': [for (final b in order) blocks.indexOf(b)],
        };
        final overlayPng = ImageCodec.encodePng(drawDetectionOverlay(image, blocks));
        final stem = p.basenameWithoutExtension(input);
        final jsonFile = File(p.join(outDir.path, '$stem.blocks.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(blocksJson));
        final overlayFile = File(p.join(outDir.path, '$stem.overlay.png'))..writeAsBytesSync(overlayPng);
        await recorder?.writeJsonArtifact('01_detect', 'blocks.json', blocksJson, page: page);
        await recorder?.writeArtifact('01_detect', 'overlay.png', overlayPng, page: page);
        pageLog.log(LogLevel.info, 'detect_done', durMs: detectMs, data: {
          'blocks': blocks.length,
          'bubbles': blocks.where((b) => b.textClass == TextClass.bubble).length,
        });

        results.add({
          'image': input,
          'blocks': blocks.length,
          'in_bubbles': blocks.where((b) => b.textClass == TextClass.bubble).length,
          'decode_ms': decodeMs,
          'detect_ms': detectMs,
          'json': jsonFile.path,
          'overlay': overlayFile.path,
        });
        ctx.say('$page: ${blocks.length} block(s), $detectMs ms → ${overlayFile.path}');
      } catch (e, st) {
        ok = false;
        pageLog.error('detect_failed', e, st);
        results.add({'image': input, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
      }
    }
    await recorder?.finish(success: ok, summary: {'pages': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
