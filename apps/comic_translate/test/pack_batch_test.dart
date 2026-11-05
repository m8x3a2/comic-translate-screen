// "Pages in one request" (the owner's idea): "Translate all" sends several
// pages in one request to a translator over the network, the bubbles named
// by their labels; what the answer leaves out is asked once more, then kept
// with its lettering and listed in the report.

import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

/// The fake engines with the real "own server" translator (in the worker too).
PluginRegistry packRegistry() => fakeRegistry()..register(openAiCompatibleFactory);

/// The same with a slow text detector (time to stop a run in the middle).
PluginRegistry slowPackRegistry() => slowFakeRegistry()..register(openAiCompatibleFactory);

class _Ui implements BatchUi {
  @override
  Future<bool> exchange(ExchangeRequest request) async => false;

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async {}

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async => true;

  @override
  Future<NetworkChoice> confirmNetwork(
    PluginInfo translator,
    PluginEndpoint endpoint, {
    required bool sendsImage,
  }) async => NetworkChoice.once;

  @override
  void showError(Object error) => fail('$error');

  @override
  Future<({EmptyFrames choice, bool remember})?> confirmEmptyFrames(int count) async =>
      (choice: EmptyFrames.read, remember: false);

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async => HandEditedChoice.translate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppServices services;
  late ProviderContainer container;
  late HttpServer server;
  // The user messages the server got, and what it answers to each.
  final asked = <String>[];
  // The Authorization headers it got.
  final keys = <String?>[];
  // Null: the answer stopped at the length limit before any text.
  late String? Function(int n) answer;

