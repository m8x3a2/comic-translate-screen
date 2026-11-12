/// Editor tools of the page viewer (original `image_viewer.py` tools: pan,
/// box, brush, eraser; text items are moved on their own).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EditorTool {
  /// Move around the page; click a box or a text to select it.
  pan,

  /// Draw, select, move and resize text boxes (where the text is on the
  /// original page).
  boxes,

  /// Move, resize and rotate the translated text.
  text,

  /// Paint the parts to clean.
  brush,

  /// Remove parts of the mask.
  eraser,

  /// "Fit to letters": a click shrinks a piece of the mask to the letters in
  /// it; Shift + click picks several for the button (new in this project).
  fit,
}

/// What the viewer shows.
enum ViewMode {
  /// The original page.
  original,

  /// The cleaned page with the translation drawn over it (the original until
  /// cleaned).
  result,

  /// What cleaning works on (the original, or the cleaned page) with the
  /// mask over it and no translation (the owner's idea).
  mask,
}

class EditorState {
  const EditorState({
    this.tool = EditorTool.pan,
    this.view = ViewMode.result,
    this.brushSize = 25,
    this.showBoxes = true,
    this.fitMargin = fitMaskMargin,
    this.fitPicks = const [],
    this.fitPage,
    this.maskOnly = false,
  });

  /// The mask view shows the mask alone: white on black, without the page.
  final bool maskOnly;

  final EditorTool tool;
  final ViewMode view;

  /// Brush and eraser diameter in page pixels (the original's default: 25).
  final double brushSize;

  /// Boxes are drawn in the pan tool too.
  final bool showBoxes;

  /// "Fit to letters": the margin around the letters, in page pixels.
  final int fitMargin;

  /// "Fit to letters": the pieces picked with Shift + click (a point in
  /// each), on the page [fitPage].
  final List<Point2> fitPicks;
  final String? fitPage;

  bool get paints => tool == EditorTool.brush || tool == EditorTool.eraser;

  /// The picks of the page [pageId] (none on another page).
  List<Point2> picksOf(String? pageId) => pageId != null && pageId == fitPage ? fitPicks : const [];

  EditorState copyWith({
    EditorTool? tool,
    ViewMode? view,
    double? brushSize,
    bool? showBoxes,
    int? fitMargin,
    List<Point2>? fitPicks,
    String? fitPage,
    bool? maskOnly,
  }) => EditorState(
    maskOnly: maskOnly ?? this.maskOnly,
    tool: tool ?? this.tool,
    view: view ?? this.view,
    brushSize: brushSize ?? this.brushSize,
    showBoxes: showBoxes ?? this.showBoxes,
    fitMargin: fitMargin ?? this.fitMargin,
    fitPicks: fitPicks ?? this.fitPicks,
    fitPage: fitPicks == null ? this.fitPage : fitPage,
  );
}

/// Most margin of "Fit to letters", in pixels.
const maxFitMargin = 12;

/// Counts requests to focus the selected block's translation in the text
/// panel (double click on a text in the viewer).
final focusTranslationProvider = NotifierProvider<FocusRequest, int>(FocusRequest.new);

class FocusRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

const minBrushSize = 2.0;
const maxBrushSize = 200.0;

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(EditorNotifier.new);

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void setTool(EditorTool tool) {
    // The mask tools open the mask view, the text tool the translation.
    final view = switch (tool) {
      EditorTool.pan || EditorTool.boxes => state.view,
      EditorTool.text => ViewMode.result,
      EditorTool.brush || EditorTool.eraser || EditorTool.fit => ViewMode.mask,
    };
    state = state.copyWith(tool: tool, view: view);
    if (tool != EditorTool.fit) clearFitPicks();
  }

  void setView(ViewMode view) {
    final tool = switch (view) {
      ViewMode.original when state.tool != EditorTool.boxes => EditorTool.pan,
      // No translation is shown to edit.
      ViewMode.mask when state.tool == EditorTool.text => EditorTool.pan,
      _ => state.tool,
    };
    state = state.copyWith(view: view, tool: tool);
  }

  void toggleMaskOnly() => state = state.copyWith(maskOnly: !state.maskOnly);

  void setBrushSize(double size) => state = state.copyWith(brushSize: size.clamp(minBrushSize, maxBrushSize));

  void toggleBoxes() => state = state.copyWith(showBoxes: !state.showBoxes);

  void setFitMargin(int margin) => state = state.copyWith(fitMargin: margin.clamp(0, maxFitMargin));

  /// Picks the piece at [point] of page [pageId], or unpicks it when a pick
  /// is that close ([near] page pixels). Picks of another page are dropped.
  void toggleFitPick(String pageId, Point2 point, {double near = 0}) {
    final picks = [...state.picksOf(pageId)];
    final i = picks.indexWhere((p) => (p.x - point.x).abs() <= near && (p.y - point.y).abs() <= near);
    i >= 0 ? picks.removeAt(i) : picks.add(point);
    state = state.copyWith(fitPicks: picks, fitPage: pageId);
  }

  void clearFitPicks() => state = state.copyWith(fitPicks: const [], fitPage: null);
}
