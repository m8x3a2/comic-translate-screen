/// Open pages with thumbnails and status (original `list_view.py`).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/batch.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

class PageList extends ConsumerWidget {
  const PageList({super.key, this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final running = ref.watch(batchProvider) is BatchRunning;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: ws.pages.length,
            itemBuilder: (context, i) =>
                _PageTile(page: ws.pages[i], index: i, selected: i == ws.current, canRemove: !running),
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

class _PageTile extends ConsumerWidget {
  const _PageTile({required this.page, required this.index, required this.selected, required this.canRemove});

  final PageEntry page;
  final int index;
  final bool selected;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final status = switch (page.status) {
      PageStatus.running => Tooltip(
        message: stageLabel(l, page.stage),
        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      PageStatus.done => Tooltip(
        message: l.statusDone,
        child: Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
      ),
      PageStatus.skipped => Tooltip(
        message: l.statusSkipped(reasonLabel(l, page.reason)),
        child: Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error),
      ),
      PageStatus.pending => const SizedBox(width: 18),
    };
    final thumb = page.translatedPath ?? page.path;
    return GestureDetector(
      onSecondaryTapDown: canRemove
          ? (d) => showMenu<void>(
              context: context,
              position: RelativeRect.fromLTRB(
                d.globalPosition.dx,
                d.globalPosition.dy,
                d.globalPosition.dx,
                d.globalPosition.dy,
              ),
              items: [
                PopupMenuItem(
                  onTap: () => ref.read(workspaceProvider.notifier).remove(page.id),
                  child: Text(l.removePage),
                ),
              ],
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Material(
          color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref.read(workspaceProvider.notifier).select(index),
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
