/// The open pages (until projects arrive in M9, a session lives in a cache
/// folder and is not restored after restart).
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../import/pdf_pages.dart';
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
    this.blocks = const [],
    this.renderScale = 1.0,
    this.exported = false,
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

  final String? translatedPath;
  final String? cleanPath;

  /// Detected blocks with text and translation, in original page
  /// coordinates.
  final List<TextBlock> blocks;

  /// How much the translated image was enlarged.
  final double renderScale;

  /// The current translation was saved with Export.
  final bool exported;

  bool get isDone => status == PageStatus.done && translatedPath != null;

  PageEntry copyWith({
    PageStatus? status,
    String? stage,
    SkipReason? reason,
    String? translatedPath,
    String? cleanPath,
    List<TextBlock>? blocks,
    double? renderScale,
    bool? exported,
    bool clearStage = false,
    bool clearReason = false,
  }) => PageEntry(
    id: id,
    name: name,
    path: path,
    source: source,
    status: status ?? this.status,
    stage: clearStage ? null : (stage ?? this.stage),
    reason: clearReason ? null : (reason ?? this.reason),
    translatedPath: translatedPath ?? this.translatedPath,
    cleanPath: cleanPath ?? this.cleanPath,
    blocks: blocks ?? this.blocks,
    renderScale: renderScale ?? this.renderScale,
    exported: exported ?? (translatedPath != null && translatedPath != this.translatedPath ? false : this.exported),
  );
}

class WorkspaceState {
  const WorkspaceState({this.pages = const [], this.current = 0, this.importing = false, this.selectedBlock});

  final List<PageEntry> pages;
  final int current;
  final bool importing;

  /// Block highlighted in the viewer (index into the current page's blocks).
  final int? selectedBlock;

  PageEntry? get currentPage => pages.isEmpty ? null : pages[current.clamp(0, pages.length - 1)];
  int get doneCount => pages.where((p) => p.isDone).length;

  /// Translated pages that would be lost on closing (not exported yet).
  int get unexportedCount => pages.where((p) => p.isDone && !p.exported).length;

  WorkspaceState copyWith({
    List<PageEntry>? pages,
    int? current,
    bool? importing,
    int? selectedBlock,
    bool clearBlock = false,
  }) => WorkspaceState(
    pages: pages ?? this.pages,
    current: current ?? this.current,
    importing: importing ?? this.importing,
    selectedBlock: clearBlock ? null : (selectedBlock ?? this.selectedBlock),
  );
}

/// What opening files produced, for messages to the user.
class ImportOutcome {
  ImportOutcome(this.added, this.skipped, this.errors);

  final int added;
  final List<String> skipped;

  /// File → error.
  final Map<String, Object> errors;
}

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

  Future<ImportOutcome> addInputs(List<String> inputs) async {
    if (inputs.isEmpty || state.importing) return ImportOutcome(0, const [], const {});
    state = state.copyWith(importing: true);
    final skipped = <String>[];
    final errors = <String, Object>{};
    try {
      final imported = await importPages(
        inputs,
        cacheDir: Directory(p.join(sessionDir.path, 'import')),
        pdf: rasterizePdf,
        skipped: skipped,
        onError: (input, e) => errors[input] = e,
      );
      final wasEmpty = state.pages.isEmpty;
      final added = [
        for (final page in imported)
          PageEntry(id: '${_nextId++}', name: page.name, path: page.path, source: page.source),
      ];
      state = state.copyWith(pages: [...state.pages, ...added], current: wasEmpty ? 0 : null);
      ref.read(servicesProvider).appLog.info('pages_opened', {
        'added': added.length,
        'skipped': skipped.length,
        'errors': errors.length,
      });
      return ImportOutcome(added.length, skipped, errors);
    } finally {
      state = state.copyWith(importing: false);
    }
  }

  void select(int index) {
    if (index < 0 || index >= state.pages.length) return;
    state = state.copyWith(current: index, clearBlock: true);
  }

  void selectBlock(int? index) =>
      state = index == null ? state.copyWith(clearBlock: true) : state.copyWith(selectedBlock: index);

  void remove(String id) {
    final pages = [...state.pages]..removeWhere((p) => p.id == id);
    state = state.copyWith(
      pages: pages,
      current: state.current.clamp(0, pages.isEmpty ? 0 : pages.length - 1),
      clearBlock: true,
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

  void updatePage(String id, PageEntry Function(PageEntry page) update) {
    state = state.copyWith(pages: [for (final p in state.pages) p.id == id ? update(p) : p]);
  }
}
