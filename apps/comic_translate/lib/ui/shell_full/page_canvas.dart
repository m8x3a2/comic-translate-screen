/// The page and everything drawn over it, in page pixels: the image, the
/// mask being painted, the translation, the boxes; and the gestures of the
/// current tool (original `image_viewer.py`, `drawing_manager.py`,
/// `rectangle.py`, `text_item.py`).
///
/// Drags are previewed locally and become one undo step when released.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ct_core/ct_core.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestEntry, BoxHitTestResult, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pipeline/page_pipeline.dart';
import '../../render/image_tiles.dart';
import '../../render/mask_raster.dart';
import '../../render/text_renderer.dart';
import '../../state/app_state.dart';
import '../../state/editor.dart';
import '../../state/page_layout.dart';
import '../../state/paint_tools.dart';
import '../../state/pipette.dart';
import '../../state/shelf.dart';
import '../../state/workspace.dart';
import '../common/key_bindings.dart';
import 'fit_mask_action.dart';

/// Handle size on screen, in logical pixels.
const _handle = 9.0;

/// Smallest box drawn by hand, in page pixels.
const _minBox = 6;

class PageCanvas extends ConsumerStatefulWidget {
  const PageCanvas({
    super.key,
    required this.page,
    required this.size,
    required this.transform,
    this.readOnly = false,
    this.active = true,
    this.onActivate,
    this.strip = false,
    this.reachBelow = 0,
  });

  final PageEntry page;

  /// The page size in pixels.
  final Size size;

  /// The viewer's zoom and pan (handles keep their size on screen; the
  /// middle mouse button pans in every tool).
  final TransformationController transform;

  /// A step or "Translate all" works on the page: no editing.
  final bool readOnly;

  /// The page is the current one (the webtoon strip shows others too: they
  /// show no selection and become current when clicked, see [onActivate]).
  final bool active;
  final VoidCallback? onActivate;

  /// Shown in the webtoon strip: what reaches below the page (text, the
  /// cleaned part of the next page) is drawn over the page below; on its own
  /// the page is cut at its edges.
  final bool strip;

  /// Rows of the next page that boxes may reach into (webtoon strip).
  final int reachBelow;

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvasState();
}

enum _Mode {
  tap,
  picked,
  area,
  newBox,
  moveBox,
  resizeBox,
  moveText,
  resizeText,
  rotateText,
  paint,
  pan,
  fit,
  pick,

  /// A touch-up stroke of the drawing tool.
  draw,

  /// The fill of the drawing tool.
  fill,

  /// The colour pipette of the drawing tool.
  colour,

  /// An outline of the area mode: a lasso, a rectangle, an ellipse, or a
  /// click of the polygon.
  shape,

  /// A picture dragged, or one of its corners.
  movePicture,
  resizePicture,
}

/// A drag in progress.
class _Drag {
  _Drag(this.mode, this.start, {this.index, this.handle, this.rect, this.angle = 0});

  final _Mode mode;
  final Offset start;
  final int? index;

  /// Corner or edge being dragged (0–7 clockwise from top-left).
  final int? handle;

  /// The box or text box at the start.
  final Rect? rect;
  final double angle;

  Offset current = Offset.zero;
  Rect? draft;
  double draftAngle = 0;
  final points = <Point2>[];
  var moved = false;

  /// A pan started with Ctrl + the left button: left without moving, it is
  /// a Ctrl + click that picks the bubble under it.
  var ctrlClick = false;
  var panned = 0.0;

  /// Shift + click: a straight line from the end of the last stroke; its end
  /// follows the mouse until the button is let go.
  var line = false;
}

class _PageCanvasState extends ConsumerState<PageCanvas> {
  ImageTiles? _mask;
  String? _maskPath;

  /// The page before cleaning, for touch-ups that bring it back.
  ImageTiles? _original;
  String? _originalPath;

  /// The pictures laid on the page, by file.
  final _pictures = <String, ui.Image>{};
  final _picturesLoading = <String>{};

  _Drag? _drag;
  Offset? _hover;

  /// The last click on a text, to notice a double click.
  (int, DateTime)? _lastTextClick;

  /// Ctrl or Space is held: the left button moves the page in any tool, as
  /// in drawing programs.
  var _grab = false;
  var _inside = false;

  /// Shift is held: a click of the brush or eraser draws a straight line.
  var _shift = false;

  /// Alt is held: a click of the drawing tool takes a colour.
  var _alt = false;

  /// The key of "Peek at the original" is held: the page before any change
  /// is shown, nothing over it.
  var _peek = false;
  PhysicalKeyboardKey? _peekKey;

