/// The webtoon strip: every page one below the other without gaps, centred
/// on each other (original `webtoons/webtoon_layout_manager.py`,
/// `webtoon_manager.py`). Only the pages near the screen are built, so long
/// chapters stay light. The page in the middle of the screen is the current
/// one (the page list follows); a click on a page makes it current for
/// editing. The wheel scrolls, Ctrl + wheel zooms.
library;

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor.dart';
import '../../state/page_layout.dart';
import '../../state/workspace.dart';
import 'page_canvas.dart';

/// Where the pages of the strip are, in strip pixels (the pages' own).
class StripLayout {
  StripLayout._(this.rects, this.width, this.height);

  /// Page sizes in order; each page is centred on the one above it.
  factory StripLayout.of(List<Size> sizes) {
    final xs = <double>[];
    var x = 0.0;
    for (final (i, s) in sizes.indexed) {
      if (i > 0) x += seamDx(sizes[i - 1].width.round(), s.width.round());
      xs.add(x);
    }
    final left = xs.isEmpty ? 0.0 : xs.reduce(math.min);
    var y = 0.0, width = 0.0;
    final rects = <Rect>[];
    for (final (i, s) in sizes.indexed) {
      rects.add(Rect.fromLTWH(xs[i] - left, y, s.width, s.height));
      y += s.height;
      width = math.max(width, xs[i] - left + s.width);
    }
    return StripLayout._(rects, width, y);
  }

  final List<Rect> rects;
  final double width;
  final double height;

