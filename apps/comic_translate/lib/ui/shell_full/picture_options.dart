/// What the pictures tool offers under the tool bar: add a picture (a meme)
/// to the page, into the selected bubble when there is one; remove the
/// selected picture; put it on the shelf.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../render/mask_raster.dart' show imageFileSize;
import '../../state/background.dart';
import '../../state/editor.dart';
import '../../state/shelf.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';

/// Picture files that can be laid on a page.
const pictureTypes = ['png', 'jpg', 'jpeg', 'webp', 'bmp'];

/// Where a picture of [width]×[height] goes: as large as fits into [area]
/// (the selected bubble), in its middle; else a third of the page wide, in
/// the middle of a [pageWidth]×[pageHeight] page.
BBox placePicture(int width, int height, {BBox? area, required int pageWidth, required int pageHeight}) {
  final double w, h;
  final double cx, cy;
  if (area != null && !area.isEmpty) {
    final s = math.min(area.width / width, area.height / height);
    (w, h) = (width * s, height * s);
    (cx, cy) = ((area.x1 + area.x2) / 2, (area.y1 + area.y2) / 2);
  } else {
    w = math.max(8.0, pageWidth / 3);
    h = w * height / width;
    (cx, cy) = (pageWidth / 2, pageHeight / 2);
  }
  return BBox((cx - w / 2).round(), (cy - h / 2).round(), (cx + w / 2).round(), (cy + h / 2).round());
}

/// Asks for a picture file and lays it on the current page.
Future<void> addPictureFromFile(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final file = await openFile(
    acceptedTypeGroups: [XTypeGroup(label: l.pictureFiles, extensions: pictureTypes)],
  );
  if (file == null) return;
  final error = await layPicture(ref, source: file.path);
  if (error != null) messenger.showSnackBar(SnackBar(content: Text(l.pictureUnreadable(error))));
}

/// Lays a picture on the current page, into the selected bubble when there
/// is one, and selects it: the file [source] (copied) or the PNG [png]
/// (a picture pasted from the clipboard). The reason when it cannot.
Future<String?> layPicture(WidgetRef ref, {String? source, List<int>? png}) async {
  final ws = ref.read(workspaceProvider);
  final page = ws.currentPage;
  if (page == null) return null;
  final notifier = ref.read(workspaceProvider.notifier);
  try {
    final ext = source == null ? '.png' : p.extension(source).toLowerCase();
    final dest = p.join(notifier.pageDir(page.id).path, 'picture_${DateTime.now().microsecondsSinceEpoch}$ext');
    if (source != null) {
      await File(source).copy(dest);
    } else {
      await File(dest).writeAsBytes(png!, flush: true);
    }
    // Read once: a file the program cannot read is not laid.
    final (image, _) = await readRgbaInBackground(dest);
    final (pw, ph) = await imageFileSize(page.path);
    final box = placePicture(image.width, image.height, area: ws.selected?.xyxy, pageWidth: pw, pageHeight: ph);
    final index = notifier.addPicture(page.id, PagePicture(path: dest, box: box));
    ref.read(pictureSelectionProvider.notifier).select(page.id, index);
    return null;
  } on Object catch (e) {
    return '$e';
  }
}

class PictureOptions extends ConsumerWidget {
  const PictureOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final page = ref.watch(workspaceProvider.select((s) => s.currentPage));
    final selectedBubble = ref.watch(workspaceProvider.select((s) => s.selectedBlock));
    final picked = ref.watch(pictureSelectionProvider);
    final index = page != null && picked != null && picked.$1 == page.id && picked.$2 < page.pictures.length
        ? picked.$2
        : null;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: selectedBubble == null ? l.pictureAddHelp : l.pictureAddIntoBubble('${selectedBubble + 1}'),
          child: FilledButton.tonalIcon(
            onPressed: page == null ? null : () => addPictureFromFile(context, ref),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(l.pictureAdd),
          ),
        ),
        IconButton(
          tooltip: l.pictureToShelf,
          onPressed: index == null
              ? null
              : () {
                  ref.read(shelfProvider.notifier).putPicture(page!.id, index);
                  ref.read(pictureSelectionProvider.notifier).clear();
                },
          icon: const Icon(Icons.move_to_inbox_outlined),
        ),
        IconButton(
          tooltip: l.pictureRemove,
          onPressed: index == null
              ? null
              : () {
                  ref.read(workspaceProvider.notifier).removePicture(page!.id, index);
                  ref.read(pictureSelectionProvider.notifier).clear();
                },
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
