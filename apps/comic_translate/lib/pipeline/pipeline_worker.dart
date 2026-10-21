/// Runs the heavy steps of the page pipeline in a background isolate, so the
/// window stays responsive while models work: whole pages
/// ([PagePipeline.prepare]) and the single steps of the editor (detect,
/// recognize, translate, mask, clean).
///
/// Plugins are created inside the worker from a [PipelineSpec] resolved on
/// the main isolate (the OS secure storage is only reachable there), when a
/// step first needs them, and stay loaded until the worker is disposed. Log
/// events are forwarded to the main isolate's log; in test mode the worker
/// also keeps the run folder. Drawing text needs dart:ui and stays on the
/// main isolate ([renderPage]); the worker writes the resulting files.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;

import 'page_pipeline.dart';

/// The plugins of a pipeline.
enum PipelinePart { detector, ocr, translator, inpainter }

/// What a worker needs to start.
class WorkerSetup {
  WorkerSetup({
    required this.spec,
    required this.modelsDir,
    this.runsDir,
    this.environment = const {},
    this.runLabel,
    this.homeDir,
    this.registry = builtInRegistry,
    this.preload = const {...PipelinePart.values},
    this.usageFile,
  });

  final PipelineSpec spec;
  final String modelsDir;

  /// Test mode: a run folder with every stage's artifacts is created here.
  final String? runsDir;

  /// `env.json` of the run folder.
  final Map<String, Object?> environment;
  final String? runLabel;

  /// Masked in the run folder's log.
  final String? homeDir;

  /// Builds the plugin registry inside the worker (a top-level function;
  /// tests pass fakes).
  final PluginRegistry Function() registry;

  /// Plugins loaded before [PipelineWorker.start] returns (its errors, like
  /// a missing model, come from there); the others load when first needed.
  final Set<PipelinePart> preload;

  /// The local usage counter ([UsageLog]); translations are counted there.
  final String? usageFile;
}

/// A file the worker writes after a page is drawn.
sealed class WorkerOutput {
  const WorkerOutput(this.path);

  final String path;
}

/// An image, encoded by the file extension (png, jpg, webp, bmp).
class ImageOutput extends WorkerOutput {
  const ImageOutput(super.path, this.image);

  final RgbImage image;
}

class JsonOutput extends WorkerOutput {
  const JsonOutput(super.path, this.json);

  final Object? json;
}

/// A grayscale image (masks), saved as PNG.
class MaskOutput extends WorkerOutput {
  const MaskOutput(super.path, this.mask);

  final GrayImage mask;
}

/// What cleaning produced: the page, and on webtoon pages the cleaned part
/// of the next page that its blocks reach into.
class CleanedImage {
  const CleanedImage(this.clean, [this.overflow]);

  final RgbImage clean;
  final SeamPatch? overflow;
}

/// A transparent PNG ([SeamPatch]).
class PatchOutput extends WorkerOutput {
  const PatchOutput(super.path, this.patch);

  final SeamPatch patch;
}

/// The worker failed in a way that cannot be sent back as the original
/// exception.
class WorkerException implements Exception {
  WorkerException(this.message, this.type, this.remoteStack);

  final String message;
  final String type;
  final String remoteStack;

  @override
  String toString() => message;
}

/// Models that failed on the graphics card in any worker (main isolate).
final gpuFallbacks = StreamController<GpuFallback>.broadcast();

/// Main-isolate handle of a background pipeline.
class PipelineWorker {
  PipelineWorker._(this._isolate, this._toWorker, this._fromWorker, this.runDir, this.runId);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;

  /// Test mode: the run folder kept by the worker.
  final String? runDir;
  final String? runId;

  final Map<int, _Pending> _pending = {};
  final Completer<void> _closed = Completer();
  var _nextId = 0;
  var _disposed = false;

  /// Disposed, or stopped on its own (crash).
  bool get isClosed => _disposed;

