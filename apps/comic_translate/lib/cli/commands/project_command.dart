import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../pipeline/page_pipeline.dart';
import '../cli.dart';
import '../cli_context.dart';

/// `cts project info <file.ctsproj>`.
class ProjectCommand extends Command<int> {
  ProjectCommand(CliContextHolder holder) {
    addSubcommand(_ProjectInfo(holder));
  }

  @override
  String get name => 'project';

  @override
  String get description => 'Look into project files (.ctsproj).';
}

class _ProjectInfo extends CtsCommand {
  _ProjectInfo(super.holder);

  @override
  String get name => 'info';

  @override
  String get description => 'Pages, size, saved time and program version of a project.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Give one .ctsproj file.');
    final ProjectInfo info;
    try {
      info = ProjectFile.info(rest.single);
    } on ProjectFormatException catch (e) {
      ctx.err.writeln(e.message);
      return ExitCodes.failure;
    } on FileSystemException catch (e) {
      ctx.err.writeln('${e.message}: ${e.path}');
      return ExitCodes.failure;
    }
    if (ctx.json) {
      ctx.printJson({
        'pages': info.pages,
        'bytes': info.bytes,
        'saved': info.saved?.toUtc().toIso8601String(),
        'app_version': info.appVersion,
      });
    } else {
      ctx.say('${p.basename(rest.single)}: ${info.pages} page(s), ${(info.bytes / 1024 / 1024).toStringAsFixed(1)} MB'
          '${info.saved == null ? '' : ', saved ${info.saved}'}${info.appVersion == null ? '' : ' by ${info.appVersion}'}');
    }
    return ExitCodes.ok;
  }
}

/// `cts export`: a project's pages into a folder, ZIP, CBZ, CB7 or PDF.
class ExportCommand extends CtsCommand {
  ExportCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'The file (zip, cbz, cb7, pdf) or folder to write (required).')
      ..addOption('as', allowed: [for (final c in ExportContainer.values) c.name], help: 'Default: from the output\'s extension, else folder.')
      ..addMultiOption('what',
          allowed: ['translated', 'cleaned', 'raw', 'translations'],
          defaultsTo: ['translated'],
          help: 'Pages with the translation, cleaned pages, recognized text, translations (JSON).')
      ..addOption('image-format', allowed: ExportSettings.formats, defaultsTo: 'source')
      ..addFlag('by-chapter', negatable: false, help: 'One file per chapter (source archive or PDF); --output is then a folder.')
      ..addOption('to', help: 'Language of the translation, for drawing it (default: that of each page, else settings).');
  }

  @override
  String get name => 'export';

  @override
  String get description => 'Export the pages of a project (.ctsproj): translated pages, cleaned pages and texts.';

  @override
  String get invocation => 'cts export <project.ctsproj> -o book.cbz [--what translated,cleaned] [--by-chapter]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Give one .ctsproj file.');
    final output = args.option('output') ?? (throw UsageException('--output is required.', usage));
    final ext = p.extension(output).toLowerCase();
    final container = args.option('as') != null
        ? ExportContainer.parse(args.option('as'))
        : ExportContainer.values.firstWhere((c) => c != ExportContainer.folder && c.extension == ext,
            orElse: () => ExportContainer.folder);
    final what = args.multiOption('what');
    final options = ExportOptions(
      container: container,
      imageFormat: args.option('image-format')!,
      translated: what.contains('translated'),
      cleaned: what.contains('cleaned'),
      recognizedText: what.contains('raw'),
      translatedText: what.contains('translations'),
      byChapter: args.flag('by-chapter'),
    );
    final settings = await ctx.services.settingsStore.load();
    // Each page has its language (--to overrides it).
    String targetOf(ProjectPage page) =>
        args.option('to') ?? (page.state['target_language'] as String?) ?? settings.targetLanguage;
    final work = Directory.systemTemp.createTempSync('cts_export_');
    try {
      final ProjectData data;
      try {
        data = ProjectFile.load(args.rest.single, Directory(p.join(work.path, 'project')));
      } on ProjectFormatException catch (e) {
        ctx.err.writeln(e.message);
        return ExitCodes.failure;
      }
      final pages = <ExportPage>[];
      for (final (i, page) in data.pages.indexed) {
        if (page.cleanImage == null && !page.blocks.any((b) => hasTranslatableContent(b.translation))) continue;
        String? translated;
        if (options.translated) {
          final base = await ImageCodec.readFile(page.cleanImage ?? page.image);
          final render = await renderPage(base, page.blocks, settings, targetLanguage: targetOf(page));
          translated = p.join(work.path, 'drawn', '$i.png');
          File(translated)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(ImageCodec.encodePng(render.image));
        }
        final ext = p.extension(page.name);
        pages.add(ExportPage(
          name: p.basenameWithoutExtension(page.name),
          chapter: page.source == null ? '' : p.basenameWithoutExtension(page.source!),
          sourceExtension: ext.isEmpty ? p.extension(page.image) : ext,
          translatedImage: translated,
          cleanImage: page.cleanImage,
          recognized: {for (final (j, b) in page.blocks.indexed) 'block_$j': b.text},
          translations: {for (final (j, b) in page.blocks.indexed) 'block_$j': b.translation},
        ));
      }
      if (pages.isEmpty) {
        ctx.err.writeln('No translated or cleaned pages in the project.');
        return ExitCodes.failure;
      }
      final ExportResult result;
      try {
        result = await exportPages(
          pages,
          options,
          output,
          bookName: p.basenameWithoutExtension(args.rest.single),
          sevenZip: container == ExportContainer.cb7 ? findArchiveTool(output) : null,
        );
      } on ArchiveToolMissingException {
        ctx.err.writeln('CB7 needs 7-Zip installed.');
        return ExitCodes.failure;
      } on ExportException catch (e) {
        ctx.err.writeln(e.message);
        return ExitCodes.failure;
      }
      ctx.services.appLog.info('exported', {'container': container.name, 'pages': result.pages, 'files': result.outputs.length});
      if (ctx.json) {
        ctx.printJson({'pages': result.pages, 'outputs': result.outputs});
      } else {
        ctx.say('${result.pages} page(s) → ${result.outputs.join(', ')}');
      }
      return ExitCodes.ok;
    } finally {
      work.deleteSync(recursive: true);
    }
  }
}
