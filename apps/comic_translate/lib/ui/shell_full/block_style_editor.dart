/// Look of the selected block's translation: font, size, colours, outline,
/// alignment, B/I/U, spacing, vertical text, rotation (original text
/// formatting controls of `main_window/builders/workspace.py` and
/// `controllers/text.py`).
library;

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/block_looks.dart';
import '../../state/page_layout.dart';
import '../../state/workspace.dart';
import '../common/fonts.dart';
import '../common/labels.dart';
import 'font_suggest.dart';

const _colors = [
  0xFF000000, 0xFFFFFFFF, 0xFF424242, 0xFF9E9E9E, 0xFFD32F2F, 0xFFF57C00, //
  0xFFFBC02D, 0xFF388E3C, 0xFF1976D2, 0xFF7B1FA2,
];

class BlockStyleEditor extends ConsumerWidget {
  const BlockStyleEditor({super.key, required this.index, this.group});

  /// The block of the current page whose look is shown.
  final int index;

  /// Bubbles picked together ([index] among them): every change goes to all
  /// of them as one undo step.
  final List<int>? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final page = ref.watch(workspaceProvider.select((s) => s.currentPage));
    if (page == null || index >= page.blocks.length) return const SizedBox.shrink();
    final block = page.blocks[index];
    final s = block.style ?? const BlockStyle();
    final settings = ref.watch(settingsProvider);
    // As drawn: the source look (see "Look as in the original") under the
    // block's own.
    final r = blockRenderSettings(block, settings.render, PageLettering.of(page.blocks));
    final ws = ref.read(workspaceProvider.notifier);
    final targets = [
      for (final i in group ?? [index])
        if (i < page.blocks.length) i,
    ];
    final many = targets.length > 1;
    void setEach(BlockStyle Function(BlockStyle s, int i) change, {String? merge}) =>
        ws.styleBlocks(targets, change, mergeKey: merge);
    void set(BlockStyle Function(BlockStyle s) change, {String? merge}) => setEach((s, _) => change(s), merge: merge);
    final layout = ref.watch(pageLayoutProvider);
    // The size the layout gave bubble [i] (each picked bubble has its own).
    int? fittedOf(int i) {
      final k = layout?.blockIndex.indexOf(i) ?? -1;
      return k >= 0 ? layout!.items[k].fontSizePt : null;
    }

    final fitted = fittedOf(index);
    final angle = s.angle ?? 0;
    final font = s.fontFamily ?? r.fontFamily;
    final fonts = {...availableFonts(), ...ref.watch(addedFontsProvider), if (font.isNotEmpty) font};
    final small = theme.textTheme.labelMedium;

