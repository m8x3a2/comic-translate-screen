/// The mask pipette (the owner's idea): a click on a letter adds its colour;
/// the mask of the current page is drawn again from the mask it had before
/// the pipette plus every pixel of the picked colours inside the text boxes
/// (of the selected block, else of all blocks, else the whole page). All the
/// pipette's changes of one go are one undo step.
library;

import 'dart:async';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'app_state.dart';
import 'background.dart';
import 'steps.dart';
import 'workspace.dart';

class PipetteState {
  const PipetteState({
    this.pageId,
    this.colours = const [],
    this.tolerance = pipetteTolerance,
    this.mask,
    this.busy = false,
  });

  /// The page of [colours], and the mask the pipette wrote last there.
  final String? pageId;
  final String? mask;
  final List<(int, int, int)> colours;

  /// How far (ΔE) a colour may be from a picked one.
  final double tolerance;

  /// The mask is being drawn again.
  final bool busy;

  /// The colours picked on [page], while its mask is still the pipette's
  /// (painting, a step or undo start the pipette anew).
  List<(int, int, int)> coloursOf(PageEntry? page) =>
      page != null && page.id == pageId && page.maskPath == mask && page.strokes.isEmpty ? colours : const [];

  PipetteState copyWith({List<(int, int, int)>? colours, double? tolerance, String? mask, bool? busy}) => PipetteState(
    pageId: pageId,
    colours: colours ?? this.colours,
    tolerance: tolerance ?? this.tolerance,
    mask: mask ?? this.mask,
    busy: busy ?? this.busy,
  );
}

final pipetteProvider = NotifierProvider<PipetteNotifier, PipetteState>(PipetteNotifier.new);

/// Where the pipette looks on [page]: the selected block, else every block,
/// else the whole page (null).
List<BBox>? pipetteRegions(PageEntry page, int? selected, int width, int height) {
  final blocks = page.blocks;
  if (blocks.isEmpty) return null;
  return textRegions(selected != null && selected < blocks.length ? [blocks[selected]] : blocks, width, height);
}

class PipetteNotifier extends Notifier<PipetteState> {
  /// The mask before the pipette, and the picture it works on.
  GrayImage? _base;
  RgbImage? _image;
  String? _imagePath;
  var _session = 0;
  var _run = 0;
  Timer? _later;

  @override
  PipetteState build() {
    ref.onDispose(() => _later?.cancel());
    return const PipetteState();
  }

  /// Adds the colour at [point] of the current page (a colour picked already
  /// is not added twice) and draws the mask again.
  Future<void> pickAt(Point2 point) async {
    final page = ref.read(workspaceProvider).currentPage;
    if (page == null) return;
    try {
      await _start(page);
      final image = _image!;
      final x = point.x.floor(), y = point.y.floor();
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
      final colour = sampleColour(image, x, y);
      if (state.colours.contains(colour)) return;
      state = state.copyWith(colours: [...state.colours, colour]);
      await _apply();
    } on Object catch (e, st) {
      ref.read(servicesProvider).appLog.error('pipette_failed', e, st);
    }
  }

  void remove((int, int, int) colour) {
    if (!state.colours.contains(colour)) return;
    state = state.copyWith(
      colours: [
        for (final c in state.colours)
          if (c != colour) c,
      ],
    );
    unawaited(_apply());
  }

  /// A new tolerance; the mask follows a moment after the slider stops.
  void setTolerance(double tolerance) {
    state = state.copyWith(tolerance: tolerance.clamp(minPipetteTolerance, maxPipetteTolerance));
    _later?.cancel();
    _later = Timer(const Duration(milliseconds: 250), () => unawaited(_apply()));
  }

  /// Picks up where the pipette left [page], or starts anew from its mask now.
  Future<void> _start(PageEntry page) async {
    if (_imagePath != page.basePath) {
      _image = await readImageInBackground(page.basePath);
      _imagePath = page.basePath;
      _base = null;
    }
    if (_base != null && page.id == state.pageId && page.maskPath == state.mask && page.strokes.isEmpty) return;
    final image = _image!;
    final mask = page.maskPath == null && page.strokes.isEmpty
        ? GrayImage.zeros(image.width, image.height)
        : await currentPageMask(page);
    _base = mask;
    _session++;
    state = PipetteState(pageId: page.id, mask: page.maskPath, tolerance: state.tolerance);
  }

  Future<void> _apply() async {
    final ws = ref.read(workspaceProvider);
    final page = ws.byId(state.pageId ?? '');
    final base = _base, image = _image;
    if (page == null || base == null || image == null || page.maskPath != state.mask || page.strokes.isNotEmpty) {
      return;
    }
    final run = ++_run;
    final session = _session;
    state = state.copyWith(busy: true);
    try {
      final regions = pipetteRegions(page, ws.selectedBlock, image.width, image.height);
      final png = await colourMaskPngInBackground(image, base, state.colours, state.tolerance, regions);
      if (run != _run) return;
      final file = p.join(
        ref.read(workspaceProvider.notifier).pageDir(page.id).path,
        'mask_pipette_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await File(file).writeAsBytes(png);
      final latest = ref.read(workspaceProvider).byId(page.id);
      if (run != _run || latest == null || latest.maskPath != state.mask || latest.strokes.isNotEmpty) return;
      ref
          .read(workspaceProvider.notifier)
          .edit(
            page.id,
            (p) => p.copyWith(maskPath: file),
            mergeKey: 'pipette:$session',
            mergeWindow: const Duration(days: 1),
          );
      state = state.copyWith(mask: file);
    } finally {
      if (run == _run) state = state.copyWith(busy: false);
    }
  }
}
