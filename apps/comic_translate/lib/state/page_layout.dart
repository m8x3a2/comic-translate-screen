/// The translation of the current page laid out as export will draw it, for
/// the viewer and the text panel (fitted font sizes).
library;

import 'dart:convert';
import 'dart:ui' show Size;

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

/// What the text engines depend on: the render settings, the target
/// language and the fonts the blocks of the current page use.
final _enginesKeyProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  final blocks = ref.watch(workspaceProvider.select((s) => s.currentPage?.blocks)) ?? const [];
  final fonts = {for (final b in blocks) ?b.style?.fontFamily}.toList()..sort();
  return jsonEncode([settings.render.toJson(), settings.targetLanguage, fonts]);
});

final textEnginesProvider = FutureProvider<TextEngines>((ref) async {
  ref.watch(_enginesKeyProvider);
  final settings = ref.read(settingsProvider);
  final blocks = ref.read(workspaceProvider).currentPage?.blocks ?? const [];
  return loadTextEngines(settings, settings.targetLanguage, blocks);
});

final _layoutCacheProvider = Provider<LayoutCache>((ref) => LayoutCache());

/// The current page's laid-out translation; null until the page size and
/// the fonts are known.
final pageLayoutProvider = Provider<RenderLayout?>((ref) {
  final page = ref.watch(workspaceProvider.select((s) => s.currentPage));
  if (page == null) return null;
  final size = ref.watch(pageSizeProvider(page.path)).value;
  final engines = ref.watch(textEnginesProvider).value;
  final settings = ref.watch(settingsProvider);
  if (size == null || engines == null) return null;
  return layoutRender(
    size.width.round(),
    size.height.round(),
    page.blocks,
    settings,
    engines,
    targetLanguage: settings.targetLanguage,
    cache: ref.read(_layoutCacheProvider),
  );
});