  /// The corners of the polygon being clicked (area mode), and the last
  /// click, to notice a double click.
  var _poly = <Point2>[];
  (Offset, DateTime)? _lastPolyClick;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _mask?.dispose();
    _original?.dispose();
    for (final image in _pictures.values) {
      image.dispose();
    }
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    final space = !typing && keys.logicalKeysPressed.contains(LogicalKeyboardKey.space);
    final grab = keys.isControlPressed || space;
    if (grab != _grab && mounted) setState(() => _grab = grab);
    final shift = keys.isShiftPressed;
    if (shift != _shift && mounted) setState(() => _shift = shift);
    // Matched like every shortcut (by the key's place, whatever the
    // keyboard layout); it lasts while that key is held.
    if (e is KeyDownEvent &&
        KeyBindings.of(ref.read(settingsProvider)).actionFor(e, typing: typing) == ShortcutAction.peekOriginal) {
      _peekKey = e.physicalKey;
    } else if (_peekKey != null &&
        (e.physicalKey == _peekKey && e is KeyUpEvent || !keys.physicalKeysPressed.contains(_peekKey))) {
      _peekKey = null;
    }
    final peek = _peekKey != null;
    if (peek != _peek && mounted) setState(() => _peek = peek);
    final alt = keys.isAltPressed;
    if (alt != _alt && mounted) {
      setState(() => _alt = alt);
      _hoverColour();
    }
    // The polygon being clicked: Enter closes it, Backspace takes the last
    // corner back, Esc drops it.
    if (_poly.isNotEmpty && !typing && e is KeyDownEvent && mounted) {
      if (e.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _poly = []);
        return true;
      }
      if (e.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() => _poly = _poly.sublist(0, _poly.length - 1));
        return true;
      }
      if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _closePolygon();
        return true;
      }
    }
    // Space over the page is ours (it would press the focused button).
    return e.logicalKey == LogicalKeyboardKey.space && !typing && (_inside || _drag?.mode == _Mode.pan);
  }

  double get _zoom => widget.transform.value.entry(0, 0).abs().clamp(1e-3, 1e3);

  void _ensureMask(String? path) {
    if (path == _maskPath) return;
    _maskPath = path;
    final old = _mask;
    _mask = null;
    old?.dispose();
    if (path == null) return;
    unawaited(() async {
      try {
        // In tiles: the mask of a long webtoon page is as tall as the page.
        final tiles = await loadImageTiles(path, gray: true);
        if (mounted && _maskPath == path) {
          setState(() => _mask = tiles);
        } else {
          tiles.dispose();
        }
      } on Object {
        // An unreadable mask file shows nothing; cleaning reports the error.
      }
    }());
  }

  void _ensureOriginal(String? path) {
    if (path == _originalPath) return;
    _originalPath = path;
    final old = _original;
    _original = null;
    old?.dispose();
    if (path == null) return;
    unawaited(() async {
      try {
        final tiles = await loadImageTiles(path);
        if (mounted && _originalPath == path) {
          setState(() => _original = tiles);
        } else {
          tiles.dispose();
        }
      } on Object {
        // An unreadable original shows nothing where it is brought back.
      }
    }());
  }

  /// Reads the pictures of the page not read yet, and lets go of those it
  /// has no more.
  void _ensurePictures(List<PagePicture> pictures) {
    final wanted = {for (final pic in pictures) pic.path};
    for (final gone in _pictures.keys.where((k) => !wanted.contains(k)).toList()) {
      _pictures.remove(gone)?.dispose();
    }
    for (final path in wanted) {
      if (_pictures.containsKey(path) || !_picturesLoading.add(path)) continue;
      unawaited(() async {
        try {
          final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
          final frame = await codec.getNextFrame();
          codec.dispose();
          if (mounted) {
            setState(() => _pictures[path] = frame.image);
          } else {
            frame.image.dispose();
          }
        } on Object {
          // An unreadable picture shows nothing.
        } finally {
          _picturesLoading.remove(path);
        }
      }());
    }
  }

  /// The topmost picture of the page at [p].
  int? _hitPicture(Offset p) {
    final pictures = widget.page.pictures;
    for (var i = pictures.length - 1; i >= 0; i--) {
      if (_rectOf(pictures[i].box).inflate(2 / _zoom).contains(p)) return i;
    }
    return null;
  }

  /// [r] with corner [handle] dragged by [d]; the picture keeps its shape
  /// unless [free] (Shift).
  Rect _resizePicture(Rect r, int handle, Offset d, {required bool free}) {
    final draft = _resize(r, handle, d);
    if (free || r.height == 0) return draft;
    final aspect = r.width / r.height;
    // The corner across stays put.
    final anchor = switch (handle) {
      0 => r.bottomRight,
      2 => r.bottomLeft,
      4 => r.topLeft,
      _ => r.topRight,
    };
    final w = math.max(draft.width.abs(), draft.height.abs() * aspect);
    final h = w / aspect;
    final sx = handle == 0 || handle == 6 ? -1.0 : 1.0, sy = handle == 0 || handle == 2 ? -1.0 : 1.0;
    return Rect.fromPoints(anchor, anchor + Offset(sx * w, sy * h));
  }

  /// [r] in whole pixels, as it is (a picture may reach past the edges).
  static BBox _wholeBox(Rect r) => BBox(
    math.min(r.left, r.right).round(),
    math.min(r.top, r.bottom).round(),
    math.max(r.left, r.right).round(),
    math.max(r.top, r.bottom).round(),
  );

  /// The drawing tool takes a colour with a click: its pipette, or Alt.
  bool _picksColour(EditorState editor) =>
      !widget.readOnly && editor.tool == EditorTool.draw && (editor.drawMode == DrawMode.pipette || _alt);

  /// Shows the colour under the mouse while picking one.
  void _hoverColour() {
    if (!mounted) return;
    final tools = ref.read(paintToolsProvider.notifier);
    final h = _hover;
    tools.hover(widget.page, h != null && _picksColour(ref.read(editorProvider)) ? Point2(h.dx, h.dy) : null);
  }

  /// Fills everything inside [outline] with the drawing colour (one undo
  /// step); nothing when it covers no pixel.
  void _fillOutline(List<Point2> outline) {
    var runs = polygonRuns(outline, widget.size.width.round(), widget.size.height.round());
    if (runs.isEmpty) return;
    final editor = ref.read(editorProvider);
    // The selection mode: the outline becomes the selection.
    if (editor.drawMode == DrawMode.area) {
      ref.read(selectionProvider.notifier).set(PageSelection(widget.page.id, outline, runs));
      return;
    }
    if (ref.read(selectionProvider.notifier).of(widget.page.id) case final sel?) {
      runs = intersectRuns(runs, sel.runs);
      if (runs.isEmpty) return;
    }
    ref
        .read(workspaceProvider.notifier)
        .addPaint(
          PaintOp(kind: editor.outlineKind, color: editor.paintColor, runs: runs),
          pageId: widget.page.id,
        );
  }

  void _closePolygon() {
    final corners = _poly;
    setState(() => _poly = []);
    if (corners.length >= 3) _fillOutline(corners);
  }

  /// A click of the polygon at [p]: a new corner, or the end of it (on the
  /// first corner, or a double click).
  void _polygonClick(Offset p) {
    final now = DateTime.now(), last = _lastPolyClick;
    _lastPolyClick = (p, now);
    final double =
        last != null && (last.$1 - p).distance * _zoom < 6 && now.difference(last.$2) < kDoubleTapTimeout * 1.5;
    final first = _poly.isEmpty ? null : Offset(_poly.first.x, _poly.first.y);
    if (_poly.length >= 3 && (double || (first! - p).distance * _zoom <= 10)) {
      _closePolygon();
    } else if (!double) {
      setState(() => _poly = [..._poly, Point2(p.dx, p.dy)]);
    }
  }

  /// The outline being drawn in the area mode, in page pixels; null when
  /// none. The polygon's last side follows the mouse.
  List<Offset>? _outlineDraft(EditorState editor) {
    final d = _drag;
    final shape = editor.outlineShape;
    if (shape == null) return null;
    if (shape == AreaShape.polygon) {
      if (_poly.isEmpty) return null;
      return [for (final p in _poly) Offset(p.x, p.y), ?_hover];
    }
    if (d == null || d.mode != _Mode.shape || !d.moved) return null;
    final a = Point2(d.start.dx, d.start.dy), b = Point2(d.current.dx, d.current.dy);
    final points = switch (shape) {
      AreaShape.lasso => d.points,
      AreaShape.rectangle => rectanglePoints(a, b),
      AreaShape.ellipse => ellipsePoints(a, b),
      AreaShape.polygon => const <Point2>[],
    };
    return [for (final p in points) Offset(p.x, p.y)];
  }

  // Geometry.

  Rect _rectOf(BBox b) => Rect.fromLTRB(b.x1.toDouble(), b.y1.toDouble(), b.x2.toDouble(), b.y2.toDouble());

  BBox _boxOf(Rect r) {
    final w = widget.size.width, h = widget.size.height + widget.reachBelow;
    final n = Rect.fromLTRB(
      math.min(r.left, r.right).clamp(0, w),
      math.min(r.top, r.bottom).clamp(0, h),
      math.max(r.left, r.right).clamp(0, w),
      math.max(r.top, r.bottom).clamp(0, h),
    );
    return BBox(n.left.round(), n.top.round(), n.right.round(), n.bottom.round());
  }

  /// [r] moved (not cut) onto the page: a box dragged to the edge keeps its
  /// size; only one bigger than the page is cut.
  BBox _movedOnto(Rect r) {
    final w = widget.size.width, h = widget.size.height + widget.reachBelow;
    final n = Rect.fromLTRB(
      math.min(r.left, r.right),
      math.min(r.top, r.bottom),
      math.max(r.left, r.right),
      math.max(r.top, r.bottom),
    );
    if (n.width > w || n.height > h) return _boxOf(n);
    final dx = n.left < 0 ? -n.left : (n.right > w ? w - n.right : 0.0);
    final dy = n.top < 0 ? -n.top : (n.bottom > h ? h - n.bottom : 0.0);
    final m = n.shift(Offset(dx, dy));
    final x = m.left.round().clamp(0, (w - n.width).floor()), y = m.top.round().clamp(0, (h - n.height).floor());
    return BBox(x, y, x + n.width.round(), y + n.height.round());
  }

  Rect _textArea(List<TextBlock> blocks, int i) =>
      _rectOf(textAreaOf(blocks, i, widget.size.width.round(), widget.size.height.round()));

  static List<Offset> _handles(Rect r) => [
    r.topLeft,
    r.topCenter,
    r.topRight,
    r.centerRight,
    r.bottomRight,
    r.bottomCenter,
    r.bottomLeft,
    r.centerLeft,
  ];

  /// Where the rotation handle of a text box is (above its top edge).
  Offset _rotateHandle(Rect r) => r.topCenter - Offset(0, 28 / _zoom);

  int? _hitHandle(Rect r, Offset p, {bool cornersOnly = false}) {
    final tolerance = _handle / _zoom;
    for (final (i, h) in _handles(r).indexed) {
      if (cornersOnly && i.isOdd) continue;
      if ((h - p).distance <= tolerance) return i;
    }
    return null;
  }

  /// The smallest box containing [p].
  int? _hitBlock(List<TextBlock> blocks, Offset p, Rect Function(int i) rectOf) {
    int? best;
    var bestArea = double.infinity;
    for (var i = 0; i < blocks.length; i++) {
      final r = rectOf(i).inflate(2 / _zoom);
      if (!r.contains(p)) continue;
      final area = r.width * r.height;
      if (area < bestArea) {
        best = i;
        bestArea = area;
      }
    }
    return best;
  }

  /// Translated blocks (those whose text is drawn).
  Set<int> _drawn(PageEntry page) => {...?ref.read(pageLayoutOfProvider(page.id))?.blockIndex};

  Rect _resize(Rect r, int handle, Offset d) {
    var (l, t, rr, b) = (r.left, r.top, r.right, r.bottom);
    if (handle == 0 || handle == 6 || handle == 7) l += d.dx;
    if (handle == 2 || handle == 3 || handle == 4) rr += d.dx;
    if (handle == 0 || handle == 1 || handle == 2) t += d.dy;
    if (handle == 4 || handle == 5 || handle == 6) b += d.dy;
    return Rect.fromLTRB(l, t, rr, b);
  }

  /// Where a Shift + click line starts: the end of the last brush or eraser
  /// stroke of the page (so undo moves it back too); for the drawing tool,
  /// of its last stroke.
  Offset? get _lineStart {
    final last = ref.read(editorProvider).tool == EditorTool.draw
        ? widget.page.paints.where((o) => o.isStroke).lastOrNull?.points.lastOrNull
        : widget.page.strokes.lastOrNull?.points.lastOrNull;
    return last == null ? null : Offset(last.x, last.y);
  }

  // Gestures.

  void _down(PointerDownEvent e) {
    if (e.buttons == kMiddleMouseButton || (_grab && e.buttons == kPrimaryButton)) {
      final ctrl = e.buttons == kPrimaryButton && HardwareKeyboard.instance.isControlPressed;
      setState(() => _drag = _Drag(_Mode.pan, e.localPosition)..ctrlClick = ctrl);
      return;
    }
    if (e.buttons != kPrimaryButton) return;
    // "As it will be": the left button moves the page, nothing changes.
    if (ref.read(editorProvider).preview) return;
    // A click on another page of the strip makes it the page being edited.
    if (!widget.active) widget.onActivate?.call();
    final ws = ref.read(workspaceProvider);
    final page = widget.page;
    final editor = ref.read(editorProvider);
    final p = e.localPosition;
    final selected = ws.selectedBlock;
    final blocks = page.blocks;
    // Ctrl / Shift + click on a bubble picks it with the others.
    final keys = HardwareKeyboard.instance;
    final picking = keys.isControlPressed || keys.isShiftPressed;
    final picks = ws.pickedBlocks;
    void pick(int hit) => ref.read(workspaceProvider.notifier).pickBlock(hit, range: keys.isShiftPressed);
    _Drag drag;
    if (widget.readOnly) {
      drag = _Drag(keys.isShiftPressed ? _Mode.area : _Mode.tap, p);
    } else {
      switch (editor.tool) {
        case EditorTool.brush || EditorTool.eraser:
          final from = HardwareKeyboard.instance.isShiftPressed ? _lineStart : null;
          drag = from == null
              ? (_Drag(_Mode.paint, p)..points.add(Point2(p.dx, p.dy)))
              : (_Drag(_Mode.paint, p)
                  ..line = true
                  ..points.addAll([Point2(from.dx, from.dy), Point2(p.dx, p.dy)]));
        case EditorTool.boxes:
          final sel = selected != null && selected < blocks.length ? _rectOf(blocks[selected].xyxy) : null;
          final handle = sel == null ? null : _hitHandle(sel, p);
          final hit = _hitBlock(blocks, p, (i) => _rectOf(blocks[i].xyxy));
          if (picking && hit != null) {
            pick(hit);
            drag = _Drag(_Mode.picked, p);
          } else if (handle != null && picks.isEmpty) {
            drag = _Drag(_Mode.resizeBox, p, index: selected, handle: handle, rect: sel);
          } else if (hit != null) {
            // A picked box drags the other picked ones along.
            if (!picks.contains(hit)) ref.read(workspaceProvider.notifier).selectBlock(hit);
            drag = _Drag(_Mode.moveBox, p, index: hit, rect: _rectOf(blocks[hit].xyxy));
          } else if (keys.isShiftPressed) {
            drag = _Drag(_Mode.area, p);
          } else {
            drag = _Drag(_Mode.newBox, p);
          }
        case EditorTool.text:
          final drawn = _drawn(page);
          final sel = selected != null && drawn.contains(selected) && picks.isEmpty
              ? _textArea(blocks, selected)
              : null;
          final angle = selected != null && selected < blocks.length ? (blocks[selected].style?.angle ?? 0.0) : 0.0;
          final corner = sel == null ? null : _hitHandle(sel, p, cornersOnly: true);
          if (sel != null && (_rotateHandle(sel) - p).distance <= _handle / _zoom) {
            drag = _Drag(_Mode.rotateText, p, index: selected, rect: sel, angle: angle)..draftAngle = angle;
          } else if (sel != null && corner != null) {
            drag = _Drag(_Mode.resizeText, p, index: selected, handle: corner, rect: sel);
          } else {
            final hit = _hitBlock(blocks, p, (i) => drawn.contains(i) ? _textArea(blocks, i) : Rect.zero);
            if (picking && hit != null) {
              pick(hit);
              drag = _Drag(_Mode.picked, p);
            } else if (hit != null) {
              if (!picks.contains(hit)) ref.read(workspaceProvider.notifier).selectBlock(hit);
              drag = _Drag(_Mode.moveText, p, index: hit, rect: _textArea(blocks, hit));
            } else {
              drag = _Drag(keys.isShiftPressed ? _Mode.area : _Mode.tap, p);
            }
          }
        case EditorTool.pan:
          drag = _Drag(keys.isShiftPressed ? _Mode.area : _Mode.tap, p);
        case EditorTool.fit:
          drag = _Drag(_Mode.fit, p);
        case EditorTool.pick:
          drag = _Drag(_Mode.pick, p);
        case EditorTool.pictures:
          final selection = ref.read(pictureSelectionProvider.notifier);
          final sel = selection.of(page.id);
          final selRect = sel != null && sel < page.pictures.length ? _rectOf(page.pictures[sel].box) : null;
          final corner = selRect == null ? null : _hitHandle(selRect, p, cornersOnly: true);
          final hit = _hitPicture(p);
          if (corner != null) {
            drag = _Drag(_Mode.resizePicture, p, index: sel, handle: corner, rect: selRect);
          } else if (hit != null) {
            selection.select(page.id, hit);
            drag = _Drag(_Mode.movePicture, p, index: hit, rect: _rectOf(page.pictures[hit].box));
          } else {
            selection.clear();
            drag = _Drag(_Mode.picked, p);
          }
        case EditorTool.draw when _picksColour(editor):
          drag = _Drag(_Mode.colour, p);
        case EditorTool.draw when editor.drawMode == DrawMode.fill:
          drag = _Drag(_Mode.fill, p);
        case EditorTool.draw when editor.outlineShape != null:
          drag = _Drag(_Mode.shape, p)..points.add(Point2(p.dx, p.dy));
        case EditorTool.draw:
          final from = HardwareKeyboard.instance.isShiftPressed ? _lineStart : null;
          drag = from == null
              ? (_Drag(_Mode.draw, p)..points.add(Point2(p.dx, p.dy)))
              : (_Drag(_Mode.draw, p)
                  ..line = true
                  ..points.addAll([Point2(from.dx, from.dy), Point2(p.dx, p.dy)]));
      }
    }
    setState(() => _drag = drag..current = p);
    final outlined = drag.mode == _Mode.shape && editor.outlineShape != AreaShape.polygon;
    if (drag.mode == _Mode.paint || drag.mode == _Mode.draw || outlined) {
      ref.read(strokeActiveProvider.notifier).set(true);
    }
  }

  void _move(PointerMoveEvent e) {
    final d = _drag;
    if (d == null || !mounted) return;
    if (d.mode == _Mode.pan) {
      widget.transform.value = Matrix4.translationValues(e.delta.dx, e.delta.dy, 0)..multiply(widget.transform.value);
      d.panned += e.delta.distance;
      if (d.panned >= 3) d.moved = true;
      return;
    }
    final p = e.localPosition;
    d.current = p;
    final delta = p - d.start;
    if (!d.moved && delta.distance * _zoom < 3) return;
    d.moved = true;
    switch (d.mode) {
      case _Mode.paint || _Mode.draw || _Mode.shape:
        final last = d.points.last;
        if (d.line) {
          d.points.last = Point2(p.dx, p.dy);
        } else if ((Offset(last.x, last.y) - p).distance * _zoom >= 1.5) {
          d.points.add(Point2(p.dx, p.dy));
        }
      case _Mode.newBox || _Mode.area:
        d.draft = Rect.fromPoints(d.start, p);
      case _Mode.moveBox || _Mode.moveText || _Mode.movePicture:
        d.draft = d.rect!.shift(delta);
      case _Mode.resizePicture:
        d.draft = _resizePicture(d.rect!, d.handle!, delta, free: HardwareKeyboard.instance.isShiftPressed);
      case _Mode.resizeBox || _Mode.resizeText:
        d.draft = _resize(d.rect!, d.handle!, delta);
      case _Mode.rotateText:
        final c = d.rect!.center;
        var a = (math.atan2(p.dy - c.dy, p.dx - c.dx) * 180 / math.pi + 90);
        if (a > 180) a -= 360;
        // Snaps to straight within 3 degrees.
        d.draftAngle = a.abs() < 3 ? 0 : double.parse(a.toStringAsFixed(1));
      case _Mode.tap || _Mode.picked || _Mode.pan || _Mode.fit || _Mode.pick || _Mode.fill || _Mode.colour:
        break;
    }
    setState(() {});
  }

  void _up(PointerUpEvent e) {
    final d = _drag;
    _drag = null;
    // The button is let go on the listener it was pressed on, even when this
    // page has left the window since.
    if (d == null || !mounted) return;
    ref.read(strokeActiveProvider.notifier).set(false);
    final ws = ref.read(workspaceProvider.notifier);
    switch (d.mode) {
      case _Mode.pan:
        // Ctrl + click without moving: picks the bubble with the others.
        if (d.ctrlClick && !d.moved && !widget.readOnly) _select(d.start, pick: true);
      case _Mode.picked:
        break;
      case _Mode.area:
        if (!d.moved || d.draft == null) {
          _select(d.start, pick: true);
          break;
        }
        // Bubbles whose middle is inside the rectangle join the picked ones.
        final area = d.draft!;
        final blocks = widget.page.blocks;
        ws.pickBlocks([
          for (final (i, b) in blocks.indexed)
            if (area.contains(_rectOf(b.xyxy).center)) i,
        ]);
      case _Mode.tap:
        if (!d.moved) _select(d.start);
      case _Mode.fit:
        if (d.moved) break;
        final at = Point2(d.start.dx, d.start.dy);
        if (HardwareKeyboard.instance.isShiftPressed) {
          ref.read(editorProvider.notifier).toggleFitPick(widget.page.id, at, near: _handle / _zoom);
        } else {
          unawaited(runFitMask(context, ref, [at]));
        }
      case _Mode.pick:
        if (!d.moved) unawaited(ref.read(pipetteProvider.notifier).pickAt(Point2(d.start.dx, d.start.dy)));
      case _Mode.paint:
        final erase = ref.read(editorProvider).tool == EditorTool.eraser;
        ws.addStroke(MaskStroke(points: List.of(d.points), width: ref.read(editorProvider).brushSize, erase: erase));
      case _Mode.draw:
        ws.addPaint(_paintOf(ref.read(editorProvider), List.of(d.points)), pageId: widget.page.id);
      case _Mode.fill:
        if (d.moved) break;
        unawaited(ref.read(paintToolsProvider.notifier).fill(widget.page.id, Point2(d.start.dx, d.start.dy)));
      case _Mode.movePicture || _Mode.resizePicture:
        final box = d.draft == null ? null : _wholeBox(d.draft!);
        final page = Offset.zero & widget.size;
        if (d.moved && d.mode == _Mode.movePicture && d.draft != null && !page.overlaps(d.draft!) && !widget.strip) {
          // Dropped past the edges: onto the desk beside the page.
          ref.read(shelfProvider.notifier).putPicture(widget.page.id, d.index!, at: box);
          ref.read(pictureSelectionProvider.notifier).clear();
        } else if (d.moved && box != null && box.width >= _minBox && box.height >= _minBox) {
          // A picture may lie on the page by a sliver (it is grabbed past the
          // edges too); one stretched off the page entirely comes back a piece.
          ws.setPictureBox(
            widget.page.id,
            d.index!,
            page.overlaps(d.draft!) ? box : keepOnPage(box, widget.size.width.round(), widget.size.height.round()),
          );
        }
      case _Mode.shape:
        final editor = ref.read(editorProvider);
        final a = Point2(d.start.dx, d.start.dy), b = Point2(d.current.dx, d.current.dy);
        switch (editor.outlineShape) {
          case null:
            break;
          case AreaShape.polygon:
            if (!d.moved) _polygonClick(d.start);
          case AreaShape.lasso:
            if (d.moved) _fillOutline(List.of(d.points));
          case AreaShape.rectangle:
            if (d.moved) _fillOutline(rectanglePoints(a, b));
          case AreaShape.ellipse:
            if (d.moved) _fillOutline(ellipsePoints(a, b));
        }
      case _Mode.colour:
        if (d.moved) break;
        unawaited(ref.read(paintToolsProvider.notifier).pick(widget.page, Point2(d.start.dx, d.start.dy)));
        // The pipette button picks one colour; Alt + click stays in the mode.
        ref.read(editorProvider.notifier).endPipette();
      case _Mode.newBox:
        final box = d.draft == null ? null : _boxOf(d.draft!);
        if (box != null && box.width >= _minBox && box.height >= _minBox) {
          ws.addBlock(box);
        } else if (!d.moved) {
          ws.selectBlock(null);
        }
      case _Mode.moveBox || _Mode.resizeBox:
        // Moved: the box keeps its size at the edge; resized: cut by the page.
        final box = d.draft == null ? null : (d.mode == _Mode.moveBox ? _movedOnto(d.draft!) : _boxOf(d.draft!));
        final picks = ref.read(workspaceProvider).pickedBlocks;
        if (d.moved &&
            d.mode == _Mode.moveBox &&
            d.draft != null &&
            picks.length <= 1 &&
            !widget.strip &&
            !(Offset.zero & widget.size).overlaps(d.draft!)) {
          // A bubble dropped past the edges: onto the desk beside the page.
          ref.read(shelfProvider.notifier).putBubbles([d.index!], at: _wholeBox(d.draft!));
          break;
        }
        if (d.moved && d.mode == _Mode.moveBox && picks.length > 1 && picks.contains(d.index) && d.draft != null) {
          // The picked boxes move together, as one undo step.
          final dx = (d.draft!.left - d.rect!.left).round(), dy = (d.draft!.top - d.rect!.top).round();
          if (dx != 0 || dy != 0) {
            ws.changeBlocks(picks, (b, _) {
              final r = b.xyxy;
              b.moveBoxTo(BBox(r.x1 + dx, r.y1 + dy, r.x2 + dx, r.y2 + dy));
            });
          }
        } else if (d.moved && box != null && box.width >= _minBox && box.height >= _minBox) {
          ws.changeBlock(d.index!, (b) => b.moveBoxTo(box));
        }
      case _Mode.moveText || _Mode.resizeText:
        final box = d.draft == null ? null : (d.mode == _Mode.moveText ? _movedOnto(d.draft!) : _boxOf(d.draft!));
        final picks = ref.read(workspaceProvider).pickedBlocks;
        if (d.moved && d.mode == _Mode.moveText && picks.length > 1 && picks.contains(d.index) && d.draft != null) {
          // The texts of the picked bubbles move together, as one undo step.
          final shift = d.draft!.topLeft - d.rect!.topLeft;
          final blocks = widget.page.blocks;
          final drawn = _drawn(widget.page);
          final areas = {
            for (final i in picks)
              if (drawn.contains(i) && i < blocks.length) i: _movedOnto(_textArea(blocks, i).shift(shift)),
          };
          ws.styleBlocks(areas.keys, (s, i) => s.copyWith(textBox: areas[i]));
        } else if (d.moved && box != null && box.width >= _minBox && box.height >= _minBox) {
          ws.styleBlock(d.index!, (s) => s.copyWith(textBox: box));
        } else if (!d.moved) {
          // A double click on a text: type its translation in the panel.
          final now = DateTime.now(), last = _lastTextClick;
          if (last != null && last.$1 == d.index && now.difference(last.$2) < kDoubleTapTimeout * 1.5) {
            ref.read(focusTranslationProvider.notifier).request();
            _lastTextClick = null;
          } else {
            _lastTextClick = (d.index!, now);
          }
        }
      case _Mode.rotateText:
        if (d.moved) ws.styleBlock(d.index!, (s) => s.copyWith(angle: d.draftAngle == 0 ? null : d.draftAngle));
    }
    setState(() {});
  }

  /// Selects the bubble at [p]; with Ctrl / Shift held (or [pick]) adds it
  /// to the picked ones instead.
  void _select(Offset p, {bool pick = false}) {
    final page = widget.page;
    final keys = HardwareKeyboard.instance;
    final drawn = _drawn(page);
    final view = ref.read(editorProvider).view;
    final hit = _hitBlock(
      page.blocks,
      p,
      (i) => view == ViewMode.result && drawn.contains(i)
          ? _textArea(page.blocks, i).expandToInclude(_rectOf(page.blocks[i].xyxy))
          : _rectOf(page.blocks[i].xyxy),
    );
    if (hit != null && (pick || keys.isControlPressed || keys.isShiftPressed)) {
      ref.read(workspaceProvider.notifier).pickBlock(hit, range: keys.isShiftPressed);
    } else {
      ref.read(workspaceProvider.notifier).selectBlock(hit);
    }
  }

  /// The touch-up a stroke along [points] makes with the drawing tool.
  PaintOp _paintOf(EditorState editor, List<Point2> points) => PaintOp(
    // Inside the selection only.
    clip: ref.read(selectionProvider.notifier).of(widget.page.id)?.runs ?? const [],
    kind: switch (editor.drawMode) {
      DrawMode.eraser => PaintKind.erase,
      DrawMode.original => PaintKind.original,
      _ => PaintKind.brush,
    },
    points: points,
    width: editor.paintSize,
    color: editor.paintColor,
  );

  MouseCursor _cursor(EditorState editor) {
    if (_drag?.mode == _Mode.pan) return SystemMouseCursors.grabbing;
    if (_grab) return SystemMouseCursors.grab;
    if (editor.preview) return SystemMouseCursors.grab;
    if (widget.readOnly) return SystemMouseCursors.basic;
    if (_picksColour(editor)) return SystemMouseCursors.precise;
    return switch (editor.tool) {
      EditorTool.brush || EditorTool.eraser => SystemMouseCursors.none,
      EditorTool.boxes => SystemMouseCursors.precise,
      EditorTool.text => SystemMouseCursors.move,
      EditorTool.pan => SystemMouseCursors.grab,
      EditorTool.fit || EditorTool.pick => SystemMouseCursors.precise,
      EditorTool.draw => editor.drawsStrokes ? SystemMouseCursors.none : SystemMouseCursors.precise,
      EditorTool.pictures => SystemMouseCursors.basic,
    };
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final editor = ref.watch(editorProvider);
    final selected = widget.active ? ref.watch(workspaceProvider.select((s) => s.selectedBlock)) : null;
    final picked = widget.active ? ref.watch(workspaceProvider.select((s) => s.pickedBlocks)) : const <int>{};
    final colors = Theme.of(context).colorScheme;
    // "As it will be": the translated page as export draws it, nothing over it.
    final preview = editor.preview;
    final result = editor.view == ViewMode.result || preview;
    // The mask view: what cleaning works on with the mask over it, no translation.
    final maskView = editor.view == ViewMode.mask && !preview;
    final maskOnly = maskView && editor.maskOnly;
    _ensureMask(page.maskPath);
    final layout = result ? ref.watch(pageLayoutOfProvider(page.id)) : null;
    final engines = ref.watch(pageEnginesProvider(page.id)).value;
    final overflow = (result || (maskView && !maskOnly)) && widget.strip ? page.overflowPath : null;
    final d = _drag;
    final peek = _peek;
    final showMask = !preview && !peek && (maskView || (result && (editor.paints || page.hasMask)));
    final draftStroke = d?.mode == _Mode.paint
        ? MaskStroke(points: d!.points, width: editor.brushSize, erase: editor.tool == EditorTool.eraser)
        : null;
    // The touch-ups lie over the cleaned page, under the translation.
    final draftPaint = d?.mode == _Mode.draw ? _paintOf(editor, d!.points) : null;
    ref.watch(selectionProvider);
    final selection = widget.active ? ref.read(selectionProvider.notifier).of(page.id) : null;
    final showPaints = result && !peek && (page.paints.isNotEmpty || draftPaint != null);
    final showPictures = result && !peek && page.pictures.isNotEmpty;
    if (showPictures) _ensurePictures(page.pictures);
    final pictureSelected = widget.active ? ref.watch(pictureSelectionProvider.notifier).of(page.id) : null;
    ref.watch(pictureSelectionProvider);
    // A picture dragged shows where it goes.
    final pictureDraft = d != null && d.moved && (d.mode == _Mode.movePicture || d.mode == _Mode.resizePicture)
        ? (d.index!, d.draft)
        : null;
    _ensureOriginal(
      showPaints && (paintsUseOriginal(page.paints) || draftPaint?.kind == PaintKind.original) ? page.path : null,
    );
    final picking = _picksColour(editor);
    final polygon = !widget.readOnly && editor.outlineShape == AreaShape.polygon;
    // Another tool or shape drops the polygon being clicked.
    if (!polygon && _poly.isNotEmpty) _poly = [];
    final hoverColour = picking ? ref.watch(paintToolsProvider.select((s) => s.hover)) : null;
    final hovers = editor.showsBrush || picking || polygon;
    // While text is moved or rotated, it is drawn by the overlay.
    final dragged = d != null && d.moved && (d.mode == _Mode.moveText || d.mode == _Mode.rotateText)
        ? (d.mode == _Mode.moveText && picked.length > 1 && picked.contains(d.index) ? picked : {d.index!})
        : const <int>{};
    final hiddenItems = layout == null
        ? const <int>{}
        : {
            for (final i in dragged)
              if (layout.blockIndex.indexOf(i) case final k when k >= 0) k,
          };
    final image = (result || maskView) && !peek ? page.basePath : page.path;
    // A picture reaching past the edges is grabbed there too.
    return _ReachPast(
      size: widget.size,
      grabs: _grabsPast,
      onEvent: _pastEvent,
      child: MouseRegion(
        cursor: _cursor(editor),
        onEnter: (_) => _inside = true,
        onHover: (e) {
          if (!hovers) return;
          setState(() => _hover = e.localPosition);
          if (picking) _hoverColour();
        },
        // Exit and cancel also come when the page is taken away under the mouse (another page opened or the
        // pages changed mid-drag): by then this state may be gone.
        onExit: (_) {
          _hover = null;
          _inside = false;
          if (mounted) {
            setState(() {});
            _hoverColour();
          }
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: (e) {
            if (hovers) _hover = e.localPosition;
            _move(e);
          },
          onPointerUp: _up,
          onPointerCancel: (_) {
            _drag = null;
            if (mounted) ref.read(strokeActiveProvider.notifier).set(false);
            if (mounted) setState(() {});
          },
          // The page is cut at its edges (but in the webtoon strip); pictures
          // and the handles over it are not, so a picture reaching past the
          // edge is seen whole ("As it will be" cuts it, as export does).
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Stack(
                  clipBehavior: widget.strip ? Clip.none : Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: maskOnly
                          ? const ColoredBox(color: Colors.black)
                          : needsTiles(widget.size)
                          ? TiledImage(path: image)
                          : Image.file(
                              File(image),
                              key: ValueKey(image),
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) =>
                                  const Center(child: Icon(Icons.broken_image_outlined, size: 64)),
                            ),
                    ),
                    if (showPaints)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _PaintsPainter(page.paints, draftPaint, _original)),
                        ),
                      ),
                  ],
                ),
              ),
              if (showPictures)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _PicturesPainter(page.pictures, Map.of(_pictures), pictureDraft, cut: preview),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Stack(
                  clipBehavior: widget.strip ? Clip.none : Clip.hardEdge,
                  children: [
                    if (overflow != null)
                      Positioned(
                        left: 0,
                        top: widget.size.height,
                        width: widget.size.width,
                        child: IgnorePointer(
                          child: Image.file(
                            File(overflow),
                            key: ValueKey(overflow),
                            gaplessPlayback: true,
                            fit: BoxFit.fitWidth,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (showMask)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _MaskPainter(_mask, page.strokes, draftStroke, solid: maskOnly)),
                        ),
                      ),
                    if (layout != null && engines != null && !peek)
                      Positioned.fill(
                        child: RepaintBoundary(child: CustomPaint(painter: _TextPainter(layout, engines, hiddenItems))),
                      ),
                  ],
                ),
              ),
              if (!preview && !peek)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _OverlayPainter(
                      transform: widget.transform,
                      colors: colors,
                      page: page,
                      editor: editor,
                      selected: selected,
                      picked: picked,
                      layout: layout,
                      engines: engines,
                      areaOf: (i) => _textArea(page.blocks, i),
                      drag: d,
                      hover: hovers && !polygon && !widget.readOnly && !_grab ? _hover : null,
                      outline: _outlineDraft(editor),
                      selection: selection == null ? null : [for (final p in selection.outline) Offset(p.x, p.y)],
                      pictureBoxes: editor.tool == EditorTool.pictures && !widget.readOnly
                          ? [
                              for (final (i, pic) in page.pictures.indexed)
                                pictureDraft != null && pictureDraft.$1 == i && pictureDraft.$2 != null
                                    ? pictureDraft.$2!
                                    : _rectOf(pic.box),
                            ]
                          : const [],
                      pictureSelected: pictureSelected,
                      closedOutline: !polygon,
                      picking: picking,
                      hoverColour: hoverColour,
                      lineFrom: _shift && d == null ? _lineStart : null,
                      showBoxes: editor.tool == EditorTool.boxes || (editor.showBoxes && editor.tool == EditorTool.pan),
                      rotateHandle: _rotateHandle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether a press at [p] past the page's edges grabs something: a picture
  /// (or a corner of the selected one) reaching past them, a handle of the
  /// selected box or text on the edge.
  bool _grabsPast(Offset p) {
    if (!mounted || widget.readOnly || widget.strip || !widget.active) return false;
    final editor = ref.read(editorProvider);
    if (editor.preview || _grab) return false;
    final page = widget.page;
    final ws = ref.read(workspaceProvider);
    final selected = ws.selectedBlock;
    final alone = ws.pickedBlocks.isEmpty;
    switch (editor.tool) {
      case EditorTool.pictures:
        final sel = ref.read(pictureSelectionProvider.notifier).of(page.id);
        if (sel != null && sel < page.pictures.length) {
          if (_hitHandle(_rectOf(page.pictures[sel].box), p, cornersOnly: true) != null) return true;
        }
        return _hitPicture(p) != null;
      case EditorTool.boxes:
        if (!alone || selected == null || selected >= page.blocks.length) return false;
        return _hitHandle(_rectOf(page.blocks[selected].xyxy), p) != null;
      case EditorTool.text:
        if (!alone || selected == null || !_drawn(page).contains(selected)) return false;
        final area = _textArea(page.blocks, selected);
        return _hitHandle(area, p, cornersOnly: true) != null || (_rotateHandle(area) - p).distance <= _handle / _zoom;
      default:
        return false;
    }
  }

  /// A press grabbed past the page's edges, and the moves and letting go
  /// after it: as on the page.
  void _pastEvent(PointerEvent e) {
    switch (e) {
      case PointerDownEvent():
        _down(e);
      case PointerMoveEvent():
        _move(e);
      case PointerUpEvent():
        _up(e);
      case PointerCancelEvent():
        _drag = null;
        if (mounted) {
          ref.read(strokeActiveProvider.notifier).set(false);
          setState(() {});
        }
      default:
        break;
    }
  }
}

