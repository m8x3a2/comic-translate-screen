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
    await t.translate(
      request([block('a')], image: RgbImage.filled(8, 8, 200, 10, 10)),
      PluginContext(log: EventLog.silent()),
    );
    final r = server.requests.single;
    expect(r.auth, isNull);
    expect(r.body.containsKey('max_completion_tokens'), isFalse);
    expect(r.body['max_tokens'], 5000);
    final parts = ((r.body['messages'] as List)[1] as Map)['content'] as List;
    expect(((parts[1] as Map)['image_url'] as Map)['url'], startsWith('data:image/jpeg;base64,'));
  });

  test('HTTP errors are reported with the server message, without the key', () async {
    server.handler = (body) => (
      401,
      jsonEncode({
        'error': {'message': 'Invalid API key'},
      }),
    );
    final redactor = Redactor()..addSecret('sk-secret-abcdefgh');
    final sink = MemorySink(redactor);
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm', apiKey: 'sk-secret-abcdefgh');
    await expectLater(
      t.translate(request([block('a')]), PluginContext(log: EventLog([sink]))),
      throwsA(
        isA<TranslationException>()
            .having((e) => e.message, 'message', contains('HTTP 401: Invalid API key'))
            .having((e) => e.kind, 'kind', TranslationErrorKind.auth),
      ),
    );
    expect(sink.lines.join('\n'), isNot(contains('sk-secret-abcdefgh')));
  });

  test('errors are sorted by kind; temporary ones are sent again', () async {
    Future<TranslationException> errorOf(OpenAiCompatibleTranslator t) async {
      try {
        await t.translate(request([block('a')]), PluginContext(log: EventLog.silent()));
      } on TranslationException catch (e) {
        return e;
      }
      throw StateError('no error');
    }

    OpenAiCompatibleTranslator make() => OpenAiCompatibleTranslator(
      apiUrl: server.url,
      model: 'm',
      retryDelays: const [Duration(milliseconds: 5), Duration(milliseconds: 5)],
    );

    for (final (status, message, kind) in [
      (401, 'Invalid API key', TranslationErrorKind.auth),
      (402, 'Insufficient credits', TranslationErrorKind.credits),
      (404, 'Not found', TranslationErrorKind.notFound),
      (400, 'foo/bar is not a valid model ID', TranslationErrorKind.notFound),
      (400, 'context too long', TranslationErrorKind.other),
    ]) {
      server.requests.clear();
      server.handler = (body) => (
        status,
        jsonEncode({
          'error': {'message': message},
        }),
      );
      final e = await errorOf(make());
      expect([e.kind, e.statusCode], [kind, status], reason: message);
      expect(server.requests, hasLength(1), reason: 'not sent again: $message');
    }
    expect(TranslationErrorKind.credits.stopsRun, isTrue);
    expect(TranslationErrorKind.badReply.stopsRun, isFalse);

    // A busy server is asked again and the page still gets translated.
    server.requests.clear();
    var calls = 0;
    server.handler = (body) => ++calls == 1 ? (503, '{}') : (200, chatReply('{"block_0": "Да"}'));
    final ok = [block('Yes')];
    await make().translate(request(ok), PluginContext(log: EventLog.silent()));
    expect(ok.single.translation, 'Да');
    expect(server.requests, hasLength(2));

    server.requests.clear();
    server.handler = (body) => (
      429,
      jsonEncode({
        'error': {'message': 'Rate limited'},
      }),
    );
    expect((await errorOf(make())).kind, TranslationErrorKind.rateLimit);
    expect(server.requests, hasLength(3), reason: 'first try and two retries');

    server.handler = (body) => (200, chatReply('Sorry, I cannot help with that.'));
    expect((await errorOf(make())).kind, TranslationErrorKind.badReply, reason: 'a reply without translations');
  });

  test('timeout, unreachable server and bad configuration', () async {
    server.handler = (body) => (200, chatReply('{}'));
    server.delay = const Duration(seconds: 3);
    final slow = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm', timeout: const Duration(seconds: 1));
    await expectLater(
      slow.translate(request([block('a')]), PluginContext(log: EventLog.silent())),
      throwsA(
        isA<TranslationException>()
            .having((e) => e.message, 'message', contains('did not answer'))
            .having((e) => e.kind, 'kind', TranslationErrorKind.timeout),
      ),
    );

    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final down = OpenAiCompatibleTranslator(apiUrl: 'http://127.0.0.1:$port/v1', model: 'm');
    await expectLater(
      down.translate(request([block('a')]), PluginContext(log: EventLog.silent())),
      throwsA(
        isA<TranslationException>()
            .having((e) => e.message, 'message', contains('cannot connect'))
            .having((e) => e.kind, 'kind', TranslationErrorKind.network),
      ),
    );

    expect(
      () => OpenAiCompatibleTranslator(
        apiUrl: '',
        model: 'm',
      ).translate(request([block('a')]), PluginContext(log: EventLog.silent())),
      throwsA(isA<TranslationException>()),
    );
    expect(
      () => OpenAiCompatibleTranslator(
        apiUrl: server.url,
        model: ' ',
      ).translate(request([block('a')]), PluginContext(log: EventLog.silent())),
      throwsA(isA<TranslationException>()),
    );
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
    expect(
      openAiCompatibleInfo.endpointFor(cloud)!.approvalKey('openai_compatible'),
      'openai_compatible@openrouter.ai',
    );
  });

  test('untranslatable blocks are skipped; mock goes through the JSON protocol', () async {
    final blocks = [block('Hello'), block('...'), block(''), block('Bye "now"')];
    final sent = await translateBlocks(MockTranslator(), request(blocks), PluginContext(log: EventLog.silent()));
    expect(sent, hasLength(2));
    expect([for (final b in blocks) b.translation], ['[ru] Hello', '', '', '[ru] Bye "now"']);
  });

  test('"Auto": the translator is told the language the scripts found', () async {
    server.handler = (body) => (200, chatReply('{"block_0": "a", "block_1": "b"}'));
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm');
    String systemPrompt() =>
        (((server.requests.last.body['messages'] as List).first as Map)['content'] as List).single['text'] as String;
    TranslationRequest auto(List<TextBlock> blocks) =>
        TranslationRequest(blocks: blocks, sourceLanguage: Languages.auto, targetLanguage: 'English');

    await translateBlocks(
      t,
      auto([block('ダメ')..script = 'Japanese_vert', block('何')..script = 'Japanese']),
      PluginContext(log: EventLog.silent()),
    );
    expect(systemPrompt(), llmSystemPrompt('Japanese', 'English'));

    // Latin script does not tell the language.
    await translateBlocks(
      t,
      auto([block('Hola')..script = 'Latin', block('Adiós')..script = 'Latin']),
      PluginContext(log: EventLog.silent()),
    );
    expect(systemPrompt(), startsWith('You are an expert translator who translates text in any language to English.'));
  });

  test('who speaks goes to the translator, numbered as the blocks sent', () async {
    server.handler = (body) => (200, chatReply('{"block_0": "a", "block_1": "b"}'));
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'm');
    await translateBlocks(
      t,
      request([block('...'), block('I came')..speaker = Speaker.female, block('Me too')]),
      PluginContext(log: EventLog.silent()),
    );
    final user = (((server.requests.last.body['messages'] as List).last as Map)['content'] as List).first['text'];
    expect(
      user,
      contains(
        'Who speaks (use the grammatical gender that fits the speaker: verbs, adjectives): '
        'block_0: a woman.',
      ),
    );
    // Nobody told: the prompt of the original.
    await translateBlocks(t, request([block('I came'), block('Me too')]), PluginContext(log: EventLog.silent()));
    final plain = (((server.requests.last.body['messages'] as List).last as Map)['content'] as List).first['text'];
    expect(plain, isNot(contains('Who speaks')));
  });

  test('each answered request is counted: tokens and cost from the reply, else estimated', () async {
    final counted = <ServiceUsage>[];
    final context = PluginContext(log: EventLog.silent(), onUsage: counted.add);
    server.handler = (body) => (
      200,
      jsonEncode({
        'choices': [
          {
            'message': {'content': '{"block_0": "Привет"}'},
          },
        ],
        'usage': {'prompt_tokens': 812, 'completion_tokens': 9, 'total_tokens': 821, 'cost': 0.000231},
      }),
    );
    final t = OpenAiCompatibleTranslator(apiUrl: server.url, model: 'deepseek/deepseek-chat-v3.1');
    await t.translate(request([block('Hello')]), context);
    final u = counted.single;
    expect((u.plugin, u.host, u.model), ('openai_compatible', '127.0.0.1', 'deepseek/deepseek-chat-v3.1'));
    expect((u.requests, u.inputTokens, u.outputTokens, u.cost, u.estimated), (1, 812, 9, 0.000231, false));

    // A local server without `usage`: about 4 characters per token.
    server.handler = (body) => (200, chatReply('{"block_0": "Привет"}'));
    await t.translate(request([block('Hello')]), context);
    final e = counted.last;
    expect(e.estimated, isTrue);
    expect(e.cost, isNull);
    expect(e.inputTokens, greaterThan(100));
    expect(e.outputTokens, 6);

    // Failed requests cost nothing and are not counted.
    server.handler = (body) => (401, jsonEncode({'error': 'no'}));
    await expectLater(t.translate(request([block('Hello')]), context), throwsA(isA<TranslationException>()));
    expect(counted, hasLength(2));
  });

  test('OpenRouter key status: only for openrouter.ai, parsed from GET /key', () async {
    PluginConfig config(String url, {String? key}) =>
        PluginConfig.resolve(openAiCompatibleInfo.settings, {'api_url': url}, secrets: {'api_key': ?key});
    expect(openAiCompatibleInfo.keyStatus!(config('http://localhost:11434/v1')), isNull);
    expect(openAiCompatibleInfo.keyStatus!(config('https://api.deepseek.com/v1')), isNull);
    final query = openAiCompatibleInfo.keyStatus!(config('https://openrouter.ai/api/v1/', key: 'sk-or-1'))!;
    expect((query.host, query.hasKey), ('openrouter.ai', true));
    expect(openAiCompatibleInfo.keyStatus!(config('https://openrouter.ai/api/v1'))!.hasKey, isFalse);

    final keyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => keyServer.close(force: true));
    final seen = <(String, String, String?)>[];
    var status = 200;
    keyServer.listen((req) async {
      seen.add((req.method, req.uri.path, req.headers.value('authorization')));
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(
          status == 200
              ? jsonEncode({
                  'data': {
                    'label': 'sk-or-v1-0e6...1c4',
                    'limit': 1,
                    'limit_reset': null,
                    'limit_remaining': 0.874,
                    'usage': 0.126,
                    'usage_daily': 0.011,
                    'usage_weekly': 0.05,
                    'usage_monthly': 0.126,
                    'is_free_tier': false,
                    'free_model_daily_requests': {'used': 3, 'limit': 50, 'remaining': 47},
                  },
                })
              : jsonEncode({
                  'error': {'message': 'User not found.'},
                }),
        );
      await req.response.close();
    });
    final uri = Uri.parse('http://127.0.0.1:${keyServer.port}/api/v1/key');
    final s = await fetchOpenRouterKeyStatus(uri, 'sk-or-secret');
    expect(seen.single, ('GET', '/api/v1/key', 'Bearer sk-or-secret'));
    expect((s.limit, s.remaining, s.used, s.usedToday, s.usedThisMonth), (1.0, 0.874, 0.126, 0.011, 0.126));
    expect(s.limitReset, isNull);
    expect((s.freeRequestsToday, s.freeRequestsLimit, s.freeRequestsLeft), (3, 50, 47));
    expect((s.label, s.freeTier), ('sk-or-v1-0e6...1c4', false));

    status = 401;
    await expectLater(
      fetchOpenRouterKeyStatus(uri, 'sk-or-secret'),
      throwsA(
        isA<TranslationException>()
            .having((e) => e.kind, 'kind', TranslationErrorKind.auth)
            .having((e) => e.message, 'message', allOf(contains('User not found'), isNot(contains('sk-or-secret')))),
      ),
    );

    // No limit of its own, but a monthly budget.
    final budget = parseOpenRouterKeyStatus({
      'limit': null,
      'limit_remaining': null,
      'usage': 2.5,
      'effective_budget': {'limit_usd': 10, 'spend_usd': 2.5, 'remaining_usd': 7.5, 'reset_interval': 'monthly'},
    });
    expect((budget.limit, budget.remaining, budget.limitReset), (10.0, 7.5, LimitReset.monthly));
    final unlimited = parseOpenRouterKeyStatus({'limit': null, 'usage': 0});
    expect((unlimited.limit, unlimited.remaining, unlimited.freeRequestsLimit), (null, null, null));
    expect((unlimited.label, unlimited.freeTier), ('', null));
  });

  test('the models of OpenRouter: listed without the key, prices per million tokens, text answers only', () async {
    PluginConfig config(String url) =>
        PluginConfig.resolve(openAiCompatibleInfo.settings, {'api_url': url}, secrets: {'api_key': 'sk-or-1'});
    expect(openAiCompatibleInfo.modelCatalog!(config('http://localhost:11434/v1')), isNull);
    final query = openAiCompatibleInfo.modelCatalog!(config('https://openrouter.ai/api/v1/'))!;
    expect((query.host, query.settingKey), ('openrouter.ai', 'model'));

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <(String, String?)>[];
    server.listen((req) async {
      seen.add((req.uri.path, req.headers.value('authorization')));
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': [
              {
                'id': 'google/gemma-3-27b-it:free',
                'name': 'Google: Gemma 3 27B (free)',
                'created': 1741756359,
                'context_length': 131072,
                'architecture': {
                  'input_modalities': ['text', 'image'],
                  'output_modalities': ['text'],
                },
                'pricing': {'prompt': '0', 'completion': '0'},
              },
              {
                'id': 'openai/gpt-4.1-mini',
                'name': 'OpenAI: GPT-4.1 Mini',
                'context_length': 1047576,
                'architecture': {'modality': 'text+image->text'},
                'pricing': {'prompt': '0.0000004', 'completion': '0.0000016'},
              },
              {
                'id': 'openrouter/auto',
                'architecture': {
                  'input_modalities': ['text'],
                  'output_modalities': ['text'],
                },
                'pricing': {'prompt': '-1', 'completion': '-1'},
              },
              {
                'id': 'some/image-maker',
                'architecture': {
                  'input_modalities': ['text'],
                  'output_modalities': ['image'],
                },
                'pricing': {'prompt': '0.000001', 'completion': '0.00004'},
              },
            ],
          }),
        );
      await req.response.close();
    });
    final models = await fetchOpenRouterModels(Uri.parse('http://127.0.0.1:${server.port}/api/v1/models'));
    expect(seen.single, ('/api/v1/models', null), reason: 'the key does not go along');
    expect([for (final m in models) m.id], ['google/gemma-3-27b-it:free', 'openai/gpt-4.1-mini', 'openrouter/auto']);
    final (gemma, gpt, auto) = (models[0], models[1], models[2]);
    expect((gemma.free, gemma.vision, gemma.contextLength, gemma.created!.year), (true, true, 131072, 2025));
    expect((gpt.free, gpt.vision), (false, true));
    expect(gpt.promptPrice, closeTo(0.4, 1e-9));
    expect(gpt.completionPrice, closeTo(1.6, 1e-9));
    expect((auto.promptPrice, auto.free, auto.vision), (null, false, false));
  });
}
