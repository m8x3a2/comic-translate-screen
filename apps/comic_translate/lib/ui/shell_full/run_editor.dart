/// The look of single words in the text panel: the translation field shows
/// styled words in their look (bold, colour, size...), and a bar of buttons
/// styles the selected part of the translation. Not in the original.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../render/text_renderer.dart';
import '../../state/app_state.dart';
import '../../state/workspace.dart';
import '../common/fonts.dart';
import '../common/labels.dart';

/// Text controller of a translation field that shows its styled words.
class RunsController extends TextEditingController {
  RunsController({super.text});

  List<StyledRun> runs = const [];
  Map<String, BlockStyle> presets = const {};

  /// Off: plain text, as without runs.
  bool showLook = true;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final t = text;
    if (!showLook || runs.isEmpty || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final children = <TextSpan>[];
    var at = 0;
    for (final r in runs) {
      if (r.start < at || r.end > t.length) continue;
      if (r.start > at) children.add(TextSpan(text: t.substring(at, r.start)));
      children.add(TextSpan(text: t.substring(r.start, r.end), style: _look(resolveRunStyle(r.style, presets), style)));
      at = r.end;
    }
    if (at < t.length) children.add(TextSpan(text: t.substring(at)));
    return TextSpan(style: style, children: children);
  }

  /// How [r] shows in the field: its font, size, weight, colour; an outline
  /// as a glow of its colour.
  TextStyle _look(RunStyle r, TextStyle? base) {
    final family = r.fontFamily;
    final color = r.color == null ? null : Color(r.color!);
    final light = color != null && color.computeLuminance() > 0.8;
    return TextStyle(
      fontFamily: family == null || isFontFile(family) ? null : (family.isEmpty ? defaultFontFamily : family),
      fontWeight: r.bold == null ? null : (r.bold! ? FontWeight.bold : FontWeight.normal),
      fontStyle: r.italic == null ? null : (r.italic! ? FontStyle.italic : FontStyle.normal),
      decoration: r.underline == true ? TextDecoration.underline : null,
      fontSize: r.scale == null || base?.fontSize == null ? null : base!.fontSize! * r.scale!,
      color: color,
      shadows: [
        if (r.outline == true) Shadow(color: Color(r.outlineColor ?? 0xFFFFFFFF), blurRadius: 3),
        // A light word on the light field stays readable.
        if (light && r.outline != true) const Shadow(color: Color(0xFF000000), blurRadius: 2),
      ],
    );
  }
}

const _colors = [
  0xFF000000, 0xFFFFFFFF, 0xFF424242, 0xFFD32F2F, 0xFFF57C00, //
  0xFFFBC02D, 0xFF388E3C, 0xFF1976D2, 0xFF7B1FA2,
];

/// Buttons for the selected characters [start]..[end] of block [index]'s
/// translation.
class RunBar extends ConsumerWidget {
  const RunBar({super.key, required this.index, required this.start, required this.end});