/// Sizes the page and takes presses past its edges as well, where [grabs]
/// says there is something to take (a picture reaching past them): only
/// those come to [onEvent], the rest of the window is left alone.
class _ReachPast extends SingleChildRenderObjectWidget {
  const _ReachPast({required this.size, required this.grabs, required this.onEvent, super.child});

  final Size size;
  final bool Function(Offset p) grabs;
  final void Function(PointerEvent e) onEvent;

  @override
  _RenderReachPast createRenderObject(BuildContext context) => _RenderReachPast(size, grabs, onEvent);

  @override
  void updateRenderObject(BuildContext context, _RenderReachPast renderObject) => renderObject
    ..pageSize = size
    ..grabs = grabs
    ..onEvent = onEvent;
}

/// The hit of a press past the page's edges.
class _PastEntry extends BoxHitTestEntry {
  _PastEntry(super.target, super.localPosition);
}

class _RenderReachPast extends RenderProxyBox {
  _RenderReachPast(this._pageSize, this.grabs, this.onEvent);

  Size _pageSize;
  set pageSize(Size v) {
    if (v == _pageSize) return;
    _pageSize = v;
    markNeedsLayout();
  }

  bool Function(Offset p) grabs;
  void Function(PointerEvent e) onEvent;

  @override
  void performLayout() {
    size = constraints.constrain(_pageSize);
    child?.layout(BoxConstraints.tight(size));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) return super.hitTest(result, position: position);
    if (!grabs(position)) return false;
    result.add(_PastEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (entry is _PastEntry) onEvent(event);
  }
}

