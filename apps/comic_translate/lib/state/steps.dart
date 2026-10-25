/// Single steps on the current page (original `manual_workflow.py`): detect
/// boxes, recognize text, translate, make the mask, clean. A step does the
/// steps before it that are missing (translating a fresh page detects and
/// reads it first). Results are undo steps of the page.
///
/// In the webtoon mode a bubble cut by the edge between two pages belongs to
/// the upper page: its steps look at the top of the page below as well (see
/// `seams.dart` in ct_core).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../pipeline/pipeline_worker.dart';
import '../render/mask_raster.dart';
import 'app_state.dart';
import 'batch.dart';
import 'editor.dart';
import 'exchange.dart';
import 'page_render.dart';
import 'worker_pool.dart';
import 'workspace.dart';

enum ManualStep { detect, recognize, translate, mask, clean }

/// How long a finished run of a step took, for the line under the step buttons.
class StepResult {
  const StepResult({required this.step, required this.pages, required this.count, required this.ms});

  /// The step asked for (the steps before it it had to do are in [ms] too).
  final ManualStep step;

  /// Pages it ran on.
  final int pages;

  /// Blocks found, read or translated by [step] (all pages together).
  final int count;

  /// Time of each step that ran, all pages together (milliseconds).
  final Map<ManualStep, int> ms;

  int get totalMs => ms.values.fold(0, (a, b) => a + b);
}

class StepState {
  const StepState({this.pageId, this.step, this.stage, this.download, this.page = 1, this.pages = 1, this.last});

  /// The page the step works on.
  final String? pageId;
  final ManualStep? step;

  /// Which of how many selected pages (1-based).
  final int page;
  final int pages;

  /// `loading`, `download` or a pipeline stage (`01_detect` …).
  final String? stage;

  /// Model download progress 0…1.
  final double? download;

  /// The run that finished last (null while a step runs, after a failure or
  /// when stopped).
  final StepResult? last;

  bool get running => step != null;

  StepState copyWith({String? stage, double? download, String? pageId, int? page}) => StepState(
    pageId: pageId ?? this.pageId,
    step: step,
    stage: stage ?? this.stage,
    download: download ?? this.download,
    page: page ?? this.page,
    pages: pages,
  );
}

final stepsProvider = NotifierProvider<StepsNotifier, StepState>(StepsNotifier.new);

/// One run of a step changes the page as one undo step, even when it takes
/// longer than the usual merge window.
const _stepMergeWindow = Duration(days: 1);

class StepsNotifier extends Notifier<StepState> {
  CancelToken? _cancel;
  var _runs = 0;

  @override
  StepState build() => const StepState();

  void cancel() {
    if (_cancel == null) return;
    ref.read(servicesProvider).appLog.info('step_cancel_asked', {'step': state.step?.name});
    _cancel!.cancel();
  }

  /// Forgets the line of the last run ("Translate all" started).
  void clearLast() {
    if (!state.running && state.last != null) state = const StepState();
  }

  /// The steps [step] needs on [page], in order.
  static List<ManualStep> plan(ManualStep step, PageEntry page, {int? block}) {
    final noBlocks = page.blocks.isEmpty;
    return switch (step) {
      ManualStep.detect => [ManualStep.detect],
      ManualStep.recognize => [if (noBlocks) ManualStep.detect, ManualStep.recognize],
      ManualStep.translate => [
        if (noBlocks) ManualStep.detect,
        if (noBlocks || _unread(page, block).isNotEmpty) ManualStep.recognize,
        ManualStep.translate,
      ],
      ManualStep.mask => [if (noBlocks) ManualStep.detect, ManualStep.mask],
      ManualStep.clean => [
        if (!page.hasMask) ...[if (noBlocks) ManualStep.detect, ManualStep.mask],
        ManualStep.clean,
      ],
    };
  }

  /// Blocks (or block [only]) without recognized text.
  static List<int> _unread(PageEntry page, int? only) => [
    for (final (i, b) in page.blocks.indexed)
      if ((only == null || only == i) && b.text.trim().isEmpty) i,
  ];

