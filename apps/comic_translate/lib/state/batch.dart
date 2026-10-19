/// "Translate all": the pipeline over the open pages, in the background
/// worker, with progress, cancellation and a report (original
/// `batch_processor.py` and `batch_report.py`).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../pipeline/page_pipeline.dart';
import '../pipeline/pipeline_worker.dart';
import 'app_state.dart';
import 'workspace.dart';

enum NetworkChoice { once, always, cancel }

/// Questions a run asks the user (dialogs live in the UI).
abstract interface class BatchUi {
  /// Download [models] (sizes and source are shown)?
  Future<bool> confirmDownload(List<ModelSpec> models);

  /// The translator sends data to [endpoint]: allow?
  Future<NetworkChoice> confirmNetwork(PluginInfo translator, PluginEndpoint endpoint, {required bool sendsImage});

  void showError(Object error);

  /// The translator sends text to an internet service but has no API key.
  Future<void> explainMissingKey(PluginInfo translator, String host);
}

/// After this many pages in a row whose translation failed, the run stops.
/// Errors that every page would repeat (key, balance, address, connection)
/// stop it at once; temporary ones are already retried by the translator.
const maxTranslationFailuresInARow = 3;

class SkippedPage {
  const SkippedPage(this.pageId, this.name, this.reason);

  final String pageId;
  final String name;
  final SkipReason reason;
}

class BatchReport {
  const BatchReport({
    required this.total,
    required this.done,
    required this.skipped,
    required this.cancelled,
    required this.duration,
    this.exportDirs = const [],
    this.stoppedBy,
  });

  final int total;
  final int done;
  final List<SkippedPage> skipped;
  final bool cancelled;
  final Duration duration;

  /// Folders of the automatic export (text, cleaned pages).
  final List<String> exportDirs;

  /// Why the run stopped before the end on its own (translator errors).
  final SkipReason? stoppedBy;
}

sealed class BatchState {
  const BatchState();
}

class BatchIdle extends BatchState {
  const BatchIdle([this.last]);

  /// Report of the previous run.
  final BatchReport? last;
}

class BatchRunning extends BatchState {
  const BatchRunning({
    required this.total,
    required this.done,
    required this.started,
    this.pageName,
    this.stage,
    this.download,
    this.pageMs = const [],
    this.stopping = false,
  });

  final int total;
  final int done;
  final DateTime started;
  final String? pageName;

  /// `loading`, `download` or a pipeline stage (`01_detect` …).
  final String? stage;

  /// Model download progress 0…1 while [stage] is `download`.
  final double? download;

  /// Time each finished page took, for the estimate.
  final List<int> pageMs;
  final bool stopping;

  /// Estimated time left, once a page is done.
  Duration? get remaining {
    if (pageMs.isEmpty) return null;
    final avg = pageMs.reduce((a, b) => a + b) / pageMs.length;
    return Duration(milliseconds: (avg * (total - done)).round());
  }

  BatchRunning copyWith({
    int? done,
    String? pageName,
    String? stage,
    double? download,
    List<int>? pageMs,
    bool? stopping,
  }) => BatchRunning(
    total: total,
    done: done ?? this.done,
    started: started,
    pageName: pageName ?? this.pageName,
    stage: stage ?? this.stage,
    download: download ?? this.download,
    pageMs: pageMs ?? this.pageMs,
    stopping: stopping ?? this.stopping,
  );
}

/// Pipeline stage → its error, worded for the user.
SkipReason skipReasonFor(Object e) => switch (e) {
  ModelNotInstalledException(:final spec) => ModelMissingReason(spec.displayName),
  TranslationException(:final kind, :final message) => TranslationFailedReason(kind, message),
  WorkerException(type: 'exit') => const WorkerStoppedReason(),
  ImageDecodeException() => const UnreadableImageReason(),
  UnsupportedError(:final message) => OtherReason(message ?? '$e'),
  _ => OtherReason('$e'),
};

final batchProvider = NotifierProvider<BatchNotifier, BatchState>(BatchNotifier.new);

class BatchNotifier extends Notifier<BatchState> {
  CancelToken? _cancel;
  var _run = 0;

  @override
  BatchState build() => const BatchIdle();

