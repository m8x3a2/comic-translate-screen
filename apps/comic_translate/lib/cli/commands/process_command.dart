import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../app_info.dart';
import '../../import/pdf_pages.dart';
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
      ..addFlag('debug', negatable: false, help: 'Test mode: save every stage (blocks, masks, images, timings).')
      ..addOption('project', help: 'Also save the results as a project (.ctsproj) to open in the window.')
      ..addFlag('webtoon',
          negatable: false,
          help: 'The pages are one webtoon strip: a bubble cut by the edge between two pages is read, cleaned and '
              'drawn whole.');
  }

  @override
  String get name => 'process';

  @override
  String get description => 'Translate pages end to end: detect, OCR, translate, remove text, draw the translation. '
      'Writes <name>.translated.png and <name>.json.';

  @override
  String get invocation => 'cts process <image|folder|archive|pdf>... [--to Russian] [--translator mock] [--allow-network] [-o dir]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image, folder, archive or PDF.');
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final source = args.option('from') ?? settings.sourceLanguage;
    final target = args.option('to') ?? settings.targetLanguage;
    if (Languages.byName(target) == null) usageException('Unknown target language "$target".');
    if (source != 'Auto' && Languages.byName(source) == null) usageException('Unknown source language "$source".');
    final translatorId = args.option('translator') ?? settings.translator;
    if (!await checkTranslatorNetwork(ctx, translatorId, settings,
        allowNetwork: args.flag('allow-network'), remember: args.flag('remember'), usageException: usageException)) {
      return ExitCodes.failure;
    }

    // Archives and PDFs are unpacked into a temporary folder for this run.
    final importDir = Directory(p.join(services.paths.cache.path, 'import-${DateTime.now().microsecondsSinceEpoch}'));
    try {
      final skipped = <String>[];
      final List<ImportedPage> inputs;
      try {
        inputs = await importPages(args.rest, cacheDir: importDir, pdf: rasterizePdf, skipped: skipped);
      } on Exception catch (e) {
        ctx.err.writeln(e);
        return ExitCodes.failure;
      }
      for (final s in skipped) {
        ctx.err.writeln('Skipped (not an image, folder, archive or PDF): $s');
      }
      if (inputs.isEmpty) {
        usageException('No pages found (images: .png .jpg .jpeg .webp .bmp; archives: .cbz .zip .epub .cbr .rar .cb7 '
            '.7z .cbt .tar; .pdf).');
      }
      return await _process(inputs, settings, source: source, target: target, translatorId: translatorId);
    } finally {
      if (importDir.existsSync()) importDir.deleteSync(recursive: true);
    }
  }

  Future<int> _process(List<ImportedPage> inputs, AppSettings settings,
      {required String source, required String target, required String translatorId}) async {
    final args = argResults!;
    final services = ctx.services;
    final useGpu = args.wasParsed('gpu') ? args.flag('gpu') : null;
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
    final projectPath = args.option('project');
    final projectPages = <ProjectPage>[];
    final cleanDir = projectPath == null ? null : Directory.systemTemp.createTempSync('cts_project_');
    final webtoon = args.flag('webtoon');
    // Webtoon: the next page (read ahead) and what of the last page reaches
    // into the following one.
    (int, RgbImage)? ahead;
    PageAbove? above;
    for (final (index, input) in inputs.indexed) {
      // Pages from archives and PDFs are named after the archive: book_001.
      final stem = input.source == null
          ? p.basenameWithoutExtension(input.path)
          : '${p.basenameWithoutExtension(input.source!)}_${p.basenameWithoutExtension(input.path)}';
      final page = input.source == null ? p.basename(input.path) : '$stem${p.extension(input.path)}';
      final origin = input.source ?? input.path;
      final pageLog = log.child(page: page);
      final context = PluginContext(log: pageLog, recorder: recorder, page: page, onUsage: ctx.services.usage.record);
      try {
        final sw = Stopwatch()..start();
        final image = ahead?.$1 == index ? ahead!.$2 : await ImageCodec.readFile(input.path);
        ahead = null;
        RgbImage? next;
        if (webtoon && index + 1 < inputs.length) {
          try {
            next = await ImageCodec.readFile(inputs[index + 1].path);
            ahead = (index + 1, next);
          } on Exception {
            // An unreadable next page fails on its own turn.
          }
        }
        final decodeMs = sw.elapsedMilliseconds;
        final cleaned = await pipeline.prepare(
          image,
          context,
          next: next,
          covered: above == null ? const [] : reachInto(above.blocks, above.height, above.width, image.width),
        );
        final renderWatch = Stopwatch()..start();
        final render = await renderPage(cleaned.clean, cleaned.blocks, settings, targetLanguage: target, above: above);
        final renderMs = renderWatch.elapsedMilliseconds;
        await recordRender(recorder, page, render.image, render.items, renderMs);
        final r = PageResult.of(cleaned, render, renderMs);
        above = webtoon
            ? PageAbove(
                width: image.width,
                height: image.height,
                blocks: cleaned.blocks,
                targetLanguage: target,
                patch: cleaned.overflow,
              )
            : null;
        final timings = {'00_decode': decodeMs, ...r.timingsMs};
        final outPng = File(p.join(outDir.path, '$stem.translated.png'))..writeAsBytesSync(ImageCodec.encodePng(r.rendered));
        final outJson = File(p.join(outDir.path, '$stem.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ')
              .convert({...r.toJson(image: page, source: source, target: target), 'timings_ms': timings}));
        if (cleanDir != null) {
          final clean = File(p.join(cleanDir.path, '$index.png'))..writeAsBytesSync(ImageCodec.encodePng(r.clean));
          final patch = cleaned.overflow;
          final overflow = patch == null
              ? null
              : (File(p.join(cleanDir.path, '$index.overflow.png'))
                  ..writeAsBytesSync(ImageCodec.encodeRgbaPng(patch.image, patch.alpha)));
          projectPages.add(ProjectPage(
            id: '$index',
            name: input.name,
            source: input.source,
            image: input.path,
            cleanImage: clean.path,
            overflow: overflow?.path,
            blocks: r.blocks,
            state: {'status': 'done', if (r.renderScale != 1) 'render_scale': r.renderScale},
          ));
        }
        final total = timings.values.fold(0, (a, b) => a + b);
        pageLog.log(LogLevel.info, 'process_done', durMs: total, data: {'blocks': r.blocks.length, 'timings': timings});
        results.add({
          'image': origin,
          'page': input.name,
          'output': outPng.path,
          'json': outJson.path,
          'blocks': r.blocks.length,
          'timings_ms': timings,
        });
        ctx.say('$page: ${r.blocks.length} block(s), ${r.inpaintReport.fastFilledBlocks} bubble(s) flat-filled, '
            '${r.items.length} text item(s)${r.renderScale == 1.0 ? '' : ', enlarged ×${r.renderScale.toStringAsFixed(2)}'}, '
            '$total ms → ${outPng.path}');
      } catch (e, st) {
        ok = false;
        above = null;
        pageLog.error('process_failed', e, st);
        results.add({'image': origin, 'page': input.name, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
        projectPages.add(ProjectPage(
          id: '$index',
          name: input.name,
          source: input.source,
          image: input.path,
          state: {
            'status': 'skipped',
            'reason': e is TranslationException
                ? {'kind': 'translation', 'error': e.kind.name, 'message': e.message}
                : {'kind': 'other', 'message': '$e'},
          },
        ));
        // Every following page would fail the same way (key, balance,
        // address, connection): stop instead of sending them.
        if (e is TranslationException && e.kind.stopsRun) {
          ctx.err.writeln('Stopped: the translator error (${e.kind.name}) would repeat on every page.');
          break;
        }
      }
    }
    if (projectPath != null && projectPages.isNotEmpty) {
      try {
        ProjectFile.save(
          projectPath,
          ProjectData(pages: projectPages, state: {if (webtoon) 'webtoon': true}),
          appVersion: AppInfo.version,
          replace: true,
        );
        ctx.say('Project: $projectPath (${projectPages.length} page(s))');
      } catch (e, st) {
        ok = false;
        log.error('project_save_failed', e, st);
        ctx.err.writeln('Could not save the project: $e');
      }
    }
    if (cleanDir != null && cleanDir.existsSync()) cleanDir.deleteSync(recursive: true);
    await recorder?.finish(success: ok, summary: {'pages': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results, 'project': ?projectPath});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
