/// The translation of a page laid out as export will draw it, for the
/// viewer and the text panel (fitted font sizes). The webtoon strip shows
/// several pages at once, so it is kept per page.
library;

import 'dart:convert';
import 'dart:ui' show Size;

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pipeline/page_pipeline.dart';
import '../render/mask_raster.dart';
import '../render/text_renderer.dart';
import 'app_state.dart';
import 'workspace.dart';

/// Size of the image file at a path.
final pageSizeProvider = FutureProvider.family<Size, String>((ref, path) async {
  final (w, h) = await imageFileSize(path);
  return Size(w.toDouble(), h.toDouble());
});

/// What the text engines of page [id] depend on: the render settings, the
/// target language and the fonts its blocks use.
final _enginesKeyProvider = Provider.autoDispose.family<String, String>((ref, id) {
  final settings = ref.watch(settingsProvider);
  final blocks = ref.watch(workspaceProvider.select((s) => s.byId(id)?.blocks)) ?? const <TextBlock>[];
  final target = ref.watch(workspaceProvider.select((s) => s.byId(id)?.targetOf(settings))) ?? settings.targetLanguage;
  final fonts = {for (final b in blocks) ?b.style?.fontFamily}.toList()..sort();
  return jsonEncode([settings.render.toJson(), target, fonts]);
});

/// The text engines of page [id] (its fonts loaded).
final pageEnginesProvider = FutureProvider.autoDispose.family<TextEngines, String>((ref, id) async {
  ref.watch(_enginesKeyProvider(id));
  final settings = ref.read(settingsProvider);
  final page = ref.read(workspaceProvider).byId(id);
  return loadTextEngines(settings, page?.targetOf(settings) ?? settings.targetLanguage, page?.blocks ?? const []);
});

/// The text engines of the current page.
final textEnginesProvider = Provider.autoDispose<AsyncValue<TextEngines>>((ref) {
  final id = ref.watch(workspaceProvider.select((s) => s.currentPage?.id));
  return id == null ? const AsyncLoading() : ref.watch(pageEnginesProvider(id));
});

final _layoutCacheProvider = Provider<LayoutCache>((ref) => LayoutCache());

/// The laid-out translation of page [id]; null until the page size and the
/// fonts are known.
final pageLayoutOfProvider = Provider.autoDispose.family<RenderLayout?, String>((ref, id) {
  final page = ref.watch(workspaceProvider.select((s) => s.byId(id)));
  if (page == null) return null;
  final size = ref.watch(pageSizeProvider(page.path)).value;
  final engines = ref.watch(pageEnginesProvider(id)).value;
  final settings = ref.watch(settingsProvider);
  if (size == null || engines == null) return null;
  return layoutRender(
    size.width.round(),
    size.height.round(),
    page.blocks,
    settings,
    engines,
    targetLanguage: page.targetOf(settings),
    cache: ref.read(_layoutCacheProvider),
  );
});

/// The current page's laid-out translation.
final pageLayoutProvider = Provider.autoDispose<RenderLayout?>((ref) {
  final id = ref.watch(workspaceProvider.select((s) => s.currentPage?.id));
  return id == null ? null : ref.watch(pageLayoutOfProvider(id));
});
