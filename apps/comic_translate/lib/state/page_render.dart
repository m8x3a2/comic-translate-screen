/// Draws edited pages again: after a change the drawn page (the cache in
/// [PageEntry.translatedPath]) is cleared, and export draws it from the
/// cleaned image and the blocks.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:path/path.dart' as p;

import '../pipeline/page_pipeline.dart';
import 'app_state.dart';
import 'workspace.dart';

/// `ref.read` of a widget or a provider.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Draws the pages among [ids] that have a translation but no drawn image,
/// one at a time; [onProgress] gets (done, total). Returns the pages as they
/// are afterwards.
Future<List<PageEntry>> drawMissingPages(
  Reader read,
  Iterable<String> ids, {
  void Function(int done, int total)? onProgress,
}) async {
  final workspace = read(workspaceProvider.notifier);
  final settings = read(settingsProvider);
  final todo = [
    for (final id in ids)
      if (read(workspaceProvider).byId(id) case final page? when page.isDone && page.translatedPath == null) page,
  ];
  for (final (i, page) in todo.indexed) {
    onProgress?.call(i, todo.length);
    final base = page.basePath;
    final image = await Isolate.run(() => ImageCodec.readFile(base));
    final render = await renderPage(image, page.blocks, settings, targetLanguage: settings.targetLanguage);
    final file = p.join(workspace.pageDir(page.id).path, 'translated_${DateTime.now().microsecondsSinceEpoch}.png');
    final rendered = render.image;
    await Isolate.run(() => File(file).writeAsBytes(ImageCodec.encodePng(rendered), flush: true));
    // Only if nothing changed meanwhile.
    workspace.updatePage(
      page.id,
      (p) => identical(p.blocks, page.blocks) && p.cleanPath == page.cleanPath
          ? p.copyWith(translatedPath: file, renderScale: render.scale)
          : p,
    );
  }
  onProgress?.call(todo.length, todo.length);
  return [for (final id in ids) ?read(workspaceProvider).byId(id)];
}
