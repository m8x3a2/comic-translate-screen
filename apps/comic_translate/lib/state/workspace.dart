/// The open pages and their edit history. Their files live in a session
/// folder in the cache; projects (`project.dart`) keep them for good.
///
/// Pages are immutable values: every change makes new [PageEntry] and
/// [TextBlock] objects (blocks are never changed in place), so an undo step
/// is just the previous value.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../import/pdf_pages.dart';
import '../pipeline/psd_page.dart' show installedFonts;
import 'app_state.dart';

enum PageStatus { pending, running, done, skipped }

/// Why a page was skipped; the UI words it in the interface language.
sealed class SkipReason {
  const SkipReason();
}

class ModelMissingReason extends SkipReason {
  const ModelMissingReason(this.model);

  final String model;
}

class TranslationFailedReason extends SkipReason {
  const TranslationFailedReason(this.kind, this.message);

  final TranslationErrorKind kind;

  /// Technical details from the translator (English).
  final String message;
}

/// The background worker stopped unexpectedly (details in the log).
class WorkerStoppedReason extends SkipReason {
  const WorkerStoppedReason();
}

class UnreadableImageReason extends SkipReason {
  const UnreadableImageReason();
}

class OtherReason extends SkipReason {
  const OtherReason(this.message);

  final String message;
}

const Object _keep = Object();

/// One open page and what was done to it.
class PageEntry {
  const PageEntry({
    required this.id,
    required this.name,
    required this.path,
    this.source,
    this.status = PageStatus.pending,
    this.stage,
    this.reason,
    this.translatedPath,
    this.cleanPath,
    this.maskPath,
    this.overflowPath,
    this.strokes = const [],
    this.blocks = const [],
    this.renderScale = 1.0,
    this.exported = false,
    this.sourceLanguage,
    this.targetLanguage,
    this.handEdited = false,
  });

  final String id;

  /// File or archive entry name.
  final String name;

  /// The original page image.
  final String path;

  /// The archive or PDF the page came from.
  final String? source;
  final PageStatus status;

  /// Pipeline stage while running (`01_detect` …).
  final String? stage;

  /// Why the page was skipped.
  final SkipReason? reason;

  /// The page drawn with its translation (a cache: cleared when the page
  /// changes, drawn again for export).
  final String? translatedPath;

  /// The page with the text removed.
  final String? cleanPath;

  /// Generated text-removal mask (PNG), before cleaning.
  final String? maskPath;

  /// Webtoon pages: the cleaned part of the next page that blocks of this
  /// page reach into (a transparent PNG drawn at this page's bottom-left
  /// corner, see [SeamPatch]).
  final String? overflowPath;

  /// Brush and eraser strokes over [maskPath], in page pixels.
  final List<MaskStroke> strokes;

  /// Detected blocks with text and translation, in original page
  /// coordinates.
  final List<TextBlock> blocks;

  /// How much [translatedPath] was enlarged.
  final double renderScale;

  /// The current translation was saved with Export.
  final bool exported;

  /// Languages of this page (original `image_states[...]['source_lang']`);
  /// null: the defaults of the settings.
  final String? sourceLanguage;
  final String? targetLanguage;

  /// Changed by hand since it was last translated whole: "Translate all"
  /// asks before doing it again, which would lose those changes.
  final bool handEdited;

  String sourceOf(AppSettings settings) => sourceLanguage ?? settings.sourceLanguage;
  String targetOf(AppSettings settings) => targetLanguage ?? settings.targetLanguage;

  /// Something was translated or cleaned: the page can be exported.
  bool get isDone => cleanPath != null || blocks.any((b) => hasTranslatableContent(b.translation));

  /// The image the translation is drawn on.
  String get basePath => cleanPath ?? path;

  /// There is a mask to clean with.
  bool get hasMask => maskPath != null || strokes.any((s) => !s.erase);

