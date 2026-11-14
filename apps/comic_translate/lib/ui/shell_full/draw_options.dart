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
    Widget mode(DrawMode m, IconData icon, String tip) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      isSelected: editor.drawMode == m,
      onPressed: () => notifier.setDrawMode(m),
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: editor.drawMode == m ? scheme.secondaryContainer : null,
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    // Two groups as wide in every mode: they wrap the same way whatever the
    // mode, so the page does not move when it changes (the pipette button
    // goes back to the brush by itself).
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mode(DrawMode.brush, Icons.brush, l.drawBrush),
            mode(DrawMode.eraser, Icons.auto_fix_normal, l.drawEraser),
            mode(DrawMode.original, Icons.restore, l.drawOriginal),
            mode(DrawMode.fill, Icons.format_color_fill, l.drawFill),
            mode(DrawMode.area, Icons.gesture, l.drawArea),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColourButton(colour: editor.paintColor),
            const SizedBox(width: 4),
            // The pipette button; while picking it shows the colour under
            // the mouse.
            Tooltip(
              message: tools.hover == null
                  ? [l.drawPipette, l.paintColourHoverNone].join('\n')
                  : l.paintColourHover(colourCode(tools.hover!)),
              child: InkWell(
                key: const ValueKey('paint-hover'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => notifier.setDrawMode(DrawMode.pipette),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tools.hover != null
                        ? Color(tools.hover!)
                        : editor.drawMode == DrawMode.pipette
                        ? scheme.secondaryContainer
                        : null,
                    border: Border.all(
                      color: editor.drawMode == DrawMode.pipette ? scheme.primary : scheme.outline,
                      width: editor.drawMode == DrawMode.pipette ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: tools.hover == null ? Icon(Icons.colorize, size: 18, color: scheme.onSurfaceVariant) : null,
                ),
              ),
            ),
            // As high in every mode (the pipette has no slider).
            SizedBox(
              width: 136,
              height: 48,
              child: Row(
                children: [
                  if (editor.drawMode == DrawMode.area) ...[
                    for (final (shape, icon, tip) in [
                      (AreaShape.lasso, Icons.gesture, l.areaLasso),
                      (AreaShape.polygon, Icons.polyline_outlined, l.areaPolygon),
                      (AreaShape.rectangle, Icons.crop_square, l.areaRectangle),
                      (AreaShape.ellipse, Icons.circle_outlined, l.areaEllipse),
                    ])
                      IconButton(
                        tooltip: tip,
                        isSelected: editor.areaShape == shape,
                        onPressed: () => notifier.setAreaShape(shape),
                        icon: Icon(icon, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: editor.areaShape == shape ? scheme.tertiaryContainer : null,
                          minimumSize: const Size(34, 34),
                          padding: const EdgeInsets.all(6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ] else if (editor.drawMode == DrawMode.fill) ...[
                    Expanded(
                      child: Tooltip(
                        message: '${l.fillTolerance}: ${editor.fillTolerance}',
                        child: Slider(
                          value: editor.fillTolerance.toDouble(),
                          max: maxFillTolerance.toDouble(),
                          onChanged: (v) => notifier.setFillTolerance(v.round()),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: tools.busy
                          ? const Center(
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              tooltip: '${l.fillSpots}: ${l.fillSpotsHelp}',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              isSelected: editor.fillSpots,
                              onPressed: notifier.toggleFillSpots,
                              icon: const Icon(Icons.blur_off, size: 20),
                              selectedIcon: const Icon(Icons.blur_on, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: editor.fillSpots ? scheme.secondaryContainer : null,
                              ),
                            ),
                    ),
                  ] else if (editor.drawMode != DrawMode.pipette) ...[
                    // The eraser and "original": a brush, or an outline.
                    if (editor.drawMode == DrawMode.eraser || editor.drawMode == DrawMode.original)
                      PopupMenuButton<int>(
                        tooltip: l.eraseShapeHelp,
                        initialValue: editor.eraseShape?.index ?? -1,
                        onSelected: (i) => notifier.setEraseShape(i < 0 ? null : AreaShape.values[i]),
                        itemBuilder: (_) => [
                          for (final (i, icon, label) in [
                            (-1, Icons.brush, l.eraseShapeBrush),
                            (AreaShape.lasso.index, Icons.gesture, l.areaLasso),
                            (AreaShape.polygon.index, Icons.polyline_outlined, l.areaPolygon),
                            (AreaShape.rectangle.index, Icons.crop_square, l.areaRectangle),
                            (AreaShape.ellipse.index, Icons.circle_outlined, l.areaEllipse),
                          ])
                            PopupMenuItem(
                              value: i,
                              child: ListTile(dense: true, leading: Icon(icon), title: Text(label)),
                            ),
                        ],
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(switch (editor.eraseShape) {
                            null => Icons.brush,
                            AreaShape.lasso => Icons.gesture,
                            AreaShape.polygon => Icons.polyline_outlined,
                            AreaShape.rectangle => Icons.crop_square,
                            AreaShape.ellipse => Icons.circle_outlined,
                          }, size: 20),
                        ),
                      ),
                    Expanded(
                      child: Tooltip(
                        message: l.brushSize,
                        child: Slider(
                          value: editor.paintSize,
                          min: minPaintSize,
                          max: maxBrushSize,
                          onChanged: notifier.setPaintSize,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: editor.drawMode == DrawMode.brush ? 46 : 40,
                      child: Text('${editor.paintSize.round()} px'),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l.clearPaints,
              visualDensity: VisualDensity.compact,
              onPressed: page != null && page.paints.isNotEmpty
                  ? () => ref.read(workspaceProvider.notifier).clearPaints()
                  : null,
              icon: const Icon(Icons.layers_clear_outlined, size: 20),
            ),
          ],
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
                    hintText: '#FFFFFF',
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
