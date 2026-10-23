/// Recognized text and translation of the current page, editable, with the
/// look of the selected block (original source/target text edits and text
/// controls of the right panel).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../../state/editor.dart';
import '../../state/glued_words.dart';
import '../../state/steps.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import '../common/panels.dart';
import 'batch_dialogs.dart';
import 'block_style_editor.dart';
import 'find_replace.dart';

/// The find panel is open.
final findOpenProvider = NotifierProvider<_FindOpen, bool>(_FindOpen.new);

class _FindOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

class TextPanel extends ConsumerStatefulWidget {
  const TextPanel({super.key});

  @override
  ConsumerState<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends ConsumerState<TextPanel> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    final blocks = page?.blocks ?? const <TextBlock>[];
    final findOpen = ref.watch(findOpenProvider);
    final busy =
        ref.watch(batchProvider) is BatchRunning ||
        (ref.watch(stepsProvider).running && ref.watch(stepsProvider).pageId == page?.id) ||
        page?.status == PageStatus.running;
    // Keeps the selected block in view when it is chosen on the page.
    ref.listen(workspaceProvider.select((s) => (s.currentPage?.id, s.selectedBlock)), (_, next) {
      final i = next.$2;
      if (i == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _keys[i]?.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 200), alignment: 0.1);
        }
      });
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              PanelToggle(Panels.text, label: l.textPanel),
              Expanded(child: Text(l.textPanel, style: theme.textTheme.titleSmall)),
              IconButton(
                tooltip: l.splitWords,
                onPressed: busy || blocks.isEmpty ? null : () => _splitWords(context, ref),
                icon: const Icon(Icons.space_bar),
              ),
              IconButton(
                tooltip: l.findReplace,
                isSelected: findOpen,
                onPressed: () => ref.read(findOpenProvider.notifier).set(!findOpen),
                icon: const Icon(Icons.find_replace),
              ),
            ],
          ),
        ),
        if (findOpen) const FindReplacePanel(),
        if (tinyTextLinePxOf(blocks) case final px?)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tinyTextAdvice(l, ref.watch(settingsProvider), px), style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        Expanded(
          child: blocks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.noBlocksHint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => KeyedSubtree(
                    key: _keys.putIfAbsent(i, GlobalKey.new),
                    child: _BlockCard(index: i, block: blocks[i], selected: ws.selectedBlock == i, readOnly: busy),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Splits glued words on the step pages, or in [block] of the current page,
/// and says how many.
Future<void> _splitWords(BuildContext context, WidgetRef ref, {int? block}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final n = await splitGluedWordsOnPages(ref, block: block);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        n == null
            ? l.splitWordsMissing
            : n == 0
            ? l.splitWordsNone
            : l.splitWordsDone('$n'),
      ),
    ),
  );
}

class _BlockCard extends ConsumerWidget {
  const _BlockCard({required this.index, required this.block, required this.selected, required this.readOnly});

  final int index;
  final TextBlock block;
  final bool selected;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ws = ref.read(workspaceProvider.notifier);
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : () => ws.selectBlock(index),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: selected
              ? _BlockEditor(index: index, block: block, readOnly: readOnly)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: Text('${index + 1}', style: theme.textTheme.labelMedium)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.text.isEmpty ? '—' : block.text,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          if (block.translation.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(block.translation, style: theme.textTheme.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The selected block: its text and translation as fields, actions, look.
class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({required this.index, required this.block, required this.readOnly});

  final int index;
  final TextBlock block;
  final bool readOnly;

  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late final _source = TextEditingController(text: widget.block.text);
  late final _translation = TextEditingController(text: widget.block.translation);
  final _translationFocus = FocusNode();
  bool _showStyle = true;

  @override
  void didUpdateWidget(_BlockEditor old) {
    super.didUpdateWidget(old);
    // Undo, a step or find and replace changed the block.
    if (_source.text != widget.block.text) _source.text = widget.block.text;
    if (_translation.text != widget.block.translation) _translation.text = widget.block.translation;
  }

  @override
  void dispose() {
    _source.dispose();
    _translation.dispose();
    _translationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.read(workspaceProvider.notifier);
    final steps = ref.watch(stepsProvider);
    final busy = widget.readOnly || steps.running || ref.watch(batchProvider) is BatchRunning;
    final i = widget.index;
    ref.listen(focusTranslationProvider, (_, _) => _translationFocus.requestFocus());
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${i + 1}', style: theme.textTheme.labelLarge),
            const Spacer(),
            IconButton(
              tooltip: l.recognizeBlock,
              visualDensity: VisualDensity.compact,
              onPressed: busy
                  ? null
                  : () => ref.read(stepsProvider.notifier).run(ManualStep.recognize, DialogBatchUi(context), block: i),
              icon: const Icon(Icons.abc, size: 20),
            ),
            IconButton(
              tooltip: l.splitWordsBlock,
              visualDensity: VisualDensity.compact,
              onPressed: busy || widget.block.text.trim().isEmpty ? null : () => _splitWords(context, ref, block: i),
              icon: const Icon(Icons.space_bar, size: 20),
            ),
            IconButton(
              tooltip: l.translateBlock,
              visualDensity: VisualDensity.compact,
              onPressed: busy
                  ? null
                  : () => ref.read(stepsProvider.notifier).run(ManualStep.translate, DialogBatchUi(context), block: i),
              icon: const Icon(Icons.translate, size: 20),
            ),
            IconButton(
              tooltip: l.deleteBlock,
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : () => ws.deleteBlock(i),
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
            IconButton(
              tooltip: l.deselect,
              visualDensity: VisualDensity.compact,
              onPressed: () => ws.selectBlock(null),
              icon: const Icon(Icons.expand_less, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _source,
          readOnly: busy,
          minLines: 1,
          maxLines: 6,
          style: theme.textTheme.bodySmall,
          decoration: deco(l.sourceText),
          onChanged: (v) => ws.changeBlock(i, (b) => b.text = v, mergeKey: 'text:$i'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _translation,
          focusNode: _translationFocus,
          readOnly: busy,
          minLines: 2,
          maxLines: 8,
          decoration: deco(l.translationText),
          onChanged: (v) => ws.changeBlock(i, (b) => b.translation = v, mergeKey: 'tr:$i'),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showStyle = !_showStyle),
            icon: Icon(_showStyle ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(l.textLook),
          ),
        ),
        if (_showStyle)
          IgnorePointer(
            ignoring: busy,
            child: BlockStyleEditor(index: i),
          ),
      ],
    );
  }
}

/// What to do about tiny text: the High level when a lighter one is chosen
/// for comics, else a larger screenshot.
String tinyTextAdvice(AppLocalizations l, AppSettings settings, double px) =>
    settings.contentKind == ContentKind.comics && settings.activeTextPrep != 'fatality_comix'
    ? l.tinyTextTryHigh('${px.round()}')
    : l.tinyTextLarger('${px.round()}');
