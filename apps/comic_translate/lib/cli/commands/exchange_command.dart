import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;

import '../../pipeline/page_pipeline.dart';
import '../cli.dart';
import '../cli_context.dart';

/// `cts exchange export|import`: the exchange with a chat AI by hand.
class ExchangeCommand extends Command<int> {
  ExchangeCommand(CliContextHolder holder) {
    addSubcommand(_ExchangeExport(holder));
    addSubcommand(_ExchangeImport(holder));
  }

  @override
  String get name => 'exchange';

  @override
  String get description =>
      'Exchange with a chat AI by hand: pictures and instructions out, the chat\'s answer back in.';
}

class _ExchangeExport extends CtsCommand {
  _ExchangeExport(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'The exchange folder to write (required).')
      ..addOption(
        'mode',
        allowed: [for (final m in ExchangeMode.values) m.name],
        help: 'What the chat does (default: both, or recognize when "together" is off in the settings).',
      )
      ..addOption('lang', help: 'Source language (default from settings).')
      ..addOption('to', help: 'Target language (default from settings).')
      ..addOption('grouping', allowed: [for (final g in SheetGrouping.values) g.name], help: 'Default from settings.')
      ..addOption('per-sheet', help: 'Pieces on a sheet with --grouping count.')
      ..addOption('sheet-px', help: 'Longest side of a sheet.')
      ..addOption('groups', help: 'Own grouping of the pieces, e.g. "1-4, 5-6".')
      ..addOption('context', allowed: [for (final c in ContextImage.values) c.name], help: 'Pictures of whole pages.')
      ..addOption(
        'images',
        allowed: [for (final i in ExchangeImages.values) i.name],
        help: 'Sheets, single crops or both.',
      );
  }

  @override
  String get name => 'export';

  @override
  String get description =>
      'Write the exchange folder for images (found and, to translate, read first) or for a project (.ctsproj).';

  @override
  String get invocation => 'cts exchange export <image...|project.ctsproj> -o dir [--mode both] [--groups "1-4, 5-6"]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give images or one .ctsproj file.');
    final output = args.option('output') ?? (throw UsageException('--output is required.', usage));
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final mode = args.option('mode') != null
        ? ExchangeMode.parse(args.option('mode'))
        : (settings.exchange.together ? ExchangeMode.both : ExchangeMode.recognize);
    final source = args.option('lang') ?? settings.sourceLanguage;
    final target = args.option('to') ?? settings.targetLanguage;
    int? number(String name) => args.option(name) == null ? null : int.tryParse(args.option(name)!);
    final exchange = settings.exchange.copyWith(
      grouping: args.option('grouping') == null ? null : SheetGrouping.parse(args.option('grouping')),
      perSheet: number('per-sheet'),
      sheetMaxPx: number('sheet-px')?.clamp(ExchangeSettings.minSheetPx, ExchangeSettings.maxSheetPx),
      contextImage: args.option('context') == null ? null : ContextImage.parse(args.option('context')),
      images: args.option('images') == null ? null : ExchangeImages.parse(args.option('images')),
    );
    final log = services.appLog.child(stage: 'exchange');
    final work = Directory.systemTemp.createTempSync('cts_exchange_');
    try {
      final List<ExchangePage> pages;
      if (args.rest.length == 1 && args.rest.single.toLowerCase().endsWith('.ctsproj')) {
        final ProjectData data;
        try {
          data = ProjectFile.load(args.rest.single, Directory(p.join(work.path, 'project')));
        } on ProjectFormatException catch (e) {
          ctx.err.writeln(e.message);
          return ExitCodes.failure;
        }
        pages = [
          for (final (i, page) in data.pages.indexed)
            ExchangePage(
              id: page.id,
              number: i + 1,
              name: page.name,
              blocks: page.blocks,
              image: mode.sendsImages ? await ImageCodec.readFile(page.image) : null,
            ),
        ];
      } else {
        final found = await _findText(args.rest, settings, mode, source, log);
        if (found == null) return ExitCodes.failure;
        pages = found;
      }
      final items = exchangeItems(pages, mode);
      var groups = const <List<int>>[];
      if (args.option('groups') case final text?) {
        try {
          groups = parseSheetGroups(text, items.length);
        } on FormatException catch (e) {
          usageException('Wrong part of --groups: "${e.message}" (${items.length} pieces).');
        }
      }
      final out = await writeExchange(
        Directory(output),
        pages,
        mode,
        exchange,
        sourceLanguage: source,
        targetLanguage: target,
        extraContext: settings.extraContext,
        screens: settings.contentKind == ContentKind.screens,
        groups: groups,
      );
      log.info('exchange_export', {'mode': mode.name, 'pieces': out.items.length, 'pictures': out.pictures.length});
      if (ctx.json) {
        ctx.printJson({
          'dir': out.dir,
          'mode': mode.name,
          'pieces': [for (final it in out.items) it.label.code],
          'pictures': out.pictures,
          'prompt': out.prompt,
        });
      } else {
        ctx.say('${out.items.length} piece(s), ${out.pictures.length} picture(s) → ${out.dir}');
        for (final f in out.pictures) {
          ctx.say('  $f');
        }
      }
      return ExitCodes.ok;
    } finally {
      work.deleteSync(recursive: true);
    }
  }

  /// Finds the text on [images] (and reads it when only translating).
  Future<List<ExchangePage>?> _findText(
    List<String> images,
    AppSettings settings,
    ExchangeMode mode,
    String source,
    EventLog log,
  ) async {
    final services = ctx.services;
    final TextDetector detector;
    OcrEngine? ocr;
    try {
      detector = await services.plugin<TextDetector>(settings.activeDetector, settings, log: log);
      if (mode == ExchangeMode.translate) {
        // Reading through the chat makes no sense here: the usual engine reads.
        final id = settings.ocr == chatOcrId ? AppSettings().ocr : settings.ocr;
        ocr = await services.plugin<OcrEngine>(id, settings, log: log);
      }
    } on ModelNotInstalledException catch (e) {
      ctx.err.writeln(e);
      return null;
    }
    return [
      for (final (i, path) in images.indexed)
        await () async {
          final image = await ImageCodec.readFile(path);
          final context = PluginContext(
            log: log.child(page: p.basename(path)),
            page: p.basename(path),
          );
          final blocks = sortBlocks(await detector.detect(image, context), rightToLeft: source == 'Japanese');
          if (ocr != null) await recognizeBlocks(ocr, image, blocks, settings, context, sourceLanguage: source);
          return ExchangePage(id: path, number: i + 1, name: p.basename(path), blocks: blocks, image: image);
        }(),
    ];
  }
}

