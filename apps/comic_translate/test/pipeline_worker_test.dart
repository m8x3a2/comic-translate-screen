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
}) {
  final settings = AppSettings(detector: detector, ocr: 'fake_ocr', translator: 'mock', inpainter: 'fake_inpaint');
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
  );
}

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