/// The mask in translucent red: the generated mask, then the strokes. [solid]
/// ("mask only"): opaque white on the black page, the fill-only margin gray.
class _MaskPainter extends CustomPainter {
  _MaskPainter(this.base, this.strokes, this.draft, {this.solid = false});

  final ImageTiles? base;
  final List<MaskStroke> strokes;
  final MaskStroke? draft;
  final bool solid;

  /// Gray PNG → red with the gray value as alpha.
  static const _redFromGray = ColorFilter.matrix([0, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]);

  /// Gray PNG → white with the gray value as alpha.
  static const _whiteFromGray = ColorFilter.matrix([0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 1, 0, 0, 0, 0]);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, solid ? 1 : 0.45));
    base?.paint(canvas, Paint()..colorFilter = solid ? _whiteFromGray : _redFromGray);
    paintStrokes(canvas, [...strokes, ?draft], solid ? Colors.white : const Color(0xFFFF0000));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.base != base ||
      old.strokes != strokes ||
      old.draft != draft ||
      old.solid != solid ||
      (draft?.points.length ?? 0) > 0;
}

/// The touch-ups over the cleaned page, as [bakePaints] draws them for
/// export: the brush paints, the eraser takes touch-ups back off, "original"
/// brings back [original] (the page before cleaning).
class _PaintsPainter extends CustomPainter {
  _PaintsPainter(this.ops, this.draft, this.original);

