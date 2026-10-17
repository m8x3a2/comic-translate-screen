import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('ct_settings_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('defaults follow the original application', () {
    final s = AppSettings();
    expect(s.inpainter, 'aot');
    expect(s.useGpu, isFalse);
    expect(s.inpaint.strategy, HdStrategy.resize);
    expect(s.inpaint.resizeLimit, 960);
    expect(s.sendPageImage, isFalse);
    expect(s.theme, 'dark');
  });

  test('round trip preserves values and unknown keys', () async {
    final store = SettingsStore(File(p.join(tmp.path, 'settings.json')));
    final s = AppSettings(
      translator: 'mock',
      useGpu: true,
      inpaint: const InpaintConfig(strategy: HdStrategy.crop, cropMargin: 256),
      plugins: {
        'openai_compatible': {'url': 'http://localhost:1234/v1', 'model': 'x'},
      },
      approvedNetworkPlugins: {'openai_compatible'},
      extra: {'future_feature': 42},
    );
    await store.save(s);
    final loaded = await store.load();
    expect(loaded.toJson(), s.toJson());
    expect(loaded.extra['future_feature'], 42);
    expect(loaded.inpaint.strategy, HdStrategy.crop);
  });

  test('corrupt file falls back to defaults and is kept as backup', () async {
    final file = File(p.join(tmp.path, 'settings.json'))..writeAsStringSync('{not json');
    final mem = MemorySink(Redactor());
    final loaded = await SettingsStore(file, log: EventLog([mem])).load();
    expect(loaded.toJson(), AppSettings().toJson());
    expect(tmp.listSync().map((e) => p.basename(e.path)).where((n) => n.startsWith('settings.json.bad-')), hasLength(1));
    expect(mem.events.single.event, 'settings_unreadable');
  });

  test('wrong types fall back per field', () {
    final s = AppSettings.fromJson(jsonDecode('{"tools": {"use_gpu": "yes", "inpainter": "lama"}, "inpaint": {"resize_limit": 1280.0}}')
        as Map<String, Object?>);
    expect(s.useGpu, isFalse);
    expect(s.inpainter, 'lama');
    expect(s.inpaint.resizeLimit, 1280);
  });

  test('RedactingSecretStore masks secrets as soon as they are read or written', () async {
    final redactor = Redactor();
    final store = RedactingSecretStore(MemorySecretStore({'plugin.x.api_key': 'stored-secret-1'}), redactor);
    expect(redactor.redact('stored-secret-1'), 'stored-secret-1');
    await store.primeRedactor();
    expect(redactor.redact('stored-secret-1'), '***');
    await store.write(pluginSecretKey('y', 'token'), 'new-secret-22');
    expect(redactor.redact('use new-secret-22'), 'use ***');
    expect(await store.keys(), ['plugin.x.api_key', 'plugin.y.token']);
  });
}
