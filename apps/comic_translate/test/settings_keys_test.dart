// API keys, the balance check, the usage counter and full screen (M8.1).

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/window_mode.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/settings/settings_screen.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      registry: fakeRegistry()..register(openAiCompatibleFactory),
    );
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
    expect(find.textContaining('abcdef'), findsNothing, reason: 'the saved key is never shown');

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
    expect(find.text('Проверить остаток'), findsOneWidget);
    expect(find.textContaining('Спрашивает у openrouter.ai'), findsOneWidget);
    await tester.ensureVisible(find.text('Проверить остаток'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить остаток'));
    await tester.pumpAndSettle();
    expect(find.text('Сначала сохраните ключ API'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await tester.runAsync(() => container.read(settingsProvider.notifier).change(
          (s) => s.plugins['openai_compatible'] = {'api_url': 'http://localhost:1234/v1', 'model': 'local'},
        ));
    await tester.pumpAndSettle();
    expect(find.text('Проверить остаток'), findsNothing);
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
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (call) async {
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
  });
}
