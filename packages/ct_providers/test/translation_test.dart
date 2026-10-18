// Translators against a local fake OpenAI-compatible server (no internet,
// no real keys) and the offline mock.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

TextBlock block(String text) => TextBlock(xyxy: const BBox(0, 0, 10, 10), text: text);

TranslationRequest request(List<TextBlock> blocks, {RgbImage? image}) => TranslationRequest(
      blocks: blocks,
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      extraContext: 'A comic about witches.',
      pageImage: image,
    );

/// A fake server; [handler] gets the decoded request and returns
/// (status, body).
class FakeServer {
  FakeServer._(this._server);

  final HttpServer _server;
  final requests = <({Map<String, Object?> body, String? auth, String path})>[];
  late (int, String) Function(Map<String, Object?> body) handler;
  Duration delay = Duration.zero;

  static Future<FakeServer> start() async {
    final s = FakeServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen((req) async {
      expect(req.headers.contentLength, greaterThan(0), reason: 'Content-Length must be set');
      final body = (jsonDecode(await utf8.decoder.bind(req).join()) as Map).cast<String, Object?>();
      s.requests.add((body: body, auth: req.headers.value('authorization'), path: req.uri.path));
      await Future<void>.delayed(s.delay);
      final (status, reply) = s.handler(body);
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(reply);
      await req.response.close();
    });
    return s;
  }

  String get url => 'http://127.0.0.1:${_server.port}/v1/';

  Future<void> close() => _server.close(force: true);
}

String chatReply(String content) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
        },
      ],
    });

void main() {
  late FakeServer server;
  setUp(() async => server = await FakeServer.start());
  tearDown(() => server.close());

  test('request has the original prompt protocol; reply fills translations', () async {
    server.handler = (body) => (200, chatReply('```json\n{"block_0": "Привет!", "block_1": "Нет!"}\n```'));
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'test-model', apiKey: 'sk-test-123456789');
    final blocks = [block('Hello!'), block('No!')];
    await t.translate(request(blocks), PluginContext(log: EventLog.silent()));

    expect([for (final b in blocks) b.translation], ['Привет!', 'Нет!']);
    final r = server.requests.single;
    expect(r.path, '/v1/chat/completions');
    expect(r.auth, 'Bearer sk-test-123456789');
    expect(r.body['model'], 'test-model');
    expect(r.body['temperature'], 1.0);
    expect(r.body['max_completion_tokens'], 5000);
    final messages = (r.body['messages'] as List).cast<Map>();
    expect(((messages[0]['content'] as List).single as Map)['text'], llmSystemPrompt('English', 'Russian'));
    final userParts = (messages[1]['content'] as List).cast<Map>();
    expect(userParts, hasLength(1), reason: 'no page image unless the user enables it');
    expect(userParts.single['text'], llmUserPrompt('A comic about witches.', blocksToJson(blocks)));
  });

  test('page image is sent only when given; token parameter is configurable; no key, no header', () async {
    server.handler = (body) => (200, chatReply('{"block_0": "x"}'));
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm', tokenLimitParam: 'max_tokens');
    await t.translate(request([block('a')], image: RgbImage.filled(8, 8, 200, 10, 10)), PluginContext(log: EventLog.silent()));
    final r = server.requests.single;
    expect(r.auth, isNull);
    expect(r.body.containsKey('max_completion_tokens'), isFalse);
    expect(r.body['max_tokens'], 5000);
    final parts = ((r.body['messages'] as List)[1] as Map)['content'] as List;
    expect(((parts[1] as Map)['image_url'] as Map)['url'], startsWith('data:image/jpeg;base64,'));
  });

  test('HTTP errors are reported with the server message, without the key', () async {
    server.handler = (body) => (401, jsonEncode({'error': {'message': 'Invalid API key'}}));
    final redactor = Redactor()..addSecret('sk-secret-abcdefgh');
    final sink = MemorySink(redactor);
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm', apiKey: 'sk-secret-abcdefgh');
    await expectLater(
      t.translate(request([block('a')]), PluginContext(log: EventLog([sink]))),
      throwsA(isA<TranslationException>().having((e) => e.message, 'message', contains('HTTP 401: Invalid API key'))),
    );
    expect(sink.lines.join('\n'), isNot(contains('sk-secret-abcdefgh')));
  });

  test('timeout, unreachable server and bad configuration', () async {
    server.handler = (body) => (200, chatReply('{}'));
    server.delay = const Duration(seconds: 3);
    final slow = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm', timeout: const Duration(seconds: 1));
    await expectLater(slow.translate(request([block('a')]), PluginContext(log: EventLog.silent())),
        throwsA(isA<TranslationException>().having((e) => e.message, 'message', contains('did not answer'))));

    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final down = OpenAiCompatibleTranslator(apiUrl: 'http://127.0.0.1:$port/v1', model: 'm');
    await expectLater(down.translate(request([block('a')]), PluginContext(log: EventLog.silent())),
        throwsA(isA<TranslationException>().having((e) => e.message, 'message', contains('cannot connect'))));

    expect(() => OpenAiCompatibleTranslator(apiUrl: '', model: 'm').translate(request([block('a')]), PluginContext(log: EventLog.silent())),
        throwsA(isA<TranslationException>()));
    expect(() => OpenAiCompatibleTranslator(apiUrl: server.url, model: ' ').translate(request([block('a')]), PluginContext(log: EventLog.silent())),
        throwsA(isA<TranslationException>()));
  });

  test('cancellation stops a running request', () async {
    server.handler = (body) => (200, chatReply('{}'));
    server.delay = const Duration(seconds: 5);
    final cancel = CancelToken();
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm');
    final f = t.translate(request([block('a')]), PluginContext(log: EventLog.silent(), cancel: cancel));
    Timer(const Duration(milliseconds: 200), cancel.cancel);
    await expectLater(f, throwsA(isA<CancelledException>()));
  });

  test('privacy depends on the server address', () {
    expect(privacyOfHost('localhost'), Privacy.local);
    expect(privacyOfHost('127.0.0.1'), Privacy.local);
    expect(privacyOfHost('[::1]'), Privacy.local);
    expect(privacyOfHost('192.168.1.20'), Privacy.lan);
    expect(privacyOfHost('10.0.0.5'), Privacy.lan);
    expect(privacyOfHost('172.20.1.1'), Privacy.lan);
    expect(privacyOfHost('my-pc.local'), Privacy.lan);
    expect(privacyOfHost('desktop'), Privacy.lan);
    expect(privacyOfHost('openrouter.ai'), Privacy.cloud);
    expect(privacyOfHost('8.8.8.8'), Privacy.cloud);
    final config = PluginConfig.resolve(openAiCompatibleInfo.settings, {'api_url': 'http://localhost:11434/v1'});
    expect(openAiCompatibleInfo.endpointFor(config), isNull);
    final cloud = PluginConfig.resolve(openAiCompatibleInfo.settings, {'api_url': 'https://openrouter.ai/api/v1'});
    expect(openAiCompatibleInfo.endpointFor(cloud)!.approvalKey('openai_compatible'), 'openai_compatible@openrouter.ai');
  });

  test('untranslatable blocks are skipped; mock goes through the JSON protocol', () async {
    final blocks = [block('Hello'), block('...'), block(''), block('Bye "now"')];
    final sent = await translateBlocks(MockTranslator(), request(blocks), PluginContext(log: EventLog.silent()));
    expect(sent, hasLength(2));
    expect([for (final b in blocks) b.translation], ['[ru] Hello', '', '', '[ru] Bye "now"']);
  });
}