  final List<PaintOp> ops;
  final PaintOp? draft;
  final ImageTiles? original;

  /// The shape of each fill (made once).
  static final _fills = Expando<Path>();

  /// The shape of each selection strokes are kept in (made once).
  static final _clipPaths = Expando<Path>();

  static Path _runsPath(List<int> r) {
    final path = Path();
    for (var k = 0; k + 2 < r.length; k += 3) {
      path.addRect(Rect.fromLTRB(r[k + 1].toDouble(), r[k].toDouble(), r[k + 2].toDouble(), r[k] + 1.0));
    }
    return path;
  }

  static Path _fillPath(PaintOp op) => _fills[op] ??= () {
    final path = Path();
    final r = op.runs;
    for (var k = 0; k + 2 < r.length; k += 3) {
      path.addRect(Rect.fromLTRB(r[k + 1].toDouble(), r[k].toDouble(), r[k + 2].toDouble(), r[k] + 1.0));
    }
    return path;
  }();

  static void _stroke(Canvas canvas, PaintOp op, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = op.width;
    if (op.points.length == 1) {
      final p = op.points.single;
      canvas.drawCircle(Offset(p.x, p.y), op.width / 2, paint..style = PaintingStyle.fill);
      return;
    }
    final path = Path();
    for (final (i, p) in op.points.indexed) {
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    canvas.drawPath(path, paint);
  }

  static Rect _bounds(PaintOp op) {
    var r = Rect.fromLTWH(op.points.first.x, op.points.first.y, 0, 0);
    for (final p in op.points) {
      r = r.expandToInclude(Rect.fromLTWH(p.x, p.y, 0, 0));
    }
    return r.inflate(op.width / 2 + 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final op in [...ops, ?draft]) {
      // An eraser or "original" made with an outline.
      if (!op.isStroke && op.kind != PaintKind.fill) {
        final path = _fillPath(op);
        if (op.kind == PaintKind.erase) {
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.clear
              ..isAntiAlias = false,
          );
        } else if (original case final o?) {
          final bounds = path.getBounds();
          canvas.saveLayer(bounds, Paint());
          canvas.clipRect(bounds);
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white
              ..isAntiAlias = false,
          );
          o.paint(canvas, Paint()..blendMode = BlendMode.srcIn);
          canvas.restore();
        }
        continue;
      }
      // A stroke made inside a selection stays inside it.
      final clipped = op.isStroke && op.clip.isNotEmpty;
      if (clipped) {
        canvas.save();
        canvas.clipPath(_clipPaths[op.clip] ??= _runsPath(op.clip));
      }
      switch (op.kind) {
        case PaintKind.fill:
          canvas.drawPath(
            _fillPath(op),
            Paint()
              ..color = Color(op.color)
              ..isAntiAlias = false,
          );
        case PaintKind.brush:
          _stroke(canvas, op, Paint()..color = Color(op.color));
        case PaintKind.erase:
          _stroke(canvas, op, Paint()..blendMode = BlendMode.clear);
        case PaintKind.original:
          final o = original;
          if (o == null || op.points.isEmpty) continue;
          final bounds = _bounds(op);
          canvas.saveLayer(bounds, Paint());
          canvas.clipRect(bounds);
          _stroke(canvas, op, Paint()..color = Colors.white);
          o.paint(canvas, Paint()..blendMode = BlendMode.srcIn);
          canvas.restore();
      }
      if (clipped) canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaintsPainter old) =>
      old.ops != ops || old.draft != draft || old.original != original || (draft?.points.length ?? 0) > 0;
}