  /// The page at height [y] (the first or last one outside the strip).
  int pageAt(double y) {
    var lo = 0, hi = rects.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (rects[mid].top <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

class WebtoonStrip extends ConsumerStatefulWidget {
  const WebtoonStrip({super.key, required this.transform, required this.readOnly, this.pan = false});

  final TransformationController transform;

  /// Dragging moves the strip in every tool (nothing can be edited).
  final bool pan;

  /// No editing on this page (a step or "Translate all" works on it).
  final bool Function(PageEntry page) readOnly;

  @override
  ConsumerState<WebtoonStrip> createState() => WebtoonStripState();
}

class WebtoonStripState extends ConsumerState<WebtoonStrip> {
  Size _viewport = Size.zero;
  StripLayout? _layout;

  /// The page the strip shows as current: when the current page changes
  /// elsewhere (page list, keys), the strip scrolls to it.
  String? _shown;
  var _fitted = false;

  @override
  void initState() {
    super.initState();
    widget.transform.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(WebtoonStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transform != widget.transform) {
      oldWidget.transform.removeListener(_onTransform);
      widget.transform.addListener(_onTransform);
    }
  }

  @override
  void dispose() {
    widget.transform.removeListener(_onTransform);
    super.dispose();
  }

  double get _scale => widget.transform.value.entry(0, 0).abs().clamp(1e-3, 1e3);
  double get _tx => widget.transform.value.entry(0, 3);
  double get _ty => widget.transform.value.entry(1, 3);

  void _set(double scale, double tx, double ty) {
    final layout = _layout;
    if (layout != null && _viewport.height > 0) {
      // Half a screen of room above the first and below the last page.
      final room = _viewport.height / 2;
      final lowest = _viewport.height - room - layout.height * scale;
      ty = ty.clamp(math.min(lowest, room), room);
    }
    widget.transform.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// The strip as wide as the screen, the current page at the top.
  void fit() {
    final layout = _layout;
    if (layout == null || _viewport.isEmpty || !mounted) return;
    final s = _viewport.width * 0.98 / layout.width;
    final ws = ref.read(workspaceProvider);
    final top = ws.pages.isEmpty ? 0.0 : layout.rects[ws.current.clamp(0, layout.rects.length - 1)].top;
    _set(s, (_viewport.width - layout.width * s) / 2, -top * s);
  }

  void _scrollTo(int index) {
    final layout = _layout;
    if (layout == null || index < 0 || index >= layout.rects.length) return;
    _set(_scale, _tx, -layout.rects[index].top * _scale);
  }

  /// The page in the middle of the screen becomes the current one.
  void _onTransform() {
    final layout = _layout;
    if (!mounted || layout == null || _viewport.isEmpty) return;
    final ws = ref.read(workspaceProvider);
    final i = layout.pageAt((_viewport.height / 2 - _ty) / _scale);
    if (i < ws.pages.length && i != ws.current && ref.read(_dragging) == 0) {
      _shown = ws.pages[i].id;
      ref.read(workspaceProvider.notifier).focusPage(i);
    }
    setState(() {});
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed) {
        final f = math.exp(-s.scrollDelta.dy / 300);
        final scale = (_scale * f).clamp(0.02, 32.0);
        final k = scale / _scale;
        final p = s.localPosition;
        _set(scale, p.dx - (p.dx - _tx) * k, p.dy - (p.dy - _ty) * k);
      } else if (keys.isShiftPressed) {
        _set(_scale, _tx - s.scrollDelta.dy, _ty);
      } else {
        _set(_scale, _tx - s.scrollDelta.dx, _ty - s.scrollDelta.dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workspaceProvider);
    final pages = ws.pages;
    final sizes = [for (final p in pages) ref.watch(pageSizeProvider(p.path))];
    if (sizes.any((s) => !s.hasValue)) return const Center(child: CircularProgressIndicator());
    final layout = _layout = StripLayout.of([for (final s in sizes) s.value!]);
    final editor = ref.watch(editorProvider);
    final current = ws.currentPage;
    if (current != null && current.id != _shown) {
      _shown = current.id;
      final index = ws.current;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitted ? _scrollTo(index) : null);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.biggest != _viewport) {
          _viewport = constraints.biggest;
          if (!_fitted) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => fit());
          }
        }
        // The pages within a screen above and below what is shown.
        final top = -_ty / _scale, bottom = (_viewport.height - _ty) / _scale;
        final room = bottom - top;
        final shown = [
          for (var i = 0; i < pages.length; i++)
            if (layout.rects[i].bottom >= top - room && layout.rects[i].top <= bottom + room) i,
        ];
        return Listener(
          onPointerSignal: _wheel,
          child: InteractiveViewer(
            transformationController: widget.transform,
            constrained: false,
            scaleEnabled: false,
            panEnabled: editor.tool == EditorTool.pan || widget.pan,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Upper pages last: what reaches below a page is drawn over
                  // the page under it.
                  for (final i in shown.reversed)
                    Positioned.fromRect(
                      rect: layout.rects[i],
                      child: _StripPage(
                        key: ValueKey(pages[i].id),
                        page: pages[i],
                        size: layout.rects[i].size,
                        transform: widget.transform,
                        readOnly: widget.readOnly(pages[i]),
                        active: i == ws.current,
                        reachBelow: i + 1 < pages.length ? layout.rects[i + 1].height.round() : 0,
                        onActivate: () {
                          _shown = pages[i].id;
                          ref.read(workspaceProvider.notifier).focusPage(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pointers held down on the strip: the current page does not follow the
/// scrolling while a drag (a box, a brush stroke) is in progress.
final _dragging = NotifierProvider<_DragCount, int>(_DragCount.new);

class _DragCount extends Notifier<int> {
  @override
  int build() => 0;

  void add(int d) => state = math.max(0, state + d);
}

class _StripPage extends ConsumerWidget {
  const _StripPage({
    super.key,
    required this.page,
    required this.size,
    required this.transform,
    required this.readOnly,
    required this.active,
    required this.reachBelow,
    required this.onActivate,
  });

  final PageEntry page;
  final Size size;
  final TransformationController transform;
  final bool readOnly;
  final bool active;
  final int reachBelow;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Listener(
    onPointerDown: (_) => ref.read(_dragging.notifier).add(1),
    onPointerUp: (_) => ref.read(_dragging.notifier).add(-1),
    onPointerCancel: (_) => ref.read(_dragging.notifier).add(-1),
    child: PageCanvas(
      page: page,
      size: size,
      transform: transform,
      readOnly: readOnly,
      active: active,
      onActivate: onActivate,
      strip: true,
      reachBelow: reachBelow,
    ),
  );
}