  /// A copy with the given fields changed; pass null to clear a nullable
  /// field.
  PageEntry copyWith({
    PageStatus? status,
    Object? stage = _keep,
    Object? reason = _keep,
    Object? translatedPath = _keep,
    Object? cleanPath = _keep,
    Object? maskPath = _keep,
    Object? overflowPath = _keep,
    List<MaskStroke>? strokes,
    List<TextBlock>? blocks,
    double? renderScale,
    bool? exported,
    Object? sourceLanguage = _keep,
    Object? targetLanguage = _keep,
    bool? handEdited,
  }) {
    T? pick<T>(Object? v, T? old) => identical(v, _keep) ? old : v as T?;
    final rendered = pick<String>(translatedPath, this.translatedPath);
    return PageEntry(
      id: id,
      name: name,
      path: path,
      source: source,
      status: status ?? this.status,
      stage: pick(stage, this.stage),
      reason: pick(reason, this.reason),
      translatedPath: rendered,
      cleanPath: pick(cleanPath, this.cleanPath),
      maskPath: pick(maskPath, this.maskPath),
      overflowPath: pick(overflowPath, this.overflowPath),
      strokes: strokes ?? this.strokes,
      blocks: blocks ?? this.blocks,
      renderScale: renderScale ?? this.renderScale,
      exported: exported ?? (rendered != null && rendered != this.translatedPath ? false : this.exported),
      sourceLanguage: pick(sourceLanguage, this.sourceLanguage),
      targetLanguage: pick(targetLanguage, this.targetLanguage),
      handEdited: handEdited ?? this.handEdited,
    );
  }
}

/// The editable part of a page, kept for undo.
class PageSnapshot {
  PageSnapshot.of(PageEntry p)
    : blocks = [for (final b in p.blocks) b.copy()],
      cleanPath = p.cleanPath,
      maskPath = p.maskPath,
      overflowPath = p.overflowPath,
      strokes = p.strokes,
      translatedPath = p.translatedPath,
      renderScale = p.renderScale,
      handEdited = p.handEdited;

  final List<TextBlock> blocks;
  final String? cleanPath;
  final String? maskPath;
  final String? overflowPath;
  final List<MaskStroke> strokes;
  final String? translatedPath;
  final double renderScale;
  final bool handEdited;

  PageEntry applyTo(PageEntry p) => p.copyWith(
    blocks: [for (final b in blocks) b.copy()],
    cleanPath: cleanPath,
    maskPath: maskPath,
    overflowPath: overflowPath,
    strokes: strokes,
    translatedPath: translatedPath,
    renderScale: renderScale,
    exported: false,
    handEdited: handEdited,
  );
}

/// Undo and redo steps of one page.
class PageHistory {
  const PageHistory({this.undo = const [], this.redo = const [], this.mergeKey, this.at});

  static const empty = PageHistory();

  /// Most recent last.
  final List<PageSnapshot> undo;
  final List<PageSnapshot> redo;

  /// Key and time of the last change, to merge typing into one step.
  final String? mergeKey;
  final DateTime? at;
}

/// Undo steps kept per page.
const maxUndoSteps = 100;

/// Changes with the same merge key closer than this become one undo step.
const defaultMergeWindow = Duration(seconds: 2);

class WorkspaceState {
  const WorkspaceState({
    this.pages = const [],
    this.current = 0,
    this.importing = false,
    this.selectedBlock,
    this.history = const {},
    this.selectedPages = const {},
    this.webtoon = false,
  });

  /// Webtoon mode: the pages are shown as one strip, and bubbles cut by the
  /// edge between two pages are handled as one (original `webtoon_mode`).
  final bool webtoon;

  final List<PageEntry> pages;
  final int current;
  final bool importing;

  /// Block selected in the viewer and the text panel (index into the
  /// current page's blocks).
  final int? selectedBlock;

  /// Page id → its undo history.
  final Map<String, PageHistory> history;

  /// Pages picked with Ctrl or Shift in the page list for the steps (the
  /// current page among them); empty: only the current page.
  final Set<String> selectedPages;

  /// The pages the steps work on, in page order.
  List<PageEntry> get stepPages {
    if (selectedPages.length < 2) return [?currentPage];
    return [
      for (final p in pages)
        if (selectedPages.contains(p.id)) p,
    ];
  }

  PageEntry? get currentPage => pages.isEmpty ? null : pages[current.clamp(0, pages.length - 1)];

