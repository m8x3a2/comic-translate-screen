import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('ct_settings_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('named server profiles round-trip separately from the original connection', () async {
    final store = SettingsStore(File(p.join(tmp.path, 'settings.json')));
    final s = AppSettings(
      ownServerNames: {'a': 'Personal', 'b': 'Work'},
      ownServerProfile: 'b',
      ownServersByName: true,
      plugins: {
        'openai_compatible': {'model': 'original'},
        'openai_compatible_a': {'model': 'first'},
        'openai_compatible_b': {'model': 'second'},
        'openrouter': {'model': 'router'},
      },
    );
    await store.save(s);
    final reopened = await store.load();
    expect(reopened.ownServerNames, s.ownServerNames);
    expect(reopened.ownServersByName, isTrue);
    expect(reopened.pluginValues('openai_compatible')['model'], 'second');
    expect(reopened.pluginStorageId('openai_compatible'), 'openai_compatible_b');
    expect(reopened.pluginValues('openrouter')['model'], 'router');
    reopened.ownServerProfile = 'a';
    expect(reopened.pluginValues('openai_compatible')['model'], 'first');
    reopened.ownServerProfile = '';
    expect(reopened.pluginValues('openai_compatible')['model'], 'original');
  });

  test('shared request templates keep profile fields and can be removed from both profiles', () async {
    final store = SettingsStore(File(p.join(tmp.path, 'settings.json')));
    final s = AppSettings(
      ownServerNames: {'a': 'Personal', 'b': 'Work'},
      ownServerProfile: 'a',
      ownServerOcrProfile: 'b',
      requestTemplates: {
        'shared': RequestTemplate(
          name: 'Gateway',
          chatPath: 'shared/chat',
          keyStatusPath: 'credits',
          keyStatusFields: {'Balance': 'data.balance'},
        ),
      },
      plugins: {
        for (final profile in ['a', 'b'])
          AppSettings.ownServerStorageId(profile): {
            'api_url': 'https://$profile.example/v1',
            'model': 'model-$profile',
            'chat_path': '$profile/chat',
            'models_path': '$profile/models',
            RequestTemplate.selectionKey: 'shared',
          },
        'openai_compatible_ocr': {'model': 'vision'},
      },
    );
    await store.save(s);
    final reopened = await store.load();
    expect(reopened.requestTemplates['shared']?.name, 'Gateway');
    for (final profile in ['a', 'b']) {
      reopened.ownServerProfile = profile;
      final config = reopened.pluginValues('openai_compatible');
      expect(config['api_url'], 'https://$profile.example/v1');
      expect(config['model'], 'model-$profile');
      expect(config['chat_path'], 'shared/chat');
      expect(config['models_path'], '$profile/models');
      expect(config[RequestTemplate.keyStatusPathKey], 'credits');
    }
    expect(reopened.pluginValues('openai_compatible_ocr')['chat_path'], 'shared/chat');
    expect(reopened.pluginValues('openai_compatible_ocr')['model'], 'vision');
    reopened.requestTemplates['shared'] = RequestTemplate(name: 'Gateway v2', chatPath: 'v2/chat');
    expect(reopened.pluginValues('openai_compatible')['chat_path'], 'v2/chat');
    reopened.removeRequestTemplate('shared');
    expect(reopened.plugins.values.any((values) => values.containsKey(RequestTemplate.selectionKey)), isFalse);
    expect(reopened.pluginValues('openai_compatible')['chat_path'], 'b/chat');
    expect(reopened.pluginValues('openai_compatible_ocr')['chat_path'], 'b/chat');
  });

  test('own server key slots persist without changing the original, other profiles or the OpenRouter key', () {
    const apiKey = SecretSetting(key: 'api_key', label: 'API key');
    const legacyOcrKey = SecretSetting(key: 'api_key', label: 'API key', sharedWith: 'openai_compatible');
    final s = AppSettings(ownServerNames: {'a': 'A', 'b': 'B'}, ownServerProfile: 'a', ownServerOcrProfile: 'b');
    s.setOwnServerKeys('openai_compatible_a', OwnServerKeys(activeId: '123', notes: {'123': 'Work'}));
    s.setOwnServerKeys('openai_compatible_b', OwnServerKeys(activeId: null, notes: {'456': 'Backup'}));
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.pluginSettingSecretKey('openai_compatible', apiKey), 'plugin.openai_compatible_a.api_key.123');
    expect(restored.pluginSettingSecretKey('openai_compatible_ocr', legacyOcrKey), isNull);
    expect(restored.pluginSettingSecretKey('openrouter', apiKey), 'plugin.openrouter.api_key');
    expect(restored.keysForOwnServer('openai_compatible_b').notes, {'456': 'Backup'});
    restored.ownServerOcrProfile = null;
    expect(restored.pluginSettingSecretKey('openai_compatible_ocr', legacyOcrKey), 'plugin.openai_compatible.api_key');
    restored.ownServerProfile = '';
    expect(restored.pluginSettingSecretKey('openai_compatible', apiKey), 'plugin.openai_compatible.api_key');
  });

  test('defaults follow the original application', () {
    final s = AppSettings();
    expect(s.inpainter, 'lama');
    expect(s.textMask, comicTextDetectorId);
    expect(CleanLevel.of(s), CleanLevel.high);
    expect(s.colourLetters, isTrue);
    expect(s.useGpu, isFalse);
    expect(s.inpaint.strategy, HdStrategy.resize);
    expect(s.inpaint.resizeLimit, 960);
    expect(s.sendPageImage, isFalse);
    expect(s.theme, 'dark');
    expect(s.textCase, TextCase.source);
    expect(s.render.hyphenate, isTrue);
    expect(s.render.shapeFit, isFalse);
    expect(s.textPrep, 'fatality_comix');
    expect(s.screenTextPrep, plainX15Id);
    expect(s.fixCyrillicLookalikes, isFalse);
    expect(s.emptyFrames, EmptyFrames.ask, reason: 'new: asks before reading empty frames');
  });

  test('round trip preserves values and unknown keys', () async {
    final store = SettingsStore(File(p.join(tmp.path, 'settings.json')));
    final s = AppSettings(
      translator: 'mock',
      useGpu: true,
      textPrep: plainX2Id,
      fixCyrillicLookalikes: true,
      colourLetters: false,
      render: const RenderSettings(
        textCase: TextCase.upper,
        shapeFit: true,
        maxFontSize: 30,
        alignment: TextAlignment.left,
        color: 0xFF112233,
      ),
      inpaint: const InpaintConfig(strategy: HdStrategy.crop, cropMargin: 256),
      plugins: {
        'openai_compatible': {'url': 'http://localhost:1234/v1', 'model': 'x'},
      },
      approvedNetworkPlugins: {'openai_compatible'},
      shortcuts: {'undo': 'Ctrl+U', 'help': ''},
      gpuCpuModels: {'rec.onnx': 'Softmax failed'},
      autoBugReport: false,
      emptyFrames: EmptyFrames.skip,
      extra: {'future_feature': 42},
    );
    await store.save(s);
    final loaded = await store.load();
    expect(loaded.toJson(), s.toJson());
    expect(loaded.extra['future_feature'], 42);
    expect(loaded.inpaint.strategy, HdStrategy.crop);
    expect(loaded.emptyFrames, EmptyFrames.skip);
    expect(loaded.fixCyrillicLookalikes, isTrue);
    expect(loaded.textPrep, plainX2Id);
    expect(
      AppSettings.fromJson({
        'tools': {'upscale_small_text': false},
      }).activeTextPrep,
      textPrepOffId,
      reason: 'the old switch, turned off',
    );
    expect(loaded.textCase, TextCase.upper);
    expect(loaded.render.shapeFit, isTrue);
    expect(
      RenderSettings.fromJson(const {'upper_case': true}).textCase,
      TextCase.upper,
      reason: 'the old switch, turned on',
    );
    expect(loaded.shortcuts, {'undo': 'Ctrl+U', 'help': ''});
    expect(loaded.gpuCpuModels, {'rec.onnx': 'Softmax failed'});
    expect(loaded.autoBugReport, isFalse);
    expect(AppSettings().autoBugReport, isTrue, reason: 'bug reports build themselves by default');
  });

  test('corrupt file falls back to defaults and is kept as backup', () async {
    final file = File(p.join(tmp.path, 'settings.json'))..writeAsStringSync('{not json');
    final mem = MemorySink(Redactor());
    final loaded = await SettingsStore(file, log: EventLog([mem])).load();
    expect(loaded.toJson(), AppSettings().toJson());
    expect(
      tmp.listSync().map((e) => p.basename(e.path)).where((n) => n.startsWith('settings.json.bad-')),
      hasLength(1),
    );
    expect(mem.events.single.event, 'settings_unreadable');
  });

  test('wrong types fall back per field', () {
    final s = AppSettings.fromJson(
      jsonDecode('{"tools": {"use_gpu": "yes", "inpainter": "lama"}, "inpaint": {"resize_limit": 1280.0}}')
          as Map<String, Object?>,
    );
    expect(s.useGpu, isFalse);
    expect(s.inpainter, 'lama');
    expect(s.inpaint.resizeLimit, 1280);
  });

  test('the Export window opens with its last choices only when told to remember them', () {
    const chosen = ExportSettings(container: ExportContainer.cbz, imageFormat: 'png', cleanedImage: true);
    // Not remembered (as before this switch existed): defaults, the
    // automatic export of a batch run kept.
    final fresh = chosen.forWindow;
    expect(fresh.container, ExportContainer.folder);
    expect(fresh.imageFormat, 'source');
    expect(fresh.cleanedImage, isTrue);
    expect(fresh.remember, isFalse);

    final kept = chosen.copyWith(remember: true);
    expect(identical(kept.forWindow, kept), isTrue);
    final back = ExportSettings.fromJson(kept.toJson());
    expect((back.remember, back.container, back.imageFormat), (true, ExportContainer.cbz, 'png'));
    expect(ExportSettings.fromJson(const {}).remember, isFalse);
  });

  test('files from before the cleaning levels move from the old default to High', () {
    AppSettings read(String tools) => AppSettings.fromJson(jsonDecode('{"tools": $tools}') as Map<String, Object?>);
    expect(CleanLevel.of(read('{"inpainter": "aot"}')), CleanLevel.high);
    expect(CleanLevel.of(read('{"inpainter": "lama"}')), CleanLevel.high);
    expect(CleanLevel.of(read('{"inpainter": "aot", "text_mask": ""}')), CleanLevel.simple);
    expect(CleanLevel.of(read('{"inpainter": "aot", "text_mask": "comic_text_detector"}')), CleanLevel.medium);
    final custom = read('{"inpainter": "lama", "text_mask": ""}');
    expect(CleanLevel.of(custom), isNull);
    CleanLevel.simple.applyTo(custom);
    expect((custom.inpainter, custom.textMask), ('aot', ''));
  });

  test('OpenRouter got a translator of its own: the "Own server" pointed at it moves there once', () async {
    final file = File(p.join(tmp.path, 'settings.json'));
    Future<(AppSettings, int?)> load(Map<String, Object?> json) async {
      file.writeAsStringSync(jsonEncode(json));
      final store = SettingsStore(file);
      return (await store.load(), store.upgradedFrom);
    }

    final (moved, from) = await load({
      'tools': {'translator': 'openai_compatible'},
      'plugins': {
        'openai_compatible': {
          'api_url': 'https://openrouter.ai/api/v1/',
          'model': 'deepseek/deepseek-chat-v3.1',
          'token_limit_param': 'max_tokens',
          'timeout': 300,
        },
      },
      'approved_network_plugins': ['openai_compatible@openrouter.ai'],
    });
    expect(from, 1);
    expect(moved.translator, 'openrouter');
    expect(moved.pluginValues('openrouter'), {'model': 'deepseek/deepseek-chat-v3.1', 'timeout': 300});
    expect(moved.approvedNetworkPlugins, contains('openrouter@openrouter.ai'));
    // Saved as version 2: loaded again, nothing moves.
    final again = SettingsStore(file);
    expect((await again.load()).translator, 'openrouter');
    expect(again.upgradedFrom, isNull);

    // No address meant OpenRouter too; a local server stays where it is.
    expect(
      (await load({
        'tools': {'translator': 'openai_compatible'},
      })).$1.translator,
      'openrouter',
    );
    final (local, _) = await load({
      'tools': {'translator': 'openai_compatible'},
      'plugins': {
        'openai_compatible': {'api_url': 'http://localhost:11434/v1', 'model': 'qwen'},
      },
    });
    expect((local.translator, local.plugins.containsKey('openrouter')), ('openai_compatible', false));

    // Version 2 with the own server chosen on purpose and no address yet: it stays.
    final (chosen, _) = await load({
      'schema_version': 2,
      'tools': {'translator': 'openai_compatible'},
    });
    expect(chosen.translator, 'openai_compatible');
    expect(AppSettings().translator, 'openrouter');
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

  test('program icon is kept, and an unknown value falls back to the green one', () {
    expect(AppSettings().appIcon, 'green');
    expect(AppSettings.fromJson(AppSettings(appIcon: 'blue').toJson()).appIcon, 'blue');
    expect(AppSettings().toJson()['ui'], isNot(contains('app_icon')));
    final navy = AppSettings.fromJson(AppSettings(appIcon: 'navy').toJson());
    expect(navy.appIcon, 'navy');
    expect(
      AppSettings.fromJson({
        'ui': {'app_icon': 'pink'},
      }).appIcon,
      'green',
    );
  });
}
