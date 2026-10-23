import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/pipeline/page_pipeline.dart';
import 'package:comic_translate/pipeline/pipeline_worker.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

WorkerSetup _setup(
  Directory dir, {
  String detector = 'fake_det',
  PluginRegistry Function() registry = fakeRegistry,
  bool testMode = false,
  Set<PipelinePart> preload = const {...PipelinePart.values},
  String textPrep = textPrepOffId,
}) {
  final settings = AppSettings(
    detector: detector,
    ocr: 'fake_ocr',
    translator: 'mock',
    inpainter: 'fake_inpaint',
    textPrep: textPrep,
  );
  return WorkerSetup(
    spec: PipelineSpec(
      settings: settings,
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      translatorId: 'mock',
      useGpu: false,
      configs: {
        detector: PluginConfig(),
        'fake_ocr': PluginConfig(),
        'mock': PluginConfig.resolve(mockTranslatorInfo.settings, {}),
        'fake_inpaint': PluginConfig(),
      },
    ),
    modelsDir: p.join(dir.path, 'models'),
    runsDir: testMode ? p.join(dir.path, 'runs') : null,
    registry: registry,
    preload: preload,
  );
}

/// Text preparation that takes its time on every piece, all of it without
/// a break (like a neural network on the CPU).
class _SlowPrep implements TextUpscaler {
  static const prepInfo = PluginInfo(
    id: 'slow_prep',
    displayName: 'slow',
    kind: PluginKind.textPrep,
    privacy: Privacy.local,
  );

  @override
  PluginInfo get info => prepInfo;

  @override
  double get factor => 2;

  @override
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context) async {
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < 150) {}
    return RgbImage.filled(width, height, 255, 255, 255);
  }

  @override
  double estimateMs(int width, int height) => 0;

  @override
  Future<void> dispose() async {}
}

/// A detector busy for a second and a half without a break (like one model
/// run): a cancel message cannot reach the worker meanwhile.
class _BusyDetector implements TextDetector {
  static const detInfo = PluginInfo(
    id: 'busy_det',
    displayName: 'busy',
    kind: PluginKind.detector,
    privacy: Privacy.local,
  );

  @override
  PluginInfo get info => detInfo;

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async {
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < 1500) {}
    return [TextBlock(xyxy: const BBox(10, 10, 90, 40))];
  }

  @override
  Future<void> dispose() async {}
}

PluginRegistry _busyRegistry() =>
    fakeRegistry()..register(PluginFactory<TextDetector>(_BusyDetector.detInfo, (c, e) async => _BusyDetector()));

