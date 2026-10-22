/// All pages over the whole window (the owner's idea): big thumbnails, a
/// click ticks a page for the steps (no Ctrl needed), dragging a page moves
/// it, a double click opens it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/batch.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

/// The grid of pages is open.
final pageGridOpenProvider = NotifierProvider<_GridOpen, bool>(_GridOpen.new);

class _GridOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

class PageGrid extends ConsumerStatefulWidget {
  const PageGrid({super.key});

  @override
  ConsumerState<PageGrid> createState() => _PageGridState();
}

class _PageGridState extends ConsumerState<PageGrid> {
  final _focus = FocusNode();

  /// Where a dragged page would land (index), for the marker.
  int? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(pageGridOpenProvider.notifier).set(false);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);
    final locked = ref.watch(batchProvider) is BatchRunning;
    final picked = ws.pickedPageIds;
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) _close();
      },
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Text(l.pageGridTitle('${ws.pages.length}'), style: theme.textTheme.titleMedium),
                  const SizedBox(width: 16),
                  Text(l.pageGridPicked('${picked.length}'), style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  TextButton(onPressed: notifier.pickAllPages, child: Text(l.pageGridPickAll)),
                  TextButton(onPressed: notifier.clearPageSelection, child: Text(l.pageGridPickNone)),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                    label: Text(l.pageGridClose),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  locked ? l.pageGridLocked : l.pageGridHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: ws.pages.length,
                itemBuilder: (context, i) {
                  final page = ws.pages[i];
                  final tile = _GridTile(
                    page: page,
                    index: i,
                    picked: picked.contains(page.id),
                    current: i == ws.current,
                    marker: _target == i,
                    onTap: () => notifier.togglePick(i),
                    onOpen: () {
                      notifier.select(i);
                      _close();
                    },
                  );
                  if (locked) return tile;
                  return DragTarget<int>(
                    onWillAcceptWithDetails: (d) {
                      setState(() => _target = i);
                      return d.data != i;
                    },
                    onLeave: (_) => setState(() => _target = null),
                    onAcceptWithDetails: (d) {
                      setState(() => _target = null);
                      notifier.movePage(d.data, i);
                    },
                    builder: (context, _, _) => Draggable<int>(
                      data: i,
                      feedback: SizedBox(width: 150, height: 200, child: Opacity(opacity: 0.8, child: tile)),
                      childWhenDragging: Opacity(opacity: 0.3, child: tile),
                      child: tile,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.page,
    required this.index,
    required this.picked,
    required this.current,
    required this.marker,
    required this.onTap,
    required this.onOpen,
  });

  final PageEntry page;
  final int index;
  final bool picked;
  final bool current;

  /// A dragged page would land here.
  final bool marker;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = page.translatedPath ?? page.cleanPath ?? page.path;
    return Material(
      color: picked ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: marker
            ? BorderSide(color: theme.colorScheme.tertiary, width: 3)
            : picked
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(thumb),
                        key: ValueKey(thumb),
                        cacheWidth: 360,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IgnorePointer(
                        child: Checkbox(value: picked, onChanged: (_) {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${index + 1}. ${page.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: current ? FontWeight.bold : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
