/// One background worker shared by "Translate all" and the editor's single
/// steps: models stay loaded between runs (a step after another costs no
/// loading time) and are released after a few idle minutes, since memory is
/// tight on small laptops.
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pipeline/page_pipeline.dart';
import '../pipeline/pipeline_worker.dart';
import 'app_state.dart';
import 'workspace.dart';

class WorkerPool {
  WorkerPool({this.idle = const Duration(minutes: 3)});

  /// How long an unused worker keeps its models.
  final Duration idle;

  PipelineWorker? _worker;
  String? _key;
  Timer? _timer;
  var _users = 0;
  var _lock = Future<void>.value();

  /// Whether a worker is running (models may be loaded).
  bool get isRunning => _worker != null && !_worker!.isClosed;

  /// A worker for [setup]: the running one when its plugins and settings
  /// match [key], else a new one. Call [release] when done.
  Future<PipelineWorker> acquire(WorkerSetup setup, String key, EventLog log) {
    _timer?.cancel();
    _users++;
    final result = _lock.then((_) async {
      final current = _worker;
      if (current != null && !current.isClosed && _key == key) return current;
      _worker = null;
      await current?.dispose();
      final worker = await PipelineWorker.start(setup, log: log);
      _worker = worker;
      _key = key;
      return worker;
    });
    _lock = result.then((_) {}, onError: (_) {});
    return result.then(
      (w) => w,
      onError: (Object e, StackTrace st) {
        release();
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  void release() {
    _users = (_users - 1).clamp(0, 1 << 30);
    if (_users > 0) return;
    _timer?.cancel();
    _timer = Timer(idle, () => unawaited(close()));
  }

  /// Stops the worker (its models are released; in test mode its run folder
  /// is finished).
  Future<void> close({bool success = true, Map<String, Object?>? summary}) async {
    _timer?.cancel();
    final worker = _worker;
    _worker = null;
    _key = null;
    await worker?.dispose(success: success, summary: summary);
  }

  /// Stops at once (the app is closing).
  void kill() {
    _timer?.cancel();
    _worker?.kill();
    _worker = null;
    _key = null;
  }
}

final workerPoolProvider = Provider<WorkerPool>((ref) {
  final pool = WorkerPool();
  ref.onDispose(pool.kill);
  return pool;
});

/// How many pages the chosen translator takes in one request (its "Pages in
/// one request"); 1 for translators without it.
int pagesPerRequest(PluginRegistry registry, AppSettings settings) {
  final id = settings.translator;
  if (!registry.contains(id)) return 1;
  final info = registry.info(id);
  if (info.field('pages_per_request') == null) return 1;
  return PluginConfig.resolve(info.settings, settings.pluginValues(id)).value<int>('pages_per_request');
}

/// [PipelineWorker.translatePack]; an answer cut off at the length limit
/// (a model that thinks first runs out of it on many pages): the pages again
/// in two halves, down to one page, before giving up. [onSplit] is told the
/// size of each pack that was split.
Future<List<List<TextBlock>>> translatePackSplitting(
  PipelineWorker worker,
  List<PackJob> pages, {
  required String sourceLanguage,
  required String targetLanguage,
  CancelToken? cancel,
  void Function(int pages)? onSplit,
}) async {
  try {
    return await worker.translatePack(
      pages,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      cancel: cancel,
    );
  } on TranslationException catch (e) {
    if (pages.length < 2 || e.kind != TranslationErrorKind.cutOff) rethrow;
    onSplit?.call(pages.length);
    final half = pages.length ~/ 2;
    Future<List<List<TextBlock>>> part(List<PackJob> some) => translatePackSplitting(
      worker,
      some,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      cancel: cancel,
      onSplit: onSplit,
    );
    return [...await part(pages.sublist(0, half)), ...await part(pages.sublist(half))];
  }
}

/// Pages that may go together in one request: in order, at most [size],
/// never across a chapter (another archive or folder, as [chapterOf] tells).
List<List<T>> packsOf<T>(List<T> pages, int size, String Function(T page) chapterOf) {
  final packs = <List<T>>[];
  for (final page in pages) {
    final last = packs.isEmpty ? null : packs.last;
    if (last != null && last.length < size && chapterOf(last.first) == chapterOf(page)) {
      last.add(page);
    } else {
      packs.add([page]);
    }
  }
  return packs;
}

/// [settings] for the worker: the chosen styles of translation and the
/// project's [glossary] go to translators over the network with the extra
/// context (as to a chat).
AppSettings settingsForTranslators(AppSettings settings, String glossary) {
  final extra = [
    settings.extraContext,
    promptStyleLine(settings.exchange.chosenStyles),
    Glossary.parse(glossary).forPrompt(),
  ].where((s) => s.trim().isNotEmpty).join('\n');
  if (extra == settings.extraContext) return settings;
  return AppSettings.fromJson(settings.toJson())..extraContext = extra;
}

/// The worker setup for the current settings (plugins load when first
/// needed) and the key that tells when a running worker no longer fits.
Future<(WorkerSetup, String)> currentWorkerSetup(Ref ref) async {
  final services = ref.read(servicesProvider);
  final settings = settingsForTranslators(ref.read(settingsProvider), ref.read(workspaceProvider).glossary);
  final spec = await PipelineSpec.resolve(
    services,
    settings,
    sourceLanguage: settings.sourceLanguage,
    targetLanguage: settings.targetLanguage,
  );
  final runs = settings.testMode ? services.paths.runs.path : null;
  final setup = WorkerSetup(
    spec: spec,
    modelsDir: services.models.root.path,
    runsDir: runs,
    environment: settings.testMode ? services.environment() : const {},
    runLabel: 'gui',
    homeDir: AppPaths.homeDir(),
    registry: ref.read(workerRegistryProvider),
    preload: const {},
    usageFile: services.paths.usageFile.path,
    historyFile: services.paths.historyFile.path,
  );
  return (setup, '${spec.fingerprint}|${services.models.root.path}|${runs ?? ''}');
}
