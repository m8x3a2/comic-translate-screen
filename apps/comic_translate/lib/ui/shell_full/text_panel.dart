/// Recognized text and translation of the current page, editable, with the
/// look of the selected block (original source/target text edits and text
/// controls of the right panel).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/block_looks.dart';
import '../../state/background.dart';
import '../../state/batch.dart';
import '../../state/editor.dart';
import '../../state/glued_words.dart';
import '../../state/steps.dart';
import '../../state/workspace.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../common/panels.dart';
import '../common/translator_history_dialog.dart';
import 'batch_dialogs.dart';
import 'block_style_editor.dart';
import 'find_replace.dart';
import 'run_editor.dart';

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
    final picked = ws.blockSelection;
    final group = picked.length > 1;
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
          // A narrow panel: "pick every bubble" goes into the look menu.
          child: LayoutBuilder(
            builder: (context, c) {
              final roomy = c.maxWidth >= _roomyHeader;
              void pickAll() => ref.read(workspaceProvider.notifier).pickAllBlocks();
              return Row(
                children: [
                  PanelToggle(Panels.text, label: l.textPanel),
                  Expanded(child: Text(l.textPanel, style: theme.textTheme.titleSmall)),
                  IconButton(
                    tooltip: l.splitWords,
                    onPressed: busy || blocks.isEmpty ? null : () => _splitWords(context, ref),
                    icon: const Icon(Icons.space_bar),
                  ),
                  _LookMenu(enabled: !busy && blocks.isNotEmpty, pickAll: roomy || blocks.length < 2 ? null : pickAll),
                  if (roomy)
                    IconButton(
                      tooltip: '${l.pickAllBlocks}\n${l.pickHint}',
                      onPressed: blocks.length < 2 ? null : pickAll,
                      icon: const Icon(Icons.select_all),
                    ),
                  IconButton(
                    tooltip: l.findReplace,
                    isSelected: findOpen,
                    onPressed: () => ref.read(findOpenProvider.notifier).set(!findOpen),
                    icon: const Icon(Icons.find_replace),
                  ),
                  // What the translator over the network answered for this page.
                  IconButton(
                    tooltip: l.historyPage,
                    onPressed: page == null ? null : () => showTranslatorHistory(context, page: page.name),
                    icon: const Icon(Icons.history),
                  ),
                ],
              );
            },
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
                  // Several bubbles picked: their shared editor first.
                  itemCount: blocks.length + (group ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, k) {
                    if (group && k == 0) return _GroupEditor(picked: picked, readOnly: busy);
                    final i = group ? k - 1 : k;
                    return KeyedSubtree(
                      key: _keys.putIfAbsent(i, GlobalKey.new),
                      child: _BlockCard(
                        index: i,
                        block: blocks[i],
                        selected: !group && ws.selectedBlock == i,
                        picked: group && picked.contains(i),
                        readOnly: busy,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// "Size as in the original" on the step pages, or in [block] of the current
/// page; says when the size of the source letters is unknown.
void _sourceSize(BuildContext context, WidgetRef ref, {int? block}) {
  if (toggleSourceSize(ref, block: block) == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.sizeFromSourceUnknown)));
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

/// "Find blocks inside": block [index] of the current page cut into its
/// columns and paragraphs (the way chosen under the arrow) as one undo step;
/// the new blocks are recognized at once when the block was. Says what
/// happened.
/// Returns into how many blocks it was cut (0: nothing found or an error);
/// [report] false: says nothing (a caller doing several reports once).
Future<int> _findInside(BuildContext context, WidgetRef ref, int index, {bool report = true}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ui = DialogBatchUi(context);
  // Taken before the wait: the button may be gone by then.
  final workspace = ref.read(workspaceProvider.notifier);
  final steps = ref.read(stepsProvider.notifier);
  final page = ref.read(workspaceProvider).currentPage;
  if (page == null || index < 0 || index >= page.blocks.length) return 0;
  final original = page.blocks[index];
  final settings = ref.read(settingsProvider);
  final mode = InsideSplit.values.firstWhere((m) => m.name == settings.splitInside, orElse: () => InsideSplit.auto);
  final List<TextBlock> parts;
  try {
    parts = await splitBlockInsideInBackground(page.path, original.copy(), mode, page.sourceOf(settings));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return 0;
  }
  if (parts.isEmpty) {
    if (report) messenger.showSnackBar(SnackBar(content: Text(l.findInsideNone)));
    return 0;
  }
  for (final b in parts) {
    b
      ..style = original.style
      ..sourceLang = original.sourceLang
      ..targetLang = original.targetLang;
  }
  if (!workspace.replaceBlock(page.id, index, original, parts)) return 0;
  if (report) messenger.showSnackBar(SnackBar(content: Text(l.findInsideDone('${parts.length}'))));
  if (original.text.trim().isNotEmpty) {
    await steps.run(ManualStep.recognize, ui, blocks: [for (var k = 0; k < parts.length; k++) index + k]);
  }
  return parts.length;
}

/// "Find blocks inside" for each of the picked bubbles, from the last one
/// (the numbers of the ones before stay); says once how many blocks came out.
Future<void> _findInsideMany(BuildContext context, WidgetRef ref, List<int> picked) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  var made = 0;
  for (final i in [...picked]..sort((a, b) => b - a)) {
    if (!context.mounted) break;
    made += await _findInside(context, ref, i, report: false);
  }
  messenger.showSnackBar(SnackBar(content: Text(made == 0 ? l.findInsideNone : l.findInsideDone('$made'))));
}

/// "Find blocks inside | ▾" of the selected block: the arrow chooses how
/// (auto, columns only, paragraphs only); the choice stays on the button.
class _FindInsideButton extends ConsumerWidget {
  const _FindInsideButton({required this.index, required this.enabled});

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.splitInside));
    void choose(InsideSplit mode) {
      ref.read(settingsProvider.notifier).change((s) => s.splitInside = mode.name);
      _findInside(context, ref, index);
    }

    String label(InsideSplit m) => switch (m) {
      InsideSplit.auto => l.findInsideAuto,
      InsideSplit.columns => l.findInsideColumns,
      InsideSplit.paragraphs => l.findInsideParagraphs,
    };
    final chosen = InsideSplit.values.firstWhere((m) => m.name == current, orElse: () => InsideSplit.auto);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '${l.findInside}\n${label(chosen)}',
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? () => _findInside(context, ref, index) : null,
          icon: const Icon(Icons.view_column_outlined, size: 20),
        ),
        MenuAnchor(
          menuChildren: [
            for (final m in InsideSplit.values)
              MenuItemButton(
                leadingIcon: Icon(m == chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
                onPressed: () => choose(m),
                child: Text(label(m)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(l.findInsideHint, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
          builder: (context, menu, _) => Tooltip(
            message: l.findInsideWhich,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? () => menu.isOpen ? menu.close() : menu.open() : null,
              child: Icon(Icons.arrow_drop_down, size: 18, color: enabled ? null : Theme.of(context).disabledColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockCard extends ConsumerWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.selected,
    required this.readOnly,
    this.picked = false,
  });

  final int index;
  final TextBlock block;
  final bool selected;
  final bool readOnly;

  /// Picked with others (Ctrl / Shift): marked, edited together above.
  final bool picked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ws = ref.read(workspaceProvider.notifier);
    return Material(
      color: selected || picked ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: picked ? BorderSide(color: theme.colorScheme.tertiary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // Ctrl / Shift + click picks bubbles for one change.
        onTap: selected
            ? null
            : () {
                final keys = HardwareKeyboard.instance;
                if (keys.isControlPressed || keys.isShiftPressed) {
                  ws.pickBlock(index, range: keys.isShiftPressed);
                } else {
                  ws.selectBlock(index);
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: selected
              ? _BlockEditor(index: index, block: block, readOnly: readOnly)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${index + 1}', style: theme.textTheme.labelMedium),
                          if (picked) Icon(Icons.check_circle, size: 16, color: theme.colorScheme.tertiary),
                          // Who speaks, when told.
                          if (block.speaker case final s?)
                            Text(
                              speakerShort(context.l10n, s),
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                        ],
                      ),
                    ),
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
                          // The translator's answer had nothing for it.
                          if (block.untranslated) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.untranslatedMark,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                            ),
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
  late final _translation = RunsController(text: widget.block.translation)..addListener(_selectionMoved);
  var _selection = const TextSelection.collapsed(offset: -1);

  /// The bar for styling words follows the selection.
  void _selectionMoved() {
    final s = _translation.selection;
    if (s != _selection && mounted) setState(() => _selection = s);
  }

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
    final settings = ref.watch(settingsProvider);
    _translation
      ..runs = widget.block.style?.runs ?? const []
      ..presets = settings.render.presets
      ..showLook = settings.showLookInPanel;
    final sel = _selection;
    final selected = sel.isValid && !sel.isCollapsed && sel.end <= widget.block.translation.length;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('${i + 1}', style: theme.textTheme.labelLarge),
            ),
            // A narrow panel: the buttons go on to a second row.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: l.recognizeBlock,
                    visualDensity: VisualDensity.compact,
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(stepsProvider.notifier)
                              .run(ManualStep.recognize, DialogBatchUi(context), block: i),
                    icon: const Icon(Icons.abc, size: 20),
                  ),
                  _FindInsideButton(index: i, enabled: !busy),
                  IconButton(
                    tooltip: l.splitWordsBlock,
                    visualDensity: VisualDensity.compact,
                    onPressed: busy || widget.block.text.trim().isEmpty
                        ? null
                        : () => _splitWords(context, ref, block: i),
                    icon: const Icon(Icons.space_bar, size: 20),
                  ),
                  IconButton(
                    tooltip: l.translateBlock,
                    visualDensity: VisualDensity.compact,
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(stepsProvider.notifier)
                              .run(ManualStep.translate, DialogBatchUi(context), block: i),
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
            ),
          ],
        ),
        _SpeakerRow(
          speaker: widget.block.speaker,
          onChanged: busy ? null : (v) => ws.changeBlock(i, (b) => b.speaker = v),
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
          decoration: deco(l.translationText).copyWith(
            helperText: widget.block.untranslated ? l.untranslatedHelp : null,
            helperMaxLines: 3,
            helperStyle: TextStyle(color: theme.colorScheme.error),
          ),
          onChanged: (v) => ws.changeBlock(i, (b) {
            // Styled words move with the text typed before them.
            final style = b.style;
            if (style != null && style.runs.isNotEmpty) {
              final moved = style.copyWith(runs: shiftRuns(style.runs, b.translation, v));
              b.style = moved.isEmpty ? null : moved;
            }
            b.translation = v;
            b.untranslated = false;
          }, mergeKey: 'tr:$i'),
        ),
        if (selected && !busy)
          RunBar(index: i, start: sel.start, end: sel.end)
        else if (widget.block.translation.isNotEmpty && !busy)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.runHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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

/// Several bubbles picked with Ctrl / Shift: what they share, changed for
/// all of them at once (who speaks, the look, the steps, delete).
class _GroupEditor extends ConsumerWidget {
  const _GroupEditor({required this.picked, required this.readOnly});

  /// The picked bubbles, in page order.
  final List<int> picked;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.read(workspaceProvider.notifier);
    final state = ref.watch(workspaceProvider);
    final page = state.currentPage;
    if (page == null) return const SizedBox.shrink();
    final shown = state.selectedBlock ?? picked.first;
    final busy = readOnly || ref.watch(stepsProvider).running || ref.watch(batchProvider) is BatchRunning;
    final speakers = {for (final i in picked) page.blocks[i].speaker};
    Widget action(String tip, IconData icon, VoidCallback? onPressed) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: busy ? null : onPressed,
      icon: Icon(icon, size: 20),
    );
    return Material(
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.tertiary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The count on a line of its own (the numbers while they are few),
            // the buttons under it: a narrow panel keeps both readable.
            Text(
              picked.length <= 20
                  ? '${l.pickedCount('${picked.length}')} (${picked.map((i) => i + 1).join(', ')})'
                  : l.pickedCount('${picked.length}'),
              style: theme.textTheme.titleSmall,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    children: [
                      action(
                        l.recognizePicked,
                        Icons.abc,
                        () => ref
                            .read(stepsProvider.notifier)
                            .run(ManualStep.recognize, DialogBatchUi(context), blocks: picked),
                      ),
                      action(
                        l.translatePicked,
                        Icons.translate,
                        () => ref
                            .read(stepsProvider.notifier)
                            .run(ManualStep.translate, DialogBatchUi(context), blocks: picked),
                      ),
                      action(
                        l.findInsidePicked,
                        Icons.view_column_outlined,
                        () => _findInsideMany(context, ref, picked),
                      ),
                      action(l.deletePicked, Icons.delete_outline, () => ws.deleteBlocks(picked)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.unpick,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ws.selectBlock(null),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            Text(l.pickedHelp('${shown + 1}'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            _SpeakerRow(
              // Different speakers: none of the buttons is on.
              speaker: speakers.length == 1 ? speakers.single : null,
              mixed: speakers.length > 1,
              onChanged: busy ? null : (v) => ws.changeBlocks(picked, (b, _) => b.speaker = v),
            ),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: busy,
              child: BlockStyleEditor(index: shown, group: picked),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Who speaks: — / M / F / N" of the selected block: the translation takes
/// the matching grammatical gender.
class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({required this.speaker, required this.onChanged, this.mixed = false});

  final Speaker? speaker;
  final ValueChanged<Speaker?>? onChanged;

  /// Picked bubbles with different speakers: no button is on.
  final bool mixed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    // A narrow panel puts the buttons under the words.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.speakerLabel, style: theme.textTheme.bodySmall),
            InfoHint(l.speakerInfo),
          ],
        ),
        SegmentedButton<Speaker?>(
          showSelectedIcon: false,
          // The card of the selected bubble has the colour of a selected
          // segment: the choice stands out in the main colour.
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? theme.colorScheme.primary : null,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? theme.colorScheme.onPrimary : null,
            ),
          ),
          segments: [
            ButtonSegment(value: null, label: const Text('—'), tooltip: l.speakerNoneTip),
            ButtonSegment(value: Speaker.male, label: Text(l.speakerMale), tooltip: l.speakerMaleTip),
            ButtonSegment(value: Speaker.female, label: Text(l.speakerFemale), tooltip: l.speakerFemaleTip),
            ButtonSegment(value: Speaker.neuter, label: Text(l.speakerNeuter), tooltip: l.speakerNeuterTip),
          ],
          selected: mixed ? const {} : {speaker},
          emptySelectionAllowed: mixed,
          onSelectionChanged: onChanged == null
              ? null
              : (s) {
                  if (s.isNotEmpty) onChanged!(s.first);
                },
        ),
      ],
    );
  }
}

/// The short mark of [speaker] in a block card: `М`, `Ж`, `Ср`.
String speakerShort(AppLocalizations l, Speaker speaker) => switch (speaker) {
  Speaker.male => l.speakerMale,
  Speaker.female => l.speakerFemale,
  Speaker.neuter => l.speakerNeuter,
};

/// What to do about tiny text: the High level when a lighter one is chosen
/// for comics, else a larger screenshot.
String tinyTextAdvice(AppLocalizations l, AppSettings settings, double px) =>
    settings.contentKind == ContentKind.comics && settings.activeTextPrep != 'fatality_comix'
    ? l.tinyTextTryHigh('${px.round()}')
    : l.tinyTextLarger('${px.round()}');

/// Width of the text panel's header with room for every button.
const _roomyHeader = 340.0;

/// The look buttons for the step pages, in one menu to save room.
class _LookMenu extends ConsumerWidget {
  const _LookMenu({required this.enabled, this.pickAll});

  final bool enabled;

  /// "Pick every bubble" when the header has no room for its button.
  final VoidCallback? pickAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    PopupMenuItem<VoidCallback> item(IconData icon, String text, VoidCallback action) => PopupMenuItem(
      value: action,
      child: ListTile(leading: Icon(icon), title: Text(text), contentPadding: EdgeInsets.zero, dense: true),
    );
    return PopupMenuButton<VoidCallback>(
      tooltip: l.textLook,
      enabled: enabled,
      icon: const Icon(Icons.format_paint_outlined),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        if (pickAll case final pick?) ...[item(Icons.select_all, l.pickAllBlocks, pick), const PopupMenuDivider()],
        item(Icons.text_fields, l.caseToggle, () => toggleCapitals(ref)),
        item(Icons.format_size, l.sizeFromSourcePages, () => _sourceSize(context, ref)),
        item(Icons.format_clear, l.styleResetPages, () => resetLooks(ref)),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: () => ref.read(settingsProvider.notifier).change((s) => s.showLookInPanel = !s.showLookInPanel),
          checked: ref.read(settingsProvider).showLookInPanel,
          child: Text(l.showLookInPanel),
        ),
      ],
    );
  }
}
