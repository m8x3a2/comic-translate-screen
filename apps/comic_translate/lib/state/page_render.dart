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
import '../render/mask_raster.dart';
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
    final render = await renderPage(
      image,
      page.blocks,
      settings,
      targetLanguage: page.targetOf(settings),
      above: await pageAbove(read(workspaceProvider), page, settings),
    );
    final file = p.join(workspace.pageDir(page.id).path, 'translated_${DateTime.now().microsecondsSinceEpoch}.png');
    final rendered = render.image;
    await Isolate.run(() => File(file).writeAsBytes(ImageCodec.encodePng(rendered), flush: true));
    // Only if nothing changed meanwhile (the page above included: it does
    // not take the drawn page away, see [WorkspaceNotifier.edit]).
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

/// Webtoon mode: the image of the page below [page], and the parts of
/// [page] that blocks of the page above reach into (none outside the mode).
Future<({String? below, List<BBox> covered})> webtoonSeams(WorkspaceState ws, PageEntry page) async {
  final i = ws.pages.indexWhere((p) => p.id == page.id);
  if (!ws.webtoon || i < 0) return (below: null, covered: const <BBox>[]);
  final next = i + 1 < ws.pages.length ? ws.pages[i + 1] : null;
  final prev = i > 0 ? ws.pages[i - 1] : null;
  var covered = const <BBox>[];
  if (prev != null && prev.blocks.isNotEmpty) {
    final (pw, ph) = await imageFileSize(prev.path);
    final (w, _) = await imageFileSize(page.path);
    covered = reachInto(prev.blocks, ph, pw, w);
  }
  return (below: next?.path, covered: covered);
}

/// Webtoon mode: what of the page above [page] is drawn on it (null when
/// nothing reaches into it, and outside the mode).
Future<PageAbove?> pageAbove(WorkspaceState ws, PageEntry page, AppSettings settings) async {
  final i = ws.pages.indexWhere((p) => p.id == page.id);
  if (!ws.webtoon || i <= 0) return null;
  final prev = ws.pages[i - 1];
  final (w, h) = await imageFileSize(prev.path);
  final file = prev.overflowPath;
  if (file == null && overflowOf(prev.blocks, h) <= 0) return null;
  SeamPatch? patch;
  if (file != null && File(file).existsSync()) {
    final (rgb, alpha) = await Isolate.run(() async => ImageCodec.decodeRgba(await File(file).readAsBytes()));
    patch = SeamPatch(rgb, alpha);
  }
  return PageAbove(width: w, height: h, blocks: prev.blocks, targetLanguage: prev.targetOf(settings), patch: patch);
}
