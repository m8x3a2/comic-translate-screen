/// The open project: its file, unsaved changes, saving and crash recovery
/// (original `app/controllers/projects.py`).
///
/// - A project with a file saves itself [ProjectNotifier.autosaveDelay]
///   after the last change (setting `projects.autosave`, on by default; the
///   original's is off by default). During "Translate all" that is after
///   every page.
/// - Work without a project file (or with autosave off) goes into a
///   recovery file every [ProjectNotifier.recoveryInterval]; after a crash the
///   next start offers to restore it. A clean exit removes it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app_info.dart';
import 'app_state.dart';
import 'workspace.dart';

bool isProjectPath(String path) => p.extension(path).toLowerCase() == ProjectFile.extension;

Map<String, Object?> skipReasonToJson(SkipReason reason) => switch (reason) {
  ModelMissingReason(:final model) => {'kind': 'model_missing', 'model': model},
  TranslationFailedReason(:final kind, :final message) => {
    'kind': 'translation',
    'error': kind.name,
    'message': message,
  },
  WorkerStoppedReason() => {'kind': 'worker_stopped'},
  UnreadableImageReason() => {'kind': 'unreadable_image'},
  OtherReason(:final message) => {'kind': 'other', 'message': message},
};

SkipReason? skipReasonFromJson(Object? json) {
  if (json is! Map) return null;
  return switch (json['kind']) {
    'model_missing' => ModelMissingReason('${json['model']}'),
    'translation' => TranslationFailedReason(
      TranslationErrorKind.values.asNameMap()[json['error']] ?? TranslationErrorKind.other,
      '${json['message'] ?? ''}',
    ),
    'worker_stopped' => const WorkerStoppedReason(),
    'unreadable_image' => const UnreadableImageReason(),
    _ => OtherReason('${json['message'] ?? ''}'),
  };
}

/// What a project file keeps of a page: everything but the drawn page (a
/// cache) and the undo history.
ProjectPage projectPageOf(PageEntry page) => ProjectPage(
  id: page.id,
  name: page.name,
  source: page.source,
  image: page.path,
  cleanImage: page.cleanPath,
  mask: page.maskPath,
  overflow: page.overflowPath,
  blocks: page.blocks,
  strokes: page.strokes,
  state: {
    'status': switch (page.status) {
      PageStatus.done => 'done',
      PageStatus.skipped => 'skipped',
      PageStatus.pending || PageStatus.running => 'pending',
    },
    if (page.reason != null) 'reason': skipReasonToJson(page.reason!),
    if (page.renderScale != 1) 'render_scale': page.renderScale,
    if (page.exported) 'exported': true,
    if (page.handEdited) 'hand_edited': true,
    'source_language': ?page.sourceLanguage,
    'target_language': ?page.targetLanguage,
  },
);

PageEntry pageEntryOf(ProjectPage page) => PageEntry(
  id: page.id,
  name: page.name,
  path: page.image,
  source: page.source,
  status: switch (page.state['status']) {
    'done' => PageStatus.done,
    'skipped' => PageStatus.skipped,
    _ => PageStatus.pending,
  },
  reason: skipReasonFromJson(page.state['reason']),
  cleanPath: page.cleanImage,
  maskPath: page.mask,
  overflowPath: page.overflow,
  strokes: page.strokes,
  blocks: page.blocks,
  renderScale: (page.state['render_scale'] as num?)?.toDouble() ?? 1,
  exported: page.state['exported'] == true,
  handEdited: page.state['hand_edited'] == true,
  sourceLanguage: page.state['source_language'] as String?,
  targetLanguage: page.state['target_language'] as String?,
);

ProjectData projectDataOf(WorkspaceState ws, {Map<String, Object?> extra = const {}}) => ProjectData(
  pages: [for (final page in ws.pages) projectPageOf(page)],
  state: {
    'current': ws.current,
    if (ws.webtoon) 'webtoon': true,
    if (ws.glossary.trim().isNotEmpty) 'glossary': ws.glossary,
    ...extra,
  },
);

// Isolate entry points: top-level, so nothing of the app is copied along.

Future<ProjectSaveReport> _saveInBackground(String path, ProjectData data, bool replace) =>
    Isolate.run(() => ProjectFile.save(path, data, appVersion: AppInfo.version, replace: replace));

Future<ProjectData> _loadInBackground(String path, String filesDir) =>
    Isolate.run(() => ProjectFile.load(path, Directory(filesDir)));

class ProjectState {
  const ProjectState({this.path, this.dirty = false, this.saving = false, this.savedAt, this.error});

  /// The project file; null while the work was never saved.
  final String? path;

