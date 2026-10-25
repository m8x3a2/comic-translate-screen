/// Open pages with thumbnails and status (original `list_view.py`).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../../state/steps.dart';
import '../../state/workspace.dart';
import '../common/key_bindings.dart';
import '../common/labels.dart';
import '../common/panels.dart';
import 'page_grid.dart';
import 'page_numbers_field.dart';

/// Height of a page in the list: the thumbnail (76) with its padding.
const pageTileExtent = 92.0;

/// Space above the first page and below the last.
const _listPadding = 6.0;

class PageList extends ConsumerStatefulWidget {
  const PageList({super.key, this.onAdd, this.onAddAt, this.onPasteAt});

  final VoidCallback? onAdd;

  /// Files or the clipboard's pages to this place in the list (null: not now).
  final ValueChanged<int>? onAddAt;
  final ValueChanged<int>? onPasteAt;

  @override
  ConsumerState<PageList> createState() => _PageListState();
}

class _PageListState extends ConsumerState<PageList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the list just enough to show page [index] (the current page,
  /// however it was chosen: keys, grid, mini view, a click).
  void _reveal(int index) {
    if (!_scroll.hasClients || index < 0) return;
    final pos = _scroll.position;
    final top = _listPadding + index * pageTileExtent;
    final bottom = top + pageTileExtent;
    double? to;
    if (top < pos.pixels) {
      to = top - _listPadding;
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      to = bottom + _listPadding - pos.viewportDimension;
    }
    if (to == null) return;
    _scroll.animateTo(
      to.clamp(pos.minScrollExtent, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onAdd = widget.onAdd, onAddAt = widget.onAddAt, onPasteAt = widget.onPasteAt;
    ref.listen(workspaceProvider.select((w) => w.current), (_, current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(current);
      });
    });
    final ws = ref.watch(workspaceProvider);
    final running = ref.watch(batchProvider) is BatchRunning;
    final l = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              PanelToggle(Panels.pages, label: l.panelPages),
              Expanded(child: Text(l.panelPages, style: Theme.of(context).textTheme.titleSmall)),
              PageSortButton(enabled: !running && ws.pages.length > 1),
              IconButton(
                tooltip: l.pageGridOpen,
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(pageGridOpenProvider.notifier).set(true),
                icon: const Icon(Icons.grid_view),
              ),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(8, 6, 8, 2), child: PageNumbersField()),
        Expanded(
          // Dragging a page moves it (not while "Translate all" runs).
          child: ReorderableListView.builder(
            scrollController: _scroll,
            itemExtent: pageTileExtent,
            padding: const EdgeInsets.symmetric(vertical: _listPadding),
            buildDefaultDragHandles: false,
            itemCount: ws.pages.length,
            onReorderItem: (from, to) => ref.read(workspaceProvider.notifier).movePage(from, to),
            itemBuilder: (context, i) => ReorderableDragStartListener(
              key: ValueKey(('page list', ws.pages[i].id)),
              index: i,
              enabled: !running,
              child: _PageTile(
                page: ws.pages[i],
                index: i,
                selected: i == ws.current,
                picked: ws.selectedPages.contains(ws.pages[i].id),
                canRemove: !running,
                onAddAt: onAddAt,
                onPasteAt: onPasteAt,
              ),
            ),
          ),
        ),
        if (ws.selectedPages.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.pagesPicked('${ws.selectedPages.length}'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (!running)
                  IconButton(
                    tooltip: context.l10n.removePicked('${ws.selectedPages.length}'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => removePickedPages(context, ref),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
                IconButton(
                  tooltip: context.l10n.pagesPickedClear,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(workspaceProvider.notifier).clearPageSelection(),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: ws.importing ? null : onAdd,
              icon: ws.importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text(ws.importing ? context.l10n.importing : context.l10n.addPages),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Order of pages": by name or file date, either way, or turned round;
/// a note with "Undo" puts the order back.
class PageSortButton extends ConsumerWidget {
  const PageSortButton({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PopupMenuButton<PageOrder>(
      tooltip: l.pageSort,
      enabled: enabled,
      icon: const Icon(Icons.sort),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelected: (order) {
        final ws = ref.read(workspaceProvider.notifier);
        final before = ws.sortPages(order);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l.pageSortDone),
              showCloseIcon: true,
              action: SnackBarAction(label: l.keyUndo, onPressed: () => ws.setPageOrder(before)),
            ),
          );
      },
      itemBuilder: (_) => [
        for (final (order, icon, label) in [
          (PageOrder.nameUp, Icons.arrow_downward, l.pageSortNameUp),
          (PageOrder.nameDown, Icons.arrow_upward, l.pageSortNameDown),
          (PageOrder.dateUp, Icons.schedule, l.pageSortDateUp),
          (PageOrder.dateDown, Icons.update, l.pageSortDateDown),
          (PageOrder.reverse, Icons.swap_vert, l.pageSortReverse),
        ])
          PopupMenuItem(
            value: order,
            child: ListTile(dense: true, leading: Icon(icon), title: Text(label)),
          ),
      ],
    );
  }
}

/// Takes the picked pages out of the list, after asking (their files stay).
Future<void> removePickedPages(BuildContext context, WidgetRef ref) async {
  final ids = {...ref.read(workspaceProvider).selectedPages};
  if (ids.isEmpty) return;
  final l = context.l10n;
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.delete_sweep_outlined),
      title: Text(l.removePagesTitle('${ids.length}')),
      content: Text(l.removePagesBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.removePagesYes)),
      ],
    ),
  );
  if (yes ?? false) ref.read(workspaceProvider.notifier).removePages(ids);
}