  final int index;
  final int start;
  final int end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final page = ref.watch(workspaceProvider.select((s) => s.currentPage));
    if (page == null || index >= page.blocks.length) return const SizedBox.shrink();
    final block = page.blocks[index];
    final settings = ref.watch(settingsProvider);
    final runs = block.style?.runs ?? const <StyledRun>[];
    final here = resolveRunStyle(
      runs.where((r) => r.start <= start && start < r.end).firstOrNull?.style ?? const RunStyle(),
      settings.render.presets,
    );
    final own = runs.where((r) => r.start <= start && start < r.end).firstOrNull?.style ?? const RunStyle();
    final bubble = blockRenderSettings(block, settings.render, PageLettering.of(page.blocks));
    void change(RunStyle Function(RunStyle s) f) => ref
        .read(workspaceProvider.notifier)
        .styleBlock(index, (s) => s.copyWith(runs: restyleRange(s.runs, start, end, f)));
    Widget toggle(IconData icon, String tip, bool on, VoidCallback onPressed) => IconButton(
      tooltip: tip,
      isSelected: on,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(backgroundColor: on ? Theme.of(context).colorScheme.secondaryContainer : null),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
    final bold = here.bold ?? bubble.bold, italic = here.italic ?? bubble.italic;
    final underline = here.underline ?? bubble.underline;
    final scale = own.scale ?? 1.0;
    final fonts = {...availableFonts(), ...ref.watch(addedFontsProvider)};
    final presets = settings.render.presets.keys.toList()..sort();
    // The buttons leave the focus (and the selection) in the field.
    return ExcludeFocus(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          toggle(Icons.format_bold, l.bold, bold, () => change((s) => s.copyWith(bold: !bold))),
          toggle(Icons.format_italic, l.italic, italic, () => change((s) => s.copyWith(italic: !italic))),
          toggle(
            Icons.format_underline,
            l.underline,
            underline,
            () => change((s) => s.copyWith(underline: !underline)),
          ),
          IconButton(
            tooltip: l.runSmaller,
            visualDensity: VisualDensity.compact,
            onPressed: () => change((s) => s.copyWith(scale: _scale(scale - 0.15))),
            icon: const Icon(Icons.text_decrease, size: 20),
          ),
          IconButton(
            tooltip: l.runBigger,
            visualDensity: VisualDensity.compact,
            onPressed: () => change((s) => s.copyWith(scale: _scale(scale + 0.15))),
            icon: const Icon(Icons.text_increase, size: 20),
          ),
          PopupMenuButton<int?>(
            tooltip: l.textColor,
            icon: Icon(Icons.format_color_text, size: 20, color: here.color == null ? null : Color(here.color!)),
            onSelected: (c) => change((s) => s.copyWith(color: c == 0 ? null : c)),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Text(l.runAsBubble)),
              for (final c in _colors) PopupMenuItem(value: c, child: _Swatch(c)),
            ],
          ),
          PopupMenuButton<int?>(
            tooltip: l.outline,
            icon: const Icon(Icons.border_color_outlined, size: 20),
            onSelected: (c) => change(
              (s) => switch (c) {
                0 => s.copyWith(outline: null, outlineColor: null),
                1 => s.copyWith(outline: false, outlineColor: null),
                _ => s.copyWith(outline: true, outlineColor: c),
              },
            ),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Text(l.runAsBubble)),
              PopupMenuItem(value: 1, child: Text(l.outlineNone)),
              for (final c in _colors) PopupMenuItem(value: c, child: _Swatch(c)),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: l.font,
            icon: const Icon(Icons.font_download_outlined, size: 20),
            onSelected: (f) => change((s) => s.copyWith(fontFamily: f == '\u0000' ? null : f)),
            itemBuilder: (context) => [
              PopupMenuItem(value: '\u0000', child: Text(l.runAsBubble)),
              for (final f in fonts)
                PopupMenuItem(
                  value: f == defaultFontFamily ? '' : f,
                  child: Text(fontLabel(f), style: TextStyle(fontFamily: isFontFile(f) ? null : f)),
                ),
            ],
          ),
          if (presets.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: l.lookPreset,
              icon: const Icon(Icons.style_outlined, size: 20),
              onSelected: (p) => change((s) => s.copyWith(preset: p.isEmpty ? null : p)),
              itemBuilder: (context) => [
                PopupMenuItem(value: '', child: Text(l.lookPresetNone)),
                for (final p in presets) CheckedPopupMenuItem(value: p, checked: own.preset == p, child: Text(p)),
              ],
            ),
          IconButton(
            tooltip: l.runClear,
            visualDensity: VisualDensity.compact,
            onPressed: () => change((_) => const RunStyle()),
            icon: const Icon(Icons.format_clear, size: 20),
          ),
        ],
      ),
    );
  }
}

/// A word's size to the bubble's, 1 unset.
double? _scale(double v) {
  final s = (v.clamp(0.4, 3.0) * 100).roundToDouble() / 100;
  return (s - 1).abs() < 0.01 ? null : s;
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final int color;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 20,
    decoration: BoxDecoration(
      color: Color(color),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}