  /// Changes since the last save.
  final bool dirty;
  final bool saving;
  final DateTime? savedAt;

  /// Why the last save failed (technical, English).
  final String? error;

  String? get name => path == null ? null : p.basenameWithoutExtension(path!);

  ProjectState copyWith({bool? dirty, bool? saving, String? error, bool clearError = false}) => ProjectState(
    path: path,
    dirty: dirty ?? this.dirty,
    saving: saving ?? this.saving,
    savedAt: savedAt,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Unsaved work found from a previous run that did not end normally.
class Recovery {
  const Recovery(this.file, this.pages, this.saved);

  final String file;
  final int pages;
  final DateTime? saved;
}

final projectProvider = NotifierProvider<ProjectNotifier, ProjectState>(ProjectNotifier.new);

class ProjectNotifier extends Notifier<ProjectState> {
  static const autosaveDelay = Duration(seconds: 2);
  static const recoveryInterval = Duration(minutes: 2);

  var _revision = 0;
  var _loading = false;
  List<PageEntry>? _loaded;
  Timer? _autosave;
  Timer? _recovery;
  Future<void> _queue = Future.value();
  RandomAccessFile? _lock;
  bool? _ownsRecovery;

  @override
  ProjectState build() {
    ref.listen(workspaceProvider.select((s) => s.pages), (prev, next) {
      if (_loading || identical(next, _loaded) || identical(prev, next)) return;
      if (next.isEmpty) {
        _closed();
      } else {
        _changed();
      }
    });
    ref.listen(workspaceProvider.select((s) => s.webtoon), (prev, next) {
      if (!_loading && prev != next && ref.read(workspaceProvider).pages.isNotEmpty) _changed();
    });
    ref.listen(workspaceProvider.select((s) => s.glossary), (prev, next) {
      if (!_loading && prev != next && ref.read(workspaceProvider).pages.isNotEmpty) _changed();
    });
    ref.onDispose(() {
      _autosave?.cancel();
      _recovery?.cancel();
      _lock?.closeSync();
    });
    return const ProjectState();
  }

  EventLog get _log => ref.read(servicesProvider).appLog;

  void _changed() {
    _revision++;
    if (!state.dirty) state = state.copyWith(dirty: true);
    if (state.path != null && ref.read(settingsProvider).projectAutosave) {
      _autosave?.cancel();
      _autosave = Timer(autosaveDelay, () => save());
    } else {
      _recovery ??= Timer(recoveryInterval, () {
        _recovery = null;
        writeRecovery();
      });
    }
  }

  /// All pages were closed: the project is closed too.
  void _closed() {
    _autosave?.cancel();
    _recovery?.cancel();
    _recovery = null;
    state = const ProjectState();
    discardRecovery();
  }

  /// Saves the project into its file, or into [to] (Save As). Saves run one
  /// after another, each with the pages as they are when it starts. Returns
  /// false when there is no file to save to or saving failed (see
  /// [ProjectState.error]).
  Future<bool> save({String? to}) {
    _autosave?.cancel();
    final done = Completer<bool>();
    _queue = _queue.then((_) async => done.complete(await _save(to)));
    return done.future;
  }

  Future<bool> _save(String? to) async {
    final path = to ?? state.path;
    final ws = ref.read(workspaceProvider);
    if (path == null || ws.pages.isEmpty) return false;
    if (to == null && !state.dirty) return true;
    final revision = _revision;
    final data = projectDataOf(ws);
    final replace = to != null && (state.path == null || !p.equals(to, state.path!));
    state = state.copyWith(saving: true);
    final sw = Stopwatch()..start();
    try {
      final report = await _saveInBackground(path, data, replace);
      _log.info('project_saved', {
        'pages': data.pages.length,
        'pages_written': report.pagesWritten,
        'files_added': report.filesAdded,
        'files_removed': report.filesRemoved,
        'ms': sw.elapsedMilliseconds,
        'save_as': to != null,
      });
      state = ProjectState(path: path, dirty: _revision != revision, savedAt: DateTime.now());
      // Remembered at once, with the state: the settings save is queued
      // before anyone sees the project as saved.
      remember(path);
      _recovery?.cancel();
      _recovery = null;
      await discardRecovery();
      if (state.dirty) _changed();
      return true;
    } on Object catch (e, st) {
      _log.error('project_save_failed', e, st, {'path': path});
      state = state.copyWith(saving: false, error: e is FileSystemException ? (e.osError?.message ?? e.message) : '$e');
      return false;
    }
  }

  /// Opens the project at [path] instead of the open pages (the caller asks
  /// about unsaved changes first). Throws [ProjectFormatException] or
  /// [FileSystemException]; the open pages stay then.
  Future<void> open(String path) async {
    await _queue;
    final ws = ref.read(workspaceProvider.notifier);
    final session = ws.newSessionDir();
    final ProjectData data;
    try {
      data = await _loadInBackground(path, p.join(session.path, 'project'));
    } catch (_) {
      try {
        session.deleteSync(recursive: true);
      } on FileSystemException {
        // removed with old sessions later
      }
      rethrow;
    }
    _show(data, session);
    state = ProjectState(path: path, savedAt: File(path).statSync().modified);
    _log.info('project_opened', {'pages': data.pages.length});
    remember(path);
  }

  void _show(ProjectData data, Directory session) {
    _autosave?.cancel();
    _recovery?.cancel();
    _recovery = null;
    _loading = true;
    try {
      ref
          .read(workspaceProvider.notifier)
          .loadPages(
            [for (final page in data.pages) pageEntryOf(page)],
            current: (data.state['current'] as num?)?.toInt() ?? 0,
            webtoon: data.state['webtoon'] == true,
            glossary: data.state['glossary'] is String ? data.state['glossary'] as String : '',
            session: session,
          );
      _loaded = ref.read(workspaceProvider).pages;
    } finally {
      _loading = false;
    }
  }

  // Recent projects.

  /// Puts [path] first in the recent projects.
  void remember(String path) => ref.read(settingsProvider.notifier).change((s) {
    s.recentProjects
      ..removeWhere((r) => p.equals(r, path))
      ..insert(0, path);
    if (s.recentProjects.length > AppSettings.maxRecentProjects) {
      s.recentProjects.removeRange(AppSettings.maxRecentProjects, s.recentProjects.length);
    }
  });

  void forget(String path) =>
      ref.read(settingsProvider.notifier).change((s) => s.recentProjects.removeWhere((r) => p.equals(r, path)));

  // Crash recovery.

  File get _recoveryFile => File(p.join(ref.read(servicesProvider).paths.root.path, 'autosave', 'recovery.ctsproj'));

  /// Only the first window of the program keeps a recovery file (a second
  /// one would overwrite it).
  bool _owns() {
    if (_ownsRecovery != null) return _ownsRecovery!;
    try {
      final lock = File(p.join(_recoveryFile.parent.path, 'instance.lock'));
      lock.parent.createSync(recursive: true);
      final raf = lock.openSync(mode: FileMode.write);
      try {
        raf.lockSync(FileLock.exclusive);
      } on FileSystemException {
        raf.closeSync();
        return _ownsRecovery = false;
      }
      _lock = raf;
      return _ownsRecovery = true;
    } on FileSystemException {
      return _ownsRecovery = false;
    }
  }

  /// Saves the open pages into the recovery file (the project file and the
  /// unsaved state stay as they are).
  Future<void> writeRecovery() {
    final done = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        final ws = ref.read(workspaceProvider);
        if (!state.dirty || ws.pages.isEmpty || !_owns()) return;
        final data = projectDataOf(ws, extra: {if (state.path != null) 'project_path': state.path});
        final sw = Stopwatch()..start();
        await _saveInBackground(_recoveryFile.path, data, false);
        _log.info('recovery_saved', {'pages': data.pages.length, 'ms': sw.elapsedMilliseconds});
      } on Object catch (e, st) {
        _log.error('recovery_save_failed', e, st);
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  /// Unsaved work of a previous run, if it ended without closing normally.
  Recovery? findRecovery() {
    final file = _recoveryFile;
    if (!file.existsSync() || !_owns()) return null;
    try {
      final info = ProjectFile.info(file.path);
      return Recovery(file.path, info.pages, info.saved);
    } on Object catch (e) {
      _log.warn('recovery_unreadable', {'error': '$e'});
      return null;
    }
  }

  /// Opens the recovered work as unsaved changes (of its project, if it had
  /// one). The recovery file stays until the work is saved or closed.
  Future<void> restoreRecovery() async {
    final file = _recoveryFile;
    final ws = ref.read(workspaceProvider.notifier);
    final session = ws.newSessionDir();
    final data = await _loadInBackground(file.path, p.join(session.path, 'project'));
    _show(data, session);
    final project = data.state['project_path'];
    state = ProjectState(path: project is String && File(project).existsSync() ? project : null, dirty: true);
    _revision++;
    _log.info('recovery_restored', {'pages': data.pages.length});
  }

  Future<void> discardRecovery() async {
    final file = _recoveryFile;
    if (!file.existsSync() || !_owns()) return;
    try {
      await file.delete();
    } on FileSystemException catch (e) {
      _log.warn('recovery_not_removed', {'error': e.message});
    }
  }
}
