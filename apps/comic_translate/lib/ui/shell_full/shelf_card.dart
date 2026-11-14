/// The shelf beside the page: bubbles and pictures put away from one page,
/// taken out on another with a click.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/shelf.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

class ShelfCard extends ConsumerWidget {
  const ShelfCard({super.key, this.readOnly = false});

  /// A step or "Translate all" works on the page: nothing is put or taken.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(shelfProvider);
    final picked = ref.watch(workspaceProvider.select((s) => s.blockSelection));
    final shelf = ref.read(shelfProvider.notifier);
    return Card(
      child: SizedBox(
        width: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.shelf, style: theme.textTheme.titleSmall)),
                  IconButton(
                    tooltip: l.close,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref.read(shelfOpenProvider.notifier).set(false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              Tooltip(
                message: l.shelfPutHelp,
                child: TextButton.icon(
                  onPressed: readOnly || picked.isEmpty ? null : () => shelf.putBubbles(picked),
                  icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                  label: Text(l.shelfPutBubbles('${picked.length}')),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  child: Text(l.shelfEmpty, style: theme.textTheme.bodySmall),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (i, item) in items.indexed)
                        ListTile(
                          key: ValueKey(item),
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 4),
                          enabled: !readOnly,
                          leading: item.picture != null
                              ? SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Image.file(
                                    File(item.picture!.path),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            item.picture != null ? l.shelfPicture : _bubbleText(item, l.shelfBubbleEmpty),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(l.shelfTakeHelp),
                          onTap: () => unawaited(shelf.take(i)),
                          trailing: IconButton(
                            tooltip: l.shelfThrow,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => shelf.remove(i),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _bubbleText(ShelfItem item, String empty) {
    final b = item.block!;
    final t = b.translation.trim().isNotEmpty ? b.translation : b.text;
    return t.trim().isEmpty ? empty : t.trim();
  }
}