  bool get isRunning => state is BatchRunning;

  void stop() {
    final s = state;
    if (s is! BatchRunning) return;
    _cancel?.cancel();
    state = s.copyWith(stopping: true);
  }

  void _update(BatchRunning Function(BatchRunning s) change) {
    final s = state;
    if (s is BatchRunning) state = change(s);
  }

  /// Translates the pages that are not done yet (all of them when every
  /// page is done, or with [all]).
  Future<void> run(BatchUi ui, {bool all = false}) async {
    if (isRunning) return;
    final services = ref.read(servicesProvider);
    final workspace = ref.read(workspaceProvider.notifier);
    final pages = ref.read(workspaceProvider).pages;
    final todo = all || pages.every((p) => p.isDone)
        ? pages
        : [
            for (final p in pages)
              if (!p.isDone) p,
          ];
    if (todo.isEmpty) return;
    final last = switch (state) {
      BatchIdle(:final last) => last,
      _ => null,
    };
    final cancel = _cancel = CancelToken();
    final started = DateTime.now();
    final log = services.appLog.child(stage: 'batch');
    state = BatchRunning(total: todo.length, done: 0, started: started, stage: 'loading');

    var done = 0;
    var failuresInARow = 0;
    SkipReason? stoppedBy;
    final skipped = <SkippedPage>[];
    final exportDirs = <String>{};
    PipelineWorker? worker;
    try {
      if (!await _checkKey(ui) || !await _approveNetwork(ui)) {
        state = BatchIdle(last);
        return;
      }
      if (!await _ensureModels(ui, cancel)) {
        state = BatchIdle(last);
        return;
      }
      final settings = ref.read(settingsProvider);
      _update((s) => s.copyWith(stage: 'loading'));
      final spec = await PipelineSpec.resolve(
        services,
        settings,
        sourceLanguage: settings.sourceLanguage,
        targetLanguage: settings.targetLanguage,
      );
      worker = await PipelineWorker.start(
        WorkerSetup(
          spec: spec,
          modelsDir: services.models.root.path,
          runsDir: settings.testMode ? services.paths.runs.path : null,
          environment: settings.testMode ? services.environment() : const {},
          runLabel: 'gui',
          homeDir: AppPaths.homeDir(),
          registry: ref.read(workerRegistryProvider),
        ),
        log: log,
      );
      log.info('batch_start', {'pages': todo.length, 'translator': settings.translator});
      final stamp = _stamp(started);
      final pageMs = <int>[];
      for (final (i, page) in todo.indexed) {
        if (cancel.isCancelled) break;
        final sw = Stopwatch()..start();
        void stage(String s) {
          workspace.updatePage(page.id, (p) => p.copyWith(stage: s));
          _update((b) => b.copyWith(stage: s));
        }

        workspace.updatePage(
          page.id,
          (p) => p.copyWith(status: PageStatus.running, stage: '01_detect', clearReason: true),
        );
        _update((b) => b.copyWith(done: i, pageName: page.name, stage: '01_detect'));
        try {
          final cleaned = await worker.prepare(
            page.name,
            path: page.path,
            sourceLanguage: settings.sourceLanguage,
            targetLanguage: settings.targetLanguage,
            cancel: cancel,
            onStage: stage,
          );
          cancel.throwIfCancelled();
          stage('06_render');
          final renderWatch = Stopwatch()..start();
          final render = await renderPage(
            cleaned.clean,
            cleaned.blocks,
            settings,
            targetLanguage: settings.targetLanguage,
          );
          final renderMs = renderWatch.elapsedMilliseconds;
          final dir = workspace.pageDir(page.id);
          final run = _run++;
          final translated = p.join(dir.path, 'translated_$run.png');
          final clean = p.join(dir.path, 'clean_$run.png');
          await worker.save(
            [
              ImageOutput(translated, render.image),
              ImageOutput(clean, cleaned.clean),
              JsonOutput(p.join(dir.path, 'page.json'), {
                'image': page.path,
                'source_language': settings.sourceLanguage,
                'target_language': settings.targetLanguage,
                'render_scale': render.scale,
                'blocks': [for (final b in cleaned.blocks) b.toJson()],
                'timings_ms': {...cleaned.timingsMs, '06_render': renderMs},
              }),
            ],
            page: page.name,
            render: render,
            renderMs: renderMs,
          );
          workspace.updatePage(
            page.id,
            (p) => p.copyWith(
              status: PageStatus.done,
              translatedPath: translated,
              cleanPath: clean,
              blocks: cleaned.blocks,
              renderScale: render.scale,
              clearStage: true,
            ),
          );
          done++;
          failuresInARow = 0;
          if (settings.export.anyAutomatic) {
            final out = await _autoExport(worker, page, cleaned, settings.export, stamp, log);
            if (out != null) exportDirs.add(out);
          }
        } on CancelledException {
          workspace.updatePage(
            page.id,
            (p) =>
                p.copyWith(status: p.translatedPath != null ? PageStatus.done : PageStatus.pending, clearStage: true),
          );
          break;
        } catch (e, st) {
          log.error('page_failed', e, st, {'page': page.name});
          final reason = skipReasonFor(e);
          skipped.add(SkippedPage(page.id, page.name, reason));
          workspace.updatePage(
            page.id,
            (p) => p.copyWith(status: PageStatus.skipped, reason: reason, clearStage: true),
          );
          failuresInARow = reason is TranslationFailedReason ? failuresInARow + 1 : 0;
          final fatal = reason is TranslationFailedReason && reason.kind.stopsRun;
          if (fatal || failuresInARow >= maxTranslationFailuresInARow || reason is WorkerStoppedReason) {
            log.warn('batch_stopped', {'failures_in_a_row': failuresInARow, 'reason': reason.runtimeType.toString()});
            stoppedBy = reason;
            pageMs.add(sw.elapsedMilliseconds);
            _update((b) => b.copyWith(done: i + 1, pageMs: List.of(pageMs)));
            break;
          }
        }
        pageMs.add(sw.elapsedMilliseconds);
        _update((b) => b.copyWith(done: i + 1, pageMs: List.of(pageMs)));
      }
    } on CancelledException {
      // Stopped while downloading or loading.
    } catch (e, st) {
      log.error('batch_failed', e, st);
      ui.showError(e);
    } finally {
      final cancelled = cancel.isCancelled;
      await worker?.dispose(success: skipped.isEmpty && !cancelled, summary: {'pages': todo.length, 'done': done});
      _cancel = null;
      if (state is BatchRunning) {
        final report = BatchReport(
          total: todo.length,
          done: done,
          skipped: skipped,
          cancelled: cancelled,
          duration: DateTime.now().difference(started),
          exportDirs: exportDirs.toList(),
          stoppedBy: stoppedBy,
        );
        log.info('batch_end', {'done': done, 'skipped': skipped.length, 'cancelled': cancelled});
        state = BatchIdle(report);
      }
    }
  }

