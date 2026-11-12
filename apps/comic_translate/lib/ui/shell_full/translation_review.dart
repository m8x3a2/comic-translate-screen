import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/batch.dart';
import '../../state/export.dart';
import '../../state/steps.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import '../settings/settings_place.dart';
import 'batch_dialogs.dart';
import 'page_grid.dart';

final translationReviewProvider = NotifierProvider<TranslationReview, bool>(TranslationReview.new);

class TranslationReview extends Notifier<bool> {
  @override
  bool build() => false;

  void open() {
    ref.read(pageGridOpenProvider.notifier).set(false);
    ref.read(settingsPanelProvider.notifier).close();
    state = true;
  }

  void close() => state = false;
}

class TranslationReviewPanel extends ConsumerWidget {
  const TranslationReviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final busy = ref.watch(stepsProvider.select((s) => s.running)) || ref.watch(batchProvider) is BatchRunning;
    final currentPage = ws.currentPage;
    if (currentPage == null) return const SizedBox.shrink();
    final chapter = chapterOf(currentPage);
    final misses = [
      for (final (pageIndex, page) in ws.pages.indexed)
        if (chapterOf(page) == chapter)
          for (final (blockIndex, block) in page.blocks.indexed)
            if (block.untranslated) (pageIndex: pageIndex, blockIndex: blockIndex, page: page, block: block),
    ];
    final currentBlock = ws.selectedBlock ?? -1;
    final next = misses.indexWhere(
      (miss) => miss.pageIndex > ws.current || (miss.pageIndex == ws.current && miss.blockIndex > currentBlock),
    );

    void show(int index) {
      final miss = misses[index];
      ref.read(workspaceProvider.notifier)
        ..select(miss.pageIndex)
        ..selectBlock(miss.blockIndex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          title: Text(l.translationReview),
          subtitle: Text(chapter.isEmpty ? l.translationReviewScope : chapter, maxLines: 1),
          trailing: IconButton(
            tooltip: l.close,
            onPressed: ref.read(translationReviewProvider.notifier).close,
            icon: const Icon(Icons.close),
          ),
        ),
        Expanded(
          child: misses.isEmpty
              ? Center(child: Text(l.translationReviewEmpty))
              : ListView.builder(
                  itemCount: misses.length,
                  itemBuilder: (context, i) {
                    final miss = misses[i];
                    return ListTile(
                      dense: true,
                      selected: miss.page.id == currentPage.id && miss.blockIndex == currentBlock,
                      title: Text(
                        '${miss.page.name} · #${miss.blockIndex + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(miss.block.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => show(i),
                    );
                  },
                ),
        ),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: busy || !misses.any((miss) => canRetryTranslation(miss.block))
                  ? null
                  : () => ref
                        .read(stepsProvider.notifier)
                        .run(ManualStep.translate, DialogBatchUi(context), retryOmissions: true),
              child: Text(l.translationReviewRetry),
            ),
            TextButton(
              onPressed: misses.isEmpty ? null : () => show(next < 0 ? 0 : next),
              child: Text(l.translationReviewNext),
            ),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }
}
