import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

class FakeTranslator implements Translator {
  FakeTranslator(this.info, this.config);

  @override
  final PluginInfo info;
  final PluginConfig config;
  bool disposed = false;

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    for (final b in request.blocks) {
      b.translation = '${config.value<String>('prefix')}${b.text}';
    }
  }

  @override
  Future<void> dispose() async => disposed = true;
}

const fakeInfo = PluginInfo(
  id: 'fake',
  displayName: 'Fake',
  kind: PluginKind.translator,
  privacy: Privacy.cloud,
  platforms: {PlatformId.windows},
  settings: [
    TextSetting(key: 'prefix', label: 'Prefix', defaultValue: '>'),
    IntSetting(key: 'timeout', label: 'Timeout', defaultValue: 30, min: 1, max: 600),
    ChoiceSetting(key: 'mode', label: 'Mode', options: {'a': 'A', 'b': 'B'}, defaultValue: 'a'),
    SecretSetting(key: 'api_key', label: 'API key'),
  ],
);

void main() {
  late Directory tmp;
  late PluginEnvironment env;
  late List<FakeTranslator> created;
  late PluginRegistry registry;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ct_registry_');
    env = PluginEnvironment(models: ModelManager(tmp), log: EventLog.silent());
    created = [];
    registry = PluginRegistry()
      ..register(PluginFactory<Translator>(fakeInfo, (config, env) async {
        final t = FakeTranslator(fakeInfo, config);
        created.add(t);
        return t;
      }));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('PluginConfig.resolve applies types, ranges and defaults; secrets separate', () {
    final config = PluginConfig.resolve(
      fakeInfo.settings,
      {'prefix': 7, 'timeout': 5000, 'mode': 'zzz', 'unknown': 1, 'api_key': 'should-not-be-here'},
      secrets: {'api_key': 'sk-1'},
    );
    expect(config.values, {'prefix': '>', 'timeout': 600, 'mode': 'a'});
    expect(config.secret('api_key'), 'sk-1');
    expect(config.values.containsKey('api_key'), isFalse);
  });

  test('duplicate registration fails', () {
    expect(() => registry.register(PluginFactory<Translator>(fakeInfo, (c, e) async => throw UnimplementedError())),
        throwsStateError);
  });

  test('available filters by kind and platform', () {
    expect(registry.available(PluginKind.translator).map((i) => i.id), ['fake']);
    expect(registry.available(PluginKind.translator, platform: PlatformId.android), isEmpty);
    expect(registry.available(PluginKind.ocr), isEmpty);
  });

  test('instances are cached per config and replaced when config changes', () async {
    final c1 = PluginConfig.resolve(fakeInfo.settings, {'prefix': '1:'});
    final a = await registry.instance<Translator>('fake', c1, env);
    final b = await registry.instance<Translator>('fake', c1, env);
    expect(identical(a, b), isTrue);

    final c2 = PluginConfig.resolve(fakeInfo.settings, {'prefix': '2:'});
    final c = await registry.instance<Translator>('fake', c2, env);
    expect(identical(a, c), isFalse);
    expect(created.first.disposed, isTrue, reason: 'stale instance is released');

    final blocks = [TextBlock(xyxy: const BBox(0, 0, 1, 1), text: 'hi')];
    await c.translate(
      TranslationRequest(blocks: blocks, sourceLanguage: 'English', targetLanguage: 'Russian'),
      PluginContext(log: EventLog.silent()),
    );
    expect(blocks.single.translation, '2:hi');

    await registry.disposeInstances();
    expect(created.last.disposed, isTrue);
  });

  test('changing a secret creates a new instance', () async {
    final a = await registry.instance<Translator>(
        'fake', PluginConfig.resolve(fakeInfo.settings, {}, secrets: {'api_key': 'one'}), env);
    final b = await registry.instance<Translator>(
        'fake', PluginConfig.resolve(fakeInfo.settings, {}, secrets: {'api_key': 'two'}), env);
    expect(identical(a, b), isFalse);
  });

  test('wrong expected type is an error', () async {
    await expectLater(
        registry.instance<OcrEngine>('fake', PluginConfig(), env), throwsA(isA<StateError>()));
  });

  test('unknown plugin', () {
    expect(() => registry.info('nope'), throwsA(isA<UnknownPluginException>()));
  });
}