  /// Starts a worker and loads the plugins of [WorkerSetup.preload]. Throws
  /// what loading threw (e.g. [ModelNotInstalledException]).
  static Future<PipelineWorker> start(WorkerSetup setup, {required EventLog log}) async {
    final port = ReceivePort();
    // The exit message (null) also arrives when the isolate dies on an
    // uncaught error, so nothing waits forever.
    final isolate = await Isolate.spawn(
      _workerMain,
      (port.sendPort, setup),
      debugName: 'pipeline',
      onExit: port.sendPort,
      onError: port.sendPort,
    );
    final ready = Completer<_Ready>();
    PipelineWorker? worker;
    port.listen((message) {
      switch (message) {
        case _Log(:final line):
          log.write(LogEvent.fromJson((jsonDecode(line) as Map).cast<String, Object?>()));
        case GpuFallback f:
          gpuFallbacks.add(f);
        case _Ready r:
          ready.complete(r);
        case _Failed f when worker == null:
          ready.completeError(f.error, StackTrace.fromString(f.stack));
        case null:
          if (!ready.isCompleted) ready.completeError(WorkerException('The pipeline worker stopped', 'exit', ''));
          worker?._onClosed();
        case [final error, final stack]:
          log.log(LogLevel.error, 'worker_crash', data: {'error': '$error', 'stack': '$stack'});
        default:
          worker?._onMessage(message);
      }
    });
    try {
      final r = await ready.future;
      return worker = PipelineWorker._(isolate, r.inbox, port, r.runDir, r.runId);
    } catch (_) {
      port.close();
      isolate.kill();
      rethrow;
    }
  }

  /// Detection, OCR, translation and cleaning of the image at [path] (or of
  /// [image]). [onStage] reports each stage as it starts. Cancelling [cancel]
  /// stops at the next step boundary with [CancelledException].
  ///
  /// Webtoon pages: [below] is the image of the next page and [covered] what
  /// blocks of the page above reach into (see [PagePipeline.prepare]).
  Future<CleanPage> prepare(
    String page, {
    String? path,
    RgbImage? image,
    required String sourceLanguage,
    required String targetLanguage,
    String? below,
    List<BBox> covered = const [],
    CancelToken? cancel,
    void Function(String stage)? onStage,
  }) async => await _job(
    _Op.prepare,
    page,
    path: path,
    image: image,
    source: sourceLanguage,
    target: targetLanguage,
    below: below,
    covered: covered,
    cancel: cancel,
    onStage: onStage,
  ) as CleanPage;

  /// Loads [parts] now (errors such as a missing model come from here).
  Future<void> load(Set<PipelinePart> parts) => _job(_Op.load, '', parts: parts);

  /// Text blocks found on the page, in reading order (webtoon pages: see
  /// [detectOnStrip]; [below] is the image of the next page).
  Future<List<TextBlock>> detect(
    String page, {
    String? path,
    RgbImage? image,
    required String sourceLanguage,
    String? below,
    List<BBox> covered = const [],
    CancelToken? cancel,
  }) async => (await _job(
    _Op.detect,
    page,
    path: path,
    image: image,
    source: sourceLanguage,
    below: below,
    covered: covered,
    cancel: cancel,
  ) as List).cast<TextBlock>();

  /// [blocks] with their text read; blocks reaching below the page are read
  /// on the page extended with the image [below].
  Future<List<TextBlock>> recognize(
    String page, {
    String? path,
    RgbImage? image,
    required List<TextBlock> blocks,
    required String sourceLanguage,
    String? below,
    CancelToken? cancel,
  }) async => (await _job(
    _Op.recognize,
    page,
    path: path,
    image: image,
    blocks: blocks,
    source: sourceLanguage,
    below: below,
    cancel: cancel,
  ) as List).cast<TextBlock>();

  /// [blocks] with their translations.
  Future<List<TextBlock>> translate(
    String page, {
    String? path,
    RgbImage? image,
    required List<TextBlock> blocks,
    required String sourceLanguage,
    required String targetLanguage,
    CancelToken? cancel,
  }) async => (await _job(
    _Op.translate,
    page,
    path: path,
    image: image,
    blocks: blocks,
    source: sourceLanguage,
    target: targetLanguage,
    cancel: cancel,
  ) as List).cast<TextBlock>();

  /// The text-removal mask of [blocks] (every block, as the original's
  /// manual "Segment"). With the image [below], blocks may reach below the
  /// page: the mask is then taller than the page by the rows they need.
  Future<GrayImage> makeMask(
    String page, {
    String? path,
    RgbImage? image,
    required List<TextBlock> blocks,
    String? below,
  }) async => await _job(_Op.mask, page, path: path, image: image, blocks: blocks, below: below) as GrayImage;

