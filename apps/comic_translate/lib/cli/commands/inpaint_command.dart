import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../cli_context.dart';

/// Blocks from a JSON written by `cts detect`, `cts ocr` or `cts translate`.
List<TextBlock> loadBlocksJson(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  return [for (final b in (json['blocks'] as List).cast<Map<String, Object?>>()) TextBlock.fromJson(b)];
}

/// `cts mask`: the text-removal mask of an image.
class MaskCommand extends CtsCommand {
  MaskCommand(super.holder) {
    argParser
      ..addOption('blocks', help: 'Blocks JSON from cts detect / ocr / translate (required).')
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out');
  }

  @override
  String get name => 'mask';

  @override
  String get description => 'Build the text-removal mask; writes <name>.mask.png (white = removed).';

  @override
  String get invocation => 'cts mask <image> --blocks name.ocr.json [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Give exactly one image.');
    final blocksPath = args.option('blocks');
    if (blocksPath == null) usageException('--blocks is required.');
    final input = args.rest.single;
    final image = await ImageCodec.readFile(input);
    final blocks = selectInpaintBlocks(loadBlocksJson(blocksPath));
    final sw = Stopwatch()..start();
    final mask = generateMask(image, blocks);
    final ms = sw.elapsedMilliseconds;
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final file = File(p.join(outDir.path, '${p.basenameWithoutExtension(input)}.mask.png'))
      ..writeAsBytesSync(ImageCodec.encodeGrayPng(mask));
    final pixels = mask.data.where((v) => v != 0).length;
    ctx.services.appLog.child(stage: 'mask').info('mask_done', {'blocks': blocks.length, 'pixels': pixels, 'ms': ms});
    ctx.say('${p.basename(input)}: ${blocks.length} block(s), $pixels masked px, $ms ms → ${file.path}');
    if (ctx.json) ctx.printJson({'ok': true, 'mask': file.path, 'blocks': blocks.length, 'pixels': pixels, 'ms': ms});
    return ExitCodes.ok;
  }
}

/// `cts inpaint`: removes the text of an image.
class InpaintCommand extends CtsCommand {
  InpaintCommand(super.holder) {
    argParser
      ..addOption('blocks', help: 'Blocks JSON from cts detect / ocr / translate. Without it (and --mask) text is detected first.')
      ..addOption('mask', help: 'Use this mask PNG instead of building one (no fast bubble fill).')
      ..addOption('inpainter', help: 'Inpainter plugin id: aot (default from settings) or lama.')
      ..addOption('strategy', allowed: ['resize', 'crop', 'original'], help: 'High-resolution strategy (default from settings: resize).')
      ..addFlag('gpu', help: 'Use the GPU (DirectML). Default from settings.', defaultsTo: null)
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addFlag('debug', negatable: false, help: 'Test mode: save the mask and intermediate images in a run folder.');
  }

  @override
  String get name => 'inpaint';

  @override
  String get description =>
      'Remove text: fast fill of uniform bubbles, then the inpainting network; writes <name>.clean.png.';

  @override
  String get invocation => 'cts inpaint <image>... [--blocks f.json | --mask m.png] [--inpainter aot|lama] [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image.');
    if ((args.option('blocks') != null || args.option('mask') != null) && args.rest.length != 1) {
      usageException('--blocks and --mask work with exactly one image.');
    }
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final useGpu = args.wasParsed('gpu') ? args.flag('gpu') : null;
    final strategy = args.option('strategy');
    final config = strategy == null
        ? settings.inpaint
        : InpaintConfig(
            strategy: HdStrategy.values.byName(strategy),
            resizeLimit: settings.inpaint.resizeLimit,
            cropMargin: settings.inpaint.cropMargin,
            cropTriggerSize: settings.inpaint.cropTriggerSize,
          );

    RunRecorder? recorder;
    if (args.flag('debug')) {
      recorder = await RunRecorder.start(
        runsDir: services.paths.runs,
        redactor: services.redactor,
        environment: services.environment(),
        label: 'inpaint',
      );
      ctx.say('Run folder: ${recorder.dir.path}');
    }
    final log = recorder?.log ?? services.appLog.child(stage: 'inpaint');

    final Inpainter inpainter;
    TextDetector? detector;
    try {
      inpainter = await services.plugin<Inpainter>(args.option('inpainter') ?? settings.inpainter, settings,
          useGpu: useGpu, log: log);
      if (args.option('blocks') == null && args.option('mask') == null) {
        detector = await services.plugin<TextDetector>(settings.detector, settings, useGpu: useGpu, log: log);
      }
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
      try {
        final image = await ImageCodec.readFile(input);
        final sw = Stopwatch()..start();
        List<TextBlock>? blocks;
        GrayImage mask;
        final maskPath = args.option('mask');
        if (maskPath != null) {
          mask = ImageCodec.decodeGray(File(maskPath).readAsBytesSync());
          if (mask.width != image.width || mask.height != image.height) {
            throw ArgumentError('mask is ${mask.width}x${mask.height}, image is ${image.width}x${image.height}');
          }
        } else {
          final all = args.option('blocks') != null
              ? loadBlocksJson(args.option('blocks')!)
              : await detector!.detect(image, context);
          blocks = selectInpaintBlocks(all);
          mask = generateMask(image, blocks);
        }
        final maskMs = sw.elapsedMilliseconds;
        await recorder?.writeArtifact('04_mask', 'mask.png', ImageCodec.encodeGrayPng(mask), page: page);

        final report = InpaintReport();
        final clean = await inpaintPage(
          image,
          mask,
          config,
          (img, m) => inpainter.inpaint(img, m, config, context),
          blocks: blocks,
          report: report,
        );
        final totalMs = sw.elapsedMilliseconds;
        recorder?.recordTiming('05_inpaint', Duration(milliseconds: totalMs - maskMs), page: page);
        final png = ImageCodec.encodePng(clean);
        await recorder?.writeArtifact('05_inpaint', 'clean.png', png, page: page);
        final file = File(p.join(outDir.path, '${p.basenameWithoutExtension(input)}.clean.png'))..writeAsBytesSync(png);
        pageLog.log(LogLevel.info, 'inpaint_done', durMs: totalMs, data: {
          'mode': report.mode,
          'patches': report.patches,
          'fast_filled': report.fastFilledBlocks,
          'notes': report.notes,
        });
        results.add({
          'image': input,
          'clean': file.path,
          'mode': report.mode,
          'patches': report.patches,
          'fast_filled_blocks': report.fastFilledBlocks,
          'mask_ms': maskMs,
          'inpaint_ms': totalMs - maskMs,
        });
        ctx.say('$page: ${report.fastFilledBlocks} bubble(s) flat-filled, network: ${report.mode}'
            '${report.patches > 0 ? ' (${report.patches} patches)' : ''}, ${totalMs - maskMs} ms → ${file.path}');
      } catch (e, st) {
        ok = false;
        pageLog.error('inpaint_failed', e, st);
        results.add({'image': input, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
      }
    }
    await recorder?.finish(success: ok, summary: {'pages': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
