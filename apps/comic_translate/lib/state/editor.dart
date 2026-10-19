/// Editor tools of the page viewer (original `image_viewer.py` tools: pan,
/// box, brush, eraser; text items are moved on their own).
library;

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
}

/// What the viewer shows.
enum ViewMode {
  /// The original page.
  original,

  /// The cleaned page with the translation drawn over it (the original until
  /// cleaned).
  result,
}

class EditorState {
  const EditorState({
    this.tool = EditorTool.pan,
    this.view = ViewMode.result,
    this.brushSize = 25,
    this.showBoxes = true,
  });

  final EditorTool tool;
  final ViewMode view;

  /// Brush and eraser diameter in page pixels (the original's default: 25).
  final double brushSize;

  /// Boxes are drawn in the pan tool too.
  final bool showBoxes;

  bool get paints => tool == EditorTool.brush || tool == EditorTool.eraser;

  EditorState copyWith({EditorTool? tool, ViewMode? view, double? brushSize, bool? showBoxes}) => EditorState(
    tool: tool ?? this.tool,
    view: view ?? this.view,
    brushSize: brushSize ?? this.brushSize,
    showBoxes: showBoxes ?? this.showBoxes,
  );
}

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
    // Painting and editing text need the page they change.
    final view = tool == EditorTool.pan || tool == EditorTool.boxes ? state.view : ViewMode.result;
    state = state.copyWith(tool: tool, view: view);
  }

  void setView(ViewMode view) {
    final tool = view == ViewMode.original && state.tool != EditorTool.boxes ? EditorTool.pan : state.tool;
    state = state.copyWith(view: view, tool: tool);
  }

  void setBrushSize(double size) => state = state.copyWith(brushSize: size.clamp(minBrushSize, maxBrushSize));

  void toggleBoxes() => state = state.copyWith(showBoxes: !state.showBoxes);
}
