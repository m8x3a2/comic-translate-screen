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

  /// The mask pipette: a click on a letter adds its colour to the mask.
  pick,

  /// Touch-ups over the cleaned page: see [DrawMode] (new in this project).
  draw,

  /// Pictures laid on the page (memes): add, move, resize, remove.
  pictures,
}

/// The outline of [DrawMode.area].
enum AreaShape {
  /// Drawn by hand while the button is held.
  lasso,

  /// Clicked point by point; closed by a click on the first point, a double
  /// click or Enter.
  polygon,

  /// Dragged from corner to corner.
  rectangle,

  /// Dragged from corner to corner of its box.
  ellipse,
}

/// What the drawing tool does.
enum DrawMode {
  /// Paints the chosen colour.
  brush,

  /// Takes the touch-ups back off (the cleaned page shows again).
  eraser,

  /// Brings back the original picture where it is painted.
  original,

  /// One click fills a bubble or a patch of one colour.
  fill,

  /// Fills everything inside a drawn outline (see [AreaShape]).
  area,

  /// One click takes the colour under the mouse (Alt + click in the other
  /// modes).
  pipette,
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

const Object _same = Object();

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
    this.drawMode = DrawMode.brush,
    this.paintSize = 12,
    this.paintColor = 0xFFFFFFFF,
    this.recentColors = const [],
    this.fillTolerance = 40,
    this.fillSpots = true,
    this.preview = false,
    this.areaShape = AreaShape.lasso,
    this.eraseShape,
  });

  /// The eraser and "original" of the drawing tool work with an outline
  /// instead of a brush (null: the brush).
  final AreaShape? eraseShape;

  /// The outline the drawing tool draws now: the area mode's, or the
  /// eraser's / "original"'s when they work with one; null for a brush.
  AreaShape? get outlineShape => tool != EditorTool.draw
      ? null
      : switch (drawMode) {
          DrawMode.area => areaShape,
          DrawMode.eraser || DrawMode.original => eraseShape,
          _ => null,
        };

  /// What an outline does: fills with the colour, erases the touch-ups or
  /// brings back the original.
  PaintKind get outlineKind => switch (drawMode) {
    DrawMode.eraser => PaintKind.erase,
    DrawMode.original => PaintKind.original,
    _ => PaintKind.fill,
  };

  /// The outline the area mode draws.
  final AreaShape areaShape;

  /// What the drawing tool does.
  final DrawMode drawMode;

  /// The drawing brush diameter in page pixels.
  final double paintSize;

  /// ARGB colour of the drawing brush and the fill.
  final int paintColor;

  /// Colours used last, newest first.
  final List<int> recentColors;

  /// The fill takes in colours that differ by this much (0–255 per channel).
  final int fillTolerance;

  /// The fill covers spots inside what it fills (leftover letters).
  final bool fillSpots;

  /// "As it will be": the page as export draws it, without boxes, mask and
  /// handles; clicks do nothing.
  final bool preview;

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

  /// The drawing tool paints strokes (brush, eraser, original).
  bool get drawsStrokes =>
      tool == EditorTool.draw &&
      (drawMode == DrawMode.brush ||
          ((drawMode == DrawMode.eraser || drawMode == DrawMode.original) && eraseShape == null));

  /// A brush outline follows the mouse.
  bool get showsBrush => paints || drawsStrokes;

  /// The size of the brush in use (the mask brush or the drawing brush).
  double get currentBrushSize => tool == EditorTool.draw ? paintSize : brushSize;

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
    DrawMode? drawMode,
    double? paintSize,
    int? paintColor,
    List<int>? recentColors,
    int? fillTolerance,
    bool? fillSpots,
    bool? preview,
    AreaShape? areaShape,
    Object? eraseShape = _same,
  }) => EditorState(
    areaShape: areaShape ?? this.areaShape,
    eraseShape: identical(eraseShape, _same) ? this.eraseShape : eraseShape as AreaShape?,
    maskOnly: maskOnly ?? this.maskOnly,
    drawMode: drawMode ?? this.drawMode,
    paintSize: paintSize ?? this.paintSize,
    paintColor: paintColor ?? this.paintColor,
    recentColors: recentColors ?? this.recentColors,
    fillTolerance: fillTolerance ?? this.fillTolerance,
    fillSpots: fillSpots ?? this.fillSpots,
    preview: preview ?? this.preview,
    tool: tool ?? this.tool,
    view: view ?? this.view,
    brushSize: brushSize ?? this.brushSize,
    showBoxes: showBoxes ?? this.showBoxes,
    fitMargin: fitMargin ?? this.fitMargin,
    fitPicks: fitPicks ?? this.fitPicks,
    fitPage: fitPicks == null ? this.fitPage : fitPage,
  );
}

