import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../pipeline/page_pipeline.dart';
import '../cli.dart';
import '../cli_context.dart';
import 'inpaint_command.dart' show loadBlocksJson;
import 'translate_command.dart' show checkTranslatorNetwork;

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
    final render = await renderPage(page, blocks, settings, targetLanguage: target);
    final items = render.items;
    final ms = sw.elapsedMilliseconds;
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final stem = p.basenameWithoutExtension(input).replaceAll(RegExp(r'\.clean$'), '');
    final png = File(p.join(outDir.path, '$stem.rendered.png'))..writeAsBytesSync(ImageCodec.encodePng(render.image));
    final layout = File(p.join(outDir.path, '$stem.layout.json'))
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'render_scale': render.scale,
        'items': [for (final i in items) i.toJson()],
      }));
    final enlarged = render.scale == 1.0 ? '' : ', enlarged ×${render.scale.toStringAsFixed(2)}';
    ctx.say('${p.basename(input)}: ${items.length} text item(s)$enlarged, $ms ms → ${png.path}');
    if (ctx.json) {
      ctx.printJson({
        'ok': true,
        'image': png.path,
        'layout': layout.path,
        'items': items.length,
        'render_scale': render.scale,
        'ms': ms,
      });
    }
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
  String get invocation => 'cts process <image|folder>... [--to Russian] [--translator mock] [--allow-network] [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image or folder.');
    final inputs = expandImageInputs(args.rest);
    if (inputs.isEmpty) usageException('No images found (.png, .jpg, .jpeg, .webp, .bmp).');
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

    final PagePipeline pipeline;
    try {
      pipeline = await PagePipeline.load(services, settings,
          sourceLanguage: source, targetLanguage: target, translatorId: translatorId, useGpu: useGpu, log: log);
    } on ModelNotInstalledException catch (e) {
      ctx.err.writeln(e);
      await recorder?.finish(success: false, summary: {'error': e.toString()});
      return ExitCodes.failure;
    }

    final outDir = Directory(args.option('output')!)..createSync(recursive: true);
    final results = <Map<String, Object?>>[];
    var ok = true;
    for (final input in inputs) {
      final page = p.basename(input);
      final pageLog = log.child(page: page);
      final context = PluginContext(log: pageLog, recorder: recorder, page: page);
      try {
        final sw = Stopwatch()..start();
        final image = await ImageCodec.readFile(input);
        final decodeMs = sw.elapsedMilliseconds;
        final r = await pipeline.run(image, context);
        final timings = {'00_decode': decodeMs, ...r.timingsMs};
        final stem = p.basenameWithoutExtension(input);
        final outPng = File(p.join(outDir.path, '$stem.translated.png'))..writeAsBytesSync(ImageCodec.encodePng(r.rendered));
        final outJson = File(p.join(outDir.path, '$stem.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ')
              .convert({...r.toJson(image: page, source: source, target: target), 'timings_ms': timings}));
        final total = timings.values.fold(0, (a, b) => a + b);
        pageLog.log(LogLevel.info, 'process_done', durMs: total, data: {'blocks': r.blocks.length, 'timings': timings});
        results.add({'image': input, 'output': outPng.path, 'json': outJson.path, 'blocks': r.blocks.length, 'timings_ms': timings});
        ctx.say('$page: ${r.blocks.length} block(s), ${r.inpaintReport.fastFilledBlocks} bubble(s) flat-filled, '
            '${r.items.length} text item(s)${r.renderScale == 1.0 ? '' : ', enlarged ×${r.renderScale.toStringAsFixed(2)}'}, '
            '$total ms → ${outPng.path}');
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

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'};

/// Files as given; folders become their images (not recursive), in natural
/// order so page2 comes before page10.
List<String> expandImageInputs(List<String> args) => [
      for (final a in args)
        if (FileSystemEntity.isDirectorySync(a))
          ...(Directory(a)
                  .listSync()
                  .whereType<File>()
                  .map((f) => f.path)
                  .where((f) => _imageExtensions.contains(p.extension(f).toLowerCase()))
                  .toList()
                ..sort(naturalCompare))
        else
          a,
    ];

final _chunks = RegExp(r'\d+|\D+');

/// Compares strings treating digit runs as numbers, case-insensitively.
int naturalCompare(String a, String b) {
  final ca = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final cb = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final na = int.tryParse(ca[i]), nb = int.tryParse(cb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : ca[i].compareTo(cb[i]);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}