/// The pictures laid on the page (memes), cut at its edges; [draft]: the
/// one being dragged and where it goes.
class _PicturesPainter extends CustomPainter {
  _PicturesPainter(this.pictures, this.images, this.draft, {this.cut = false});

  final List<PagePicture> pictures;
  final Map<String, ui.Image> images;
  final (int, Rect?)? draft;

  /// Cut at the page's edges, as export does ("As it will be").
  final bool cut;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (cut) canvas.clipRect(Offset.zero & size);
    for (final (i, pic) in pictures.indexed) {
      final image = images[pic.path];
      if (image == null) continue;
      final b = pic.box;
      var dst = Rect.fromLTRB(b.x1.toDouble(), b.y1.toDouble(), b.x2.toDouble(), b.y2.toDouble());
      if (draft case (final k, final r?) when k == i) dst = Rect.fromPoints(r.topLeft, r.bottomRight);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, pic.opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicturesPainter old) =>
      old.pictures != pictures || old.draft != draft || old.images.length != images.length || old.cut != cut;
}

/// The translation, as export draws it.
class _TextPainter extends CustomPainter {
  _TextPainter(this.layout, this.engines, this.hidden);

  final RenderLayout layout;
  final TextEngines engines;

  /// Items drawn by the overlay while dragged.
  final Set<int> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(1 / layout.scale);
    for (final (k, item) in layout.items.indexed) {
      if (!hidden.contains(k)) engines.draw(canvas, item);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TextPainter old) =>
      old.layout != layout || old.engines != engines || !setEquals(old.hidden, hidden);
}