  /// An internet translator without its key would fail every page.
  Future<bool> _checkKey(BatchUi ui) async {
    final services = ref.read(servicesProvider);
    final settings = ref.read(settingsProvider);
    final info = services.registry.info(settings.translator);
    final config = await services.pluginConfig(settings.translator, settings);
    final endpoint = info.endpointFor(config);
    final keys = info.settings.whereType<SecretSetting>();
    if (endpoint == null || endpoint.privacy != Privacy.cloud || keys.isEmpty) return true;
    if (keys.any((k) => config.secret(k.key) != null)) return true;
    await ui.explainMissingKey(info, endpoint.host);
    return false;
  }

  Future<bool> _approveNetwork(BatchUi ui) async {
    final services = ref.read(servicesProvider);
    final settings = ref.read(settingsProvider);
    final info = services.registry.info(settings.translator);
    final endpoint = info.endpointFor(await services.pluginConfig(settings.translator, settings));
    if (endpoint == null) return true;
    final key = endpoint.approvalKey(info.id);
    if (settings.approvedNetworkPlugins.contains(key)) return true;
    switch (await ui.confirmNetwork(info, endpoint, sendsImage: settings.sendPageImage)) {
      case NetworkChoice.cancel:
        return false;
      case NetworkChoice.once:
        return true;
      case NetworkChoice.always:
        await ref.read(settingsProvider.notifier).change((s) => s.approvedNetworkPlugins.add(key));
        return true;
    }
  }