  static PipelinePart _part(ManualStep s) => switch (s) {
    ManualStep.detect => PipelinePart.detector,
    ManualStep.recognize => PipelinePart.ocr,
    ManualStep.translate => PipelinePart.translator,
    ManualStep.clean => PipelinePart.inpainter,
    ManualStep.mask => PipelinePart.textMask,
  };

  static String _stage(ManualStep s) => switch (s) {
    ManualStep.detect => '01_detect',
    ManualStep.recognize => '02_ocr',
    ManualStep.translate => '03_translate',
    ManualStep.mask => '04_mask',
    ManualStep.clean => '05_inpaint',
  };

  /// Runs [step] on the current page, or on every selected page (original:
  /// the selected pages of the list); [block] limits recognizing and
  /// translating to one block of the current page. Each page is one undo
  /// step. Errors are shown with [ui] and stop the run.
  ///
  /// Reading or translating through a chat (the chosen engines, or [chat]
  /// for the chat buttons whatever the engines): the steps before it run
  /// first, then the exchange window, then the steps after it.
  Future<void> run(ManualStep step, BatchUi ui, {int? block, ExchangeMode? chat}) async {
    if (state.running || ref.read(batchProvider) is BatchRunning) return;
    final ws = ref.read(workspaceProvider);
    final targets = block == null ? ws.stepPages : [?ws.currentPage];
    if (targets.isEmpty) return;
    final start = targets.first;
    final plans = {for (final page in targets) page.id: plan(step, page, block: block)};
    final settings0 = ref.read(settingsProvider);
    bool viaChat(ManualStep s) => switch (chat) {
      null =>
        (s == ManualStep.recognize && readsThroughChat(settings0)) ||
            (s == ManualStep.translate && translatesThroughChat(settings0)),
      ExchangeMode.recognize => s == ManualStep.recognize,
      ExchangeMode.translate => s == ManualStep.translate,
      ExchangeMode.both => s == ManualStep.recognize || s == ManualStep.translate,
    };
    final rounds = chat != null
        ? [chat]
        : chatRounds(
            settings0,
            read: plans.values.any((s) => s.contains(ManualStep.recognize)),
            translate: plans.values.any((s) => s.contains(ManualStep.translate)),
          );
    final parts = {for (final steps in plans.values) ...steps.where((s) => !viaChat(s)).map(_part).nonNulls};
    final services = ref.read(servicesProvider);
    final workspace = ref.read(workspaceProvider.notifier);
    final log = services.appLog.child(stage: 'edit');
    if (plans.values.any((s) => s.any((x) => x == ManualStep.translate && !viaChat(x))) &&
        (!await checkTranslatorKey(ref, ui) || !await approveTranslatorNetwork(ref, ui))) {
      return;
    }
    final cancel = _cancel = CancelToken();
    state = StepState(pageId: start.id, step: step, stage: 'loading', pages: targets.length);
    final pool = ref.read(workerPoolProvider);
    // What the run took, for the line under the step buttons (the wait for a
    // chat's answer is not counted).
    final times = <ManualStep, int>{};
    var count = 0;
    final timedPages = <String>{};
    StepResult? result;
    PipelineWorker? worker;
    try {
      final ready = await ensureModels(
        ref,
        ui,
        cancel,
        parts: parts,
        sourceLanguages: {for (final page in targets) page.sourceOf(ref.read(settingsProvider))},
        onProgress: (f) => state = state.copyWith(stage: 'download', download: f),
      );
      if (!ready) return;
      state = state.copyWith(stage: 'loading');
      final (setup, key) = await currentWorkerSetup(ref);
      worker = await pool.acquire(setup, key, log);
      await worker.load(parts, cancel: cancel);
      final settings = ref.read(settingsProvider);
      log.info('step_start', {'step': step.name, 'pages': targets.length});
      final active = worker;
      Future<void> runSteps(Map<String, List<ManualStep>> plans) async {
        final worker = active;
        for (final (n, target) in targets.indexed) {
          final id = target.id;
          final steps = plans[id]!;
          if (steps.isEmpty) continue;
          final merge = 'step:${_runs++}';
          state = state.copyWith(pageId: id, page: n + 1);
          log.info('step_page', {
            'steps': [for (final s in steps) s.name],
            'page': target.name,
          });
          for (final s in steps) {
            cancel.throwIfCancelled();
            state = state.copyWith(stage: _stage(s));
            final page = ref.read(workspaceProvider).byId(id);
            // Removed meanwhile: on to the next page.
            if (page == null) break;
            void commit(PageEntry Function(PageEntry p) change) =>
                workspace.edit(id, change, mergeKey: merge, mergeWindow: _stepMergeWindow, byHand: false);
            final seams = await webtoonSeams(ref.read(workspaceProvider), page);
            final sw = Stopwatch()..start();
            void timed([int done = 0]) {
              times[s] = (times[s] ?? 0) + sw.elapsedMilliseconds;
              if (s == step) count += done;
              timedPages.add(id);
            }

            switch (s) {
              case ManualStep.detect:
                final found = await worker.detect(
                  page.name,
                  path: page.path,
                  sourceLanguage: page.sourceOf(settings),
                  below: seams.below,
                  covered: seams.covered,
                  cancel: cancel,
                );
                timed(found.length);
                commit((p) => p.copyWith(blocks: found));
                workspace.selectBlock(null);
              case ManualStep.recognize:
                final which = block != null
                    ? [block]
                    : step == ManualStep.translate
                    ? _unread(page, null)
                    : [for (var i = 0; i < page.blocks.length; i++) i];
                if (which.isEmpty) continue;
                final read = await worker.recognize(
                  page.name,
                  path: page.path,
                  blocks: [for (final i in which) page.blocks[i].copy()],
                  sourceLanguage: page.sourceOf(settings),
                  below: seams.below,
                  cancel: cancel,
                );
                timed(which.length);
                commit(
                  (p) => p.copyWith(
                    blocks: _replace(
                      p.blocks,
                      which,
                      read,
                      (old, b) => old.copy()
                        ..text = b.text
                        ..linePx = b.linePx
                        ..sourceStyle = b.sourceStyle,
                    ),
                  ),
                );
              case ManualStep.translate:
                final which = [
                  for (final (i, b) in page.blocks.indexed)
                    if ((block == null || block == i) && b.text.trim().isNotEmpty) i,
                ];
                if (which.isEmpty) continue;
                final done = await worker.translate(
                  page.name,
                  path: page.path,
                  blocks: [for (final i in which) page.blocks[i].copy()],
                  sourceLanguage: page.sourceOf(settings),
                  targetLanguage: page.targetOf(settings),
                  cancel: cancel,
                );
                timed(which.length);
                commit(
                  (p) => p.copyWith(
                    // A new translation starts from the automatic look (the owner's
                    // choice): only where its text goes stays.
                    blocks: _replace(
                      p.blocks,
                      which,
                      done,
                      (old, b) => old.copy()
                        ..translation = b.translation
                        ..untranslated = b.untranslated
                        ..style = old.style?.placeOnly,
                    ),
                  ),
                );
              case ManualStep.mask:
                final mask = await worker.makeMask(
                  page.name,
                  path: page.path,
                  blocks: page.blocks,
                  below: seams.below,
                  cancel: cancel,
                );
                final file = p.join(workspace.pageDir(id).path, 'mask_${_stamp()}.png');
                await worker.save([MaskOutput(file, mask)]);
                timed();
                commit((p) => p.copyWith(maskPath: file));
                if (step == ManualStep.mask) ref.read(editorProvider.notifier).setTool(EditorTool.brush);
              case ManualStep.clean:
                final mask = await _currentMask(page);
                final cleaned = await worker.inpaint(
                  page.name,
                  path: page.basePath,
                  mask: mask,
                  blocks: page.blocks,
                  below: seams.below,
                  cancel: cancel,
                );
                final dir = workspace.pageDir(id).path;
                final file = p.join(dir, 'clean_${_stamp()}.png');
                final overflow = cleaned.overflow;
                final patch = overflow == null ? null : p.join(dir, 'overflow_${_stamp()}.png');
                await worker.save([ImageOutput(file, cleaned.clean), if (patch != null) PatchOutput(patch, overflow!)]);
                timed();
                // A mask within the page leaves what was cleaned below it.
                final reached = mask.height > cleaned.clean.height;
                commit(
                  (p) => p.copyWith(
                    cleanPath: file,
                    maskPath: null,
                    strokes: const [],
                    overflowPath: reached ? patch : p.overflowPath,
                  ),
                );
                ref.read(editorProvider.notifier).setView(ViewMode.result);
            }
          }
          workspace.updatePage(
            id,
            (p) => p.status == PageStatus.skipped ? p.copyWith(status: PageStatus.pending, reason: null) : p,
          );
        }
      }

      if (rounds.isEmpty) {
        await runSteps(plans);
      } else {
        await runSteps({for (final e in plans.entries) e.key: e.value.takeWhile((s) => !viaChat(s)).toList()});
        for (final mode in rounds) {
          cancel.throwIfCancelled();
          state = state.copyWith(stage: 'exchange');
          final ws = ref.read(workspaceProvider);
          final only = <String, List<int>>{
            for (final target in targets)
              if (ws.byId(target.id) case final page?)
                target.id: block != null
                    ? [block]
                    : mode == ExchangeMode.recognize && step == ManualStep.translate
                    ? _unread(page, null)
                    : [for (var i = 0; i < page.blocks.length; i++) i],
          };
          final request = ExchangeRequest(
            pageIds: [
              for (final t in targets)
                if (only[t.id]?.isNotEmpty ?? false) t.id,
            ],
            mode: mode,
            only: only,
            fromRun: true,
          );
          if (request.pageIds.isEmpty) continue;
          if (!await ui.exchange(request)) throw const CancelledException();
        }
        await runSteps({
          for (final e in plans.entries)
            e.key: e.value.skipWhile((s) => !viaChat(s)).where((s) => !viaChat(s)).toList(),
        });
      }
      if (timedPages.isNotEmpty) result = StepResult(step: step, pages: timedPages.length, count: count, ms: times);
      log.info('step_done', {
        'step': step.name,
        'pages': targets.length,
        'ms': {for (final e in times.entries) e.key.name: e.value},
      });
    } on CancelledException {
      log.info('step_cancelled', {'step': step.name});
    } catch (e, st) {
      log.error('step_failed', e, st, {'step': step.name, 'page': start.name});
      ui.showError(e);
    } finally {
      if (worker != null) pool.release();
      _cancel = null;
      state = StepState(last: result);
    }
  }

  /// The generated mask plus the strokes, at the page's size (taller on a
  /// webtoon page whose mask reaches into the page below).
  Future<GrayImage> _currentMask(PageEntry page) async {
    final maskPath = page.maskPath;
    final base = maskPath == null
        ? null
        : await Isolate.run(() async => ImageCodec.decodeGray(await File(maskPath).readAsBytes()));
    final (w, h) = base == null ? await imageFileSize(page.path) : (base.width, base.height);
    return rasterizeMask(w, h, base: base, strokes: page.strokes);
  }
}

/// [blocks] with the blocks at [indexes] updated from [results] by [apply].
List<TextBlock> _replace(
  List<TextBlock> blocks,
  List<int> indexes,
  List<TextBlock> results,
  TextBlock Function(TextBlock old, TextBlock result) apply,
) {
  final out = [...blocks];
  for (final (k, i) in indexes.indexed) {
    if (i < out.length && k < results.length) out[i] = apply(out[i], results[k]);
  }
  return out;
}

String _stamp() => '${DateTime.now().microsecondsSinceEpoch}';
