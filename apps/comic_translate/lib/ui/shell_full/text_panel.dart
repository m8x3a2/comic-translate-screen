/// Recognized text and translation of the current page (read-only until the
/// text editing of M8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/workspace.dart';
import '../common/labels.dart';

class TextPanel extends ConsumerWidget {
  const TextPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    final blocks = page?.blocks ?? const [];
    final empty = page == null || !page.isDone ? l.translateToSeeText : l.noTextFound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(l.textPanel, style: theme.textTheme.titleSmall),
        ),
        Expanded(
          child: blocks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(empty, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final b = blocks[i];
                    final selected = ws.selectedBlock == i;
                    return Material(
                      color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => ref.read(workspaceProvider.notifier).selectBlock(selected ? null : i),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 24, child: Text('${i + 1}', style: theme.textTheme.labelMedium)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      b.text,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(b.translation, style: theme.textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
