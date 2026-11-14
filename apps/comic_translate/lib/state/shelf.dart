/// The shelf beside the page (the owner's idea, step 7): a bubble or a
/// picture put there leaves its page, and is taken out on another one (a
/// clipboard of this program). It is kept in the project; the changes of
/// the pages are undo steps as usual.
library;

import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../render/mask_raster.dart' show imageFileSize;
import 'workspace.dart';

/// A bubble (with its text, translation and look) or a picture on the shelf.
typedef ShelfItem = ShelfEntry;

final shelfProvider = NotifierProvider<ShelfNotifier, List<ShelfItem>>(ShelfNotifier.new);

class ShelfNotifier extends Notifier<List<ShelfItem>> {
  @override
  List<ShelfItem> build() => const [];

  WorkspaceNotifier get _ws => ref.read(workspaceProvider.notifier);

  /// Puts bubbles [indexes] of the current page on the shelf (one undo step
  /// of the page).
  void putBubbles(Iterable<int> indexes) {
    final page = ref.read(workspaceProvider).currentPage;
    if (page == null) return;
    final which = {
      for (final i in indexes)
        if (i >= 0 && i < page.blocks.length) i,
    };
    if (which.isEmpty) return;
    final items = [for (final i in which.toList()..sort()) ShelfItem.bubble(page.blocks[i].copy())];
    _ws.deleteBlocks(which);
    state = [...state, ...items];
    ref.read(shelfOpenProvider.notifier).set(true);
  }

  /// Puts picture [index] of page [pageId] on the shelf.
  void putPicture(String pageId, int index) {
    final page = ref.read(workspaceProvider).byId(pageId);
    if (page == null || index < 0 || index >= page.pictures.length) return;
    final picture = page.pictures[index];
    _ws.removePicture(pageId, index);
    state = [...state, ShelfItem.picture(picture)];
    ref.read(shelfOpenProvider.notifier).set(true);
  }

  /// Takes item [index] off the shelf onto the current page, where it was on
  /// its page (moved inside when the page is smaller).
  Future<void> take(int index) async {
    final page = ref.read(workspaceProvider).currentPage;
    if (page == null || index < 0 || index >= state.length) return;
    final item = state[index];
    final (w, h) = await imageFileSize(page.path);
    if (!ref.mounted) return;
    final now = ref.read(workspaceProvider).currentPage;
    if (now == null || now.id != page.id || index >= state.length || !identical(state[index], item)) return;
    if (item.block case final block?) {
      final b = block.copy()..moveBoxTo(_inside(block.xyxy, w, h));
      _ws.edit(page.id, (p) => p.copyWith(blocks: [...p.blocks, b]));
      _ws.selectBlock(ref.read(workspaceProvider).currentPage!.blocks.length - 1);
    } else if (item.picture case final picture?) {
      _ws.addPicture(page.id, picture.withBox(_inside(picture.box, w, h, partly: true)));
    }
    state = [...state]..removeAt(index);
  }

  /// The shelf of a project just opened (or none when the pages are closed).
  void replace(List<ShelfItem> items) => state = items;

  /// Throws item [index] away.
  void remove(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  /// [box] moved inside a [w]×[h] page; with [partly] it only has to touch
  /// the page (a picture may reach past the edges).
  static BBox _inside(BBox box, int w, int h, {bool partly = false}) {
    var dx = 0, dy = 0;
    if (partly) {
      if (box.x1 >= w) dx = w - box.width ~/ 2 - box.x1;
      if (box.x2 <= 0) dx = -box.x1 - box.width ~/ 2;
      if (box.y1 >= h) dy = h - box.height ~/ 2 - box.y1;
      if (box.y2 <= 0) dy = -box.y1 - box.height ~/ 2;
    } else {
      if (box.x2 > w) dx = w - box.x2;
      if (box.y2 > h) dy = h - box.y2;
      dx = math.max(dx, -box.x1);
      dy = math.max(dy, -box.y1);
    }
    return BBox(box.x1 + dx, box.y1 + dy, box.x2 + dx, box.y2 + dy);
  }
}

/// The shelf card is shown beside the page.
final shelfOpenProvider = NotifierProvider<ShelfOpen, bool>(ShelfOpen.new);

class ShelfOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;

  void toggle() => state = !state;
}