PluginRegistry _slowPrepRegistry() =>
    fakeRegistry()..register(PluginFactory<TextUpscaler>(_SlowPrep.prepInfo, (c, e) async => _SlowPrep()));

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('cts_worker_test_'));
  tearDown(() => dir.delete(recursive: true));

  test('prepares a page in the background and writes the outputs', () async {
    final sink = MemorySink(Redactor());
    final worker = await PipelineWorker.start(_setup(dir, testMode: true), log: EventLog([sink]));
    final stages = <String>[];
    final page = await worker.prepare(
      'p1.png',
      image: RgbImage.filled(100, 60, 255, 255, 255),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      onStage: stages.add,
    );
    expect(stages, ['01_detect', '02_ocr', '03_translate', '04_mask', '05_inpaint']);
    expect(page.blocks.single.text, 'HELLO');
    expect(page.blocks.single.translation, contains('HELLO'));
    expect([page.clean.width, page.clean.height], [100, 60]);

    final out = p.join(dir.path, 'out');
    final render = RenderedPage(page.clean, const [], 1.0);
    await worker.save(
      [
        ImageOutput(p.join(out, 'page.png'), page.clean),
        ImageOutput(p.join(out, 'page.jpg'), page.clean),
        JsonOutput(p.join(out, 'page.json'), {'ok': true}),
      ],
      page: 'p1.png',
      render: render,
      renderMs: 5,
    );
    expect(ImageCodec.decode(File(p.join(out, 'page.png')).readAsBytesSync()).width, 100);
    expect(File(p.join(out, 'page.jpg')).readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);
    expect(jsonDecode(File(p.join(out, 'page.json')).readAsStringSync()), {'ok': true});

    final runDir = worker.runDir!;
    await worker.dispose(summary: {'pages': 1});
    expect(File(p.join(runDir, 'pages', 'p1.png', '06_render', 'final.png')).existsSync(), isTrue);
    expect(File(p.join(runDir, 'result.json')).existsSync(), isTrue);
    // Worker log events reach the main isolate's log.
    expect(sink.events.map((e) => e.event), containsAll(['run_start', 'fake_ocr_ran']));
    expect(sink.events.firstWhere((e) => e.event == 'fake_ocr_ran').page, 'p1.png');
  });

  test('a cancel stops the preparation of small text half way', () async {
    final worker = await PipelineWorker.start(
      _setup(dir, registry: _slowPrepRegistry, textPrep: 'slow_prep'),
      log: EventLog.silent(),
    );
    // Twenty blocks of small text far apart: twenty pieces of 150 ms.
    final blocks = [
      for (var y = 0; y < 4000; y += 200)
        TextBlock(
          xyxy: BBox(10, y + 10, 190, y + 40),
          lines: [TextLine.box(BBox(10, y + 10, 190, y + 20)), TextLine.box(BBox(10, y + 24, 190, y + 34))],
        ),
    ];
    final cancel = CancelToken();
    final sw = Stopwatch()..start();
    final future = worker.recognize(
      'p1.png',
      image: RgbImage.filled(200, 4000, 255, 255, 255),
      blocks: blocks,
      sourceLanguage: 'English',
      cancel: cancel,
    );
    Timer(const Duration(milliseconds: 600), cancel.cancel);
    await expectLater(future, throwsA(isA<CancelledException>()));
    expect(sw.elapsedMilliseconds, lessThan(1800), reason: 'not after all twenty pieces (3 s)');
    await worker.dispose();
  });

  test('a cancel answers at once even while the worker is busy; its late result is dropped', () async {
    final worker = await PipelineWorker.start(
      _setup(dir, detector: 'busy_det', registry: _busyRegistry),
      log: EventLog.silent(),
    );
    final image = RgbImage.filled(100, 60, 255, 255, 255);
    final cancel = CancelToken();
    final sw = Stopwatch()..start();
    final future = worker.detect('p1.png', image: image, sourceLanguage: 'English', cancel: cancel);
    Timer(const Duration(milliseconds: 200), cancel.cancel);
    await expectLater(future, throwsA(isA<CancelledException>()));
    expect(sw.elapsedMilliseconds, lessThan(1000), reason: 'not after the busy detector (1.5 s)');
    // The next job waits for the busy one, then runs as usual.
    expect(await worker.detect('p2.png', image: image, sourceLanguage: 'English'), hasLength(1));
    await worker.dispose();
  });

  test('pages can be cancelled between steps', () async {
    final worker = await PipelineWorker.start(_setup(dir, registry: slowFakeRegistry), log: EventLog.silent());
    final cancel = CancelToken();
    final future = worker.prepare(
      'p1.png',
      image: RgbImage.filled(100, 60, 255, 255, 255),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      cancel: cancel,
      onStage: (s) => cancel.cancel(),
    );
    await expectLater(future, throwsA(isA<CancelledException>()));
    // The worker keeps going after a cancelled page.
    final page = await worker.prepare(
      'p2.png',
      image: RgbImage.filled(100, 60, 255, 255, 255),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
    );
    expect(page.blocks, hasLength(1));
    await worker.dispose();
  });

  test('single steps load their plugins when first needed', () async {
    final sink = MemorySink(Redactor());
    // A detector that does not exist: only a step that needs it fails.
    final worker = await PipelineWorker.start(
      _setup(dir, detector: 'nope', preload: {}),
      log: EventLog([sink]),
    );
    final image = RgbImage.filled(100, 60, 255, 255, 255);
    await expectLater(
      worker.detect('p', image: image, sourceLanguage: 'English'),
      throwsA(isA<WorkerException>().having((e) => e.message, 'message', contains('nope'))),
    );
    final blocks = [TextBlock(xyxy: const BBox(10, 10, 90, 40))];
    final read = await worker.recognize('p', image: image, blocks: blocks, sourceLanguage: 'English');
    expect(read.single.text, 'HELLO');
    final translated = await worker.translate(
      'p',
      image: image,
      blocks: read,
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
    );
    expect(translated.single.translation, contains('HELLO'));
    final mask = await worker.makeMask('p', image: image, blocks: translated);
    expect([mask.width, mask.height], [100, 60]);
    final clean = (await worker.inpaint('p', image: image, mask: mask, blocks: translated)).clean;
    expect([clean.width, clean.height], [100, 60]);
    await worker.dispose();
    expect(worker.isClosed, isTrue);
  });

  test('loading errors reach the caller', () async {
    await expectLater(
      PipelineWorker.start(_setup(dir, detector: 'nope'), log: EventLog.silent()),
      throwsA(isA<WorkerException>().having((e) => e.message, 'message', contains('nope'))),
    );
  });

  test('a missing image file fails only that page', () async {
    final worker = await PipelineWorker.start(_setup(dir), log: EventLog.silent());
    await expectLater(
      worker.prepare('x', path: p.join(dir.path, 'missing.png'), sourceLanguage: 'English', targetLanguage: 'Russian'),
      throwsA(anything),
    );
    final page = await worker.prepare(
      'p2.png',
      image: RgbImage.filled(100, 60, 255, 255, 255),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
    );
    expect(page.blocks, hasLength(1));
    await worker.dispose();
  });
}