  /// The image with the [mask]ed parts cleaned; uniform bubbles of [blocks]
  /// are filled without the network. A mask taller than the page cleans the
  /// top of the image [below] too: that part comes back as
  /// [CleanedImage.overflow].
  Future<CleanedImage> inpaint(
    String page, {
    String? path,
    RgbImage? image,
    required GrayImage mask,
    List<TextBlock> blocks = const [],
    String? below,
    CancelToken? cancel,
  }) async =>
      await _job(_Op.inpaint, page, path: path, image: image, mask: mask, blocks: blocks, below: below, cancel: cancel)
          as CleanedImage;

  Future<Object?> _job(
    _Op op,
    String page, {
    String? path,
    RgbImage? image,
    List<TextBlock>? blocks,
    GrayImage? mask,
    String source = '',
    String target = '',
    Set<PipelinePart> parts = const {},
    String? below,
    List<BBox> covered = const [],
    CancelToken? cancel,
    void Function(String stage)? onStage,
  }) {
    assert(op == _Op.load || (path == null) != (image == null), 'pass either path or image');
    final id = _nextId++;
    final pending = _Pending<Object?>(onStage);
    _send(id, pending, _Job(id, op, page, path, image, blocks, mask, source, target, parts, below, covered));
    cancel?.onCancel(() {
      if (_pending.containsKey(id)) _toWorker.send(_Cancel(id));
    });
    return pending.completer.future;
  }

  /// Writes [outputs] and, in test mode, records the render step of [page].
  Future<void> save(List<WorkerOutput> outputs, {String? page, RenderedPage? render, int renderMs = 0}) {
    final id = _nextId++;
    final pending = _Pending<void>(null);
    _send(
      id,
      pending,
      _Save(id, outputs, page, render?.image, [
        for (final i in render?.items ?? const <TextItem>[]) i.toJson(),
      ], renderMs),
    );
    return pending.completer.future;
  }

  void _send(int id, _Pending pending, Object message) {
    if (_disposed) throw WorkerException('The pipeline worker stopped', 'exit', '');
    _pending[id] = pending;
    _toWorker.send(message);
  }

  void _onMessage(Object? message) {
    switch (message) {
      case _Stage(:final id, :final stage):
        _pending[id]?.onStage?.call(stage);
      case _Done(:final id, :final result):
        _pending.remove(id)?.completer.complete(result);
      case _Failed(:final id, :final error, :final stack):
        _pending.remove(id)?.completer.completeError(error, StackTrace.fromString(stack));
    }
  }

  void _onClosed() {
    _disposed = true;
    _fromWorker.close();
    if (!_closed.isCompleted) _closed.complete();
    for (final p in _pending.values) {
      p.completer.completeError(WorkerException('The pipeline worker stopped', 'exit', ''));
    }
    _pending.clear();
  }

  /// Stops the isolate at once (the app is closing): no run folder summary.
  void kill() {
    if (_disposed) return;
    _isolate.kill(priority: Isolate.immediate);
    _onClosed();
  }

  /// Releases the models, finishes the run folder and stops the isolate.
  /// Work still in progress is cancelled.
  Future<void> dispose({bool success = true, Map<String, Object?>? summary}) async {
    if (_disposed) return;
    _disposed = true;
    for (final id in _pending.keys) {
      _toWorker.send(_Cancel(id));
    }
    _toWorker.send(_Shutdown(success, summary));
    await _closed.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _isolate.kill(priority: Isolate.immediate);
        _onClosed();
      },
    );
  }
}

class _Pending<T> {
  _Pending(this.onStage);

  final Completer<T> completer = Completer();
  final void Function(String stage)? onStage;
}

enum _Op { prepare, load, detect, recognize, translate, mask, inpaint }

// Messages main → worker.

class _Job {
  _Job(
    this.id,
    this.op,
    this.page,
    this.path,
    this.image,
    this.blocks,
    this.mask,
    this.source,
    this.target,
    this.parts,
    this.below,
    this.covered,
  );

  final int id;
  final _Op op;
  final String page;
  final String? path;
  final RgbImage? image;
  final List<TextBlock>? blocks;
  final GrayImage? mask;
  final String source;
  final String target;
  final Set<PipelinePart> parts;

  /// Webtoon pages: the image of the next page, and what blocks of the page
  /// above reach into.
  final String? below;
  final List<BBox> covered;
}

class _Cancel {
  _Cancel(this.id);

  final int id;
}

class _Save {
  _Save(this.id, this.outputs, this.page, this.rendered, this.items, this.renderMs);

  final int id;
  final List<WorkerOutput> outputs;
  final String? page;
  final RgbImage? rendered;
  final List<Map<String, Object?>> items;
  final int renderMs;
}