/// The right-click menu of a page in the list and in the grid: pages from
/// the clipboard or files below it, removing it.
void showPageMenu(
  BuildContext context,
  WidgetRef ref,
  Offset at, {
  required PageEntry page,
  required int index,
  ValueChanged<int>? onAddAt,
  ValueChanged<int>? onPasteAt,
}) {
  final l = context.l10n;
  final picked = ref.read(workspaceProvider).selectedPages;
  showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      if (onPasteAt != null)
        PopupMenuItem(
          onTap: () => onPasteAt(index + 1),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.content_paste),
            title: Text(l.pasteBelow),
            trailing: Text(KeyBindings.of(ref.read(settingsProvider)).labelOf(ShortcutAction.paste)),
          ),
        ),
      if (onAddAt != null)
        PopupMenuItem(
          onTap: () => onAddAt(index + 1),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: Text(l.addBelow),
          ),
        ),
      PopupMenuItem(
        onTap: () => ref.read(workspaceProvider.notifier).remove(page.id),
        child: ListTile(dense: true, leading: const Icon(Icons.delete_outline), title: Text(l.removePage)),
      ),
      if (picked.length > 1 && picked.contains(page.id))
        PopupMenuItem(
          onTap: () => removePickedPages(context, ref),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l.removePicked('${picked.length}')),
          ),
        ),
    ],
  );
}

class _PageTile extends ConsumerWidget {
  const _PageTile({
    required this.page,
    required this.index,
    required this.selected,
    required this.picked,
    required this.canRemove,
    this.onAddAt,
    this.onPasteAt,
  });

  final PageEntry page;
  final int index;
  final bool selected;

  /// Among the pages selected for the steps.
  final bool picked;
  final bool canRemove;
  final ValueChanged<int>? onAddAt;
  final ValueChanged<int>? onPasteAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final step = ref.watch(stepsProvider);
    final stepHere = step.running && step.pageId == page.id;
    final status = page.status == PageStatus.running || stepHere
        ? Tooltip(
            message: stageLabel(l, stepHere ? step.stage : page.stage),
            child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : page.status == PageStatus.skipped
        ? Tooltip(
            message: l.statusSkipped(reasonLabel(l, page.reason)),
            child: Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error),
          )
        : page.isDone
        ? Tooltip(
            message: l.statusDone,
            child: Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
          )
        : const SizedBox(width: 18);
    final thumb = page.translatedPath ?? page.cleanPath ?? page.path;
    return GestureDetector(
      onSecondaryTapDown: canRemove
          ? (d) => showPageMenu(
              context,
              ref,
              d.globalPosition,
              page: page,
              index: index,
              onAddAt: onAddAt,
              onPasteAt: onPasteAt,
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Material(
          color: selected
              ? theme.colorScheme.secondaryContainer
              : picked
              ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          // Material takes a shape or a border radius, not both.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: picked ? BorderSide(color: theme.colorScheme.primary, width: 1.5) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final keys = HardwareKeyboard.instance;
              ref
                  .read(workspaceProvider.notifier)
                  .select(index, toggle: keys.isControlPressed, range: keys.isShiftPressed);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 76,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(thumb),
                        key: ValueKey(thumb),
                        cacheWidth: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${index + 1}', style: theme.textTheme.labelSmall),
                        Text(page.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  status,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
