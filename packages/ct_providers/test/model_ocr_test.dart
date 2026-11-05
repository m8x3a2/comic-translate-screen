// Reading by a model through the network, against a server on this computer.

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  final requests = <({Map<String, Object?> body, String? auth})>[];
  late List<String> replies;

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = (jsonDecode(await utf8.decoder.bind(req).join()) as Map).cast<String, Object?>();
      requests.add((body: body, auth: req.headers.value('authorization')));
      final content = replies.removeAt(0);
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': content},
              },
            ],
            'usage': {'prompt_tokens': 1000, 'completion_tokens': 20, 'cost': 0.0004},
          }),
        );
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  ModelOcr ocr({String model = 'vision/model'}) => ModelOcr.of(
    PluginConfig.resolve(
      openAiCompatibleOcrInfo.settings,
      {'api_url': 'http://127.0.0.1:${server.port}/v1', 'model': model},
      secrets: {'api_key': 'k'},
    ),
    openAiCompatibleOcrInfo,
    apiUrl: 'http://127.0.0.1:${server.port}/v1',
  );

  List<TextBlock> blocks() => [
    TextBlock(xyxy: const BBox(10, 10, 60, 40)),
    TextBlock(xyxy: const BBox(70, 10, 120, 40)),
    TextBlock(xyxy: const BBox(130, 10, 190, 40)),
  ];
  final page = RgbImage.filled(200, 60, 255, 255, 255);

  List<String> texts(Map<String, Object?> body) => [
    for (final part in ((body['messages'] as List).single as Map)['content'] as List)
      if ((part as Map)['type'] == 'text') part['text'] as String,
  ];
  int pictures(Map<String, Object?> body) => [
    for (final part in ((body['messages'] as List).single as Map)['content'] as List)
      if ((part as Map)['type'] == 'image_url' && '${(part['image_url'] as Map)['url']}'.startsWith('data:image/png'))
        part,
  ].length;

  test('one request with the labelled sheets; the bubbles left out are asked once more', () async {
    replies = ['Sure:\n[01-001] HELLO\n[01-003] "WORLD!"', '[01-002] AGAIN'];
    final used = <ServiceUsage>[];
    final history = <HistoryEntry>[];
    final b = blocks();
    await ocr().recognize(
      page,
      b,
      sourceLanguage: 'English',
      context: PluginContext(
        log: EventLog.silent(),
        onUsage: (u) async => used.add(u),
        onHistory: (h) async => history.add(h),
      ),
    );
    expect([for (final x in b) x.text], ['HELLO', 'AGAIN', 'WORLD!']);
    expect(requests, hasLength(2));
    expect(requests.first.auth, 'Bearer k');
    expect(requests.first.body['model'], 'vision/model');
    expect(pictures(requests.first.body), greaterThan(0));
    expect(texts(requests.first.body).single, contains('Labels: [01-001] [01-002] [01-003]'));
    expect(texts(requests.last.body).single, contains('Labels: [01-002]\n'));
    expect([for (final u in used) u.cost], [0.0004, 0.0004]);
    expect(
      [for (final h in history) (h.plugin, h.image, h.again)],
      [('openai_compatible_ocr', true, false), ('openai_compatible_ocr', true, true)],
    );
  });

  test('no text for any bubble is an error; no model is told before anything is sent', () async {
    replies = ['I cannot read these pictures.', 'Still nothing.'];
    await expectLater(
      ocr().recognize(
        page,
        blocks(),
        sourceLanguage: 'English',
        context: PluginContext(log: EventLog.silent()),
      ),
      throwsA(isA<TranslationException>().having((e) => e.kind, 'kind', TranslationErrorKind.badReply)),
    );
    expect(requests, hasLength(1), reason: 'nothing to ask again when nothing came');
    await expectLater(
      ocr(model: ' ').recognize(
        page,
        blocks(),
        sourceLanguage: 'English',
        context: PluginContext(log: EventLog.silent()),
      ),
      throwsA(isA<TranslationException>().having((e) => e.kind, 'kind', TranslationErrorKind.config)),
    );
    expect(requests, hasLength(1));
  });

  test('the key is the one of the translator of the same service', () {
    String keyOf(PluginInfo info) => info.settings.whereType<SecretSetting>().single.storeKey(info.id);
    expect(keyOf(openRouterOcrInfo), pluginSecretKey('openrouter', 'api_key'));
    expect(keyOf(openAiCompatibleOcrInfo), pluginSecretKey('openai_compatible', 'api_key'));
    expect(keyOf(openRouterInfo), pluginSecretKey('openrouter', 'api_key'));
    expect(builtInRegistry().info('openrouter_ocr').kind, PluginKind.ocr);
  });
}
