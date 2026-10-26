/// "Suggest a font": the fonts whose letters look most like the source
/// lettering of the current page (weight, slant, width), to pick from. The
/// font is never changed without the user's choice. Not in the original.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../render/bundled_fonts.dart';
import '../../render/text_renderer.dart';
import '../../state/app_state.dart';
import '../../state/workspace.dart';
import '../common/fonts.dart';
import '../common/labels.dart';

/// A font that might be chosen, by its setting (a family or a font file).
class _Candidate {
  _Candidate(this.setting, this.family, this.distance);

  final String setting;

  /// The family to draw it with.
  final String family;
  final double distance;
}

/// How many fonts are suggested.
const _shown = 3;

/// The fonts closest to the page's lettering, closest first.
Future<List<_Candidate>> _rank(LetteringShape target, String sample, List<String> settings) async {
  final out = <_Candidate>[];
  for (final setting in settings) {
    final String family;
    try {
      family = await resolveFontFamily(setting);
    } on Object {
      continue;
    }
    final image = await renderSample(sample, family);
    if (image == null) continue;
    final box = BBox(0, 0, image.width, image.height);
    final style = measureSourceStyle(
      image,
      TextBlock(xyxy: box, lines: [TextLine.box(box)], text: sample, fontColor: [0, 0, 0]),
    );
    final shape = style == null ? null : LetteringShape.of(style, sample);
    if (shape != null) out.add(_Candidate(setting, family, target.distance(shape)));
  }
  return out..sort((a, b) => a.distance.compareTo(b.distance));
}

/// [box] of the page at [path], as PNG, cut in another isolate. A function of
/// its own: a closure takes along every variable of the function it is made
/// in, and a widget ref cannot be sent to an isolate.
Future<Uint8List> _cropPng(String path, BBox box) => Isolate.run(() async {
  final image = await ImageCodec.readFile(path);
  return ImageCodec.encodePng(image.crop(box.inflate(8, 8).clampTo(image.width, image.height)));
});

/// Why [blocks] give no lettering to compare fonts with.
String _noShapeReason(AppLocalizations l, List<TextBlock> blocks) {
  final read = [
    for (final b in blocks)
      if (b.text.trim().isNotEmpty) b,
  ];
  if (read.isEmpty) return l.fontSuggestNoText;
  final sizes = [for (final b in read) ?b.sourceStyle?.letterPx];
  if (sizes.isNotEmpty && sizes.every((px) => px < minMeasuredLetterPx)) {
    return l.fontSuggestTooSmall(npMedian(sizes).round(), minMeasuredLetterPx.round());
  }
  return l.fontSuggestUnmeasured;
}

/// Opens the suggestions for the current page; with [block], the choice can
/// be for that bubble only.
Future<void> showFontSuggestions(BuildContext context, WidgetRef ref, {int? block}) async {
  final l = context.l10n;
  final page = ref.read(workspaceProvider).currentPage;
  final target = page == null ? null : LetteringShape.ofPage(page.blocks);
  if (page == null || target == null) {
    final reason = _noShapeReason(l, page?.blocks ?? const []);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    return;
  }
  // The longest text read on the page shows the lettering best.
  final sourceBlocks = [
    for (final b in page.blocks)
      if (b.sourceStyle?.weight != null && b.text.trim().length >= 3) b,
  ]..sort((a, b) => b.text.length.compareTo(a.text.length));
  final shown = block != null && block < page.blocks.length && page.blocks[block].sourceStyle != null
      ? page.blocks[block]
      : sourceBlocks.first;
  var sample = shown.text.trim();
  if (sample.length > 28) sample = sample.substring(0, 28).trim();
  final settings = [
    for (final f in bundledFonts) f.family == defaultFontFamily ? '' : f.family,
    ...ref.read(addedFontsProvider),
  ];
  final crop = _cropPng(page.path, shown.xyxy);
  final ranked = _rank(target, sample, settings);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _SuggestDialog(
      crop: crop,
      ranked: ranked,
      // As drawn: capitals where the page has them.
      preview: shown.translation.trim().isEmpty
          ? shown.text
          : casedTranslation(shown, ref.read(settingsProvider).textCase, upperCase: shown.style?.upperCase),
      block: block,
    ),
  );
}

class _SuggestDialog extends ConsumerWidget {
  const _SuggestDialog({required this.crop, required this.ranked, required this.preview, this.block});

  final Future<Uint8List> crop;
  final Future<List<_Candidate>> ranked;
  final String preview;
  final int? block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    void choose(_Candidate c, {required bool all}) {
      if (all) {
        ref.read(settingsProvider.notifier).change((s) => s.render = s.render.copyWith(fontFamily: c.setting));
      } else {
        ref.read(workspaceProvider.notifier).styleBlock(block!, (s) => s.copyWith(fontFamily: c.setting));
      }
      Navigator.pop(context);
    }

    return AlertDialog(
      title: Text(l.fontSuggestTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.fontSuggestHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Text(l.fontSuggestOriginal, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              FutureBuilder(
                future: crop,
                builder: (context, snap) => snap.hasData
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: Image.memory(snap.data!, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                      )
                    : const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
              ),
              const SizedBox(height: 12),
              FutureBuilder(
                future: ranked,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in snap.data!.take(_shown))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fontLabel(c.setting), style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(preview, style: TextStyle(fontFamily: c.family, fontSize: 22, height: 1.2)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.tonal(
                                      onPressed: () => choose(c, all: true),
                                      child: Text(l.fontSuggestForAll),
                                    ),
                                    if (block != null)
                                      OutlinedButton(
                                        onPressed: () => choose(c, all: false),
                                        child: Text(l.fontSuggestForBlock),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
    );
  }
}
