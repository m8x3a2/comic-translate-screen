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
  const BlockStyleEditor({super.key, required this.index});

  /// The block of the current page.
  final int index;

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
    void set(BlockStyle Function(BlockStyle s) change, {String? merge}) =>
        ws.styleBlock(index, change, mergeKey: merge);
    final layout = ref.watch(pageLayoutProvider);
    final k = layout?.blockIndex.indexOf(index) ?? -1;
    final fitted = k >= 0 ? layout!.items[k].fontSizePt : null;
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
                onSelected: (auto) =>
                    set((s) => s.copyWith(fontSizePt: auto ? null : (fitted ?? r.maxFontSize), sourceSizePx: null)),
              ),
              FilterChip(
                label: Text(l.fromSource),
                tooltip: l.sizeFromSource,
                selected: s.sourceSizePx != null,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  if (toggleSourceSize(ref, block: index) == null) {
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
                    onPressed: () => set(
                      (s) => s.copyWith(
                        fontSizePt: ((s.fontSizePt ?? fitted ?? r.maxFontSize) - 1).clamp(4, 200),
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
                    onPressed: () => set(
                      (s) => s.copyWith(
                        fontSizePt: ((s.fontSizePt ?? fitted ?? r.minFontSize) + 1).clamp(4, 200),
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
            value: s.color,
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
              label: Text(l.styleToAll),
              onPressed: () {
                final look = s.copyWith(textBox: null, angle: null, fontSizePt: null, sourceSizePx: null);
                ws.styleAll(
                  (other) => look.copyWith(
                    textBox: other.textBox,
                    angle: other.angle,
                    fontSizePt: other.fontSizePt,
                    sourceSizePx: other.sourceSizePx,
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.format_clear, size: 18),
              label: Text(l.styleReset),
              onPressed: block.style == null ? null : () => set((_) => const BlockStyle()),
            ),
          ],
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