class _Shutdown {
  _Shutdown(this.success, this.summary);

  final bool success;
  final Map<String, Object?>? summary;
}

// Messages worker → main.

class _Ready {
  _Ready(this.inbox, this.runDir, this.runId);

  final SendPort inbox;
  final String? runDir;
  final String? runId;
}

class _Log {
  _Log(this.line);

  final String line;
}

/// A model that failed on the graphics card and goes on on the CPU.
class GpuFallback {
  const GpuFallback(this.model, this.reason, {this.speedTest = false});

  /// Model file name (`en_PP-OCRv5_rec_mobile_infer.onnx`).
  final String model;
  final String reason;

  /// During the speed test of the settings (shown there, not as a notice).
  final bool speedTest;
}

class _Stage {
  _Stage(this.id, this.stage);

  final int id;
  final String stage;
}

class _Done {
  _Done(this.id, this.result);

  final int id;
  final Object? result;
}

class _Failed {
  _Failed(this.id, this.error, this.stack);

  final int id;
  final Object error;
  final String stack;
}

/// Forwards log events to the main isolate (redacted there).
class _PortSink implements LogSink {
  _PortSink(this._port);

  final SendPort _port;

  @override
  void write(LogEvent event) => _port.send(_Log(jsonEncode(event.toJson(), toEncodable: (o) => o.toString())));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Exceptions the main isolate handles by type are sent as they are; others
/// as text, since they may hold resources that cannot cross isolates.
Object _sendable(Object e) => switch (e) {
  CancelledException() || ModelNotInstalledException() || TranslationException() || ImageDecodeException() => e,
  _ => WorkerException(e.toString(), e.runtimeType.toString(), ''),
};

Future<void> _workerMain((SendPort, WorkerSetup) args) async {
  final (toMain, setup) = args;
  final inbox = ReceivePort();
  final forward = _PortSink(toMain);
  final redactor = Redactor(homeDir: setup.homeDir);
  for (final config in setup.spec.configs.values) {
    config.secrets.values.forEach(redactor.addSecret);
  }
  final registry = setup.registry();
  final settings = setup.spec.settings;
  final usage = setup.usageFile == null ? null : UsageLog(File(setup.usageFile!));
  RunRecorder? recorder;
  late final EventLog log;
  late final LazyPlugins plugins;

  void fail(int id, Object e, StackTrace st) {
    try {
      toMain.send(_Failed(id, _sendable(e), st.toString()));
    } on ArgumentError {
      toMain.send(_Failed(id, WorkerException(e.toString(), e.runtimeType.toString(), ''), st.toString()));
    }
  }

  Future<void> load(Set<PipelinePart> parts) async {
    for (final part in PipelinePart.values.where(parts.contains)) {
      await switch (part) {
        PipelinePart.detector => plugins.detector,
        PipelinePart.ocr => plugins.ocr,
        PipelinePart.translator => plugins.translator,
        PipelinePart.inpainter => plugins.inpainter,
      };
    }
  }

  try {
    if (setup.runsDir != null) {
      recorder = await RunRecorder.start(
        runsDir: Directory(setup.runsDir!),
        redactor: redactor,
        environment: setup.environment,
        extraSinks: [forward],
        label: setup.runLabel,
      );
    }
    log = recorder?.log ?? EventLog([forward]);
    // Models that failed on this graphics card before open on the CPU.
    OrtSession.cpuOnlyModels = settings.gpuCpuModels.keys.toSet();
    OrtSession.onRuntimeFallback = (path, reason) {
      log.warn('gpu_fallback', {'model': p.basename(path), 'reason': reason});
      toMain.send(GpuFallback(p.basename(path), reason, speedTest: setup.runLabel == 'gpu_benchmark'));
    };
    plugins = LazyPlugins(registry, ModelManager(Directory(setup.modelsDir), log: log), setup.spec, log);
    await load(setup.preload);
  } catch (e, st) {
    await recorder?.finish(success: false, summary: {'error': e.toString()});
    await registry.disposeInstances();
    fail(-1, e, st);
    inbox.close();
    return;
  }
  toMain.send(_Ready(inbox.sendPort, recorder?.dir.path, recorder?.runId));

  Future<Object?> run(_Job m, CancelToken token) async {
    if (m.op == _Op.load) {
      await load(m.parts);
      return null;
    }
    token.throwIfCancelled();
    final image = m.image ?? await ImageCodec.readFile(m.path!);
    final next = m.below == null ? null : await ImageCodec.readFile(m.below!);
    // The page with the rows of the next one that [blocks] reach into.
    RgbImage strip(List<TextBlock> blocks) {
      final rows = next == null ? 0 : seamRows(blocks, image.height, next.height);
      return rows > 0 ? extendBelow(image, next!, rows) : image;
    }

    final context = PluginContext(
      log: log.child(page: m.page),
      cancel: token,
      recorder: recorder,
      page: m.page,
      onUsage: usage?.record,
    );
    final blocks = m.blocks ?? const <TextBlock>[];
    switch (m.op) {
      case _Op.prepare:
        final pipeline = await plugins.pipeline(m.source, m.target);
        return pipeline.prepare(
          image,
          context,
          onStage: (stage) => toMain.send(_Stage(m.id, stage)),
          next: next,
          covered: m.covered,
        );
      case _Op.detect:
        final found = await detectOnStrip(await plugins.detector, image, context, next: next, covered: m.covered);
        return sortBlocks(found, rightToLeft: m.source == 'Japanese');
      case _Op.recognize:
        await recognizeBlocks(await plugins.ocr, strip(blocks), blocks, settings, context, sourceLanguage: m.source);
        return blocks;
      case _Op.translate:
        await translatePageBlocks(
          await plugins.translator,
          image,
          blocks,
          settings,
          context,
          sourceLanguage: m.source,
          targetLanguage: m.target,
        );
        return blocks;
      case _Op.mask:
        return generateMask(strip(blocks), blocks);
      case _Op.inpaint:
        final inpainter = await plugins.inpainter;
        var mask = m.mask!;
        var work = image;
        if (next != null && mask.height > image.height) {
          work = extendBelow(image, next, mask.height - image.height);
          if (mask.height > work.height) mask = mask.crop(BBox(0, 0, mask.width, work.height));
        } else if (mask.height != image.height || mask.width != image.width) {
          mask = extendMask(mask, image.height).crop(BBox(0, 0, image.width, image.height));
        }
        final cleaned = await inpaintPage(
          work,
          mask,
          settings.inpaint,
          (img, mask) => inpainter.inpaint(img, mask, settings.inpaint, context),
          blocks: blocks,
          report: InpaintReport(),
        );
        final (clean, overflow) = splitBelow(cleaned, mask, image.height);
        return CleanedImage(clean, overflow);
      case _Op.load:
        return null;
    }
  }

  // One job at a time (memory); cancel messages are handled in between.
  final cancels = <int, CancelToken>{};
  var queue = Future<void>.value();
  void enqueue(int id, Future<void> Function() job) {
    queue = queue.then((_) async {
      try {
        await job();
      } catch (e, st) {
        fail(id, e, st);
      } finally {
        cancels.remove(id);
      }
    });
  }

  await for (final message in inbox) {
    switch (message) {
      case _Job m:
        final token = cancels[m.id] = CancelToken();
        enqueue(m.id, () async => toMain.send(_Done(m.id, await run(m, token))));
      case _Cancel m:
        cancels[m.id]?.cancel();
      case _Save m:
        enqueue(m.id, () async {
          for (final o in m.outputs) {
            await File(o.path).parent.create(recursive: true);
            final bytes = switch (o) {
              ImageOutput(:final image, :final path) => ImageCodec.encodeByExtension(image, _extension(path)),
              MaskOutput(:final mask) => ImageCodec.encodeGrayPng(mask),
              PatchOutput(:final patch) => ImageCodec.encodeRgbaPng(patch.image, patch.alpha),
              JsonOutput(:final json) => utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
            };
            await File(o.path).writeAsBytes(bytes, flush: true);
          }
          final rendered = m.rendered;
          final rec = recorder;
          if (rec != null && rendered != null) {
            rec.recordTiming('06_render', Duration(milliseconds: m.renderMs), page: m.page);
            await rec.writeArtifact('06_render', 'final.png', ImageCodec.encodePng(rendered), page: m.page);
            await rec.writeJsonArtifact('06_render', 'layout.json', m.items, page: m.page);
          }
          toMain.send(_Done(m.id, null));
        });
      case _Shutdown m:
        await queue;
        await registry.disposeInstances();
        await recorder?.finish(success: m.success, summary: m.summary);
        inbox.close();
    }
  }
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '.png' : path.substring(dot).toLowerCase();
}
