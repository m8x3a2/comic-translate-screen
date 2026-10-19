/// What the Export window saves, made from the open pages.
library;

import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

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

ExportPage exportPageOf(PageEntry page) {
  final ext = p.extension(page.name);
  return ExportPage(
    name: p.basenameWithoutExtension(page.name),
    chapter: chapterOf(page),
    sourceExtension: ext.isEmpty ? p.extension(page.path) : ext,
    translatedImage: page.translatedPath,
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
  final pages = options.translated
      ? await drawMissingPages(read, ids, onProgress: onProgress)
      : [for (final id in ids) ?read(workspaceProvider).byId(id)];
  final sevenZip = options.container == ExportContainer.cb7 ? findSevenZip() : null;
  return _exportInBackground([for (final page in pages) exportPageOf(page)], options, output, bookName, sevenZip);
}
