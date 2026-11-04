// A translator server that answers badly (a proxy's HTML page, errors,
// broken JSON, chatter, a dropped connection, wrong labels, a huge answer):
// "Translate all" and the "Translate" step end, no page stays busy, a page
// whose answer failed is told why and keeps what it had.

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

PluginRegistry _registry() => fakeRegistry()..register(openAiCompatibleFactory);

class _Ui implements BatchUi {
  final errors = <Object>[];

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
  void showError(Object error) => errors.add(error);

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async => HandEditedChoice.translate;
}

/// The chat answer [content] as the server sends it.
String _chat(String? content, {String? finish}) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
      'finish_reason': ?finish,
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppServices services;
  late ProviderContainer container;
  late HttpServer server;
  var requests = 0;
  // Writes the answer to request number n (from 1).
  late Future<void> Function(int n, HttpRequest req) respond;

  setUp(() async {
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      await respond(++requests, req);
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

  Future<void> start({int pages = 3, int perRequest = 2, int timeout = 120}) async {
    dir = Directory.systemTemp.createTempSync('cts_bad_translator_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: _registry());
    services.appLog.info('test_start');
    final settings = fakeSettings()
      ..translator = 'openai_compatible'
      ..plugins['openai_compatible'] = {
        'api_url': 'http://127.0.0.1:${server.port}/v1',
        'model': 'test-model',
        'pages_per_request': perRequest,
        'resend_missing': true,
        'timeout': timeout,
      };
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(settings),
        workerRegistryProvider.overrideWithValue(_registry),
      ],
    );
    final files = [for (var n = 0; n < pages; n++) p.join(dir.path, 'page_$n.png')];
    for (final f in files) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await container.read(workspaceProvider.notifier).addInputs(files);
  }

  List<PageEntry> pages() => container.read(workspaceProvider).pages;

  /// Runs "Translate all"; no page may stay busy.
  Future<BatchReport> translateAll() async {
    await container.read(batchProvider.notifier).run(_Ui()).timeout(const Duration(seconds: 90));
    expect([for (final page in pages()) page.status], isNot(contains(PageStatus.running)));
    expect([for (final page in pages()) page.stage], everyElement(isNull));
    return (container.read(batchProvider) as BatchIdle).last!;
  }

  Matcher translationFailed(TranslationErrorKind kind, Pattern message) => isA<TranslationFailedReason>()
      .having((r) => r.kind, 'kind', kind)
      .having((r) => r.message, 'message', contains(message));

  test('a proxy\'s HTML page instead of the answer: told as such, the run stops', () async {
    respond = (n, req) async {
      req.response
        ..headers.contentType = ContentType.html
        ..write('<html><body>Sign in to the network</body></html>');
      await req.response.close();
    };
    await start();
    final report = await translateAll();
    expect(report.done, 0);
    expect(report.stoppedBy, translationFailed(TranslationErrorKind.badReply, 'not JSON'));
  });

  test('the server fails every time: sent three times, then the run stops', () async {
    respond = (n, req) async {
      req.response
        ..statusCode = 500
        ..headers.contentType = ContentType.json
        ..write('{"error": {"message": "boom"}}');
      await req.response.close();
    };
    await start();
    final report = await translateAll();
    expect(report.done, 0);
    expect(report.stoppedBy, translationFailed(TranslationErrorKind.server, 'boom'));
    expect(requests, 6, reason: 'two requests, each sent three times');
  });

  test('broken JSON, no choices, an empty answer: told, nothing taken for a translation', () async {
    for (final body in ['{"choices": [{"message"', '{"choices": []}', _chat(null, finish: 'stop'), _chat('')]) {
      respond = (n, req) async {
        req.response
          ..headers.contentType = ContentType.json
          ..write(body);
        await req.response.close();
      };
      await start();
      final report = await translateAll();
      expect(report.done, 0, reason: body);
      expect(report.stoppedBy, isA<TranslationFailedReason>(), reason: body);
      expect([for (final page in pages()) page.status], everyElement(PageStatus.skipped), reason: body);
      expect(
        [
          for (final page in pages())
            for (final b in page.blocks) b.translation,
        ],
        everyElement(''),
        reason: body,
      );
      container.dispose();
      await services.dispose();
      requests = 0;
    }
    // For tearDown.
    await start(pages: 1);
  });

  test('the connection drops in the middle of the answer: a network error, every page of the request free', () async {
    respond = (n, req) async {
      req.response.contentLength = 500;
      final socket = await req.response.detachSocket(writeHeaders: true);
      socket.add(utf8.encode('{"choices": [{"message": {"content": "{\\"01-001\\": '));
      await socket.flush();
      socket.destroy();
    };
    await start();
    final report = await translateAll();
    expect(report.done, 0);
    expect(report.stoppedBy, translationFailed(TranslationErrorKind.network, 'Connection closed'));
    expect([for (final page in pages()) page.status], [PageStatus.skipped, PageStatus.skipped, PageStatus.pending]);
    expect(report.skipped, hasLength(2));
  });

  test('chatter, wrong labels and values that are not text: no junk in a bubble, the rest listed', () async {
    // A reply with no translation at all for a page fails that page (told,
    // not silently untranslated); a bubble without one is listed.
    final answers = {
      'Sorry, I cannot help with that.': (done: 0, untranslated: 0),
      '{"99-001": "x", "01-001": 5, "02-001": null, "03-001": {"a": 1}}': (done: 2, untranslated: 1),
      '{"01-001": ["a", "b"], "02-001": true}': (done: 0, untranslated: 0),
    };
    for (final MapEntry(key: content, value: want) in answers.entries) {
      respond = (n, req) async {
        req.response
          ..headers.contentType = ContentType.json
          ..write(_chat(content));
        await req.response.close();
      };
      await start();
      final report = await translateAll();
      final translations = [
        for (final page in pages())
          for (final b in page.blocks) b.translation,
      ];
      expect(translations, everyElement(anyOf('', '5')), reason: content);
      expect((report.done, report.untranslated.length), (want.done, want.untranslated), reason: content);
      container.dispose();
      await services.dispose();
      requests = 0;
    }
    // For tearDown.
    await start(pages: 1);
  });

  test('a huge answer (a translator that repeated itself) is drawn in seconds', () async {
    final long = 'Очень длинный перевод. ' * 20000;
    respond = (n, req) async {
      req.response
        ..headers.contentType = ContentType.json
        ..write(_chat(jsonEncode({'01-001': long, '02-001': 'Пока', '03-001': 'Ну'})));
      await req.response.close();
    };
    await start(pages: 3, perRequest: 3);
    final sw = Stopwatch()..start();
    final report = await translateAll();
    expect(report.done, 3);
    expect(pages().first.blocks.single.translation, long);
    expect(sw.elapsed, lessThan(const Duration(seconds: 60)));
  });

  test('the server does not answer in time: told, the run stops', () async {
    respond = (n, req) async {
      await Future<void>.delayed(const Duration(seconds: 7));
      req.response.write(_chat('{}'));
      await req.response.close();
    };
    // The shortest wait the setting allows.
    await start(timeout: 5);
    final report = await translateAll();
    expect(report.done, 0);
    expect(report.stoppedBy, translationFailed(TranslationErrorKind.timeout, 'did not answer'));
  });

  test('the "Translate" step with a failing server: the error is shown, the pages free, translations kept', () async {
    var bad = false;
    respond = (n, req) async {
      if (bad) {
        req.response
          ..headers.contentType = ContentType.html
          ..write('<html>proxy</html>');
      } else {
        req.response
          ..headers.contentType = ContentType.json
          ..write(_chat('{"01-001": "Раз", "02-001": "Два", "03-001": "Три"}'));
      }
      await req.response.close();
    };
    await start(perRequest: 3);
    await translateAll();
    expect([for (final page in pages()) page.blocks.single.translation], ['Раз', 'Два', 'Три']);

    bad = true;
    container.read(workspaceProvider.notifier).pickPages({0, 1, 2});
    final ui = _Ui();
    await container.read(stepsProvider.notifier).run(ManualStep.translate, ui).timeout(const Duration(seconds: 90));
    expect(ui.errors.single, isA<TranslationException>().having((e) => e.message, 'message', contains('not JSON')));
    expect([for (final page in pages()) page.status], isNot(contains(PageStatus.running)));
    expect([for (final page in pages()) page.blocks.single.translation], ['Раз', 'Два', 'Три']);
  });
}
