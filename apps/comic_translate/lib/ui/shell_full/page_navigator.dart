/// The mini view (the owner's idea, like the navigator of drawing programs):
/// the whole page, or for a webtoon the strip, small, with a frame around
/// what the window shows. A click or a drag in it moves the view there. A
/// long strip does not fit: the mini view scrolls along, keeping the frame
/// in sight.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One picture of the mini view: its file and where it is in the scene (the
/// page's own pixels, or the strip's).
typedef NavigatorPicture = ({String path, Rect rect});

class PageNavigator extends StatefulWidget {
  const PageNavigator({
    super.key,
    required this.pictures,
    required this.scene,
    required this.transform,
    required this.viewport,
    required this.onJump,
    this.maxHeight = 260,
  });

  final List<NavigatorPicture> pictures;

  /// The size of everything shown (the page, or the whole strip).
  final Size scene;
  final TransformationController transform;

  /// The size of the window part showing the scene.
  final Size viewport;

  /// Centre the view on this scene point.
  final ValueChanged<Offset> onJump;
  final double maxHeight;

  @override
  State<PageNavigator> createState() => _PageNavigatorState();
}

class _PageNavigatorState extends State<PageNavigator> {
  /// The scroll of a long strip, held while dragging (else the mini view
  /// would run away under the mouse).
  double? _heldOffset;

  static const _width = 160.0;

  /// Width of the bar of the whole strip.
  static const _bar = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scene = widget.scene;
    if (scene.isEmpty || widget.viewport.isEmpty) return const SizedBox.shrink();
    final k = _width / scene.width;
    final height = math.min(scene.height * k, widget.maxHeight);
    // A strip longer than the mini view: a bar of its whole length beside.
    final long = scene.height * k > height + 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _width + (long ? _bar : 0),
        height: height,
        child: ListenableBuilder(
          listenable: widget.transform,
          builder: (context, _) {
            final m = widget.transform.value;
            final s = m.entry(0, 0).abs().clamp(1e-6, 1e6);
            // What the window shows, in scene pixels.
            final seen = Rect.fromLTWH(
              -m.entry(0, 3) / s,
              -m.entry(1, 3) / s,
              widget.viewport.width / s,
              widget.viewport.height / s,
            );
            final room = math.max(0.0, scene.height * k - height);
            final offset = _heldOffset ?? (seen.center.dy * k - height / 2).clamp(0.0, room);
            Offset toScene(Offset local) => Offset(local.dx / k, (local.dy + offset) / k);
            void jump(Offset local) => widget.onJump(toScene(local));
            final mini = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => jump(d.localPosition),
              onPanStart: (d) {
                setState(() => _heldOffset = offset);
                jump(d.localPosition);
              },
              onPanUpdate: (d) => jump(d.localPosition),
              onPanEnd: (_) => setState(() => _heldOffset = null),
              onPanCancel: () => setState(() => _heldOffset = null),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: ColoredBox(color: theme.colorScheme.surfaceContainerHighest)),
                    for (final picture in widget.pictures)
                      if (picture.rect.bottom * k >= offset && picture.rect.top * k <= offset + height)
                        Positioned(
                          left: picture.rect.left * k,
                          top: picture.rect.top * k - offset,
                          width: picture.rect.width * k,
                          height: picture.rect.height * k,
                          child: Image.file(
                            File(picture.path),
                            cacheWidth: (_width * MediaQuery.devicePixelRatioOf(context)).round(),
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
                          ),
                        ),
                    Positioned(
                      left: seen.left * k,
                      top: seen.top * k - offset,
                      width: seen.width * k,
                      height: seen.height * k,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            // Red as in drawing programs: seen on black-and-white and colour pages.
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.redAccent, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (!long) return mini;
            void jumpTo(double y) => widget.onJump(Offset(seen.center.dx, (y / height).clamp(0.0, 1.0) * scene.height));
            return Row(
              children: [
                SizedBox(width: _width, child: mini),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => jumpTo(d.localPosition.dy),
                  onPanUpdate: (d) => jumpTo(d.localPosition.dy),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: CustomPaint(
                      size: Size(_bar, height),
                      painter: _WholeStrip(
                        tops: [for (final p in widget.pictures) p.rect.top / scene.height],
                        seenTop: seen.top / scene.height,
                        seenBottom: seen.bottom / scene.height,
                        background: theme.colorScheme.surfaceContainerHigh,
                        ticks: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The bar of the whole strip: a tick where each page starts, the part
/// shown in red.
class _WholeStrip extends CustomPainter {
  _WholeStrip({
    required this.tops,
    required this.seenTop,
    required this.seenBottom,
    required this.background,
    required this.ticks,
  });

  /// Page tops and the part shown, as fractions of the strip's height.
  final List<double> tops;
  final double seenTop;
  final double seenBottom;
  final Color background;
  final Color ticks;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final tick = Paint()
      ..color = ticks
      ..strokeWidth = 1;
    for (final t in tops.skip(1)) {
      final y = t * size.height;
      canvas.drawLine(Offset(3, y), Offset(size.width - 3, y), tick);
    }
    final top = seenTop.clamp(0.0, 1.0) * size.height;
    final bottom = math.max(top + 4, seenBottom.clamp(0.0, 1.0) * size.height);
    canvas.drawRect(Rect.fromLTRB(1, top, size.width - 1, bottom), Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(_WholeStrip old) =>
      old.seenTop != seenTop || old.seenBottom != seenBottom || old.tops.length != tops.length;
}
