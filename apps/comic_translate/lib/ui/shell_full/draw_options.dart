/// What the drawing tool offers under the tool bar: its modes, the colour
/// (the chosen one and the one under the mouse while picking), the brush
/// size or the fill's tolerance, and removing every touch-up of the page.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/labels.dart';
import '../../state/editor.dart';
import '../../state/paint_tools.dart';
import '../../state/workspace.dart';

/// Colours offered at once: black, white, grays, then a few bright ones.
const paintPresets = [
  0xFF000000, 0xFFFFFFFF, 0xFF424242, 0xFF9E9E9E, 0xFFE0E0E0, 0xFFD32F2F, //
  0xFFF57C00, 0xFFFBC02D, 0xFF388E3C, 0xFF1976D2, 0xFF7B1FA2, 0xFFF8BBD0,
];

/// `#RRGGBB` of [argb].
String colourCode(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The colour of a `#RRGGBB` (or `RRGGBB`, `#RGB`) code; null when it is not one.
int? parseColourCode(String text) {
  var t = text.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

class DrawOptions extends ConsumerWidget {
  const DrawOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final tools = ref.watch(paintToolsProvider);
    final page = ref.watch(workspaceProvider.select((s) => s.currentPage));
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<DrawMode>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: DrawMode.brush, icon: const Icon(Icons.brush), tooltip: l.drawBrush),
            ButtonSegment(value: DrawMode.eraser, icon: const Icon(Icons.auto_fix_normal), tooltip: l.drawEraser),
            ButtonSegment(value: DrawMode.original, icon: const Icon(Icons.restore), tooltip: l.drawOriginal),
            ButtonSegment(value: DrawMode.fill, icon: const Icon(Icons.format_color_fill), tooltip: l.drawFill),
            ButtonSegment(value: DrawMode.pipette, icon: const Icon(Icons.colorize), tooltip: l.drawPipette),
          ],
          selected: {editor.drawMode},
          onSelectionChanged: (s) => notifier.setDrawMode(s.first),
        ),
        const SizedBox(width: 4),
        _ColourButton(colour: editor.paintColor),
        // The colour under the mouse while picking; the place is kept, so
        // nothing moves when picking starts.
        Tooltip(
          message: tools.hover == null ? l.paintColourHoverNone : l.paintColourHover(colourCode(tools.hover!)),
          child: Container(
            key: const ValueKey('paint-hover'),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: tools.hover == null ? null : Color(tools.hover!),
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: tools.hover == null ? Icon(Icons.colorize, size: 14, color: scheme.outline) : null,
          ),
        ),
        const SizedBox(width: 4),
        if (editor.drawMode == DrawMode.fill) ...[
          Tooltip(
            message: l.fillTolerance,
            child: SizedBox(
              width: 120,
              child: Slider(
                value: editor.fillTolerance.toDouble(),
                max: maxFillTolerance.toDouble(),
                onChanged: (v) => notifier.setFillTolerance(v.round()),
              ),
            ),
          ),
          SizedBox(width: 32, child: Text('${editor.fillTolerance}')),
          Tooltip(
            message: l.fillSpotsHelp,
            child: FilterChip(
              label: Text(l.fillSpots),
              selected: editor.fillSpots,
              onSelected: (_) => notifier.toggleFillSpots(),
            ),
          ),
          SizedBox(
            width: 24,
            child: tools.busy
                ? const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ] else if (editor.drawMode != DrawMode.pipette) ...[
          Tooltip(
            message: l.brushSize,
            child: SizedBox(
              width: 150,
              child: Slider(
                value: editor.paintSize,
                min: minPaintSize,
                max: maxBrushSize,
                onChanged: notifier.setPaintSize,
              ),
            ),
          ),
          SizedBox(width: 44, child: Text('${editor.paintSize.round()} px')),
        ],
        IconButton(
          tooltip: l.clearPaints,
          onPressed: page != null && page.paints.isNotEmpty
              ? () => ref.read(workspaceProvider.notifier).clearPaints()
              : null,
          icon: const Icon(Icons.layers_clear_outlined),
        ),
      ],
    );
  }
}

/// The chosen colour; a click offers presets, recent colours and a code.
class _ColourButton extends ConsumerStatefulWidget {
  const _ColourButton({required this.colour});

  final int colour;

  @override
  ConsumerState<_ColourButton> createState() => _ColourButtonState();
}

class _ColourButtonState extends ConsumerState<_ColourButton> {
  final _menu = MenuController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _choose(int c) {
    ref.read(editorProvider.notifier).setPaintColor(c);
    _menu.close();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final editor = ref.watch(editorProvider);
    Widget dot(int c) => InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _choose(c),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(c),
          shape: BoxShape.circle,
          border: Border.all(
            color: c == editor.paintColor ? scheme.primary : scheme.outlineVariant,
            width: c == editor.paintColor ? 3 : 1,
          ),
        ),
      ),
    );
    return MenuAnchor(
      controller: _menu,
      onOpen: () => _code.text = colourCode(editor.paintColor),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 196,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final c in paintPresets) dot(c)]),
                if (editor.recentColors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(l.paintColourRecent, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final c in editor.recentColors) dot(c)]),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _code,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l.paintColourCode,
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]'))],
                  onSubmitted: (t) {
                    final c = parseColourCode(t);
                    if (c != null) _choose(c);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: l.paintColour(colourCode(widget.colour)),
        child: InkWell(
          key: const ValueKey('paint-colour'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(widget.colour),
              border: Border.all(color: scheme.outline, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
