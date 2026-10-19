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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pipeline/page_pipeline.dart';
import '../../render/mask_raster.dart';
import '../../render/text_renderer.dart';
import '../../state/editor.dart';
import '../../state/page_layout.dart';
import '../../state/workspace.dart';

/// Handle size on screen, in logical pixels.
const _handle = 9.0;

/// Smallest box drawn by hand, in page pixels.
const _minBox = 6;

class PageCanvas extends ConsumerStatefulWidget {
  const PageCanvas({super.key, required this.page, required this.size, required this.transform, this.readOnly = false});

  final PageEntry page;

  /// The page size in pixels.
  final Size size;

  /// The viewer's zoom and pan (handles keep their size on screen; the
  /// middle mouse button pans in every tool).
  final TransformationController transform;

  /// A step or "Translate all" works on the page: no editing.
  final bool readOnly;

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvasState();
}

enum _Mode { tap, newBox, moveBox, resizeBox, moveText, resizeText, rotateText, paint, pan }

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
}

class _PageCanvasState extends ConsumerState<PageCanvas> {
  ui.Image? _mask;
  String? _maskPath;

  _Drag? _drag;
  Offset? _hover;

  /// The last click on a text, to notice a double click.
  (int, DateTime)? _lastTextClick;

  @override
  void dispose() {
    _mask?.dispose();
    super.dispose();
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
        final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
        final frame = await codec.getNextFrame();
        codec.dispose();
        if (mounted && _maskPath == path) {
          setState(() => _mask = frame.image);
        } else {
          frame.image.dispose();
        }
      } on Object {
        // An unreadable mask file shows nothing; cleaning reports the error.
      }
    }());
  }

  // Geometry.

  Rect _rectOf(BBox b) => Rect.fromLTRB(b.x1.toDouble(), b.y1.toDouble(), b.x2.toDouble(), b.y2.toDouble());

  BBox _boxOf(Rect r) {
    final w = widget.size.width, h = widget.size.height;
    final n = Rect.fromLTRB(
      math.min(r.left, r.right).clamp(0, w),
      math.min(r.top, r.bottom).clamp(0, h),
      math.max(r.left, r.right).clamp(0, w),
      math.max(r.top, r.bottom).clamp(0, h),
    );
    return BBox(n.left.round(), n.top.round(), n.right.round(), n.bottom.round());
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
  Set<int> _drawn(PageEntry page) => {...?ref.read(pageLayoutProvider)?.blockIndex};

  Rect _resize(Rect r, int handle, Offset d) {
    var (l, t, rr, b) = (r.left, r.top, r.right, r.bottom);
    if (handle == 0 || handle == 6 || handle == 7) l += d.dx;
    if (handle == 2 || handle == 3 || handle == 4) rr += d.dx;
    if (handle == 0 || handle == 1 || handle == 2) t += d.dy;
    if (handle == 4 || handle == 5 || handle == 6) b += d.dy;
    return Rect.fromLTRB(l, t, rr, b);
  }

  // Gestures.

  void _down(PointerDownEvent e) {
    if (e.buttons == kMiddleMouseButton) {
      _drag = _Drag(_Mode.pan, e.localPosition);
      return;
    }
    if (e.buttons != kPrimaryButton) return;
    final ws = ref.read(workspaceProvider);
    final page = widget.page;
    final editor = ref.read(editorProvider);
    final p = e.localPosition;
    final selected = ws.selectedBlock;
    final blocks = page.blocks;
    _Drag drag;
    if (widget.readOnly) {
      drag = _Drag(_Mode.tap, p);
    } else {
      switch (editor.tool) {
        case EditorTool.brush || EditorTool.eraser:
          drag = _Drag(_Mode.paint, p)..points.add(Point2(p.dx, p.dy));
        case EditorTool.boxes:
          final sel = selected != null && selected < blocks.length ? _rectOf(blocks[selected].xyxy) : null;
          final handle = sel == null ? null : _hitHandle(sel, p);
          final hit = _hitBlock(blocks, p, (i) => _rectOf(blocks[i].xyxy));
          if (handle != null) {
            drag = _Drag(_Mode.resizeBox, p, index: selected, handle: handle, rect: sel);
          } else if (hit != null) {
            ref.read(workspaceProvider.notifier).selectBlock(hit);
            drag = _Drag(_Mode.moveBox, p, index: hit, rect: _rectOf(blocks[hit].xyxy));
          } else {
            drag = _Drag(_Mode.newBox, p);
          }
        case EditorTool.text:
          final drawn = _drawn(page);
          final sel = selected != null && drawn.contains(selected) ? _textArea(blocks, selected) : null;
          final angle = selected != null && selected < blocks.length ? (blocks[selected].style?.angle ?? 0.0) : 0.0;
          final corner = sel == null ? null : _hitHandle(sel, p, cornersOnly: true);
          if (sel != null && (_rotateHandle(sel) - p).distance <= _handle / _zoom) {
            drag = _Drag(_Mode.rotateText, p, index: selected, rect: sel, angle: angle)..draftAngle = angle;
          } else if (sel != null && corner != null) {
            drag = _Drag(_Mode.resizeText, p, index: selected, handle: corner, rect: sel);
          } else {
            final hit = _hitBlock(blocks, p, (i) => drawn.contains(i) ? _textArea(blocks, i) : Rect.zero);
            if (hit != null) {
              ref.read(workspaceProvider.notifier).selectBlock(hit);
              drag = _Drag(_Mode.moveText, p, index: hit, rect: _textArea(blocks, hit));
            } else {
              drag = _Drag(_Mode.tap, p);
            }
          }
        case EditorTool.pan:
          drag = _Drag(_Mode.tap, p);
      }
    }
    setState(() => _drag = drag..current = p);
  }

  void _move(PointerMoveEvent e) {
    final d = _drag;
    if (d == null) return;
    if (d.mode == _Mode.pan) {
      widget.transform.value = Matrix4.translationValues(e.delta.dx, e.delta.dy, 0)..multiply(widget.transform.value);
      return;
    }
    final p = e.localPosition;
    d.current = p;
    final delta = p - d.start;
    if (!d.moved && delta.distance * _zoom < 3) return;
    d.moved = true;
    switch (d.mode) {
      case _Mode.paint:
        final last = d.points.last;
        if ((Offset(last.x, last.y) - p).distance * _zoom >= 1.5) d.points.add(Point2(p.dx, p.dy));
      case _Mode.newBox:
        d.draft = Rect.fromPoints(d.start, p);
      case _Mode.moveBox || _Mode.moveText:
        d.draft = d.rect!.shift(delta);
      case _Mode.resizeBox || _Mode.resizeText:
        d.draft = _resize(d.rect!, d.handle!, delta);
      case _Mode.rotateText:
        final c = d.rect!.center;
        var a = (math.atan2(p.dy - c.dy, p.dx - c.dx) * 180 / math.pi + 90);
        if (a > 180) a -= 360;
        // Snaps to straight within 3 degrees.
        d.draftAngle = a.abs() < 3 ? 0 : double.parse(a.toStringAsFixed(1));
      case _Mode.tap || _Mode.pan:
        break;
    }
    setState(() {});
  }

  void _up(PointerUpEvent e) {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    final ws = ref.read(workspaceProvider.notifier);
    switch (d.mode) {
      case _Mode.pan:
        break;
      case _Mode.tap:
        if (!d.moved) _select(d.start);
      case _Mode.paint:
        final erase = ref.read(editorProvider).tool == EditorTool.eraser;
        ws.addStroke(MaskStroke(points: List.of(d.points), width: ref.read(editorProvider).brushSize, erase: erase));
      case _Mode.newBox:
        final box = d.draft == null ? null : _boxOf(d.draft!);
        if (box != null && box.width >= _minBox && box.height >= _minBox) {
          ws.addBlock(box);
        } else if (!d.moved) {
          ws.selectBlock(null);
        }
      case _Mode.moveBox || _Mode.resizeBox:
        final box = d.draft == null ? null : _boxOf(d.draft!);
        if (d.moved && box != null && box.width >= _minBox && box.height >= _minBox) {
          ws.changeBlock(d.index!, (b) => b.xyxy = box);
        }
      case _Mode.moveText || _Mode.resizeText:
        final box = d.draft == null ? null : _boxOf(d.draft!);
        if (d.moved && box != null && box.width >= _minBox && box.height >= _minBox) {
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

  void _select(Offset p) {
    final page = widget.page;
    final drawn = _drawn(page);
    final view = ref.read(editorProvider).view;
    final hit = _hitBlock(
      page.blocks,
      p,
      (i) => view == ViewMode.result && drawn.contains(i)
          ? _textArea(page.blocks, i).expandToInclude(_rectOf(page.blocks[i].xyxy))
          : _rectOf(page.blocks[i].xyxy),
    );
    ref.read(workspaceProvider.notifier).selectBlock(hit);
  }

  MouseCursor _cursor(EditorState editor) {
    if (widget.readOnly) return SystemMouseCursors.basic;
    return switch (editor.tool) {
      EditorTool.brush || EditorTool.eraser => SystemMouseCursors.none,
      EditorTool.boxes => SystemMouseCursors.precise,
      EditorTool.text => SystemMouseCursors.move,
      EditorTool.pan => SystemMouseCursors.grab,
    };
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final editor = ref.watch(editorProvider);
    final selected = ref.watch(workspaceProvider.select((s) => s.selectedBlock));
    final colors = Theme.of(context).colorScheme;
    final result = editor.view == ViewMode.result;
    _ensureMask(page.maskPath);
    final layout = result ? ref.watch(pageLayoutProvider) : null;
    final engines = ref.watch(textEnginesProvider).value;
    final d = _drag;
    final showMask = result && (editor.paints || page.hasMask);
    final draftStroke = d?.mode == _Mode.paint
        ? MaskStroke(points: d!.points, width: editor.brushSize, erase: editor.tool == EditorTool.eraser)
        : null;
    // While text is moved or rotated, it is drawn by the overlay.
    final dragged = d != null && d.moved && (d.mode == _Mode.moveText || d.mode == _Mode.rotateText) ? d.index : null;
    final hiddenItem = dragged == null || layout == null ? null : layout.blockIndex.indexOf(dragged);
    final image = result ? page.basePath : page.path;
    return MouseRegion(
      cursor: _cursor(editor),
      onHover: (e) => editor.paints ? setState(() => _hover = e.localPosition) : null,
      onExit: (_) => setState(() => _hover = null),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: (e) {
          if (editor.paints) _hover = e.localPosition;
          _move(e);
        },
        onPointerUp: _up,
        onPointerCancel: (_) => setState(() => _drag = null),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(image),
                key: ValueKey(image),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 64)),
              ),
            ),
            if (showMask)
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _MaskPainter(_mask, page.strokes, draftStroke))),
              ),
            if (layout != null && engines != null)
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _TextPainter(layout, engines, hiddenItem))),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _OverlayPainter(
                  transform: widget.transform,
                  colors: colors,
                  page: page,
                  editor: editor,
                  selected: selected,
                  layout: layout,
                  engines: engines,
                  areaOf: (i) => _textArea(page.blocks, i),
                  drag: d,
                  hover: editor.paints && !widget.readOnly ? _hover : null,
                  showBoxes: editor.tool == EditorTool.boxes || (editor.showBoxes && editor.tool == EditorTool.pan),
                  rotateHandle: _rotateHandle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mask in translucent red: the generated mask, then the strokes.
class _MaskPainter extends CustomPainter {
  _MaskPainter(this.base, this.strokes, this.draft);

  final ui.Image? base;
  final List<MaskStroke> strokes;
  final MaskStroke? draft;

  /// Gray PNG → red with the gray value as alpha.
  static const _redFromGray = ColorFilter.matrix([0, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.45));
    if (base != null) canvas.drawImage(base!, Offset.zero, Paint()..colorFilter = _redFromGray);
    paintStrokes(canvas, [...strokes, ?draft], const Color(0xFFFF0000));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.base != base || old.strokes != strokes || old.draft != draft || (draft?.points.length ?? 0) > 0;
}

/// The translation, as export draws it.
class _TextPainter extends CustomPainter {
  _TextPainter(this.layout, this.engines, this.hidden);

  final RenderLayout layout;
  final TextEngines engines;

  /// Item drawn by the overlay while dragged.
  final int? hidden;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(1 / layout.scale);
    for (final (k, item) in layout.items.indexed) {
      if (k != hidden) engines.draw(canvas, item);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TextPainter old) => old.layout != layout || old.engines != engines || old.hidden != hidden;
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
    required this.layout,
    required this.engines,
    required this.areaOf,
    required this.drag,
    required this.hover,
    required this.showBoxes,
    required this.rotateHandle,
  }) : super(repaint: transform);

  final TransformationController transform;
  final ColorScheme colors;
  final PageEntry page;
  final EditorState editor;
  final int? selected;
  final RenderLayout? layout;
  final TextEngines? engines;
  final Rect Function(int index) areaOf;
  final _Drag? drag;
  final Offset? hover;
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
        final isSel = i == selected;
        if (d != null && d.index == i && d.draft != null && (d.mode == _Mode.moveBox || d.mode == _Mode.resizeBox)) {
          r = d.draft!;
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
        if (isSel && editor.tool == EditorTool.boxes) handles(r);
      }
      if (d?.mode == _Mode.newBox && d!.draft != null) canvas.drawRect(d.draft!, line(colors.tertiary, 2));
    }

    if (editor.tool == EditorTool.text && layout != null) {
      for (final i in layout!.blockIndex) {
        if (i >= blocks.length) continue;
        final isSel = i == selected;
        var r = areaOf(i);
        if (d != null && d.index == i && d.draft != null) r = d.draft!;
        _dashed(
          canvas,
          r,
          line(isSel ? colors.tertiary : colors.primary.withValues(alpha: 0.7), isSel ? 2 : 1),
          6 * px,
        );
        if (isSel) {
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
      final k = layout!.blockIndex.indexOf(d.index!);
      if (k >= 0) {
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

    final h = hover;
    if (h != null) {
      final r = editor.brushSize / 2;
      canvas.drawCircle(h, r, line(Colors.white, 2.5));
      canvas.drawCircle(h, r, line(editor.tool == EditorTool.eraser ? Colors.black : Colors.red, 1.2));
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
