// Several OpenRouter keys (step 9): the old key is the first; spending is
// counted per key.

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  const apiKey = SecretSetting(key: 'api_key', label: 'API key');
  const sharedKey = SecretSetting(key: 'api_key', label: 'API key', sharedWith: 'openrouter');

  test('the key kept before is the first one; translator and OCR use the chosen one', () {
    final s = AppSettings();
    expect(s.pluginSettingSecretKey('openrouter', apiKey), pluginSecretKey('openrouter', 'api_key'));
    expect(s.pluginSettingSecretKey('openrouter_ocr', sharedKey), pluginSecretKey('openrouter', 'api_key'));
    s.setOwnServerKeys(
      AppSettings.openRouterKeysId,
      s.keysForOwnServer('openrouter').withNote('2', 'free').select('2'),
    );
    expect(s.pluginSettingSecretKey('openrouter', apiKey), AppSettings.ownServerSecretKey('openrouter', '2'));
    expect(s.pluginSettingSecretKey('openrouter_ocr', sharedKey), AppSettings.ownServerSecretKey('openrouter', '2'));
    // Kept in the settings file.
    final back = AppSettings.fromJson(s.toJson());
    expect(back.keysForOwnServer('openrouter').activeId, '2');
    expect(back.keysForOwnServer('openrouter').notes, {'2': 'free'});
  });

  test('spending is counted for the key chosen, only for OpenRouter', () async {
    final dir = Directory.systemTemp.createTempSync('cts_keys_usage_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final log = UsageLog(File('${dir.path}/usage.json'));
    final s = AppSettings();
    const request = ServiceUsage(plugin: 'openrouter', host: 'openrouter.ai', model: 'm', cost: 0.5);
    await s.countUsageTo(log.record)!(request);
    s.setOwnServerKeys('openrouter', s.keysForOwnServer('openrouter').withNote('2', '').select('2'));
    await s.countUsageTo(log.record)!(request);
    await s.countUsageTo(log.record)!(const ServiceUsage(plugin: 'openai_compatible', host: 'localhost', model: 'm'));
    final entries = (await log.read()).entries;
    expect(
      {for (final e in entries) (e.plugin, e.key)},
      {('openrouter', ''), ('openrouter', '2'), ('openai_compatible', null)},
    );
    expect(entries.where((e) => e.key == '2').single.total.cost, 0.5);
    expect(AppSettings().countUsageTo(null), isNull);
  });
}