/// Boxes, text boxes, handles, drafts and the brush outline; sizes follow
/// the zoom so they look the same on screen.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.transform,
    required this.colors,
    required this.page,
    required this.editor,
    required this.selected,
    required this.picked,
    required this.layout,
    required this.engines,
    required this.areaOf,
    required this.drag,
    required this.hover,
    this.outline,
    this.selection,
    this.closedOutline = true,
    this.pictureBoxes = const [],
    this.pictureSelected,
    this.picking = false,
    this.hoverColour,
    required this.lineFrom,
    required this.showBoxes,
    required this.rotateHandle,
  }) : super(repaint: transform);

  final TransformationController transform;
  final ColorScheme colors;
  final PageEntry page;
  final EditorState editor;
  final int? selected;

  /// Bubbles picked together (two or more), marked like the selected one.
  final Set<int> picked;
  final RenderLayout? layout;
  final TextEngines? engines;
  final Rect Function(int index) areaOf;
  final _Drag? drag;
  final Offset? hover;

  /// The outline of the area mode being drawn (page pixels), filled
  /// lightly with the drawing colour; the polygon's corners are marked.
  final List<Offset>? outline;
  final bool closedOutline;

  /// The outline of the selection of the page.
  final List<Offset>? selection;

  /// The pictures tool: where each picture lies, and the selected one.
  final List<Rect> pictureBoxes;
  final int? pictureSelected;

  /// The drawing tool takes a colour: a square by the mouse shows the one
  /// under it ([hoverColour]) and the chosen one.
  final bool picking;
  final int? hoverColour;

  /// Shift is held: where a click would start its straight line.
  final Offset? lineFrom;
  final bool showBoxes;
  final Offset Function(Rect area) rotateHandle;

  double get _zoom => transform.value.entry(0, 0).abs().clamp(1e-3, 1e3);

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / _zoom;
    final blocks = page.blocks;
    final d = drag;
    Paint line(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * px
      ..color = c;
    void handles(Rect r, {bool cornersOnly = false}) {
      for (final (i, h) in _PageCanvasState._handles(r).indexed) {
        if (cornersOnly && i.isOdd) continue;
        final rect = Rect.fromCenter(center: h, width: _handle * px, height: _handle * px);
        canvas.drawRect(rect, Paint()..color = colors.surface);
        canvas.drawRect(rect, line(colors.primary, 1.5));
      }
    }

    if (showBoxes) {
      for (final (i, b) in blocks.indexed) {
        var r = Rect.fromLTRB(b.xyxy.x1.toDouble(), b.xyxy.y1.toDouble(), b.xyxy.x2.toDouble(), b.xyxy.y2.toDouble());
        final isSel = i == selected || picked.contains(i);
        if (d != null && d.index == i && d.draft != null && (d.mode == _Mode.moveBox || d.mode == _Mode.resizeBox)) {
          r = d.draft!;
        } else if (d != null &&
            d.mode == _Mode.moveBox &&
            d.draft != null &&
            picked.contains(d.index) &&
            picked.contains(i)) {
          // The other picked boxes follow the dragged one.
          r = r.shift(d.draft!.topLeft - d.rect!.topLeft);
        }
        canvas.drawRect(r, line(isSel ? colors.tertiary : colors.primary, isSel ? 2.5 : 1.5));
        final label = TextPainter(
          text: TextSpan(
            text: ' ${i + 1} ',
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 12 * px,
              backgroundColor: isSel ? colors.tertiary : colors.primary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, r.topLeft - Offset(0, label.height));
        if (isSel && picked.isEmpty && editor.tool == EditorTool.boxes) handles(r);
      }
      if (d?.mode == _Mode.newBox && d!.draft != null) canvas.drawRect(d.draft!, line(colors.tertiary, 2));
    }

    // Shift + drag: the rectangle that picks bubbles.
    if (d?.mode == _Mode.area && d!.draft != null) {
      canvas.drawRect(d.draft!, Paint()..color = colors.tertiary.withValues(alpha: 0.12));
      _dashed(canvas, d.draft!, line(colors.tertiary, 1.5), 6 * px);
    }

    if (editor.tool == EditorTool.text && layout != null) {
      for (final i in layout!.blockIndex) {
        if (i >= blocks.length) continue;
        final isSel = i == selected || picked.contains(i);
        var r = areaOf(i);
        if (d != null && d.index == i && d.draft != null) {
          r = d.draft!;
        } else if (d != null &&
            d.mode == _Mode.moveText &&
            d.draft != null &&
            picked.contains(d.index) &&
            picked.contains(i)) {
          r = r.shift(d.draft!.topLeft - d.rect!.topLeft);
        }
        _dashed(
          canvas,
          r,
          line(isSel ? colors.tertiary : colors.primary.withValues(alpha: 0.7), isSel ? 2 : 1),
          6 * px,
        );
        if (isSel && picked.isEmpty) {
          handles(r, cornersOnly: true);
          final rh = rotateHandle(r);
          canvas.drawLine(r.topCenter, rh, line(colors.tertiary, 1.5));
          canvas.drawCircle(rh, _handle / 2 * px, Paint()..color = colors.surface);
          canvas.drawCircle(rh, _handle / 2 * px, line(colors.tertiary, 1.5));
        }
      }
    }

    // The dragged text, moved or turned.
    final e = engines;
    if (d != null &&
        d.moved &&
        e != null &&
        layout != null &&
        (d.mode == _Mode.moveText || d.mode == _Mode.rotateText)) {
      final group = d.mode == _Mode.moveText && picked.length > 1 && picked.contains(d.index) ? picked : {d.index!};
      for (final i in group) {
        final k = layout!.blockIndex.indexOf(i);
        if (k < 0) continue;
        final item = layout!.items[k];
        final s = layout!.scale;
        final shift = d.mode == _Mode.moveText ? (d.current - d.start) * s : Offset.zero;
        final moved = TextItem(
          text: item.text,
          fontSizePt: item.fontSizePt,
          x: item.x + shift.dx,
          y: item.y + shift.dy,
          width: item.width,
          height: item.height,
          color: item.color,
          vertical: item.vertical,
          block: item.block,
          angle: d.mode == _Mode.rotateText ? d.draftAngle : item.angle,
          settings: item.settings,
        );
        canvas.save();
        canvas.scale(1 / s);
        e.draw(canvas, moved);
        canvas.restore();
      }
    }

    // Pieces picked for "Fit to letters": a ringed dot where each was clicked.
    for (final pick in editor.picksOf(page.id)) {
      final c = Offset(pick.x, pick.y);
      canvas.drawCircle(c, 7 * px, Paint()..color = colors.tertiary);
      canvas.drawCircle(c, 7 * px, line(Colors.white, 2));
      canvas.drawCircle(c, 2.5 * px, Paint()..color = Colors.white);
    }

    for (final (i, r) in pictureBoxes.indexed) {
      final sel = i == pictureSelected;
      if (sel) {
        canvas.drawRect(r, line(colors.tertiary, 2));
        handles(r, cornersOnly: true);
      } else {
        _dashed(canvas, r, line(colors.primary.withValues(alpha: 0.8), 1.2), 6 * px);
      }
    }

    if (selection case final sel? when sel.length >= 3) {
      final path = Path()..addPolygon(sel, true);
      canvas.drawPath(path, Paint()..color = colors.tertiary.withValues(alpha: 0.08));
      canvas.drawPath(path, line(Colors.white, 2.5));
      final dash = line(Colors.black, 1.2);
      for (var i = 0; i < sel.length; i++) {
        final a = sel[i], b = sel[(i + 1) % sel.length];
        final len = (b - a).distance;
        if (len == 0) continue;
        final dir = (b - a) / len;
        for (var t = 0.0; t < len; t += 10 * px) {
          canvas.drawLine(a + dir * t, a + dir * math.min(t + 5 * px, len), dash);
        }
      }
    }

    if (outline case final o? when o.isNotEmpty) {
      final path = Path()..addPolygon(o, closedOutline);
      if (o.length >= 3) {
        final tint = editor.drawMode == DrawMode.area
            ? colors.tertiary
            : switch (editor.outlineKind) {
                PaintKind.erase => Colors.white,
                PaintKind.original => Colors.blue,
                _ => Color(editor.paintColor),
              };
        canvas.drawPath(Path()..addPolygon(o, true), Paint()..color = tint.withValues(alpha: 0.4));
      }
      canvas.drawPath(path, line(Colors.white, 3));
      canvas.drawPath(path, line(Colors.black, 1.2));
      if (!closedOutline) {
        for (final (i, c) in o.indexed) {
          if (i == o.length - 1) break;
          // The first corner is round: a click on it closes the polygon.
          if (i == 0) {
            canvas.drawCircle(c, 6 * px, Paint()..color = colors.tertiary);
            canvas.drawCircle(c, 6 * px, line(Colors.white, 1.5));
          } else {
            final r = Rect.fromCenter(center: c, width: 7 * px, height: 7 * px);
            canvas.drawRect(r, Paint()..color = Colors.white);
            canvas.drawRect(r, line(Colors.black, 1));
          }
        }
      }
    }

    final h = hover;
    if (h != null && picking) {
      // The colour under the mouse, and the chosen one in its corner.
      final size = 26 * px;
      final square = Rect.fromLTWH(h.dx + 14 * px, h.dy + 14 * px, size, size);
      final chosen = Rect.fromLTWH(square.right - size * 0.4, square.bottom - size * 0.4, size * 0.55, size * 0.55);
      canvas.drawRect(square.inflate(1.5 * px), Paint()..color = Colors.white);
      canvas.drawRect(square, Paint()..color = hoverColour == null ? Colors.transparent : Color(hoverColour!));
      canvas.drawRect(square, line(Colors.black, 1));
      canvas.drawRect(chosen.inflate(1.5 * px), Paint()..color = Colors.white);
      canvas.drawRect(chosen, Paint()..color = Color(editor.paintColor));
      canvas.drawRect(chosen, line(Colors.black, 1));
    } else if (h != null) {
      final r = editor.currentBrushSize / 2;
      final ink = switch (editor.tool) {
        EditorTool.eraser => Colors.black,
        EditorTool.draw => switch (editor.drawMode) {
          DrawMode.eraser => Colors.black,
          DrawMode.original => Colors.blue,
          _ => Color(editor.paintColor).computeLuminance() > 0.8 ? Colors.black54 : Color(editor.paintColor),
        },
        _ => Colors.red,
      };
      if (lineFrom case final from?) {
        canvas.drawLine(from, h, line(Colors.white, 2.5));
        canvas.drawLine(from, h, line(ink, 1.2));
      }
      canvas.drawCircle(h, r, line(Colors.white, 2.5));
      canvas.drawCircle(h, r, line(ink, 1.2));
    }
  }

  static void _dashed(Canvas canvas, Rect r, Paint paint, double dash) {
    void side(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash * 2) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
      }
    }

    side(r.topLeft, r.topRight);
    side(r.topRight, r.bottomRight);
    side(r.bottomRight, r.bottomLeft);
    side(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