  /// Offers to download the models the chosen plugins need.
  Future<bool> _ensureModels(BatchUi ui, CancelToken cancel) async {
    final services = ref.read(servicesProvider);
    final settings = ref.read(settingsProvider);
    final missing = await missingModels(services.registry, services.models, settings);
    if (missing.isEmpty) return true;
    if (!await ui.confirmDownload(missing)) return false;
    final total = missing.fold<int>(0, (a, m) => a + m.files.fold(0, (b, f) => b + f.size));
    var before = 0;
    for (final spec in missing) {
      _update((s) => s.copyWith(stage: 'download', download: before / total));
      await services.models.download(
        spec,
        cancel: cancel,
        onProgress: (d) {
          _update((s) => s.copyWith(stage: 'download', download: (before + d.received) / total));
        },
      );
      before += spec.files.fold(0, (b, f) => b + f.size);
    }
    return true;
  }

  /// Writes the original's automatic exports for [page]; returns the folder.
  Future<String?> _autoExport(
    PipelineWorker worker,
    PageEntry page,
    CleanPage cleaned,
    ExportSettings export,
    String stamp,
    EventLog log,
  ) async {
    final origin = page.source ?? page.path;
    final base = p.join(p.dirname(origin), 'comic_translate_$stamp');
    final sub = page.source == null ? '' : p.basenameWithoutExtension(page.source!);
    final stem = p.basenameWithoutExtension(page.source == null ? page.path : page.name);
    String at(String kind, String file) => p.joinAll([base, kind, if (sub.isNotEmpty) sub, file]);
    Map<String, String> texts(String Function(TextBlock b) pick) => {
      for (final (i, b) in cleaned.blocks.indexed) 'block_$i': pick(b),
    };
    try {
      await worker.save([
        if (export.rawText) JsonOutput(at('raw_texts', '${stem}_raw.json'), texts((b) => b.text)),
        if (export.translatedText)
          JsonOutput(at('translated_texts', '${stem}_translated.json'), texts((b) => b.translation)),
        if (export.cleanedImage)
          ImageOutput(at('cleaned_images', '${stem}_cleaned${_writableExtension(page.path)}'), cleaned.clean),
      ]);
      return base;
    } catch (e, st) {
      log.error('auto_export_failed', e, st, {'page': page.name, 'dir': base});
      return null;
    }
  }
}

/// Models the plugins chosen in [settings] need and that are not downloaded.
Future<List<ModelSpec>> missingModels(PluginRegistry registry, ModelManager models, AppSettings settings) async {
  final ids = <String>{
    for (final id in [settings.detector, settings.ocr, settings.inpainter])
      if (registry.contains(id)) ...registry.info(id).requiredModels(settings.sourceLanguage),
  };
  return [
    for (final id in ids)
      if (ModelCatalog.byId(id) case final spec? when await models.status(spec) != ModelStatus.installed) spec,
  ];
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// The extension of [path] if images can be written in it, else `.png`.
String _writableExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  return const {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}.contains(ext) ? ext : '.png';
}

/// Saves the translated pages into [dir] (in a background isolate), named
/// after the original files; returns how many were written.
Future<int> exportTranslatedPages(List<PageEntry> pages, String dir, String format) async {
  final jobs = <(String, String)>[];
  final used = <String>{};
  for (final page in pages.where((p) => p.isDone)) {
    final ext = format == 'source' ? _writableExtension(page.path) : '.$format';
    final stem = page.source == null
        ? p.basenameWithoutExtension(page.path)
        : '${p.basenameWithoutExtension(page.source!)}_${p.basenameWithoutExtension(page.path)}';
    var name = '$stem$ext';
    for (var n = 2; !used.add(name.toLowerCase()); n++) {
      name = '${stem}_$n$ext';
    }
    jobs.add((page.translatedPath!, p.join(dir, name)));
  }
  return Isolate.run(() async {
    for (final (from, to) in jobs) {
      if (p.extension(to).toLowerCase() == '.png') {
        await File(from).copy(to);
      } else {
        await ImageCodec.writeFile(to, await ImageCodec.readFile(from));
      }
    }
    return jobs.length;
  });
}