  setUp(() async {
    asked.clear();
    keys.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      keys.add(req.headers.value(HttpHeaders.authorizationHeader));
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      final user = (body['messages'] as List).last as Map;
      asked.add(((user['content'] as List).first as Map)['text'] as String);
      final content = answer(asked.length);
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': content},
                if (content == null) 'finish_reason': 'length',
              },
            ],
          }),
        );
      await req.response.close();
    });
  });

  tearDown(() async {
    container.dispose();
    await services.dispose();
    await server.close(force: true);
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open somewhere; the folder is in temp.
    }
  });

  Future<void> start({
    required int pages,
    int perRequest = 2,
    bool resend = true,
    bool slow = false,
    bool testMode = false,
    String translator = 'openai_compatible',
  }) async {
    dir = Directory.systemTemp.createTempSync('cts_pack_batch_');
    final registry = slow ? slowPackRegistry : packRegistry;
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: registry());
    services.appLog.info('test_start');
    final settings = fakeSettings()
      ..testMode = testMode
      ..translator = translator
      ..plugins['openai_compatible'] = {
        'api_url': 'http://127.0.0.1:${server.port}/v1',
        'model': 'test-model',
        'pages_per_request': perRequest,
        'resend_missing': resend,
      };
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(settings),
        workerRegistryProvider.overrideWithValue(registry),
      ],
    );
    final files = [for (var n = 0; n < pages; n++) p.join(dir.path, 'page_$n.png')];
    for (final f in files) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await container.read(workspaceProvider.notifier).addInputs(files);
  }

  List<PageEntry> pages() => container.read(workspaceProvider).pages;

  test('three pages, two in a request: two requests, the bubbles named by their labels', () async {
    answer = (n) => n == 1 ? '{"01-001": "Привет", "02-001": "Пока"}' : '{"03-001": "Ну"}';
    await start(pages: 3);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(asked.length, 2);
    expect(asked[0], allOf(contains('"01-001": "HELLO"'), contains('"02-001": "HELLO"'), contains(packTranslatorNote)));
    expect(asked[1], allOf(contains('"03-001": "HELLO"'), isNot(contains('01-001'))));
    expect([for (final page in pages()) page.blocks.single.translation], ['Привет', 'Пока', 'Ну']);
    expect(pages().every((page) => page.isDone), isTrue);
    final history = await services.history.read();
    expect([for (final e in history.reversed) e.page], ['page_0.png, page_1.png', 'page_2.png']);
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect(report.done, 3);
    expect(report.untranslated, isEmpty);
    expect(report.stageMs.containsKey('03_translate'), isTrue, reason: 'the time of the requests is counted');
  });

  test('a bubble left out: asked once more; still none: done, its lettering kept, in the report', () async {
    answer = (n) => n == 1 ? '{"01-001": "Привет"}' : '{}';
    await start(pages: 2);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(asked.length, 2);
    expect(asked[1], allOf(contains('"02-001": "HELLO"'), isNot(contains('01-001'))), reason: 'only the missing one');
    final second = pages()[1];
    expect((second.isDone, second.blocks.single.untranslated), (true, true));
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect([for (final (_, name, count) in report.untranslated) (name, count)], [('page_1.png', 1)]);
  });

  test('the "Translate" step on picked pages: found and read, then one request for them', () async {
    answer = (n) => '{"01-001": "Привет", "03-001": "Ну"}';
    await start(pages: 3);
    container.read(workspaceProvider.notifier).pickPages({0, 2});
    await container.read(stepsProvider.notifier).run(ManualStep.translate, _Ui());
    expect(asked.length, 1);
    expect(asked.single, allOf(contains('"01-001": "HELLO"'), contains('"03-001": "HELLO"')));
    expect(
      [for (final page in pages()) page.blocks.isEmpty ? null : page.blocks.single.translation],
      ['Привет', null, 'Ну'],
    );
    expect(container.read(stepsProvider).last!.count, 2);
  });

  test('an answer cut off at the length limit: the pages again in two halves', () async {
    answer = (n) => switch (n) {
      1 => null,
      2 => '{"01-001": "Раз", "02-001": "Два"}',
      _ => '{"03-001": "Три", "04-001": "Четыре"}',
    };
    await start(pages: 4, perRequest: 4);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(asked.length, 3);
    expect(asked[1], allOf(contains('01-001'), contains('02-001'), isNot(contains('03-001'))));
    expect([for (final page in pages()) page.blocks.single.translation], ['Раз', 'Два', 'Три', 'Четыре']);
    expect(pages().every((page) => page.isDone), isTrue);
  });

  /// Stops "Translate all" once the first page waits ([waitStage]) while the
  /// second is being found; then no page may be left running (busy pages
  /// cannot be edited).
  Future<void> stopWhileWaiting(String waitStage) async {
    final batch = container.read(batchProvider.notifier);
    final run = batch.run(_Ui());
    while (pages().first.stage != waitStage || pages()[1].status != PageStatus.running) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    batch.stop();
    await run;
    expect(asked, isEmpty);
    expect([for (final page in pages()) page.status], everyElement(PageStatus.pending));
    expect([for (final page in pages()) page.stage], everyElement(isNull));
  }

  test('stopped while pages wait for their request: none is left busy', () async {
    answer = (n) => '{}';
    await start(pages: 3, perRequest: 3, slow: true);
    await stopWhileWaiting('03_translate');
  });

  test('stopped while pages wait for the exchange with a chat: none is left busy', () async {
    answer = (n) => '{}';
    await start(pages: 3, slow: true, translator: chatTranslatorId);
    await stopWhileWaiting('exchange');
  });

  test('the API key goes to the server only: not in the log, the run, the history or a bug report', () async {
    const key = 'sk-test-KEYMARK-1234567890';
    // The second request is the one asked again: the answer left out page 2.
    answer = (n) => n == 1 ? '{"01-001": "Привет"}' : '{"02-001": "Пока"}';
    await start(pages: 2, testMode: true);
    await services.secrets.write(pluginSecretKey('openai_compatible', 'api_key'), key);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(keys, ['Bearer $key', 'Bearer $key'], reason: 'the key was used');
    expect(pages().every((page) => page.isDone), isTrue);
    final zip = await services.buildBugReport(note: 'check');
    final unpacked = Directory(p.join(dir.path, 'report_unpacked'))..createSync();
    final tar = await Process.run('tar', ['-xf', zip.path, '-C', unpacked.path]);
    expect(tar.exitCode, 0, reason: '${tar.stderr}');
    final files = dir.listSync(recursive: true).whereType<File>().toList();
    expect(
      files.map((f) => p.basename(f.path)),
      containsAll(['app.jsonl', 'translator_history.json', 'request.redacted.json']),
    );
    expect(files.where((f) => f.path.startsWith(unpacked.path)), isNotEmpty);
    for (final file in files) {
      final text = latin1.decode(file.readAsBytesSync());
      expect(text.contains('KEYMARK'), isFalse, reason: file.path);
    }
  });

  test('one page in a request: as before, the keys of the original', () async {
    answer = (n) => '{"block_0": "Привет"}';
    await start(pages: 2, perRequest: 1);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(asked.length, 2);
    expect(asked.first, contains('"block_0": "HELLO"'));
  });
}