class _ExchangeImport extends CtsCommand {
  _ExchangeImport(super.holder) {
    argParser.addOption(
      'answer',
      help: 'A file with the chat\'s answer as it was copied (default: what was written into ALL.txt and page_NN.txt).',
    );
  }

  @override
  String get name => 'import';

  @override
  String get description => 'Read the chat\'s answer for an exchange folder and tell what matched.';

  @override
  String get invocation => 'cts exchange import <dir> [--answer answer.txt]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Give one exchange folder.');
    final dir = Directory(args.rest.single);
    final ExchangeManifest manifest;
    try {
      manifest = await ExchangeManifest.read(dir);
    } on FileSystemException {
      ctx.err.writeln('No $exchangeManifestName in ${dir.path}: not an exchange folder.');
      return ExitCodes.failure;
    }
    final answerFile = args.option('answer');
    final match = answerFile == null
        ? await readExchangeFolder(dir, manifest)
        : matchExchangeAnswer(
            manifest.items,
            parseExchangeAnswer(await File(answerFile).readAsString(), manifest.mode),
            manifest.mode,
          );
    ctx.services.appLog.child(stage: 'exchange').info('exchange_import', {
      'mode': manifest.mode.name,
      'found': match.replies.length,
      'missing': match.missing.length,
      'unknown': match.unknown.length,
    });
    List<String> codes(List<ExchangeLabel> labels) => [for (final l in labels) l.code];
    if (ctx.json) {
      ctx.printJson({
        'mode': manifest.mode.name,
        'replies': {
          for (final e in match.replies.entries)
            e.key.code: {'original': ?e.value.original, 'translation': ?e.value.translation},
        },
        'missing': codes(match.missing),
        'unknown': codes(match.unknown),
        'missing_arrow': codes(match.missingArrow),
        'repeated': codes(match.repeated),
        if (match.sources.isNotEmpty) 'sources': {for (final e in match.sources.entries) e.key.code: e.value},
      });
    } else {
      ctx.say('${match.replies.length} of ${manifest.items.length} piece(s) answered.');
      for (final e in match.replies.entries) {
        final r = e.value;
        ctx.say('  ${e.key} ${[?r.original, ?r.translation].join(' --> ')}');
      }
      if (match.missing.isNotEmpty) ctx.say('No answer: ${codes(match.missing).join(', ')}');
      if (match.unknown.isNotEmpty) ctx.say('Not sent: ${codes(match.unknown).join(', ')}');
      if (match.missingArrow.isNotEmpty) ctx.say('Without -->: ${codes(match.missingArrow).join(', ')}');
    }
    return match.replies.isEmpty ? ExitCodes.failure : ExitCodes.ok;
  }
}
