/// The desk beside the page (the shelf, laid out): bubbles and pictures
/// dragged past the page's edges lie there, beside whichever page is open,
/// and are dragged back onto a page to put them on it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/shelf.dart';
import '../common/labels.dart';

class DeskLayer extends ConsumerWidget {
  const DeskLayer({super.key, required this.transform, required this.pageSize, this.readOnly = false});

  /// The viewer's zoom and pan (page pixels to the viewer).
  final TransformationController transform;
  final Size pageSize;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shelfProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: transform,
      builder: (context, _) => Stack(
        children: [
          for (final (i, item) in items.indexed)
            _DeskItem(
              key: ValueKey(item),
              index: i,
              item: item,
              place: _placeOf(ShelfNotifier.boxOf(item), i),
              transform: transform.value,
              pageSize: pageSize,
              readOnly: readOnly,
            ),
        ],
      ),
    );
  }

  /// Where an item lies, in page pixels: an item over the page (put there
  /// before the desk) is shown beside it.
  Rect _placeOf(BBox b, int i) {
    final r = Rect.fromLTRB(b.x1.toDouble(), b.y1.toDouble(), b.x2.toDouble(), b.y2.toDouble());
    if (!(Offset.zero & pageSize).overlaps(r)) return r;
    return r.shift(Offset(pageSize.width + 40 + 24.0 * i - r.left, 0));
  }
}

class _DeskItem extends ConsumerStatefulWidget {
  const _DeskItem({
    super.key,
    required this.index,
    required this.item,
    required this.place,
    required this.transform,
    required this.pageSize,
    required this.readOnly,
  });

  final int index;
  final ShelfItem item;

  /// Page pixels.
  final Rect place;
  final Matrix4 transform;
  final Size pageSize;
  final bool readOnly;

  @override
  ConsumerState<_DeskItem> createState() => _DeskItemState();
}

class _DeskItemState extends ConsumerState<_DeskItem> {
  /// The drag so far, in page pixels.
  Offset _moved = Offset.zero;

  double get _scale => widget.transform.entry(0, 0).abs().clamp(1e-3, 1e3);

  void _drop() {
    final r = widget.place.shift(_moved);
    setState(() => _moved = Offset.zero);
    final box = BBox(r.left.round(), r.top.round(), r.right.round(), r.bottom.round());
    final shelf = ref.read(shelfProvider.notifier);
    if ((Offset.zero & widget.pageSize).overlaps(r)) {
      unawaited(shelf.take(widget.index, at: box));
    } else {
      shelf.moveItem(widget.index, box);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screen = MatrixUtils.transformRect(widget.transform, widget.place.shift(_moved));
    final item = widget.item;
    final Widget body;
    if (item.picture case final pic?) {
      body = Opacity(
        opacity: pic.opacity,
        child: Image.file(
          File(pic.path),
          fit: BoxFit.fill,
          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
        ),
      );
    } else {
      final b = item.block!;
      final text = (b.translation.trim().isNotEmpty ? b.translation : b.text).trim();
      body = ColoredBox(
        color: colors.surface.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            child: text.isEmpty
                ? Icon(Icons.chat_bubble_outline, color: colors.onSurface)
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: math.max(40, widget.place.width)),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ),
          ),
        ),
      );
    }
    return Positioned.fromRect(
      rect: screen,
      child: Tooltip(
        message: context.l10n.pasteboardHelp,
        waitDuration: const Duration(milliseconds: 800),
        child: MouseRegion(
          cursor: widget.readOnly ? SystemMouseCursors.basic : SystemMouseCursors.move,
          child: GestureDetector(
            onPanUpdate: widget.readOnly ? null : (d) => setState(() => _moved += d.delta / _scale),
            onPanEnd: widget.readOnly ? null : (_) => _drop(),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(border: Border.all(color: colors.tertiary, width: 1.5)),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
