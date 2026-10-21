/// What the Export window saves, made from the open pages.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../pipeline/psd_page.dart';
import 'app_state.dart';
import 'page_render.dart';
import 'workspace.dart';

/// Top-level, so nothing of the app is copied into the isolate.
Future<ExportResult> _exportInBackground(
  List<ExportPage> pages,
  ExportOptions options,
  String output,
  String bookName,
  String? sevenZip,
) => Isolate.run(() => exportPages(pages, options, output, bookName: bookName, sevenZip: sevenZip));

/// The chapter of a page: the archive or PDF it came from ('' for single
/// images).
String chapterOf(PageEntry page) => page.source == null ? '' : p.basenameWithoutExtension(page.source!);

int chapterCount(Iterable<PageEntry> pages) => {for (final page in pages) chapterOf(page)}.length;

/// [translatedImage] replaces the drawn page (a PSD file).
ExportPage exportPageOf(PageEntry page, {String? translatedImage}) {
  final ext = p.extension(page.name);
  return ExportPage(
    name: p.basenameWithoutExtension(page.name),
    chapter: chapterOf(page),
    sourceExtension: ext.isEmpty ? p.extension(page.path) : ext,
    translatedImage: translatedImage ?? page.translatedPath,
    cleanImage: page.cleanPath,
    recognized: page.blocks.isEmpty ? null : {for (final (i, b) in page.blocks.indexed) 'block_$i': b.text},
    translations: page.blocks.isEmpty ? null : {for (final (i, b) in page.blocks.indexed) 'block_$i': b.translation},
  );
}

/// 7-Zip for CB7, if installed.
String? findSevenZip() => findArchiveTool('pages.cb7');

/// Draws the translated pages among [ids] that need it, then exports them
/// into [output] as [options] say.
Future<ExportResult> exportOpenPages(
  Reader read,
  List<String> ids,
  ExportOptions options,
  String output, {
  required String bookName,
  void Function(int done, int total)? onProgress,
}) async {
  if (options.imageFormat == 'psd') return _exportPsd(read, ids, options, output, bookName, onProgress);
  final pages = options.translated
      ? await drawMissingPages(read, ids, onProgress: onProgress)
      : [for (final id in ids) ?read(workspaceProvider).byId(id)];
  final sevenZip = options.container == ExportContainer.cb7 ? findSevenZip() : null;
  return _exportInBackground([for (final page in pages) exportPageOf(page)], options, output, bookName, sevenZip);
}

/// Writes the layered Photoshop file of [page] into [dir] (see
/// [buildPagePsd]); with whether it uses the bundled font.
Future<(String, bool)> writePagePsd(Reader read, PageEntry page, String dir) async {
  final settings = read(settingsProvider);
  final path = page.path, cleanPath = page.cleanPath;
  final original = await Isolate.run(() => ImageCodec.readFile(path));
  final clean = cleanPath == null ? original : await Isolate.run(() => ImageCodec.readFile(cleanPath));
  final doc = await buildPagePsd(
    original,
    clean,
    page.blocks,
    settings,
    targetLanguage: page.targetOf(settings),
    above: await pageAbove(read(workspaceProvider), page, settings),
  );
  final file = p.join(dir, '${page.id}${doc.large ? '.psb' : '.psd'}');
  await Isolate.run(() => writePsdFile(file, doc));
  return (file, usesBundledFont(doc));
}

Future<ExportResult> _exportPsd(
  Reader read,
  List<String> ids,
  ExportOptions options,
  String output,
  String bookName,
  void Function(int done, int total)? onProgress,
) async {
  final ws = read(workspaceProvider);
  final pages = [for (final id in ids) ?ws.byId(id)];
  final dir = Directory.systemTemp.createTempSync('cts_psd_');
  try {
    final out = <ExportPage>[];
    var font = false;
    for (final (i, page) in pages.indexed) {
      onProgress?.call(i, pages.length);
      String? file;
      if (options.translated) {
        final (f, bundled) = await writePagePsd(read, page, dir.path);
        file = f;
        font |= bundled;
      }
      out.add(exportPageOf(page, translatedImage: file));
    }
    onProgress?.call(pages.length, pages.length);
    return await _exportInBackground(
      out,
      font ? options.withExtraFiles(bundledFontFiles()) : options,
      output,
      bookName,
      null,
    );
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