/// A stroke is being painted on the page (a brush of the mask or of the
/// drawing tool): the view does not zoom meanwhile, so a second finger on a
/// touchpad cannot turn the stroke into a pinch.
final strokeActiveProvider = NotifierProvider<StrokeActive, bool>(StrokeActive.new);

class StrokeActive extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool active) {
    if (state != active) state = active;
  }
}

/// A selection of the drawing tool on a page: while it is there, the
/// brush, eraser, "original" and fill work only inside it (a stencil, as in
/// drawing programs).
class PageSelection {
  const PageSelection(this.pageId, this.outline, this.runs);

  final String pageId;

  /// Its outline (page pixels), and its pixels as `y, x1, x2` runs.
  final List<Point2> outline;
  final List<int> runs;
}

final selectionProvider = NotifierProvider<SelectionNotifier, PageSelection?>(SelectionNotifier.new);

class SelectionNotifier extends Notifier<PageSelection?> {
  @override
  PageSelection? build() => null;

  void set(PageSelection selection) => state = selection;

  void clear() => state = null;

  /// The selection of page [pageId], if any.
  PageSelection? of(String? pageId) => state != null && state!.pageId == pageId ? state : null;
}

/// The picture of a page selected with the pictures tool: (page id, index).
final pictureSelectionProvider = NotifierProvider<PictureSelection, (String, int)?>(PictureSelection.new);

class PictureSelection extends Notifier<(String, int)?> {
  @override
  (String, int)? build() => null;

  void select(String pageId, int index) => state = (pageId, index);

  void clear() => state = null;

  /// The selected picture of page [pageId], if any.
  int? of(String? pageId) => state != null && state!.$1 == pageId ? state!.$2 : null;
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

/// The drawing brush may be one pixel thin (fine touch-ups).
const minPaintSize = 1.0;

/// How many recent drawing colours are kept.
const maxRecentColors = 8;

/// Most tolerance of the fill.
const maxFillTolerance = 120;
const maxBrushSize = 200.0;

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(EditorNotifier.new);

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void setTool(EditorTool tool) {
    // The mask tools open the mask view, the text tool the translation.
    final view = switch (tool) {
      EditorTool.pan || EditorTool.boxes => state.view,
      EditorTool.text || EditorTool.draw || EditorTool.pictures => ViewMode.result,
      EditorTool.brush || EditorTool.eraser || EditorTool.fit || EditorTool.pick => ViewMode.mask,
    };
    state = state.copyWith(tool: tool, view: view, preview: false);
    if (tool != EditorTool.fit) clearFitPicks();
  }

  /// The drawing mode to go back to after the pipette.
  var _beforePipette = DrawMode.brush;

  /// Picks the drawing tool in [mode].
  void setDrawMode(DrawMode mode) {
    if (mode == DrawMode.pipette && state.drawMode != DrawMode.pipette) _beforePipette = state.drawMode;
    setTool(EditorTool.draw);
    state = state.copyWith(drawMode: mode);
  }

  /// A colour was taken with the pipette button: back to what was drawn.
  void endPipette() {
    if (state.tool == EditorTool.draw && state.drawMode == DrawMode.pipette) {
      state = state.copyWith(drawMode: _beforePipette);
    }
  }

  /// Makes [argb] the drawing colour (it joins the recent ones).
  void setPaintColor(int argb) {
    final c = argb | 0xFF000000;
    state = state.copyWith(
      paintColor: c,
      recentColors: [c, ...state.recentColors.where((r) => r != c)].take(maxRecentColors).toList(),
    );
  }

  /// The size of the brush in use.
  void setCurrentBrushSize(double size) => state.tool == EditorTool.draw ? setPaintSize(size) : setBrushSize(size);

  void setPaintSize(double size) => state = state.copyWith(paintSize: size.clamp(minPaintSize, maxBrushSize));

  void setFillTolerance(int value) => state = state.copyWith(fillTolerance: value.clamp(0, maxFillTolerance));

  void toggleFillSpots() => state = state.copyWith(fillSpots: !state.fillSpots);

  void setAreaShape(AreaShape shape) => state = state.copyWith(areaShape: shape);

  /// The eraser and "original" work with [shape] (null: the brush).
  void setEraseShape(AreaShape? shape) => state = state.copyWith(eraseShape: shape);

  /// Turns "As it will be" on or off.
  void togglePreview() => state = state.copyWith(preview: !state.preview);

  void setView(ViewMode view) {
    final tool = switch (view) {
      // Touch-ups are drawn over the translated page.
      ViewMode.original ||
      ViewMode.mask when state.tool == EditorTool.draw || state.tool == EditorTool.pictures => EditorTool.pan,
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
