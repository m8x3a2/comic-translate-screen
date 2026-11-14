/// The colour pipette and the fill of the drawing tool: both look at the
/// page as it is drawn (the cleaned page with the touch-ups).
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background.dart';
import 'editor.dart';
import 'workspace.dart';

class PaintToolsState {
  const PaintToolsState({this.hover, this.busy = false});

  /// ARGB colour under the mouse while picking a colour; null otherwise.
  final int? hover;

  /// A fill is being worked out.
  final bool busy;
}

final paintToolsProvider = NotifierProvider<PaintToolsNotifier, PaintToolsState>(PaintToolsNotifier.new);

class PaintToolsNotifier extends Notifier<PaintToolsState> {
  /// The page image the colours are read from, and its file.
  RgbImage? _image;
  String? _path;
  Future<RgbImage?>? _loading;

  @override
  PaintToolsState build() => const PaintToolsState();

  Future<RgbImage?> _imageOf(PageEntry page) {
    final path = page.finalBasePath;
    if (_path == path) {
      if (_image != null) return Future.value(_image);
      if (_loading != null) return _loading!;
    }
    _path = path;
    _image = null;
    final load = readImageInBackground(path).then<RgbImage?>((image) {
      if (_path == path) _image = image;
      return image;
    }, onError: (Object _) => null);
    _loading = load;
    return load;
  }

  static int? _colourAt(RgbImage image, Point2 at) {
    final x = at.x.floor(), y = at.y.floor();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return null;
    final i = image.offset(x, y);
    return 0xFF000000 | (image.data[i] << 16) | (image.data[i + 1] << 8) | image.data[i + 2];
  }

  /// The mouse is at [at] on [page] while picking a colour (null: it left,
  /// or the picking ended).
  void hover(PageEntry page, Point2? at) {
    if (at == null) {
      if (state.hover != null) state = PaintToolsState(busy: state.busy);
      return;
    }
    // Touch-ups not drawn into a file yet (a project just opened): now.
    if (!page.paintsReady) unawaited(ref.read(workspaceProvider.notifier).ensurePainted(page.id));
    final image = _path == page.finalBasePath ? _image : null;
    if (image == null) {
      // Shown once the page is read.
      unawaited(_imageOf(page));
      return;
    }
    final c = _colourAt(image, at);
    if (c != state.hover) state = PaintToolsState(hover: c, busy: state.busy);
  }

  /// Takes the colour at [at] of [page] for the drawing tool.
  Future<void> pick(PageEntry page, Point2 at) async {
    final image = await _imageOf(await ref.read(workspaceProvider.notifier).ensurePainted(page.id) ?? page);
    if (!ref.mounted) return;
    final c = image == null ? null : _colourAt(image, at);
    if (c != null && ref.mounted) ref.read(editorProvider.notifier).setPaintColor(c);
  }

  /// Fills the patch at [at] of page [pageId] with the drawing colour (one
  /// undo step).
  Future<void> fill(String pageId, Point2 at) async {
    if (state.busy) return;
    state = PaintToolsState(hover: state.hover, busy: true);
    try {
      final workspace = ref.read(workspaceProvider.notifier);
      // The fill sees the touch-ups made before it.
      final page = await workspace.ensurePainted(pageId);
      if (page == null || !ref.mounted) return;
      final editor = ref.read(editorProvider);
      var runs = await floodFillInBackground(
        page.finalBasePath,
        at.x.floor(),
        at.y.floor(),
        editor.fillTolerance,
        editor.fillSpots,
      );
      if (runs.isEmpty || !ref.mounted) return;
      // Inside the selection only.
      final sel = ref.read(selectionProvider.notifier).of(pageId);
      final inside = sel == null ? runs : intersectRuns(runs, sel.runs);
      if (inside.isEmpty) return;
      runs = inside;
      workspace.addPaint(
        PaintOp(kind: PaintKind.fill, color: editor.paintColor, runs: runs),
        pageId: pageId,
      );
    } finally {
      if (ref.mounted) state = PaintToolsState(hover: state.hover);
    }
  }
}
