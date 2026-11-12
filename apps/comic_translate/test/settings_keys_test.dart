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
import 'package:comic_translate/ui/settings/http_request_dialog.dart';
import 'package:comic_translate/ui/settings/model_prompt.dart';
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
        ..register(openAiCompatibleOcrFactory)
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
    ..plugins['openai_compatible'] = {
      'api_url': 'https://openrouter.ai/api/v1',
      'model': 'deepseek/deepseek-chat-v3.1',
    };

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

  bool obscured(WidgetTester tester) => tester
      .widget<TextField>(
        find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith('Ключ API')),
      )
      .obscureText;

  test('OpenRouter uses shared HTTP overrides and restores native requests when deselected', () async {
    final settings = fakeSettings()..translator = 'openrouter';
    const chat = HttpRequestSpec('POST custom/chat', '{"text":"result"}');
    settings.requestTemplates['custom'] = RequestTemplate(
      name: 'Custom',
      http: {
        HttpOperation.chat: chat,
        HttpOperation.models: const HttpRequestSpec('GET custom/models', '{"items":"data","id":"id"}'),
        HttpOperation.keyStatus: const HttpRequestSpec('GET custom/key', '{"fields":{"Balance":"remaining"}}'),
      },
    );
    settings.plugins['openrouter'] = {RequestTemplate.selectionKey: 'custom', 'model': 'text-model'};
    settings.plugins['openrouter_ocr'] = {'model': 'vision-model'};
    final config = await services.pluginConfig('openrouter', settings);
    expect(openRouterModelCatalog(config)!.usesProfileCredentials, isTrue);
    expect(openRouterKeyStatus(config)!.custom, isTrue);
    final ocr = await services.pluginConfig('openrouter_ocr', settings);
    expect(httpRequestSpec(ocr, HttpOperation.chat)?.request, chat.request);
    expect(ocr.value<String>('model'), 'vision-model');

    settings.plugins['openrouter']!.remove(RequestTemplate.selectionKey);
    final native = await services.pluginConfig('openrouter', settings);
    expect(httpRequestSpec(native, HttpOperation.chat), isNull);
    expect(openRouterModelCatalog(native)!.usesProfileCredentials, isFalse);
    expect(openRouterKeyStatus(native)!.custom, isFalse);
  });

  testWidgets('pasted HTTP response is parsed in the editor without sending', (tester) async {
    final settings = fakeSettings()..translator = 'openrouter';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HttpRequestDialog(
              operation: HttpOperation.chat,
              spec: const HttpRequestSpec('POST custom/chat', '{"text":"output.text"}'),
              enabled: true,
              settings: settings,
              pluginId: 'openrouter',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Проверить вставленный JSON'));
    await tester.pumpAndSettle();
    final sample = find.byWidgetPredicate((w) => w is TextFormField).last;
    await tester.enterText(sample, '{"output":{"text":"offline-result"}}');
    await tester.tap(find.text('Проверить пример'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('offline-result'), findsOneWidget);
  });

  testWidgets('combined prompt example matches both frame labels', (tester) async {
    final settings = fakeSettings()..plugins['openrouter_ocr'] = {'together': true};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialSettingsProvider.overrideWithValue(settings)],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ModelPromptButton(pluginId: 'openrouter_ocr', storageId: 'openrouter_ocr', reader: true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Редактор промпта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить пример'));
    await tester.pumpAndSettle();
    expect(find.textContaining('[01-001], [01-002]'), findsOneWidget);
    await tester.ensureVisible(find.text('Подставить пример'));
    await tester.tap(find.text('Подставить пример'));
    await tester.tap(find.text('Проверить пример'));
    await tester.pumpAndSettle();
    expect(find.text('Обе рамки сопоставлены.'), findsOneWidget);
  });

  testWidgets('named model prompts can be saved, edited, selected and deleted independently', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = fakeSettings()
      ..modelPromptPresets[ModelPromptKind.ocr] = const [PromptPreset('OCR only', 'Read punctuation.')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services), initialSettingsProvider.overrideWithValue(settings)],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ModelPromptButton(pluginId: 'openrouter', storageId: 'openrouter'),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(ModelPromptButton)));
    Future<void> tap(Finder target) async {
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    AppSettings restored() => AppSettings.fromJson(container.read(settingsProvider).toJson());
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    final editor = find.text('Редактор промпта').first;
    final instructions = find.byType(TextFormField).last;
    final name = find.byType(TextFormField).first;

    await tap(editor);
    expect(find.text('OCR only'), findsNothing);
    await tap(find.byTooltip('Создать заготовку'));
    await tester.enterText(name, 'Dialogue');
    await tester.enterText(instructions, 'Translate naturally.');
    await tap(save.last);
    expect(find.text('Dialogue'), findsOneWidget);
    await tap(save);
    expect(restored().modelPromptPresets[ModelPromptKind.translation]!.single.name, 'Dialogue');
    expect(restored().pluginValues('openrouter')[llmPromptSetting.key], 'Translate naturally.');

    await tap(editor);
    await tap(find.byTooltip('Редактировать заготовку'));
    await tester.enterText(name, 'Short dialogue');
    await tester.enterText(instructions, 'Keep sentences short.');
    await tap(save.last);
    await tap(find.byType(DropdownButtonFormField<int>));
    await tap(find.text('Встроенный промпт').last);
    await tap(find.byType(DropdownButtonFormField<int>));
    await tap(find.text('Short dialogue').last);
    expect(find.text('Keep sentences short.'), findsOneWidget);
    await tap(find.byTooltip('Удалить заготовку'));
    await tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tap(save);

    final after = restored();
    expect(after.modelPromptPresets[ModelPromptKind.translation], isNull);
    expect(after.modelPromptPresets[ModelPromptKind.ocr]!.single.name, 'OCR only');
    expect(after.pluginValues('openrouter')[llmPromptSetting.key], 'Keep sentences short.');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  });

  test('OCR uses its selected profile with a separate model and no fallback to another key', () async {
    const id = 'openai_compatible_ocr';
    final settings = AppSettings()
      ..ownServerNames.addAll({'translation': 'Translation', 'reading': 'Reading'})
      ..ownServerProfile = 'translation'
      ..ownServerOcrProfile = 'reading'
      ..plugins[AppSettings.ownServerStorageId('reading')] = {
        'api_url': 'http://reading.local',
        'chat_path': 'llm/chat',
        'model': 'translation-model',
      }
      ..plugins[id] = {'api_url': 'http://legacy.local', 'model': 'vision-model'};
    await secrets.write(pluginSecretKey('openai_compatible', 'api_key'), 'legacy-key');
    await secrets.write(pluginSecretKey(AppSettings.ownServerStorageId('reading'), 'api_key'), 'reading-key');
    final restored = AppSettings.fromJson(settings.toJson());
    final config = await services.pluginConfig(id, restored);
    expect(config.secret('api_key'), 'reading-key');
    expect(config.value<String>('api_url'), 'http://reading.local');
    expect(config.value<String>('chat_path'), 'llm/chat');
    expect(config.value<String>('model'), 'vision-model');

    restored.ownServerNames.remove('reading');
    restored.plugins.remove(AppSettings.ownServerStorageId('reading'));
    await secrets.delete(pluginSecretKey(AppSettings.ownServerStorageId('reading'), 'api_key'));
    final removed = await services.pluginConfig(id, restored);
    expect(removed.value<String>('api_url'), isEmpty);
    expect(removed.secret('api_key'), isNull);
  });

  testWidgets('recognition edits the shared profile while keeping its own selection and model', (tester) async {
    final settings = openRouter()
      ..ocr = 'openai_compatible_ocr'
      ..ownServerNames.addAll({'write': 'Translation server', 'read': 'Vision server'})
      ..ownServerProfile = 'write'
      ..plugins['openai_compatible_write'] = {'api_url': 'http://localhost:18081', 'model': 'text-model'}
      ..plugins['openai_compatible_read'] = {'api_url': 'http://localhost:18082', 'model': 'another-text-model'}
      ..plugins['openai_compatible_ocr'] = {'model': 'vision-model'};
    await openTranslatorSettings(tester, settings);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    AppSettings current() => container.read(settingsProvider);
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await tap(find.widgetWithText(ListTile, 'Распознавание'));
    expect(find.text('Как очищать большие страницы'), findsNothing);
    await tap(find.text('Отдельный адрес (прежние настройки)'));
    await tap(find.widgetWithText(ListTile, 'Vision server'));
    expect(current().ownServerOcrProfile, 'read');
    expect(current().ownServerProfile, 'write');
    expect(find.text('vision-model'), findsOneWidget);
    await tap(find.text('Настройки общего подключения'));
    expect(find.text('http://localhost:18082'), findsOneWidget);
    expect(find.text('http://localhost:18081'), findsNothing);
    final apiUrl = find.widgetWithText(TextField, 'Адрес API');
    await tester.enterText(apiUrl, 'http://localhost:18083');
    await tester.runAsync(() async {
      tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(current().pluginValues('openai_compatible_ocr')['api_url'], 'http://localhost:18083');
    expect(current().pluginValuesForStorage('openai_compatible_read')['api_url'], 'http://localhost:18083');
    expect(current().pluginValues('openai_compatible')['api_url'], 'http://localhost:18081');
    expect(current().pluginValues('openai_compatible')['model'], 'text-model');
    await tap(find.widgetWithText(SwitchListTile, 'Распознавать и переводить одним запросом'));
    expect(current().pluginValues('openai_compatible_ocr')['together'], isTrue);
    await tap(find.widgetWithText(ListTile, 'Очистка'));
    expect(find.text('Как очищать большие страницы'), findsOneWidget);
    expect(find.text('Распознавать и переводить одним запросом'), findsNothing);
  });

  testWidgets('create, edit and delete a shared request template without copying a key', (tester) async {
    final settings = openRouter()
      ..ownServerNames['work'] = 'Work'
      ..ownServerProfile = 'work'
      ..plugins['openai_compatible_work'] = {'api_url': 'http://localhost:1234', 'chat_path': 'original/chat'};
    await openTranslatorSettings(tester, settings);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    AppSettings current() => container.read(settingsProvider);
    Finder field(String label) => find.widgetWithText(TextField, label);
    Finder action(String label) =>
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, label));
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await tap(find.byTooltip('Создать шаблон запросов'));
    await tap(find.widgetWithText(OutlinedButton, 'Список моделей'));
    await tester.enterText(field('HTTP-запрос'), 'POST catalog\n\n{"type":"chat"}');
    await tap(action('Использовать запрос'));
    await tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(OutlinedButton, 'Сведения о ключе')),
    );
    await tap(find.text('Отмена').last);
    await tap(find.text('Параметры совместимости'));
    await tester.enterText(field('Название шаблона'), 'Shared test');
    await tester.enterText(field('Путь чата'), 'shared/chat');
    final options = field('Дополнительные поля чата (JSON)');
    await tester.enterText(options, '{"api_key":"do-not-save"}');
    await tap(action('Сохранить'));
    expect(find.text('Данные авторизации вводятся в поле «Ключ API» в профиле.'), findsOneWidget);
    expect(current().requestTemplates, isEmpty);
    await tester.enterText(options, '{"temperature":null}');
    await tap(action('Сохранить'));
    expect(find.text('Shared test'), findsOneWidget);
    expect(current().pluginValues('openai_compatible')['chat_path'], 'shared/chat');
    expect(current().requestTemplates.values.single.http[HttpOperation.models]?.request, contains('POST catalog'));

    await tap(find.byTooltip('Редактировать шаблон запросов'));
    await tester.enterText(field('Название шаблона'), 'Shared edited');
    await tap(action('Сохранить'));
    expect(find.text('Shared edited'), findsOneWidget);

    await tap(find.byTooltip('Удалить шаблон запросов'));
    await tap(action('Удалить'));
    expect(current().requestTemplates, isEmpty);
    expect(current().pluginValues('openai_compatible')['chat_path'], 'original/chat');
  });

  testWidgets('server picker scrolls and filters saved profiles, and rejects duplicate names', (tester) async {
    final settings = openRouter()
      ..ownServerNames.addAll({
        'old-a': 'Legacy',
        'old-b': 'Legacy',
        'alpha': 'alpha',
        for (var i = 1; i <= 22; i++) 'server-$i': 'Server $i',
      })
      ..plugins['openai_compatible_server-22'] = {'model': 'lookup-model'};
    await openTranslatorSettings(tester, settings);

    await tester.tap(find.text('Исходное подключение'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy · 1'), findsOneWidget);
    expect(find.text('Legacy · 2'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Legacy · 1')).dy, lessThan(tester.getTopLeft(find.text('alpha')).dy));
    await tester.runAsync(() async {
      await tester.tap(find.text('По имени'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final original = find.descendant(of: find.byType(AlertDialog), matching: find.text('Исходное подключение'));
    expect(tester.getTopLeft(original).dy, lessThan(tester.getTopLeft(find.text('alpha')).dy));
    expect(tester.getTopLeft(find.text('alpha')).dy, lessThan(tester.getTopLeft(find.text('Legacy · 1')).dy));
    await tester.runAsync(() async {
      await tester.tap(find.text('По добавлению'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Legacy · 1')).dy, lessThan(tester.getTopLeft(find.text('alpha')).dy));
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).last;
    await tester.scrollUntilVisible(find.text('Server 22'), 150, scrollable: list);
    expect(find.text('Server 22'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Поиск по имени, адресу или модели');
    await tester.enterText(search, '  LOOKUP-MODEL  ');
    await tester.pumpAndSettle();
    expect(find.text('Server 22'), findsOneWidget);
    expect(find.text('Legacy · 1'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Server 22'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Server 22'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить подключение'));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, 'Название подключения');
    await tester.enterText(name, 'a' * 101);
    expect(tester.widget<TextField>(name).controller!.text, 'a' * 100);
    await tester.enterText(name, '  LEGACY ');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Сохранить')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подключение с таким именем уже существует.'), findsOneWidget);
  });

  testWidgets('the private catalog asks before sending a saved key to a remote server', (tester) async {
    final settings = openRouter()..plugins['openai_compatible'] = {'api_url': 'https://catalog.example/v1'};
    await secrets.write(pluginSecretKey('openai_compatible', 'api_key'), 'qa-catalog-auth');
    await openTranslatorSettings(tester, settings);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Загрузить модели'));
    await tester.pumpAndSettle();
    expect(
      find.text('Отправить сохранённый ключ API на catalog.example, чтобы получить список моделей?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the OpenRouter HTTP catalog asks before sending the saved key', (tester) async {
    final settings = fakeSettings()
      ..translator = 'openrouter'
      ..plugins['openrouter'] = {RequestTemplate.selectionKey: 'catalog'}
      ..requestTemplates['catalog'] = RequestTemplate(
        name: 'Catalog',
        http: const {
          HttpOperation.models: HttpRequestSpec(
            'GET models\nAuthorization: Bearer {{api_key}}',
            '{"items":"data","id":"id"}',
          ),
        },
      );
    await secrets.write(pluginSecretKey('openrouter', 'api_key'), 'qa-catalog-auth');
    await openTranslatorSettings(tester, settings);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Выбрать…'));
    await tester.pumpAndSettle();
    expect(
      find.text('Отправить сохранённый ключ API на openrouter.ai, чтобы получить список моделей?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('API key: show while typing, last 4 characters once saved, replace, delete after asking', (tester) async {
    await openTranslatorSettings(tester, openRouter());
    expect(keyField('Не задан'), findsOneWidget);
    expect(find.textContaining('Для запросов используется выбранный ниже ключ'), findsOneWidget);

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

  testWidgets('own server keys keep separate notes, switch explicitly and never fall back after removal', (
    tester,
  ) async {
    const storageId = 'openai_compatible_work';
    const oldKey = 'sk-legacy-key-1122';
    const newKey = 'sk-other-key-3344';
    final settings = openRouter()
      ..ownServerNames['work'] = 'Work'
      ..ownServerProfile = 'work'
      ..ownServerOcrProfile = 'work'
      ..plugins[storageId] = {'api_url': 'http://localhost:1234'};
    final legacy = AppSettings.ownServerSecretKey(storageId, '');
    await secrets.write(legacy, oldKey);
    await openTranslatorSettings(tester, settings);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    AppSettings current() => container.read(settingsProvider);
    Future<String?> configured([String id = 'openai_compatible']) async =>
        (await services.pluginConfig(id, current())).secret('api_key');
    Finder dialogButton(String label) =>
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, label));
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    expect(await configured(), oldKey);
    await tap(find.byTooltip('Добавить ключ API'));
    await tester.enterText(find.widgetWithText(TextField, 'Новый ключ API'), newKey);
    final note = find.widgetWithText(TextField, 'Заметка к ключу');
    await tester.enterText(note, 'a' * 101);
    expect(tester.widget<TextField>(note).controller!.text, 'a' * 100);
    await tester.enterText(note, 'Запасной');
    await tap(dialogButton('Сохранить'));
    expect(await configured(), oldKey);
    final keyId = current().keysForOwnServer(storageId).notes.keys.single;
    final second = AppSettings.ownServerSecretKey(storageId, keyId);
    expect(await secrets.read(second), newKey);
    expect(jsonEncode(current().toJson()), isNot(contains(newKey)));

    await tap(find.text('Первый ключ'));
    await tap(find.text('Ключ 2 · Запасной').last);
    expect(await configured(), newKey);
    expect(await configured('openai_compatible_ocr'), newKey);
    await tap(find.byTooltip('Редактировать заметку к ключу'));
    await tester.enterText(note, 'Рабочий');
    await tap(dialogButton('Сохранить'));
    expect(find.text('Ключ 2 · Рабочий'), findsOneWidget);
    expect(keyField('Сохранён: …3344'), findsOneWidget);

    await tap(find.text('Удалить ключ'));
    await tap(dialogButton('Удалить'));
    expect(find.text('Без ключа'), findsOneWidget);
    expect(await configured(), isNull);
    expect(await configured('openai_compatible_ocr'), isNull);
    expect(await secrets.read(second), isNull);
    expect(await secrets.read(legacy), oldKey);
  });

  testWidgets('balance check only for OpenRouter, marked as sent to it, and needs a saved key', (tester) async {
    await openTranslatorSettings(tester, openRouter());
    expect(find.text('Сведения о ключе'), findsOneWidget);
    expect(find.textContaining('Спрашивает у openrouter.ai'), findsOneWidget);
    expect(find.text('Загрузить модели'), findsOneWidget, reason: 'the list of models beside the model field');
    await tester.ensureVisible(find.text('Сведения о ключе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сведения о ключе'));
    await tester.pumpAndSettle();
    expect(find.text('Сначала сохраните ключ API'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await tester.runAsync(
      () => container
          .read(settingsProvider.notifier)
          .change((s) => s.plugins['openai_compatible'] = {'api_url': 'http://localhost:1234/v1', 'model': 'local'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сведения о ключе'), findsNothing);
    expect(find.text('Загрузить модели'), findsOneWidget);
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
      await services.history.record(
        HistoryEntry(
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
        ),
      );
      await services.history.record(
        HistoryEntry(
          time: DateTime(2026, 10, 25, 18, 5),
          plugin: 'openrouter',
          host: 'openrouter.ai',
          model: 'nvidia/nemotron:free',
          page: 'p2.png',
          ms: 900,
          error: 'openrouter.ai answered HTTP 429',
        ),
      );
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

  testWidgets('the list of models: search, free ones, ones that take pictures, the picked one goes back', (
    tester,
  ) async {
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
          const CatalogModel(
            id: 'deepseek/deepseek-chat-v3.1',
            name: 'DeepSeek V3.1',
            promptPrice: 0.2,
            completionPrice: 0.8,
          ),
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
      await services.usage.record(
        const ServiceUsage(
          plugin: 'openai_compatible',
          host: 'openrouter.ai',
          model: 'deepseek/deepseek-chat-v3.1',
          inputTokens: 4000,
          outputTokens: 512,
          cost: 0.0021,
        ),
      );
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