  /// The pages the steps work on, by id (the current one when none are
  /// selected).
  Set<String> get pickedPageIds => selectedPages.length < 2 ? {?currentPage?.id} : selectedPages;
  int get doneCount => pages.where((p) => p.isDone).length;

  /// Translated pages that would be lost on closing (not exported yet).
  int get unexportedCount => pages.where((p) => p.isDone && !p.exported).length;

  /// The selected block of the current page.
  TextBlock? get selected {
    final page = currentPage, i = selectedBlock;
    return page == null || i == null || i < 0 || i >= page.blocks.length ? null : page.blocks[i];
  }

  bool get canUndo => history[currentPage?.id]?.undo.isNotEmpty ?? false;
  bool get canRedo => history[currentPage?.id]?.redo.isNotEmpty ?? false;

  PageEntry? byId(String id) {
    for (final p in pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  WorkspaceState copyWith({
    List<PageEntry>? pages,
    int? current,
    bool? importing,
    int? selectedBlock,
    bool clearBlock = false,
    Map<String, PageHistory>? history,
    Set<String>? selectedPages,
    bool? webtoon,
  }) => WorkspaceState(
    pages: pages ?? this.pages,
    current: current ?? this.current,
    importing: importing ?? this.importing,
    selectedBlock: clearBlock ? null : (selectedBlock ?? this.selectedBlock),
    history: history ?? this.history,
    selectedPages: selectedPages ?? this.selectedPages,
    webtoon: webtoon ?? this.webtoon,
  );
}

/// What opening files produced, for messages to the user.
class ImportOutcome {
  ImportOutcome(this.added, this.skipped, this.errors, [this.notices = const {}, this.repeatsLeft = 0]);

  final int added;
  final List<String> skipped;

  /// Pages not added: the same pictures are open already.
  final int repeatsLeft;

  /// File → error.
  final Map<String, Object> errors;

  /// PSD file name → what to tell about it.
  final Map<String, List<PsdNotice>> notices;
}

/// A page about to be added with the same picture as an open page or as an
/// earlier one of the same adding.
class RepeatedPage {
  const RepeatedPage({
    required this.name,
    required this.path,
    required this.sameAs,
    required this.sameAsPath,
    this.sameAsNumber,
  });

  final String name;
  final String path;

  /// The name of the page with the same picture, and its number among the
  /// open pages (null: one of the pages being added).
  final String sameAs;
  final int? sameAsNumber;

  /// The picture of that page, to compare.
  final String sameAsPath;
}

/// How "Sort" puts the pages: by name or by file date (of the archive for
/// its pages), either way, or the order turned round.
enum PageOrder { nameUp, nameDown, dateUp, dateDown, reverse }

/// Which of the repeats to add anyway (indexes into the list).
typedef RepeatChooser = Future<Set<int>> Function(List<RepeatedPage> repeats);

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  Directory? _session;
  var _nextId = 0;

  @override
  WorkspaceState build() => const WorkspaceState();

  /// Cache folder of this session: unpacked archives and results.
  Directory get sessionDir {
    if (_session != null) return _session!;
    final root = Directory(p.join(ref.read(servicesProvider).paths.cache.path, 'sessions'));
    _removeOldSessions(root);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    return _session = Directory(p.join(root.path, '$stamp-$pid'))..createSync(recursive: true);
  }

  /// Sessions are not restored yet; old ones are only kept for two days in
  /// case something needs to be recovered by hand.
  static void _removeOldSessions(Directory root) {
    if (!root.existsSync()) return;
    final limit = DateTime.now().subtract(const Duration(days: 2));
    for (final d in root.listSync().whereType<Directory>()) {
      try {
        if (d.statSync().modified.isBefore(limit)) d.deleteSync(recursive: true);
      } on FileSystemException {
        // In use by another window; try next time.
      }
    }
  }

  /// Folder for the results of page [id].
  Directory pageDir(String id) => Directory(p.join(sessionDir.path, 'pages', id))..createSync(recursive: true);

  /// A fresh session folder, for the files of a project being opened; the
  /// current session stays until [loadPages] replaces it.
  Directory newSessionDir() {
    final root = Directory(p.join(ref.read(servicesProvider).paths.cache.path, 'sessions'));
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    return Directory(p.join(root.path, '$stamp-$pid-${_sessionCount++}'))..createSync(recursive: true);
  }

  var _sessionCount = 0;

  /// Replaces the open pages with the pages of a project, whose files are in
  /// [session] (a [newSessionDir]); the old session's files are removed. No
  /// undo history: it is not kept in project files.
  void loadPages(List<PageEntry> pages, {int current = 0, Directory? session, bool webtoon = false}) {
    final old = _session;
    if (session != null) _session = session;
    var next = 0;
    for (final page in pages) {
      final n = int.tryParse(page.id);
      if (n != null && n >= next) next = n + 1;
    }
    _nextId = next;
    state = WorkspaceState(
      pages: pages,
      current: pages.isEmpty ? 0 : current.clamp(0, pages.length - 1),
      webtoon: webtoon,
    );
    if (old != null && session != null && !p.equals(old.path, session.path) && old.existsSync()) {
      try {
        old.deleteSync(recursive: true);
      } on FileSystemException {
        // Files still open; removed with old sessions later.
      }
    }
  }

  /// Adds the pages of [inputs] at [at] (the end by default). Pages with the
  /// same picture as an open page are added only if [chooseRepeats] picks
  /// them (without it: all are added). [open] goes to the first added page.
  Future<ImportOutcome> addInputs(
    List<String> inputs, {
    int? at,
    RepeatChooser? chooseRepeats,
    bool open = false,
  }) async {
    if (inputs.isEmpty || state.importing) return ImportOutcome(0, const [], const {});
    state = state.copyWith(importing: true);
    final skipped = <String>[];
    final errors = <String, Object>{};
    try {
      var imported = await importPages(
        inputs,
        cacheDir: Directory(p.join(sessionDir.path, 'import')),
        pdf: rasterizePdf,
        skipped: skipped,
        onError: (input, e) => errors[input] = e,
        fonts: installedFonts,
      );
      var repeatsLeft = 0;
      if (chooseRepeats != null && imported.isNotEmpty) {
        final open = state.pages;
        final added = [for (final page in imported) page.path];
        final existing = [for (final page in open) page.path];
        final same = await _repeatsInBackground(existing, added);
        final repeats = <int>[
          for (final (i, j) in same.indexed)
            if (j != null) i,
        ];
        if (repeats.isNotEmpty) {
          final keep = await chooseRepeats([
            for (final i in repeats)
              RepeatedPage(
                name: imported[i].name,
                path: imported[i].path,
                sameAs: same[i]! < open.length ? open[same[i]!].name : imported[same[i]! - open.length].name,
                sameAsNumber: same[i]! < open.length ? same[i]! + 1 : null,
                sameAsPath: same[i]! < open.length ? open[same[i]!].path : imported[same[i]! - open.length].path,
              ),
          ]);
          final drop = {
            for (final (k, i) in repeats.indexed)
              if (!keep.contains(k)) i,
          };
          repeatsLeft = drop.length;
          imported = [
            for (final (i, page) in imported.indexed)
              if (!drop.contains(i)) page,
          ];
        }
      }
      final wasEmpty = state.pages.isEmpty;
      final settings = ref.read(settingsProvider);
      final added = [
        for (final page in imported)
          PageEntry(
            id: '${_nextId++}',
            name: page.name,
            path: page.path,
            source: page.source,
            // PSD files: cleaned and translated already.
            cleanPath: page.cleanPath,
            blocks: page.blocks,
            status: page.blocks.isNotEmpty || page.cleanPath != null ? PageStatus.done : PageStatus.pending,
            sourceLanguage: settings.sourceLanguage,
            targetLanguage: settings.targetLanguage,
          ),
      ];
      final pages = state.pages;
      final where = (at ?? pages.length).clamp(0, pages.length);
      state = state.copyWith(
        pages: [...pages.take(where), ...added, ...pages.skip(where)],
        current: open && added.isNotEmpty
            ? where
            : wasEmpty
            ? 0
            : (where <= state.current ? state.current + added.length : null),
        clearBlock: open && added.isNotEmpty,
      );
      ref.read(servicesProvider).appLog.info('pages_opened', {
        'added': added.length,
        'skipped': skipped.length,
        'errors': errors.length,
        'repeats_left': repeatsLeft,
        'at': ?at,
      });
      return ImportOutcome(added.length, skipped, errors, {
        for (final page in imported)
          if (page.notices.isNotEmpty) page.name: page.notices,
      }, repeatsLeft);
    } finally {
      state = state.copyWith(importing: false);
    }
  }

  /// Goes to page [index]. With [toggle] (Ctrl) the page is added to or
  /// taken out of the selected pages; with [range] (Shift) every page from
  /// the current one to it is selected. A plain click clears the selection.
  void select(int index, {bool toggle = false, bool range = false}) {
    if (index < 0 || index >= state.pages.length) return;
    final id = state.pages[index].id;
    Set<String> picked;
    if (range) {
      final from = state.current.clamp(0, state.pages.length - 1);
      final (a, b) = from <= index ? (from, index) : (index, from);
      picked = {...state.selectedPages, for (var i = a; i <= b; i++) state.pages[i].id};
    } else if (toggle) {
      final current = state.currentPage?.id;
      picked = {...state.selectedPages, ?current};
      if (!picked.remove(id) || picked.isEmpty) picked.add(id);
    } else {
      picked = const {};
    }
    // Ctrl on the only selected page takes it out: go to another selected one.
    var go = index;
    if (toggle && !picked.contains(id) && picked.isNotEmpty) {
      go = state.pages.indexWhere((p) => picked.contains(p.id));
    }
    state = state.copyWith(current: go, clearBlock: true, selectedPages: picked.length < 2 ? const {} : picked);
  }

  /// Turns the webtoon mode on or off.
  void setWebtoon(bool on) {
    if (on == state.webtoon) return;
    // Pages below a cut bubble are drawn with its part only in the mode.
    final pages = state.pages;
    state = state.copyWith(
      webtoon: on,
      pages: [
        for (final (i, p) in pages.indexed)
          i > 0 && pages[i - 1].overflowPath != null && p.translatedPath != null ? p.copyWith(translatedPath: null) : p,
      ],
    );
  }

  /// Makes page [index] current without changing the selection (scrolling
  /// the webtoon strip, a click on another page of it).
  void focusPage(int index) {
    if (index < 0 || index >= state.pages.length || index == state.current) return;
    state = state.copyWith(current: index, clearBlock: true);
  }

  void clearPageSelection() => state = state.copyWith(selectedPages: const {});

  /// Ticks page [index] for the steps or takes it out, without Ctrl (the
  /// grid of pages). The last page taken out leaves the current one.
  void togglePick(int index) {
    if (index < 0 || index >= state.pages.length) return;
    final id = state.pages[index].id;
    final picked = {...state.pickedPageIds};
    final added = picked.add(id);
    if (!added) picked.remove(id);
    if (picked.isEmpty) return;
    final go = added ? index : state.pages.indexWhere((p) => picked.contains(p.id));
    state = state.copyWith(current: go, clearBlock: true, selectedPages: picked.length < 2 ? const {} : picked);
  }

  /// Picks the pages at [indexes] for the steps ("1,5-8,10" in the page
  /// list). One page is just opened; with several, the current page stays
  /// open if it is among them, otherwise the first one is opened.
  void pickPages(Set<int> indexes) {
    final valid = indexes.where((i) => i >= 0 && i < state.pages.length).toList()..sort();
    if (valid.isEmpty) return;
    final go = valid.contains(state.current) ? state.current : valid.first;
    state = state.copyWith(
      current: go,
      clearBlock: go != state.current,
      selectedPages: valid.length < 2 ? const {} : {for (final i in valid) state.pages[i].id},
    );
  }

  /// Ticks every page for the steps.
  void pickAllPages() {
    if (state.pages.length < 2) return;
    state = state.copyWith(selectedPages: {for (final p in state.pages) p.id});
  }

  /// Moves page [from] to place [to] (the grid of pages). The current page
  /// stays current. In the webtoon mode a bubble cut by the edge no longer
  /// continues on the page that now follows: its part below is dropped and
  /// both pages are drawn again.
  void movePage(int from, int to) {
    final n = state.pages.length;
    if (from < 0 || from >= n || to < 0 || to >= n || from == to) return;
    final pages = [...state.pages];
    final page = pages.removeAt(from);
    pages.insert(to, page);
    _reorder(pages);
  }

  /// Puts the pages in [order] (by name or date, or turned round); the
  /// order before is returned, for "Undo". Pages that tie (the pages of
  /// one archive by date) keep their order.
  List<String> sortPages(PageOrder order) {
    final before = [for (final p in state.pages) p.id];
    final indexed = state.pages.indexed.toList();
    int byIndex((int, PageEntry) a, (int, PageEntry) b) => a.$1.compareTo(b.$1);
    switch (order) {
      case PageOrder.nameUp || PageOrder.nameDown:
        final sign = order == PageOrder.nameUp ? 1 : -1;
        indexed.sort((a, b) {
          final c = naturalCompare(a.$2.name, b.$2.name) * sign;
          return c != 0 ? c : byIndex(a, b);
        });
      case PageOrder.dateUp || PageOrder.dateDown:
        final sign = order == PageOrder.dateUp ? 1 : -1;
        final times = <String, DateTime>{};
        DateTime time(PageEntry p) => times.putIfAbsent(p.source ?? p.path, () {
          try {
            return File(p.source ?? p.path).lastModifiedSync();
          } on FileSystemException {
            return DateTime(0);
          }
        });
        indexed.sort((a, b) {
          final c = time(a.$2).compareTo(time(b.$2)) * sign;
          return c != 0 ? c : byIndex(a, b);
        });
      case PageOrder.reverse:
        indexed.sort((a, b) => byIndex(b, a));
    }
    _reorder([for (final (_, p) in indexed) p]);
    return before;
  }

  /// The pages in the order of [ids] (an order returned by [sortPages]);
  /// pages not named stay at the end.
  void setPageOrder(List<String> ids) {
    final place = {for (final (i, id) in ids.indexed) id: i};
    final indexed = state.pages.indexed.toList()
      ..sort((a, b) {
        final c = (place[a.$2.id] ?? ids.length).compareTo(place[b.$2.id] ?? ids.length);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    _reorder([for (final (_, p) in indexed) p]);
  }

  /// The open pages in a new order [pages]; see [movePage].
  void _reorder(List<PageEntry> pages) {
    final n = pages.length;
    final current = state.currentPage?.id;
    final oldNext = {for (var i = 0; i + 1 < n; i++) state.pages[i].id: state.pages[i + 1].id};
    final redraw = <String>{};
    final moved = <PageEntry>[];
    for (var i = 0; i < n; i++) {
      final p = pages[i];
      final next = i + 1 < n ? pages[i + 1].id : null;
      if (p.overflowPath != null && oldNext[p.id] != next) {
        redraw.addAll([p.id, ?oldNext[p.id], ?next]);
        moved.add(p.copyWith(overflowPath: null));
      } else {
        moved.add(p);
      }
    }
    state = state.copyWith(
      pages: [for (final p in moved) redraw.contains(p.id) ? p.copyWith(translatedPath: null) : p],
      current: moved.indexWhere((p) => p.id == current).clamp(0, n - 1),
    );
  }

  void selectBlock(int? index) =>
      state = index == null ? state.copyWith(clearBlock: true) : state.copyWith(selectedBlock: index);

  void remove(String id) {
    final pages = [...state.pages]..removeWhere((p) => p.id == id);
    final picked = {...state.selectedPages}..remove(id);
    state = state.copyWith(
      pages: pages,
      current: state.current.clamp(0, pages.isEmpty ? 0 : pages.length - 1),
      clearBlock: true,
      history: {...state.history}..remove(id),
      selectedPages: picked.length < 2 ? const {} : picked,
    );
  }

  void clear() {
    state = const WorkspaceState();
    final dir = _session;
    _session = null;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Files still open (images on screen); removed with old sessions later.
      }
    }
  }

  void markExported(Iterable<String> ids) {
    final set = ids.toSet();
    state = state.copyWith(pages: [for (final p in state.pages) set.contains(p.id) ? p.copyWith(exported: true) : p]);
  }

  /// Changes page [id] without an undo step (progress, status).
  void updatePage(String id, PageEntry Function(PageEntry page) update) {
    state = state.copyWith(pages: [for (final p in state.pages) p.id == id ? update(p) : p]);
  }

  /// Changes page [id] as one undo step. Changes with the same [mergeKey]
  /// within [mergeWindow] of each other (typing in a field, dragging) become
  /// one step. The
  /// drawn page is cleared unless [change] brings a new one, and the page
  /// counts as not exported. A change [byHand] marks the page as edited by
  /// hand (the steps and "Translate all" are not).
  void edit(
    String id,
    PageEntry Function(PageEntry page) change, {
    String? mergeKey,
    Duration mergeWindow = defaultMergeWindow,
    bool byHand = true,
  }) {
    final page = state.byId(id);
    if (page == null) return;
    final h = state.history[id] ?? PageHistory.empty;
    final now = DateTime.now();
    final merge =
        mergeKey != null &&
        h.mergeKey == mergeKey &&
        h.undo.isNotEmpty &&
        h.at != null &&
        now.difference(h.at!) < mergeWindow;
    final undo = merge ? h.undo : [...h.undo, PageSnapshot.of(page)];
    final history = PageHistory(
      undo: undo.length > maxUndoSteps ? undo.sublist(undo.length - maxUndoSteps) : undo,
      mergeKey: mergeKey,
      at: now,
    );
    var next = change(page);
    if (next.translatedPath == page.translatedPath) next = next.copyWith(translatedPath: null);
    next = next.copyWith(exported: false, handEdited: byHand ? true : null);
    // Webtoon mode: the page below shows what reaches into it; it is drawn
    // again too.
    final below = state.webtoon && (!identical(next.blocks, page.blocks) || next.overflowPath != page.overflowPath)
        ? state.pages.indexWhere((p) => p.id == id) + 1
        : -1;
    state = state.copyWith(
      pages: [
        for (final (i, p) in state.pages.indexed)
          if (p.id == id) next else if (i == below && p.translatedPath != null) p.copyWith(translatedPath: null) else p,
      ],
      history: {...state.history, id: history},
    );
  }

  /// Changes block [index] of page [id] (a copy of it) as one undo step.
  void editBlock(String id, int index, void Function(TextBlock block) change, {String? mergeKey}) => edit(id, (p) {
    if (index < 0 || index >= p.blocks.length) return p;
    final blocks = [...p.blocks];
    blocks[index] = blocks[index].copy();
    change(blocks[index]);
    return p.copyWith(blocks: blocks);
  }, mergeKey: mergeKey);

  // Editing the current page.

  /// Adds a block with [box] (page pixels) and selects it.
  void addBlock(BBox box) {
    final page = state.currentPage;
    if (page == null) return;
    edit(
      page.id,
      (p) => p.copyWith(
        blocks: [
          ...p.blocks,
          TextBlock(xyxy: box),
        ],
      ),
    );
    state = state.copyWith(selectedBlock: page.blocks.length);
  }

  void deleteBlock(int index) {
    final page = state.currentPage;
    if (page == null || index < 0 || index >= page.blocks.length) return;
    edit(page.id, (p) => p.copyWith(blocks: [...p.blocks]..removeAt(index)));
    state = state.copyWith(clearBlock: true);
  }

  /// Changes block [index] of the current page (a copy of it).
  void changeBlock(int index, void Function(TextBlock block) change, {String? mergeKey}) {
    final page = state.currentPage;
    if (page != null) editBlock(page.id, index, change, mergeKey: mergeKey);
  }

  /// Changes the style of block [index] of the current page.
  void styleBlock(int index, BlockStyle Function(BlockStyle style) change, {String? mergeKey}) =>
      changeBlock(index, (b) {
        final s = change(b.style ?? const BlockStyle());
        b.style = s.isEmpty ? null : s;
      }, mergeKey: mergeKey);

  /// Applies [change] to the style of every block of the current page.
  void styleAll(BlockStyle Function(BlockStyle style) change) {
    final page = state.currentPage;
    if (page == null || page.blocks.isEmpty) return;
    edit(
      page.id,
      (p) => p.copyWith(
        blocks: [
          for (final b in p.blocks)
            b.copy()
              ..style = (() {
                final s = change(b.style ?? const BlockStyle());
                return s.isEmpty ? null : s;
              })(),
        ],
      ),
    );
  }

  void addStroke(MaskStroke stroke) {
    final page = state.currentPage;
    if (page != null) edit(page.id, (p) => p.copyWith(strokes: [...p.strokes, stroke]));
  }

  /// Removes the mask and the strokes of the current page.
  /// Sets the languages of the current page, or of every page with [all]
  /// (original "Set for all"). Not an undo step, as in the original.
  void setLanguages({String? source, String? target, bool all = false}) {
    final current = state.currentPage;
    if (current == null) return;
    state = state.copyWith(
      pages: [
        for (final p in state.pages)
          if (all || p.id == current.id)
            p.copyWith(
              sourceLanguage: source ?? p.sourceLanguage,
              targetLanguage: target ?? p.targetLanguage,
              translatedPath: target != null && target != p.targetLanguage ? null : p.translatedPath,
            )
          else
            p,
      ],
    );
  }

  /// Makes every box of the current page [by] pixels larger on each side
  /// (smaller when negative; original "Increase / Reduce the size of all
  /// blocks"). Boxes never get smaller than 4 px.
  void growAllBlocks(int by) {
    final page = state.currentPage;
    if (page == null || page.blocks.isEmpty || by == 0) return;
    edit(
      page.id,
      (p) => p.copyWith(
        blocks: [
          for (final b in p.blocks)
            b.copy()
              ..xyxy = () {
                final r = b.xyxy;
                var (x1, y1, x2, y2) = (r.x1 - by, r.y1 - by, r.x2 + by, r.y2 + by);
                if (x2 - x1 < 4) (x1, x2) = ((r.x1 + r.x2) ~/ 2 - 2, (r.x1 + r.x2) ~/ 2 + 2);
                if (y2 - y1 < 4) (y1, y2) = ((r.y1 + r.y2) ~/ 2 - 2, (r.y1 + r.y2) ~/ 2 + 2);
                return BBox(x1, y1, x2, y2);
              }(),
        ],
      ),
    );
  }

  /// Removes every box of the current page (original "Remove all the boxes").
  void deleteAllBlocks() {
    final page = state.currentPage;
    if (page == null || page.blocks.isEmpty) return;
    edit(page.id, (p) => p.copyWith(blocks: const []));
    state = state.copyWith(clearBlock: true);
  }

  void clearMask() {
    final page = state.currentPage;
    if (page != null && page.hasMask) edit(page.id, (p) => p.copyWith(maskPath: null, strokes: const []));
  }

  void undo() => _step(back: true);

  void redo() => _step(back: false);

  void _step({required bool back}) {
    final page = state.currentPage;
    if (page == null) return;
    final h = state.history[page.id] ?? PageHistory.empty;
    final from = back ? h.undo : h.redo;
    if (from.isEmpty) return;
    final target = from.last;
    final rest = from.sublist(0, from.length - 1);
    final other = [...(back ? h.redo : h.undo), PageSnapshot.of(page)];
    final history = back ? PageHistory(undo: rest, redo: other) : PageHistory(undo: other, redo: rest);
    final restored = target.applyTo(page);
    final selected = state.selectedBlock;
    state = state.copyWith(
      pages: [for (final p in state.pages) p.id == page.id ? restored : p],
      history: {...state.history, page.id: history},
      clearBlock: selected == null || selected >= restored.blocks.length,
    );
  }
}

/// [findRepeatedFiles] off the UI thread (a top-level function: the closure
/// must not hold the notifier).
Future<List<int?>> _repeatsInBackground(List<String> existing, List<String> added) =>
    Isolate.run(() => findRepeatedFiles(existing, added));
