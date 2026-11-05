// Reading by a model by key (the owner's ideas): requests are made of
// bubbles, not pages, and the model that reads may translate in the same
// requests ("Read and translate in one request").

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

/// The fake engines with the real "own server" reading and translator.
PluginRegistry readingRegistry() => fakeRegistry()
  ..register(openAiCompatibleFactory)
  ..register(openAiCompatibleOcrFactory);

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
  // The instructions the server got: the reading ones have labels, the
  // translator's have JSON.
  final asked = <String>[];

  /// The answer of the model to [prompt]: every label it asks for, read as
  /// HELLO (and translated as ПРИВЕТ when asked to translate); JSON for the
  /// translator.
  String answerTo(String prompt) {
    if (!prompt.contains('Labels: ')) {
      final keys = RegExp(r'"(block_\d+|\d\d-\d\d\d)": "HELLO"').allMatches(prompt).map((m) => m[1]);
      return jsonEncode({for (final k in keys) k: 'Перевод'});
    }
    final labels = prompt.split('Labels: ').last.split('\n').first.trim().split(' ');
    final translate = prompt.contains('-->');
    return [for (final l in labels) translate ? '$l HELLO --> ПРИВЕТ' : '$l HELLO'].join('\n');
  }

  setUp(() async {
    asked.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      final user = (body['messages'] as List).last as Map;
      final content = user['content'];
      final prompt = content is String
          ? content
          : [
              for (final part in content as List)
                if ((part as Map)['type'] == 'text') part['text'],
            ].join('\n');
      asked.add(prompt);
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': answerTo(prompt)},
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

  Future<void> start({required int pages, required bool together, int maxBlocks = 40, int perRequest = 1}) async {
    dir = Directory.systemTemp.createTempSync('cts_reading_pack_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: readingRegistry(),
    );
    services.appLog.info('test_start');
    final url = 'http://127.0.0.1:${server.port}/v1';
    final settings = fakeSettings()
      ..ocr = 'openai_compatible_ocr'
      ..translator = 'openai_compatible'
      ..plugins['openai_compatible'] = {'api_url': url, 'model': 'text-model', 'pages_per_request': perRequest}
      ..plugins['openai_compatible_ocr'] = {
        'api_url': url,
        'model': 'vision-model',
        'together': together,
        'max_blocks': maxBlocks,
      };
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(settings),
        workerRegistryProvider.overrideWithValue(readingRegistry),
      ],
    );
    final files = [for (var n = 0; n < pages; n++) p.join(dir.path, 'page_$n.png')];
    for (final f in files) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await container.read(workspaceProvider.notifier).addInputs(files);
  }

  List<PageEntry> pages() => container.read(workspaceProvider).pages;
  List<String> labelsOf(String prompt) => prompt.split('Labels: ').last.split('\n').first.trim().split(' ');

  test(
    '"Translate all", one request: pages go together up to the bubbles allowed, the translator is not asked',
    () async {
      await start(pages: 3, together: true, maxBlocks: 2);
      await container.read(batchProvider.notifier).run(_Ui());
      expect(asked, hasLength(2));
      expect(labelsOf(asked[0]), ['[01-001]', '[02-001]']);
      expect(labelsOf(asked[1]), ['[01-001]']);
      expect(asked[0], contains('-->'), reason: 'read and translated');
      expect(
        [for (final page in pages()) (page.blocks.single.text, page.blocks.single.translation)],
        [('HELLO', 'ПРИВЕТ'), ('HELLO', 'ПРИВЕТ'), ('HELLO', 'ПРИВЕТ')],
      );
      expect(pages().every((page) => page.isDone), isTrue);
      final report = (container.read(batchProvider) as BatchIdle).last!;
      expect(report.done, 3);
      expect(report.untranslated, isEmpty);
      expect(report.unread, isEmpty);
      expect(report.stageMs.containsKey('02_ocr'), isTrue);
    },
  );

  test('"Translate all", read apart: one reading for all pages, then the translator page by page', () async {
    await start(pages: 3, together: false);
    await container.read(batchProvider.notifier).run(_Ui());
    expect(asked, hasLength(4));
    expect(labelsOf(asked[0]), ['[01-001]', '[02-001]', '[03-001]']);
    expect(asked[0], isNot(contains('-->')), reason: 'only read');
    expect(
      [for (final page in pages()) (page.blocks.single.text, page.blocks.single.translation)],
      [('HELLO', 'Перевод'), ('HELLO', 'Перевод'), ('HELLO', 'Перевод')],
    );
  });

  test('"Translate all", read apart, the translator takes two pages: read together, translated in packs', () async {
    await start(pages: 3, together: false, perRequest: 2);
    await container.read(batchProvider.notifier).run(_Ui());
    // One reading of 2 pages + one translation, then the last page the same.
    expect(asked, hasLength(4));
    expect(labelsOf(asked[0]), ['[01-001]', '[02-001]']);
    expect(asked[1], allOf(contains('"01-001": "HELLO"'), contains('"02-001": "HELLO"')));
    expect([for (final page in pages()) page.blocks.single.translation], everyElement('Перевод'));
  });

  test('"Read and translate" on picked pages: read again and translated in one request', () async {
    await start(pages: 3, together: true);
    // Read before by hand: read again all the same.
    for (final page in pages()) {
      container
          .read(workspaceProvider.notifier)
          .edit(page.id, (p) => p.copyWith(blocks: [TextBlock(xyxy: const BBox(10, 10, 90, 40))..text = 'OLD']));
    }
    container.read(workspaceProvider.notifier).pickPages({0, 2});
    await container.read(stepsProvider.notifier).run(ManualStep.translate, _Ui(), readFirst: true);
    expect(asked, hasLength(1));
    expect(labelsOf(asked.single), ['[01-001]', '[02-001]']);
    expect(
      [for (final page in pages()) (page.blocks.single.text, page.blocks.single.translation)],
      [('HELLO', 'ПРИВЕТ'), ('OLD', ''), ('HELLO', 'ПРИВЕТ')],
    );
    expect(container.read(stepsProvider).last!.count, 2);
  });

  test('"Recognize" on picked pages: one request; "Translate" of read pages asks the translator', () async {
    await start(pages: 3, together: true);
    container.read(workspaceProvider.notifier).pickPages({0, 1, 2});
    await container.read(stepsProvider.notifier).run(ManualStep.recognize, _Ui());
    expect(asked, hasLength(1));
    expect(
      [for (final page in pages()) (page.blocks.single.text, page.blocks.single.translation)],
      [('HELLO', ''), ('HELLO', ''), ('HELLO', '')],
    );
    // Already read: translating needs no reading, so the translator does it.
    await container.read(stepsProvider.notifier).run(ManualStep.translate, _Ui());
    expect(asked, hasLength(4));
    expect([for (final page in pages()) page.blocks.single.translation], everyElement('Перевод'));
  });
}