    Widget row(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: small)),
          Expanded(child: child),
        ],
      ),
    );

    final presets = settings.render.presets;
    final names = presets.keys.toList()..sort();
    final preset = s.preset != null && presets.containsKey(s.preset) ? s.preset : null;
    void setPresets(Map<String, BlockStyle> next) =>
        ref.read(settingsProvider.notifier).change((x) => x.render = x.render.copyWith(presets: next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          l.lookPreset,
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: preset ?? '',
                  isExpanded: true,
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: '', child: Text(l.lookPresetNone)),
                    for (final n in names)
                      DropdownMenuItem(
                        value: n,
                        child: Text(n, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => set((s) => s.copyWith(preset: v == null || v.isEmpty ? null : v)),
                ),
              ),
              PopupMenuButton<VoidCallback>(
                tooltip: l.lookPresetHelp,
                icon: const Icon(Icons.style_outlined, size: 20),
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: () async {
                      final name = await _askPresetName(context, preset ?? '');
                      if (name == null) return;
                      // The look as it is now: the preset's under the bubble's own.
                      final current = (presets[preset]?.look ?? const BlockStyle()).merge(s.look);
                      setPresets({...presets, name: current});
                      set((s) => s.withoutLook.copyWith(preset: name));
                    },
                    child: Text(l.lookPresetSave),
                  ),
                  if (preset != null) ...[
                    PopupMenuItem(
                      value: () {
                        setPresets({...presets, preset: presets[preset]!.merge(s.look)});
                        set((s) => s.withoutLook);
                      },
                      child: Text(l.lookPresetUpdate(preset)),
                    ),
                    PopupMenuItem(
                      value: () {
                        setPresets({...presets}..remove(preset));
                        set((s) => s.copyWith(preset: null));
                      },
                      child: Text(l.lookPresetDelete(preset)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        row(
          l.font,
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: font.isEmpty ? defaultFontFamilyLabel : font,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final f in fonts.isEmpty ? [defaultFontFamilyLabel] : fonts)
                      DropdownMenuItem(
                        value: f,
                        child: Text(fontLabel(f), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => set((s) => s.copyWith(fontFamily: v)),
                ),
              ),
              IconButton(
                tooltip: l.fontFile,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                onPressed: () async {
                  final file = await openFile(
                    acceptedTypeGroups: [const XTypeGroup(label: 'Fonts', extensions: fontExtensions)],
                  );
                  if (file != null) set((s) => s.copyWith(fontFamily: file.path));
                },
              ),
              if (!many)
                IconButton(
                  tooltip: l.fontSuggest,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                  onPressed: () => showFontSuggestions(context, ref, block: index),
                ),
            ],
          ),
        ),
        row(
          l.fontSize,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(l.sizeAuto),
                selected: s.fontSizePt == null && s.sourceSizePx == null,
                visualDensity: VisualDensity.compact,
                onSelected: (auto) => setEach(
                  (s, i) => s.copyWith(fontSizePt: auto ? null : (fittedOf(i) ?? r.maxFontSize), sourceSizePx: null),
                ),
              ),
              FilterChip(
                label: Text(l.fromSource),
                tooltip: l.sizeFromSource,
                selected: s.sourceSizePx != null,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  if (toggleSourceSize(ref, blocks: targets) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.sizeFromSourceUnknown)));
                  }
                },
              ),
              // − size + wrap as one group.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 18),
                    // Each picked bubble one point smaller than its own size.
                    onPressed: () => setEach(
                      (s, i) => s.copyWith(
                        fontSizePt: ((s.fontSizePt ?? fittedOf(i) ?? r.maxFontSize) - 1).clamp(4, 200),
                        sourceSizePx: null,
                      ),
                      merge: 'size:$index',
                    ),
                  ),
                  if (s.fontSizePt ?? fitted case final size?)
                    Text('$size', style: theme.textTheme.bodyMedium)
                  else
                    Tooltip(
                      message: l.sizeUnknown,
                      child: Icon(Icons.help_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => setEach(
                      (s, i) => s.copyWith(
                        fontSizePt: ((s.fontSizePt ?? fittedOf(i) ?? r.minFontSize) + 1).clamp(4, 200),
                        sourceSizePx: null,
                      ),
                      merge: 'size:$index',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        row(
          l.textColor,
          _Swatches(
            // A style's colour shows as chosen too.
            value: s.color ?? presets[preset]?.color,
            auto: l.colorAuto,
            onChanged: (c) => set((s) => s.copyWith(color: c)),
          ),
        ),
        row(
          l.outline,
          Row(
            children: [
              Switch(
                value: r.outline,
                onChanged: (v) => set((s) => s.copyWith(outline: v)),
              ),
              if (r.outline)
                Expanded(
                  child: Slider(
                    value: r.outlineWidth.clamp(0.0, 6.0),
                    max: 6,
                    divisions: 24,
                    label: r.outlineWidth.toStringAsFixed(2),
                    onChanged: (v) => set((s) => s.copyWith(outlineWidth: v), merge: 'outline:$index'),
                  ),
                ),
            ],
          ),
        ),
        if (r.outline)
          row(
            l.outlineColor,
            _Swatches(
              value: s.outlineColor,
              onChanged: (c) => set((s) => s.copyWith(outlineColor: c)),
            ),
          ),
        row(
          l.alignment,
          Wrap(
            children: [
              SegmentedButton<TextAlignment>(
                segments: const [
                  ButtonSegment(value: TextAlignment.left, icon: Icon(Icons.format_align_left, size: 18)),
                  ButtonSegment(value: TextAlignment.center, icon: Icon(Icons.format_align_center, size: 18)),
                  ButtonSegment(value: TextAlignment.right, icon: Icon(Icons.format_align_right, size: 18)),
                ],
                selected: {r.alignment},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (v) => set((s) => s.copyWith(alignment: v.first)),
              ),
            ],
          ),
        ),
        row(
          l.textStyle,
          Wrap(
            children: [
              _Toggle(Icons.format_bold, l.bold, r.bold, (v) => set((s) => s.copyWith(bold: v))),
              _Toggle(Icons.format_italic, l.italic, r.italic, (v) => set((s) => s.copyWith(italic: v))),
              _Toggle(Icons.format_underline, l.underline, r.underline, (v) => set((s) => s.copyWith(underline: v))),
              _Toggle(
                Icons.text_rotate_vertical,
                l.verticalText,
                s.vertical ?? false,
                (v) => set((s) => s.copyWith(vertical: v)),
              ),
            ],
          ),
        ),
        row(
          l.textCase,
          Wrap(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('АБВ')),
                  ButtonSegment(value: false, label: Text('Абв')),
                ],
                selected: {drawnInCapitals(block, settings)},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (v) => set((s) => s.copyWith(upperCase: v.first)),
              ),
            ],
          ),
        ),
        row(
          l.textFit,
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              FilterChip(
                label: Text(l.hyphenateBlock),
                tooltip: l.hyphenateInfo,
                selected: r.hyphenate,
                visualDensity: VisualDensity.compact,
                onSelected: (v) => set((s) => s.copyWith(hyphenate: v)),
              ),
              FilterChip(
                label: Text(l.shapeFitBlock),
                tooltip: l.shapeFitInfo,
                selected: r.shapeFit,
                visualDensity: VisualDensity.compact,
                onSelected: (v) => set((s) => s.copyWith(shapeFit: v)),
              ),
            ],
          ),
        ),
        row(
          l.lineSpacing,
          Slider(
            value: r.lineSpacing.clamp(0.6, 2.5),
            min: 0.6,
            max: 2.5,
            divisions: 19,
            label: r.lineSpacing.toStringAsFixed(1),
            onChanged: (v) =>
                set((s) => s.copyWith(lineSpacing: double.parse(v.toStringAsFixed(1))), merge: 'spacing:$index'),
          ),
        ),
        row(
          l.rotation,
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: angle.clamp(-180.0, 180.0),
                  min: -180,
                  max: 180,
                  divisions: 72,
                  label: '${angle.round()}°',
                  onChanged: (v) => set((s) => s.copyWith(angle: v == 0 ? null : v), merge: 'angle:$index'),
                ),
              ),
              SizedBox(width: 40, child: Text('${angle.round()}°', style: small)),
            ],
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: Text(l.lookApply),
              onPressed: () => showApplyLookDialog(context, ref, index, picked: many ? targets : const []),
            ),
            TextButton.icon(
              icon: const Icon(Icons.format_clear, size: 18),
              label: Text(l.styleReset),
              onPressed: targets.every((i) => page.blocks[i].style == null)
                  ? null
                  : () => set((_) => const BlockStyle()),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Apply to others": ticks for the parts of bubble [source]'s look and
/// where they go ([picked]: the bubbles picked with it, offered first).
Future<void> showApplyLookDialog(BuildContext context, WidgetRef ref, int source, {List<int> picked = const []}) async {
  final ws = ref.read(workspaceProvider);
  final page = ws.currentPage;
  if (page == null || source >= page.blocks.length) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  int bubbles(Iterable<PageEntry> pages) => pages.fold(0, (n, p) => n + p.blocks.length);
  final result = await showDialog<(Set<LookPart>, LookScope)>(
    context: context,
    builder: (_) => _ApplyLookDialog(
      number: source + 1,
      picked: picked.length,
      onPage: page.blocks.length,
      pickedPages: ws.selectedPages.length > 1 ? bubbles(ws.stepPages) : 0,
      allPages: ws.pages.length > 1 ? bubbles(ws.pages) : 0,
    ),
  );
  if (result == null) return;
  _lastLookParts = result.$1;
  final from = page.blocks[source].style ?? const BlockStyle();
  final count = applyLook(ref, from, result.$1, result.$2, source: source, picked: picked);
  messenger.showSnackBar(SnackBar(content: Text(l.lookApplyDone('$count')), showCloseIcon: true));
}

/// The parts ticked last time (while the program runs).
Set<LookPart> _lastLookParts = LookPart.usual;

class _ApplyLookDialog extends StatefulWidget {
  const _ApplyLookDialog({
    required this.number,
    required this.picked,
    required this.onPage,
    required this.pickedPages,
    required this.allPages,
  });

  /// The source bubble's number.
  final int number;

  /// Bubbles in each place (0: the place is not offered).
  final int picked, onPage, pickedPages, allPages;

  @override
  State<_ApplyLookDialog> createState() => _ApplyLookDialogState();
}

class _ApplyLookDialogState extends State<_ApplyLookDialog> {
  late final _parts = {..._lastLookParts};
  late LookScope _scope = widget.picked > 1 ? LookScope.picked : LookScope.page;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    String label(LookPart p) => switch (p) {
      LookPart.preset => l.lookPreset,
      LookPart.font => l.font,
      LookPart.size => l.lookPartSize,
      LookPart.color => l.textColor,
      LookPart.outline => l.outline,
      LookPart.alignment => l.alignment,
      LookPart.emphasis => l.lookPartEmphasis,
      LookPart.letterCase => l.textCase,
      LookPart.lineSpacing => l.lineSpacing,
      LookPart.fit => l.lookPartFit,
      LookPart.vertical => l.verticalText,
      LookPart.angle => l.rotation,
    };
    final places = [
      if (widget.picked > 1) (LookScope.picked, l.lookScopePicked('${widget.picked}')),
      (LookScope.page, l.lookScopePage('${widget.onPage}')),
      if (widget.pickedPages > 0) (LookScope.pickedPages, l.lookScopePickedPages('${widget.pickedPages}')),
      if (widget.allPages > 0) (LookScope.allPages, l.lookScopeAll('${widget.allPages}')),
    ];
    return AlertDialog(
      title: Text(l.lookApplyTitle('${widget.number}')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.lookApplyWhat, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in LookPart.values)
                    FilterChip(
                      label: Text(label(p)),
                      selected: _parts.contains(p),
                      onSelected: (v) => setState(() => v ? _parts.add(p) : _parts.remove(p)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.lookApplyNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(l.lookApplyWhere, style: theme.textTheme.titleSmall),
              for (final (scope, text) in places)
                RadioListTile<LookScope>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: scope,
                  // ignore: deprecated_member_use
                  groupValue: _scope,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _scope = v ?? _scope),
                  title: Text(text),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _parts.isEmpty ? null : () => Navigator.pop(context, (_parts, _scope)),
          child: Text(l.textImportApply),
        ),
      ],
    );
  }
}

