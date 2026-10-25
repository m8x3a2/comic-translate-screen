/// "Translate all": the pipeline over the open pages, in the background
/// worker, with progress, cancellation and a report (original
/// `batch_processor.py` and `batch_report.py`).
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../pipeline/page_pipeline.dart';
import '../pipeline/pipeline_worker.dart';
import 'app_state.dart';
import 'exchange.dart';
import 'page_render.dart';
import 'steps.dart';
import 'worker_pool.dart';
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
  /// An empty [host]: no server address is set at all.
  Future<void> explainMissingKey(PluginInfo translator, String host);

  /// [count] of the pages to translate were changed by hand: translate them
  /// again (losing those changes), skip them, or stop?
  Future<HandEditedChoice> confirmHandEdited(int count);

  /// Opens the exchange with a chat AI for [request]; true when the
  /// chat's answer was applied.
  Future<bool> exchange(ExchangeRequest request);
}

enum HandEditedChoice { translate, skip, cancel }

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
    this.stageMs = const {},
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

  /// Time of each stage (`01_detect` … `06_render`), all translated pages
  /// together, in milliseconds.
  final Map<String, int> stageMs;
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
  /// page is done, or with [all]); with [only], among these pages.
  Future<void> run(BatchUi ui, {bool all = false, Set<String>? only}) async {
    if (isRunning) return;
    final services = ref.read(servicesProvider);
    // The line of the last step would tell about the pages before this run.
    ref.read(stepsProvider.notifier).clearLast();
    final workspace = ref.read(workspaceProvider.notifier);
    final pages = [
      for (final p in ref.read(workspaceProvider).pages)
        if (only == null || only.contains(p.id)) p,
    ];
    var todo = all || pages.every((p) => p.isDone)
        ? pages
        : [
            for (final p in pages)
              if (!p.isDone) p,
          ];
    if (todo.isEmpty) return;
    // Translating again would lose what was changed by hand: ask first.
    final edited = todo.where((p) => p.handEdited).length;
    if (edited > 0) {
      switch (await ui.confirmHandEdited(edited)) {
        case HandEditedChoice.cancel:
          return;
        case HandEditedChoice.skip:
          todo = [
            for (final p in todo)
              if (!p.handEdited) p,
          ];
          if (todo.isEmpty) return;
        case HandEditedChoice.translate:
      }
    }
    final last = switch (state) {
      BatchIdle(:final last) => last,
      _ => null,
    };
    final cancel = _cancel = CancelToken();
    final started = DateTime.now();
    final log = services.appLog.child(stage: 'batch');
    state = BatchRunning(total: todo.length, done: 0, started: started, stage: 'loading');

    var done = 0;
    // Time of each stage, all finished pages together (for the report).
    final stageMs = <String, int>{};
    var failuresInARow = 0;
    SkipReason? stoppedBy;
    final skipped = <SkippedPage>[];
    final exportDirs = <String>{};
    final pool = ref.read(workerPoolProvider);
    PipelineWorker? worker;
    try {
      if (!await checkTranslatorKey(ref, ui) || !await approveTranslatorNetwork(ref, ui)) {
        state = BatchIdle(last);
        return;
      }
      final ready = await ensureModels(
        ref,
        ui,
        cancel,
        sourceLanguages: {for (final page in todo) page.sourceOf(ref.read(settingsProvider))},
        onProgress: (f) => _update((s) => s.copyWith(stage: 'download', download: f)),
      );
      if (!ready) {
        state = BatchIdle(last);
        return;
      }
      final settings = ref.read(settingsProvider);
      _update((s) => s.copyWith(stage: 'loading'));
      final (setup, key) = await currentWorkerSetup(ref);
      worker = await pool.acquire(setup, key, log);
      await worker.load({...PipelinePart.values}, cancel: cancel);
      log.info('batch_start', {'pages': todo.length, 'translator': settings.translator});
      // Reading or translating through a chat: the text of every page is
      // found first, then the exchange window, then cleaning and drawing.
      final rounds = chatRounds(settings);
      final viaChat = rounds.isNotEmpty;
      final withText = viaChat ? await _findText(worker, todo, settings, cancel, skipped, log) : todo;
      if (viaChat) {
        for (final mode in rounds) {
          if (withText.isEmpty || cancel.isCancelled) break;
          _update((b) => b.copyWith(stage: 'exchange', pageName: ''));
          final applied = await ui.exchange(
            ExchangeRequest(pageIds: [for (final p in withText) p.id], mode: mode, fromRun: true),
          );
          if (!applied) {
            log.info('batch_exchange_cancelled', {'mode': mode.name});
            cancel.cancel();
          }
        }
        for (final page in withText) {
          workspace.updatePage(
            page.id,
            (p) => p.copyWith(status: p.isDone ? PageStatus.done : PageStatus.pending, stage: null),
          );
        }
      }
      final stamp = _stamp(started);
      final pageMs = <int>[];
      for (final (i, page) in todo.indexed) {
        if (cancel.isCancelled) break;
        if (viaChat && !withText.contains(page)) continue;
        final sw = Stopwatch()..start();
        void stage(String s) {
          workspace.updatePage(page.id, (p) => p.copyWith(stage: s));
          _update((b) => b.copyWith(stage: s));
        }

        workspace.updatePage(page.id, (p) => p.copyWith(status: PageStatus.running, stage: '01_detect', reason: null));
        _update((b) => b.copyWith(done: i, pageName: page.name, stage: '01_detect'));
        try {
          // Webtoon mode: bubbles cut by the edge to the next page are this
          // page's; those of the page above (done just before) are its.
          final seams = await webtoonSeams(ref.read(workspaceProvider), page);
          final found = viaChat ? ref.read(workspaceProvider).byId(page.id)?.blocks : null;
          final cleaned = await worker.prepare(
            page.name,
            path: page.path,
            sourceLanguage: page.sourceOf(settings),
            targetLanguage: page.targetOf(settings),
            below: seams.below,
            covered: seams.covered,
            blocks: found == null ? null : [for (final b in found) b.copy()],
            read: !viaChat,
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
            targetLanguage: page.targetOf(settings),
            above: await pageAbove(ref.read(workspaceProvider), page, settings),
          );
          final renderMs = renderWatch.elapsedMilliseconds;
          final dir = workspace.pageDir(page.id);
          final run = _run++;
          final translated = p.join(dir.path, 'translated_$run.png');
          final clean = p.join(dir.path, 'clean_$run.png');
          final overflow = cleaned.overflow;
          final patch = overflow == null ? null : p.join(dir.path, 'overflow_$run.png');
          await worker.save(
            [
              ImageOutput(translated, render.image),
              ImageOutput(clean, cleaned.clean),
              if (patch != null) PatchOutput(patch, overflow!),
              JsonOutput(p.join(dir.path, 'page.json'), {
                'image': page.path,
                'source_language': page.sourceOf(settings),
                'target_language': page.targetOf(settings),
                'render_scale': render.scale,
                'blocks': [for (final b in cleaned.blocks) b.toJson()],
                'timings_ms': {...cleaned.timingsMs, '06_render': renderMs},
              }),
            ],
            page: page.name,
            render: render,
            renderMs: renderMs,
          );
          workspace.edit(
            page.id,
            (p) => p.copyWith(
              status: PageStatus.done,
              translatedPath: translated,
              cleanPath: clean,
              maskPath: null,
              overflowPath: patch,
              strokes: const [],
              blocks: cleaned.blocks,
              renderScale: render.scale,
              stage: null,
              handEdited: false,
            ),
            byHand: false,
          );
          for (final e in {...cleaned.timingsMs, '06_render': renderMs}.entries) {
            stageMs[e.key] = (stageMs[e.key] ?? 0) + e.value;
          }
          done++;
          failuresInARow = 0;
          if (settings.export.anyAutomatic) {
            final out = await _autoExport(worker, page, cleaned, settings.export, stamp, log);
            if (out != null) exportDirs.add(out);
          }
        } on CancelledException {
          workspace.updatePage(
            page.id,
            (p) => p.copyWith(status: p.isDone ? PageStatus.done : PageStatus.pending, stage: null),
          );
          break;
        } catch (e, st) {
          log.error('page_failed', e, st, {'page': page.name});
          final reason = skipReasonFor(e);
          skipped.add(SkippedPage(page.id, page.name, reason));
          workspace.updatePage(page.id, (p) => p.copyWith(status: PageStatus.skipped, reason: reason, stage: null));
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
      if (worker != null) {
        pool.release();
        // Test mode: finish the run folder now; otherwise keep the models
        // loaded for the editor's steps.
        if (ref.read(settingsProvider).testMode) {
          await pool.close(success: skipped.isEmpty && !cancelled, summary: {'pages': todo.length, 'done': done});
        }
      }
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
          stageMs: stageMs,
        );
        log.info('batch_end', {'done': done, 'skipped': skipped.length, 'cancelled': cancelled});
        state = BatchIdle(report);
      }
    }
  }

  /// Before the exchange with a chat: finds the text blocks of [pages] (and
  /// reads them when reading does not go through the chat). Returns the
  /// pages that worked; the others are added to [skipped].
  Future<List<PageEntry>> _findText(
    PipelineWorker worker,
    List<PageEntry> pages,
    AppSettings settings,
    CancelToken cancel,
    List<SkippedPage> skipped,
    EventLog log,
  ) async {
    final workspace = ref.read(workspaceProvider.notifier);
    final read = !readsThroughChat(settings);
    final ready = <PageEntry>[];
    for (final page in pages) {
      cancel.throwIfCancelled();
      workspace.updatePage(page.id, (p) => p.copyWith(status: PageStatus.running, stage: '01_detect', reason: null));
      _update((b) => b.copyWith(pageName: page.name, stage: '01_detect'));
      try {
        final seams = await webtoonSeams(ref.read(workspaceProvider), page);
        var blocks = await worker.detect(
          page.name,
          path: page.path,
          sourceLanguage: page.sourceOf(settings),
          below: seams.below,
          covered: seams.covered,
          cancel: cancel,
        );
        if (read && blocks.isNotEmpty) {
          workspace.updatePage(page.id, (p) => p.copyWith(stage: '02_ocr'));
          _update((b) => b.copyWith(stage: '02_ocr'));
          blocks = await worker.recognize(
            page.name,
            path: page.path,
            blocks: blocks,
            sourceLanguage: page.sourceOf(settings),
            below: seams.below,
            cancel: cancel,
          );
        }
        workspace.edit(page.id, (p) => p.copyWith(blocks: blocks, stage: 'exchange'), byHand: false);
        ready.add(page);
      } on CancelledException {
        workspace.updatePage(
          page.id,
          (p) => p.copyWith(status: p.isDone ? PageStatus.done : PageStatus.pending, stage: null),
        );
        rethrow;
      } catch (e, st) {
        log.error('page_failed', e, st, {'page': page.name});
        final reason = skipReasonFor(e);
        skipped.add(SkippedPage(page.id, page.name, reason));
        workspace.updatePage(page.id, (p) => p.copyWith(status: PageStatus.skipped, reason: reason, stage: null));
      }
    }
    return ready;
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

/// An internet translator without its key would fail every page: explains
/// where to enter it and returns false.
Future<bool> checkTranslatorKey(Ref ref, BatchUi ui) async {
  final services = ref.read(servicesProvider);
  final settings = ref.read(settingsProvider);
  final info = services.registry.info(settings.translator);
  final config = await services.pluginConfig(settings.translator, settings);
  final endpoint = info.endpointFor(config);
  // No server address at all: say that, not "sends to (nothing)".
  if (endpoint != null && endpoint.host.isEmpty) {
    await ui.explainMissingKey(info, '');
    return false;
  }
  final keys = info.settings.whereType<SecretSetting>();
  if (endpoint == null || endpoint.privacy != Privacy.cloud || keys.isEmpty) return true;
  if (keys.any((k) => config.secret(k.key) != null)) return true;
  await ui.explainMissingKey(info, endpoint.host);
  return false;
}

/// Asks before the translator sends data off the device (once, or always
/// for this translator and address).
Future<bool> approveTranslatorNetwork(Ref ref, BatchUi ui) async {
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

/// Offers to download the models that [parts] of the chosen plugins need;
/// false when the user declines.
Future<bool> ensureModels(
  Ref ref,
  BatchUi ui,
  CancelToken cancel, {
  Set<PipelinePart> parts = const {...PipelinePart.values},
  Set<String>? sourceLanguages,
  void Function(double fraction)? onProgress,
}) async {
  final services = ref.read(servicesProvider);
  final settings = ref.read(settingsProvider);
  final missing = await missingModels(
    services.registry,
    services.models,
    settings,
    parts: parts,
    sourceLanguages: sourceLanguages,
  );
  if (missing.isEmpty) return true;
  if (!await ui.confirmDownload(missing)) return false;
  final total = missing.fold<int>(0, (a, m) => a + m.files.fold(0, (b, f) => b + f.size));
  var before = 0;
  for (final spec in missing) {
    onProgress?.call(before / total);
    await services.models.download(
      spec,
      cancel: cancel,
      onProgress: (d) => onProgress?.call((before + d.received) / total),
    );
    before += spec.files.fold(0, (b, f) => b + f.size);
  }
  return true;
}

/// Models that [parts] of the plugins chosen in [settings] need for
/// [sourceLanguages] (default: the settings' source language) and that are
/// not downloaded.
Future<List<ModelSpec>> missingModels(
  PluginRegistry registry,
  ModelManager models,
  AppSettings settings, {
  Set<PipelinePart> parts = const {...PipelinePart.values},
  Set<String>? sourceLanguages,
}) async {
  final chosen = [
    if (parts.contains(PipelinePart.detector)) settings.activeDetector,
    if (parts.contains(PipelinePart.ocr)) ...[settings.ocr, settings.activeTextPrep],
    if (parts.contains(PipelinePart.ocr) && settings.checksLines) lineCheckerId,
    if (parts.contains(PipelinePart.translator)) settings.translator,
    if (parts.contains(PipelinePart.inpainter)) settings.inpainter,
    if (parts.contains(PipelinePart.textMask)) settings.textMask,
  ];
  final languages = sourceLanguages ?? {settings.sourceLanguage};
  final ids = <String>{
    for (final id in chosen)
      if (registry.contains(id))
        for (final language in languages) ...registry.info(id).requiredModels(language),
    if (parts.contains(PipelinePart.ocr))
      for (final language in languages)
        for (final id in readLevelPlugins(settings, language))
          if (registry.contains(id)) ...registry.info(id).requiredModels(language),
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
