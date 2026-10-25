// API keys, the balance check, the usage counter and full screen (M8.1).

import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/window_mode.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/common/model_catalog_dialog.dart';
import 'package:comic_translate/ui/settings/settings_screen.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

void main() {
  late Directory dir;
  late AppServices services;
  late MemorySecretStore secrets;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_keys_test_');
    secrets = MemorySecretStore();
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: secrets,
      registry: fakeRegistry()
        ..register(openAiCompatibleFactory)
        ..register(openRouterFactory),
    );
    // The log file is opened outside the test clock (else tearDown waits for it).
    services.appLog.info('test_start');
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  AppSettings openRouter() => fakeSettings()
    ..translator = 'openai_compatible'
    ..plugins['openai_compatible'] = {'api_url': 'https://openrouter.ai/api/v1', 'model': 'deepseek/deepseek-chat-v3.1'};

  Future<void> openTranslatorSettings(WidgetTester tester, AppSettings settings) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(settings),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
        ],
        child: const ComicTranslateApp(),
      ),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Переводчик'));
    await tester.pumpAndSettle();
    // Let the real file reads (usage counter) finish.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  Finder keyField(String state) =>
      find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').contains(state));

  bool obscured(WidgetTester tester) => tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.labelText ?? '').startsWith('Ключ API'),
      )).obscureText;

  testWidgets('API key: show while typing, last 4 characters once saved, replace, delete after asking', (tester) async {
    await openTranslatorSettings(tester, openRouter());
    expect(keyField('Не задан'), findsOneWidget);
    expect(find.textContaining('У каждого переводчика'), findsOneWidget);

    await tester.enterText(keyField('Не задан'), 'sk-or-v1-abcdef123456wxyz');
    expect(obscured(tester), isTrue);
    await tester.tap(find.byTooltip('Показать введённое'));
    await tester.pump();
    expect(obscured(tester), isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(await secrets.read('plugin.openai_compatible.api_key'), 'sk-or-v1-abcdef123456wxyz');
    expect(keyField('Сохранён: …wxyz'), findsOneWidget);
    expect(obscured(tester), isTrue, reason: 'hidden again after saving');
    expect(find.textContaining('abcdef'), findsNothing, reason: 'the saved key is not shown by itself');

    // Shown and copied only on request; hidden again after half a minute.
    await tester.tap(find.text('Показать ключ'));
    await tester.pumpAndSettle();
    expect(find.text('sk-or-v1-abcdef123456wxyz'), findsOneWidget);
    await tester.tap(find.text('Скрыть ключ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('abcdef'), findsNothing);
    await tester.tap(find.text('Показать ключ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    expect(find.textContaining('abcdef'), findsNothing);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();
    expect(copied, 'sk-or-v1-abcdef123456wxyz');
    expect(find.text('Ключ скопирован'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));

    await tester.enterText(keyField('Сохранён'), 'sk-or-v1-second-key-9876');
    await tester.tap(find.widgetWithText(FilledButton, 'Заменить'));
    await tester.pumpAndSettle();
    expect(keyField('Сохранён: …9876'), findsOneWidget);

    await tester.tap(find.text('Удалить ключ'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить ключ?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(await secrets.read('plugin.openai_compatible.api_key'), 'sk-or-v1-second-key-9876');

    await tester.tap(find.text('Удалить ключ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(await secrets.read('plugin.openai_compatible.api_key'), isNull);
    expect(keyField('Не задан'), findsOneWidget);
  });

  testWidgets('balance check only for OpenRouter, marked as sent to it, and needs a saved key', (tester) async {
    await openTranslatorSettings(tester, openRouter());
    expect(find.text('Сведения о ключе'), findsOneWidget);
    expect(find.textContaining('Спрашивает у openrouter.ai'), findsOneWidget);
    expect(find.text('Выбрать…'), findsOneWidget, reason: 'the list of models beside the model field');
    await tester.ensureVisible(find.text('Сведения о ключе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сведения о ключе'));
    await tester.pumpAndSettle();
    expect(find.text('Сначала сохраните ключ API'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await tester.runAsync(() => container.read(settingsProvider.notifier).change(
          (s) => s.plugins['openai_compatible'] = {'api_url': 'http://localhost:1234/v1', 'model': 'local'},
        ));
    await tester.pumpAndSettle();
    expect(find.text('Сведения о ключе'), findsNothing);
    expect(find.text('Выбрать…'), findsNothing);
  });

  testWidgets('OpenRouter: no address, the model list, a key page, the rare settings folded', (tester) async {
    await openTranslatorSettings(tester, fakeSettings()..translator = 'openrouter');
    expect(find.text('OpenRouter'), findsWidgets);
    expect(find.text('Адрес API'), findsNothing);
    expect(find.text('Выбрать…'), findsOneWidget);
    expect(find.text('Получить ключ'), findsOneWidget);
    expect(find.text('Параметр ограничения длины'), findsNothing);
    expect(find.text('Температура'), findsNothing, reason: 'folded under "More settings"');
    await tester.ensureVisible(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    expect(find.text('Температура'), findsOneWidget);
    expect(find.text('Сведения о ключе'), findsOneWidget);
  });

  test('the key of the own server pointed at OpenRouter moves to the OpenRouter translator once', () async {
    final keyDir = Directory.systemTemp.createTempSync('cts_key_move_');
    addTearDown(() => keyDir.deleteSync(recursive: true));
    final store = MemorySecretStore({pluginSecretKey('openai_compatible', 'api_key'): 'sk-or-old-1234567890'});
    Future<AppServices> start() async {
      final s = AppServices.create(dataDirOverride: keyDir.path, secretStore: store, registry: fakeRegistry());
      await s.init();
      return s;
    }

    File(p.join(keyDir.path, 'settings.json')).writeAsStringSync(
      jsonEncode({
        'tools': {'translator': 'openai_compatible'},
        'plugins': {
          'openai_compatible': {'api_url': 'https://openrouter.ai/api/v1', 'model': 'x'},
        },
      }),
    );
    final first = await start();
    expect(await store.read(pluginSecretKey('openrouter', 'api_key')), 'sk-or-old-1234567890');
    expect((await first.settingsStore.load()).translator, 'openrouter');
    await first.dispose();

    // Removed by the user later: it does not come back.
    await store.delete(pluginSecretKey('openrouter', 'api_key'));
    final second = await start();
    expect(await store.read(pluginSecretKey('openrouter', 'api_key')), isNull);
    await second.dispose();
  });

  testWidgets('the translator history: newest first, one page or all, what went and came, cleared on request', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await services.history.record(HistoryEntry(
        time: DateTime(2026, 10, 25, 18, 0),
        plugin: 'openrouter',
        host: 'openrouter.ai',
        model: 'nvidia/nemotron:free',
        page: 'p1.png',
        ms: 3200,
        sent: '[user]\n{"block_0": "Hello"}',
        reply: '{"block_0": "Привет"}',
        blocks: 2,
        warnings: const ['block_1 missing'],
      ));
      await services.history.record(HistoryEntry(
        time: DateTime(2026, 10, 25, 18, 5),
        plugin: 'openrouter',
        host: 'openrouter.ai',
        model: 'nvidia/nemotron:free',
        page: 'p2.png',
        ms: 900,
        error: 'openrouter.ai answered HTTP 429',
      ));
    });
    await openTranslatorSettings(tester, fakeSettings()..translator = 'openrouter');
    await tester.ensureVisible(find.text('История запросов'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('История запросов'));
    for (var i = 0; i < 20 && find.textContaining('Показано').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Показано: 2 из 2'), findsOneWidget);
    expect(find.text('Ошибка: openrouter.ai answered HTTP 429'), findsOneWidget);
    expect(find.text('Переведено 1 из 2: на часть пузырей в ответе ничего нет'), findsOneWidget);
    await tester.tap(find.text('Переведено 1 из 2: на часть пузырей в ответе ничего нет'));
    await tester.pumpAndSettle();
    expect(find.text('{"block_0": "Привет"}'), findsOneWidget);
    expect(find.text('[user]\n{"block_0": "Hello"}'), findsOneWidget);

    await tester.tap(find.text('Очистить историю'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Очистить историю'));
    for (var i = 0; i < 20 && find.text('Показано: 0 из 0').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.textContaining('Запросов ещё нет'), findsOneWidget);
    expect(await tester.runAsync(() => services.history.read()), isEmpty);
  });

  testWidgets('the list of models: search, free ones, ones that take pictures, the picked one goes back',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var asked = 0;
    final query = ModelCatalogQuery(
      host: 'openrouter.ai',
      settingKey: 'model',
      run: () async {
        asked++;
        return [
          CatalogModel(
            id: 'google/gemma-3-27b-it:free',
            name: 'Gemma 3 27B (free)',
            contextLength: 131072,
            promptPrice: 0,
            completionPrice: 0,
            vision: true,
            created: DateTime(2025),
          ),
          CatalogModel(
            id: 'openai/gpt-4.1-mini',
            name: 'GPT-4.1 Mini',
            promptPrice: 0.4,
            completionPrice: 1.6,
            vision: true,
            created: DateTime(2024),
          ),
          const CatalogModel(id: 'deepseek/deepseek-chat-v3.1', name: 'DeepSeek V3.1', promptPrice: 0.2, completionPrice: 0.8),
        ];
      },
    );
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    picked = await showModelCatalogDialog(context, query, current: 'deepseek/deepseek-chat-v3.1'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('Показано: 3 из 3'), findsOneWidget);
    expect(find.textContaining('бесплатно · контекст 131'), findsOneWidget);
    expect(find.textContaining('запрос 0,40'), findsOneWidget);

    await tester.tap(find.text('Только бесплатные'));
    await tester.pump();
    expect(find.text('Показано: 1 из 3'), findsOneWidget);
    await tester.tap(find.text('Только бесплатные'));
    await tester.tap(find.text('Видит картинки'));
    await tester.pump();
    expect(find.text('Показано: 2 из 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mini');
    await tester.pump();
    expect(find.text('Показано: 1 из 3'), findsOneWidget);
    await tester.tap(find.text('GPT-4.1 Mini'));
    await tester.pumpAndSettle();
    expect(picked, 'openai/gpt-4.1-mini');

    // Opened again: the list fetched before, without asking.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('Показано: 3 из 3'), findsOneWidget);
  });

  testWidgets('the usage counted on this computer is listed per model and can be reset', (tester) async {
    await tester.runAsync(() async {
      await services.usage.record(const ServiceUsage(
        plugin: 'openai_compatible',
        host: 'openrouter.ai',
        model: 'deepseek/deepseek-chat-v3.1',
        inputTokens: 4000,
        outputTokens: 512,
        cost: 0.0021,
      ));
    });
    await openTranslatorSettings(tester, openRouter());
    expect(find.text('Расход на этом компьютере'), findsOneWidget);
    expect(find.text('deepseek/deepseek-chat-v3.1 · openrouter.ai'), findsOneWidget);
    expect(find.textContaining('запросов: 1'), findsNWidgets(2), reason: 'today and total');
    expect(find.textContaining('стоимость: 0,0021'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Сбросить счётчик'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить счётчик'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сбросить'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('Запросов к серверам перевода ещё не было.'), findsOneWidget);
  });

  testWidgets('F11 turns full screen on and off on any screen', (tester) async {
    final calls = <Object?>[];
    final titles = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (call) async {
      if (call.method == 'setTitle') {
        titles.add(call.arguments);
        return null;
      }
      expect(call.method, 'setFullScreen');
      calls.add(call.arguments);
      return call.arguments;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, null));
    await openTranslatorSettings(tester, fakeSettings());

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, [true]);
    expect(find.text('Полноэкранный режим. Выйти — F11.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(calls, [true, false]);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(fullScreenProvider), isFalse);
    expect(titles, ['Comic Translate Screen'], reason: 'no pages: the program name');
  });
}