/// Shown for the bundled font when no family is set.
const defaultFontFamilyLabel = 'Pangolin';

class _Toggle extends StatelessWidget {
  const _Toggle(this.icon, this.tooltip, this.value, this.onChanged);

  final IconData icon;
  final String tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    isSelected: value,
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(backgroundColor: value ? Theme.of(context).colorScheme.secondaryContainer : null),
    onPressed: () => onChanged(!value),
    icon: Icon(icon, size: 20),
  );
}

/// Colour presets; [auto] (when given) unsets the colour.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.value, required this.onChanged, this.auto});

  final int? value;
  final ValueChanged<int?> onChanged;
  final String? auto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(int? c, {Widget? child}) => InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onChanged(c),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c == null ? null : Color(c),
          shape: BoxShape.circle,
          border: Border.all(color: c == value ? scheme.primary : scheme.outlineVariant, width: c == value ? 3 : 1),
        ),
        child: child,
      ),
    );
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (auto != null)
          Tooltip(
            message: auto!,
            child: dot(null, child: const Icon(Icons.auto_awesome, size: 12)),
          ),
        for (final c in _colors) dot(c),
      ],
    );
  }
}

/// Asks for the name of a new style; null when cancelled or empty.
Future<String?> _askPresetName(BuildContext context, String initial) async {
  final l = context.l10n;
  final field = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.lookPresetSave),
      content: TextField(
        controller: field,
        autofocus: true,
        decoration: InputDecoration(labelText: l.lookPresetName),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, field.text), child: Text(l.save)),
      ],
    ),
  );
  // Not disposed here: the dialog may still be closing with the field in it.
  final n = name?.trim() ?? '';
  return n.isEmpty ? null : n;
}
