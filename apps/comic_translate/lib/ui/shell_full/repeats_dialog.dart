/// "Already added": pages about to be added with the same picture as open
/// ones (the owner's idea). Ticked ones are added anyway; nothing is ticked
/// at first.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../state/workspace.dart';
import '../common/labels.dart';

/// Which of [repeats] to add anyway (indexes); closing the window skips all.
Future<Set<int>> showRepeatsDialog(BuildContext context, List<RepeatedPage> repeats) async =>
    await showDialog<Set<int>>(context: context, builder: (_) => _RepeatsDialog(repeats)) ?? const {};

class _RepeatsDialog extends StatefulWidget {
  const _RepeatsDialog(this.repeats);

  final List<RepeatedPage> repeats;

  @override
  State<_RepeatsDialog> createState() => _RepeatsDialogState();
}

class _RepeatsDialogState extends State<_RepeatsDialog> {
  final _ticked = <int>{};

  Widget _picture(String path, {int? cacheWidth}) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Image.file(
      File(path),
      cacheWidth: cacheWidth,
      fit: cacheWidth == null ? BoxFit.contain : BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined)),
    ),
  );

  /// The new file and the page it repeats, big and side by side.
  void _compare(RepeatedPage r) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    Widget side(String title, String name, String path) => Expanded(
      child: Column(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Expanded(child: _picture(path)),
        ],
      ),
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.repeatsCompare),
        content: SizedBox(
          width: size.width * 0.8,
          height: size.height * 0.7,
          child: Row(
            children: [
              side(l.repeatsCompareNew, r.name, r.path),
              const SizedBox(width: 16),
              side(
                r.sameAsNumber == null ? l.repeatsCompareAdding : l.repeatsComparePage('${r.sameAsNumber}'),
                r.sameAs,
                r.sameAsPath,
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final repeats = widget.repeats;
    return AlertDialog(
      icon: const Icon(Icons.content_copy),
      title: Text(l.repeatsTitle('${repeats.length}')),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.repeatsHint),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: repeats.length,
                itemBuilder: (context, i) {
                  final r = repeats[i];
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ticked.contains(i),
                    onChanged: (v) => setState(() => v == true ? _ticked.add(i) : _ticked.remove(i)),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final path in [r.path, r.sameAsPath])
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              onTap: () => _compare(r),
                              child: SizedBox(width: 40, height: 54, child: _picture(path, cacheWidth: 80)),
                            ),
                          ),
                        IconButton(
                          tooltip: l.repeatsCompare,
                          onPressed: () => _compare(r),
                          icon: const Icon(Icons.compare),
                        ),
                      ],
                    ),
                    title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      r.sameAsNumber == null
                          ? l.repeatsSameAsNew(r.sameAs)
                          : l.repeatsSameAs('${r.sameAsNumber}', r.sameAs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, <int>{}), child: Text(l.repeatsSkipAll)),
        TextButton(
          onPressed: _ticked.isEmpty ? null : () => Navigator.pop(context, {..._ticked}),
          child: Text(l.repeatsAddPicked('${_ticked.length}')),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, {for (var i = 0; i < repeats.length; i++) i}),
          child: Text(l.repeatsAddAll),
        ),
      ],
    );
  }
}
