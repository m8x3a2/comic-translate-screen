/// The page canvas: original or translation, zoom and pan, text boxes
/// (original `image_viewer.py`; editing comes in M8).
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/workspace.dart';
import '../common/labels.dart';

class PageViewer extends ConsumerStatefulWidget {
  const PageViewer({super.key});

  @override
  ConsumerState<PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends ConsumerState<PageViewer> {
  final _transform = TransformationController();
  bool _showTranslation = true;
  bool _showBoxes = false;
  Size? _imageSize;
  Size _viewport = Size.zero;
  String? _shownPath;
  double _shownScale = 1.0;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void dispose() {
    _detach();
    _transform.dispose();
    super.dispose();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  /// Reads the image size (to fit it into the window) when the shown file
  /// changes.
  void _watchImage(String path) {
    if (path == _shownPath) return;
    final firstPage = _shownPath == null;
    final samePage = _shownPath != null && _imageSize != null;
    _shownPath = path;
    _detach();
    final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
      final old = _imageSize;
      setState(() => _imageSize = size);
      // Switching between original and an enlarged translation keeps the view.
      if (samePage && !firstPage && old != null && old != size) {
        final k = old.width / size.width;
        _transform.value = _transform.value.clone()..multiply(Matrix4.diagonal3Values(k, k, 1));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      }
    }, onError: (_, _) {});
    _stream = stream..addListener(_listener!);
  }

  void _fit() {
    final size = _imageSize;
    if (size == null || _viewport.isEmpty) return;
    final s = math.min(_viewport.width / size.width, _viewport.height / size.height) * 0.98;
    final dx = (_viewport.width - size.width * s) / 2, dy = (_viewport.height - size.height * s) / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    setState(() {});
  }

  void _zoom(double factor) {
    final c = _viewport.center(Offset.zero);
    _transform.value = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(_transform.value);
    setState(() {});
  }

  /// Screen pixels per image pixel of the shown image, times the
  /// enlargement of a translated page: zoom relative to the original page.
  double _percent(double dpr) => _transform.value.entry(0, 0) * dpr * _shownScale * 100;

  /// One original page pixel per screen pixel.
  void _actualSize() => _zoom(100 / _percent(MediaQuery.devicePixelRatioOf(context)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    if (page == null) return const SizedBox.shrink();
    ref.listen(workspaceProvider.select((s) => s.currentPage?.id), (_, _) {
      _shownPath = null;
      _imageSize = null;
    });
    final translated = _showTranslation && page.isDone;
    final path = translated ? page.translatedPath! : page.path;
    _watchImage(path);
    final scale = translated ? page.renderScale : 1.0;
    _shownScale = scale;
    final percent = _percent(MediaQuery.devicePixelRatioOf(context));
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.viewOriginal)),
                  ButtonSegment(value: true, label: Text(l.viewTranslated), enabled: page.isDone),
                ],
                selected: {translated},
                onSelectionChanged: (s) => setState(() => _showTranslation = s.first),
                showSelectedIcon: false,
              ),
              FilterChip(
                label: Text(l.showBoxes),
                selected: _showBoxes,
                onSelected: page.blocks.isEmpty ? null : (v) => setState(() => _showBoxes = v),
              ),
              if (translated && page.renderScale > 1.0)
                Tooltip(
                  message: l.pageEnlarged(page.renderScale.toStringAsFixed(1)),
                  child: Chip(
                    avatar: const Icon(Icons.zoom_out_map, size: 16),
                    label: Text('×${page.renderScale.toStringAsFixed(1)}'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = constraints.biggest;
                  if (viewport != _viewport) {
                    final first = _viewport.isEmpty;
                    _viewport = viewport;
                    if (first) WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
                  }
                  final size = _imageSize;
                  return Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: 0.02,
                        maxScale: 16,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        onInteractionUpdate: (_) => setState(() {}),
                        child: size == null
                            ? const SizedBox(width: 1, height: 1)
                            : SizedBox(
                                width: size.width,
                                height: size.height,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.file(
                                        File(path),
                                        key: ValueKey(path),
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                    if (_showBoxes)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _BoxesPainter(
                                            page.blocks,
                                            scale,
                                            ws.selectedBlock,
                                            theme.colorScheme,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Card(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l.zoomOut,
                                onPressed: () => _zoom(1 / 1.25),
                                icon: const Icon(Icons.zoom_out),
                              ),
                              SizedBox(width: 48, child: Text('${percent.round()}%', textAlign: TextAlign.center)),
                              IconButton(
                                tooltip: l.zoomIn,
                                onPressed: () => _zoom(1.25),
                                icon: const Icon(Icons.zoom_in),
                              ),
                              IconButton(
                                tooltip: l.zoomFit,
                                onPressed: _fit,
                                icon: const Icon(Icons.fit_screen_outlined),
                              ),
                              IconButton(
                                tooltip: l.zoomActual,
                                onPressed: _actualSize,
                                icon: const Icon(Icons.crop_original),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (page.status == PageStatus.running)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(stageLabel(l, page.stage)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (page.status == PageStatus.skipped)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: Card(
                            color: theme.colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                l.statusSkipped(reasonLabel(l, page.reason)),
                                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoxesPainter extends CustomPainter {
  _BoxesPainter(this.blocks, this.scale, this.selected, this.colors);

  final List<TextBlock> blocks;
  final double scale;
  final int? selected;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(2.0, size.width / 600);
    for (final (i, b) in blocks.indexed) {
      final r = Rect.fromLTRB(b.xyxy.x1 * scale, b.xyxy.y1 * scale, b.xyxy.x2 * scale, b.xyxy.y2 * scale);
      final isSelected = i == selected;
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? stroke * 2 : stroke
          ..color = isSelected ? colors.tertiary : colors.primary,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: math.max(12, stroke * 7),
            backgroundColor: colors.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, r.topLeft);
    }
  }

  @override
  bool shouldRepaint(_BoxesPainter old) => old.blocks != blocks || old.scale != scale || old.selected != selected;
}
