import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../pipeline/word_list.dart';
import '../cli.dart';
import '../cli_context.dart';

class OcrCommand extends CtsCommand {
  OcrCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addOption(
        'blocks',
        help: 'Use blocks from a <name>.blocks.json of `cts detect` instead of detecting (one image only).',
      )
      ..addOption(
        'lang',
        help: 'Source language, e.g. English, Japanese, or Auto to find it per block (default from settings).',
      )
      ..addOption('ocr', help: 'OCR plugin id (default from settings: ppocr).')
      ..addOption('detector', help: 'Detector plugin id (default from settings).')
      ..addFlag('gpu', help: 'Use the GPU (DirectML). Default from settings.', defaultsTo: null)
      ..addOption(
        'prep',
        help:
            'How small text is prepared for reading: text_prep_off, plain_x1_5, plain_x2, waifu2x_cunet, '
            'waifu2x_swin, fatality_comix (default from settings).',
      )
      ..addOption(
        'prep-seconds',
        help: 'Time a neural network may spend preparing small text on one page, 0 for no limit (default from settings: 60).',
      )
      ..addFlag(
        'upscale',
        help: '--no-upscale: read small text as it is (same as --prep text_prep_off).',
        defaultsTo: null,
      )
      ..addFlag(
        'check-lines',
        help:
            'Check the heuristic lines of comic blocks and let the PP-OCR line detector redo the wrong ones '
            '(default from settings: on for comics).',
        defaultsTo: null,
      )
      ..addFlag(
        'split-words',
        help: 'Split English words glued together by the OCR (default from settings: off).',
        defaultsTo: null,
      )
      ..addFlag('debug', negatable: false, help: 'Test mode: save a run folder with artifacts and timings.');
  }

  @override
  String get name => 'ocr';

  @override
  String get description =>
      'Recognize the text of each block; writes <name>.ocr.json and prints the text in reading order.';

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
    final prepId = args.wasParsed('upscale') && !args.flag('upscale')
        ? textPrepOffId
        : args.option('prep') ?? settings.activeTextPrep;
    if (!services.registry.contains(prepId) || services.registry.info(prepId).kind != PluginKind.textPrep) {
      usageException('Unknown text preparation "$prepId".');
    }
    final prepSeconds = int.tryParse(args.option('prep-seconds') ?? '${settings.textPrepSeconds}');
    if (prepSeconds == null || prepSeconds < 0) {
      usageException('--prep-seconds takes a number of seconds (0: no limit).');
    }
    final TextUpscaler textPrep;
    LineDetector? lineChecker;
    try {
      ocr = await services.plugin<OcrEngine>(args.option('ocr') ?? settings.ocr, settings, useGpu: useGpu, log: log);
      textPrep = await services.textPrep(settings, id: prepId, useGpu: useGpu, log: log);
      if (textPrep.info.id != prepId) {
        ctx.err.writeln('"$prepId" is not downloaded: plain ×2 instead (cts models download).');
      }
      if (args.wasParsed('check-lines') ? args.flag('check-lines') : settings.checksLines) {
        lineChecker = await services.plugin<LineDetector>(lineCheckerId, settings, useGpu: useGpu, log: log);
      }
      if (blocksPath == null) {
        detector = await services.plugin<TextDetector>(
          args.option('detector') ?? settings.activeDetector,
          settings,
          useGpu: useGpu,
          log: log,
        );
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
        final fixedBefore = blocks.where((b) => b.fixedLines).length;
        final reading = await readBlocks(
          ocr,
          image,
          blocks,
          sourceLanguage: language,
          context: context,
          upscaler: textPrep,
          lineChecker: lineChecker,
          neuralBudgetMs: prepSeconds * 1000,
        );
        final linesRedone = blocks.where((b) => b.fixedLines).length - fixedBefore;
        if (settings.fixCyrillicLookalikes) {
          final code = Languages.byName(language)?.code ?? '';
          for (final b in blocks) {
            fixOcrScript([b], code.isEmpty ? b.sourceLang : code);
          }
        }
        if (args.wasParsed('split-words') ? args.flag('split-words') : settings.splitGluedWords) {
          final split = (await loadGluedWords())?.splitBlocks(blocks, sourceLanguage: language) ?? 0;
          if (split > 0) pageLog.info('glued_words_split', {'words': split});
        }
        final ocrMs = sw.elapsedMilliseconds - detectMs;
        recorder?.recordTiming('02_ocr', Duration(milliseconds: ocrMs), page: page);

        final detected = resolveAutoSourceLanguage(blocks, language);
        final order = sortBlocks(blocks, rightToLeft: detected == 'Japanese');
        final out = {
          'image': page,
          'width': image.width,
          'height': image.height,
          'source_language': language,
          if (language == Languages.auto) 'detected_language': detected,
          'ocr': ocr.info.id,
          'text_prep': textPrep.info.id,
          'reading_factor': reading.factor,
          'enlarged_pieces': reading.pieces,
          'plain_pieces': reading.plainPieces,
          'lines_redone': linesRedone,
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
        final scaleNote = reading.scaled
            ? ' (small text: ${reading.pieces} piece(s) at ×${reading.factor} with ${textPrep.info.id}'
                  '${reading.plainPieces > 0 ? ', ${reading.plainPieces} plainly to save time' : ''})'
            : '';
        final langNote = language == Languages.auto ? ', language: $detected' : '';
        final linesNote = linesRedone > 0 ? ', lines redone in $linesRedone block(s)' : '';
        ctx.say('$page: ${blocks.length} block(s), OCR $ocrMs ms$scaleNote$linesNote$langNote → ${jsonFile.path}');
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
