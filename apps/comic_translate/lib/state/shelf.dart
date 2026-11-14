/// The shelf beside the page (the owner's idea, step 7): a bubble or a
/// picture put there leaves its page, and is taken out on another one (a
/// clipboard of this program). It is kept in the project; the changes of
/// the pages are undo steps as usual.
library;

import 'dart:async';
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
  /// of the page): one bubble to [at] (page pixels, beside the page), else
  /// beside the page at the right.
  void putBubbles(Iterable<int> indexes, {BBox? at}) {
    final page = ref.read(workspaceProvider).currentPage;
    if (page == null) return;
    final which = {
      for (final i in indexes)
        if (i >= 0 && i < page.blocks.length) i,
    };
    if (which.isEmpty) return;
    final items = [
      for (final i in which.toList()..sort())
        ShelfItem.bubble(
          at != null && which.length == 1 ? (page.blocks[i].copy()..moveBoxTo(at)) : page.blocks[i].copy(),
        ),
    ];
    _ws.deleteBlocks(which);
    final first = state.length;
    state = [...state, ...items];
    if (at == null) unawaited(_besidePage(page.path, first, items.length));
  }

  /// Puts picture [index] of page [pageId] on the shelf: to [at] (page
  /// pixels, beside the page), else beside the page at the right.
  void putPicture(String pageId, int index, {BBox? at}) {
    final page = ref.read(workspaceProvider).byId(pageId);
    if (page == null || index < 0 || index >= page.pictures.length) return;
    final picture = page.pictures[index];
    _ws.removePicture(pageId, index);
    state = [...state, ShelfItem.picture(at == null ? picture : picture.withBox(at))];
    if (at == null) unawaited(_besidePage(page.path, state.length - 1, 1));
  }

  /// The place of item [index] on the desk beside the page.
  static BBox boxOf(ShelfItem item) => item.picture?.box ?? item.block!.xyxy;

  /// Moves item [index] to [box] (page pixels) on the desk.
  void moveItem(int index, BBox box) {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    final moved = item.picture != null
        ? ShelfItem.picture(item.picture!.withBox(box))
        : ShelfItem.bubble(item.block!.copy()..moveBoxTo(box));
    state = [...state]..[index] = moved;
  }

  /// Items [first]… ([count] of them) laid on the desk at the right of the
  /// page in [pagePath], at the height they had.
  Future<void> _besidePage(String pagePath, int first, int count) async {
    final (w, _) = await imageFileSize(pagePath);
    if (!ref.mounted) return;
    for (var i = first; i < first + count && i < state.length; i++) {
      final b = boxOf(state[i]);
      final x = w + 40 + 24 * (i - first);
      moveItem(i, BBox(x, b.y1, x + b.width, b.y2));
    }
  }

  /// Takes item [index] off the shelf onto the current page: to [at] (where
  /// it was dropped), else where it lies; moved onto the page as needed.
  Future<void> take(int index, {BBox? at}) async {
    final page = ref.read(workspaceProvider).currentPage;
    if (page == null || index < 0 || index >= state.length) return;
    final item = state[index];
    final (w, h) = await imageFileSize(page.path);
    if (!ref.mounted) return;
    final now = ref.read(workspaceProvider).currentPage;
    if (now == null || now.id != page.id || index >= state.length || !identical(state[index], item)) return;
    if (item.block case final block?) {
      final b = block.copy()..moveBoxTo(_inside(at ?? block.xyxy, w, h));
      _ws.edit(page.id, (p) => p.copyWith(blocks: [...p.blocks, b]));
      _ws.selectBlock(ref.read(workspaceProvider).currentPage!.blocks.length - 1);
    } else if (item.picture case final picture?) {
      _ws.addPicture(page.id, picture.withBox(keepOnPage(at ?? picture.box, w, h)));
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
