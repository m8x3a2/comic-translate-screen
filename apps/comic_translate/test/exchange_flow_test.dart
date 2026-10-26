// The exchange with a chat AI inside "Translate all", the steps and the
// chat buttons; the exchange window itself.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/state/worker_pool.dart';
import 'package:comic_translate/ui/shell_full/exchange_dialog.dart';
import 'package:comic_translate/ui/shell_full/text_export_dialog.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

/// Plays the user in the exchange window: answers with [answer] for each
/// round (null: closes the window).
class _ChatUi implements BatchUi {
  _ChatUi(this.container, this.answer);

  final ProviderContainer container;
  final String? Function(ExchangeRequest request) answer;
  final requests = <ExchangeRequest>[];
  final errors = <Object>[];

  @override
  Future<bool> exchange(ExchangeRequest request) async {
    requests.add(request);
    final text = answer(request);
    if (text == null) return false;
    final ws = container.read(workspaceProvider);
    final items = exchangeItems(exchangePages(ws, request), request.mode);
    final match = matchExchangeAnswer(items, parseExchangeAnswer(text, request.mode), request.mode);
    applyExchange(container.read(workspaceProvider.notifier), ws, items, match, request.mode);
    return true;
  }

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async {}

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async => true;

  @override
  Future<NetworkChoice> confirmNetwork(
    PluginInfo translator,
    PluginEndpoint endpoint, {
    required bool sendsImage,
  }) async => NetworkChoice.once;

  @override
  void showError(Object error) => errors.add(error);

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async => HandEditedChoice.translate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppServices services;
  late ProviderContainer container;

  Future<void> start(AppSettings settings) async {
    dir = Directory.systemTemp.createTempSync('cts_exchange_flow_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(settings),
        workerRegistryProvider.overrideWithValue(fakeRegistry),
      ],
    );
    final pages = [
      for (final n in ['a.png', 'b.png']) p.join(dir.path, n),
    ];
    for (final page in pages) {
      await ImageCodec.writeFile(page, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await container.read(workspaceProvider.notifier).addInputs(pages);
  }

  tearDown(() async {
    container.dispose();
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open somewhere; the folder is in temp.
    }
  });

  List<PageEntry> pages() => container.read(workspaceProvider).pages;

  test('"Translate all" with the chat translator: read here, translated by the chat, then cleaned and drawn', () async {
    await start(fakeSettings()..translator = chatTranslatorId);
    final ui = _ChatUi(container, (r) => '[01-001] Привет!\n[02-001] Пока!');
    await container.read(batchProvider.notifier).run(ui);
    expect(ui.errors, isEmpty);
    expect(ui.requests.single.mode, ExchangeMode.translate);
    expect(ui.requests.single.fromRun, isTrue);
    expect(ui.requests.single.pageIds, [for (final p in pages()) p.id]);
    expect(
      [for (final p in pages()) (p.blocks.single.text, p.blocks.single.translation)],
      [('HELLO', 'Привет!'), ('HELLO', 'Пока!')],
    );
    for (final page in pages()) {
      expect(page.status, PageStatus.done);
      expect(File(page.translatedPath!).existsSync(), isTrue);
      expect(page.cleanPath, isNotNull);
    }
  });

  test('reading and translating through the chat: one message, the original and the translation', () async {
    await start(
      fakeSettings()
        ..ocr = chatOcrId
        ..translator = chatTranslatorId,
    );
    final ui = _ChatUi(container, (r) => '[01-001] Hi --> Привет\n[02-001] Bye --> Пока');
    await container.read(batchProvider.notifier).run(ui);
    expect(ui.requests.single.mode, ExchangeMode.both);
    expect(
      [for (final p in pages()) (p.blocks.single.text, p.blocks.single.translation)],
      [('Hi', 'Привет'), ('Bye', 'Пока')],
    );
    expect(pages().every((p) => p.isDone), isTrue);
  });

  test('not together: reading first, then translating, in two rounds', () async {
    final settings = fakeSettings()
      ..ocr = chatOcrId
      ..translator = chatTranslatorId;
    settings.exchange = settings.exchange.copyWith(together: false);
    await start(settings);
    final ui = _ChatUi(
      container,
      (r) => r.mode == ExchangeMode.recognize ? '[01-001] Hi\n[02-001] Bye' : '[01-001] Привет\n[02-001] Пока',
    );
    await container.read(batchProvider.notifier).run(ui);
    expect([for (final r in ui.requests) r.mode], [ExchangeMode.recognize, ExchangeMode.translate]);
    expect(pages().first.blocks.single.text, 'Hi');
    expect(pages().last.blocks.single.translation, 'Пока');
  });

  test('closing the exchange window stops "Translate all"; the found boxes stay', () async {
    await start(fakeSettings()..translator = chatTranslatorId);
    final ui = _ChatUi(container, (r) => null);
    await container.read(batchProvider.notifier).run(ui);
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect(report.cancelled, isTrue);
    expect(report.done, 0);
    for (final page in pages()) {
      expect(page.status, PageStatus.pending);
      expect(page.blocks, hasLength(1));
      expect(page.cleanPath, isNull);
    }
  });

  test('the chat button: the selected pages read and translated by the chat, whatever the engines', () async {
    await start(fakeSettings());
    final ui = _ChatUi(container, (r) => '[01-001] Hi --> Привет');
    await container.read(stepsProvider.notifier).run(ManualStep.translate, ui, chat: ExchangeMode.both);
    expect(ui.errors, isEmpty);
    expect(ui.requests.single.mode, ExchangeMode.both);
    expect(ui.requests.single.pageIds, [pages().first.id], reason: 'the current page');
    final b = pages().first.blocks.single;
    expect((b.text, b.translation), ('Hi', 'Привет'), reason: 'the local reader did not run');
    expect(container.read(workspaceProvider).history[pages().first.id]!.undo, hasLength(2));

    // Only translating: the local reader reads first.
    container.read(workspaceProvider.notifier).select(1);
    await container.read(stepsProvider.notifier).run(ManualStep.translate, ui, chat: ExchangeMode.translate);
    expect(ui.requests.last.mode, ExchangeMode.translate);
    expect(pages().last.blocks.single.text, 'HELLO');
  });

  testWidgets('the exchange window: instructions, the answer checked as it is pasted, then applied', (tester) async {
    await tester.runAsync(() => start(fakeSettings()));
    final id = pages().first.id;
    container
        .read(workspaceProvider.notifier)
        .edit(
          id,
          (p) => p.copyWith(
            blocks: [
              TextBlock(xyxy: const BBox(10, 10, 50, 30), text: 'Hello'),
              TextBlock(xyxy: const BBox(10, 35, 50, 55), text: 'Bye'),
            ],
          ),
        );
    var applied = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => applied = await showExchangeDialog(
                  context,
                  ExchangeRequest(pageIds: [id], mode: ExchangeMode.translate),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // The folder is written in the background.
    for (var i = 0; i < 50 && find.text('Копировать инструкцию').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text('Копировать инструкцию'), findsOneWidget);
    expect(find.text('Пузырей с текстом: 2, страниц: 1'), findsOneWidget);
    final folders = Directory(p.join(dir.path, 'exchange')).listSync();
    expect(File(p.join(folders.single.path, 'ALL.txt')).readAsStringSync(), '[01-001] Hello -->\n[01-002] Bye -->\n');

    await tester.enterText(find.byType(TextField).last, 'Sure!\n[01-001] Привет\n[07-001] ?');
    await tester.pump();
    expect(find.text('Найдено ответов: 1 из 2'), findsOneWidget);
    expect(find.text('Нет ответа: 01-002'), findsOneWidget);
    expect(find.text('Таких не отправляли (пропущены): 07-001'), findsOneWidget);

    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(applied, isTrue);
    expect([for (final b in pages().first.blocks) b.translation], ['Привет', '']);
  });

  testWidgets('two fields: originals and translations apart, an answer with === splits itself', (tester) async {
    final settings = fakeSettings();
    settings.exchange = settings.exchange.copyWith(apart: true);
    await tester.runAsync(() => start(settings));
    final id = pages().first.id;
    container
        .read(workspaceProvider.notifier)
        .edit(
          id,
          (p) => p.copyWith(
            blocks: [
              TextBlock(xyxy: const BBox(10, 10, 50, 30)),
              TextBlock(xyxy: const BBox(10, 35, 50, 55)),
            ],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExchangeDialog(context, ExchangeRequest(pageIds: [id], mode: ExchangeMode.both)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    for (var i = 0; i < 80 && find.text('Копировать картинки (1)').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text('Копировать картинки (1)'), findsOneWidget);
    final folder = Directory(p.join(dir.path, 'exchange')).listSync().single.path;
    expect(File(p.join(folder, 'prompt.txt')).readAsStringSync(), contains('Then a line with only ==='));

    final original = find.widgetWithText(TextField, 'Оригинал');
    final translation = find.widgetWithText(TextField, 'Перевод');
    await tester.enterText(original, '[01-001] Hi\n[01-002] Bye');
    await tester.enterText(translation, '[01-001] Привет');
    await tester.pump();
    expect(find.text('Найдено ответов: 2 из 2'), findsOneWidget);

    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect([for (final b in pages().first.blocks) (b.text, b.translation)], [('Hi', 'Привет'), ('Bye', '')]);
  });

  /// Puts [blocks] on each page and opens the exchange window for
  /// [request]; waits until [ready] shows.
  Future<void> openWindow(WidgetTester tester, ExchangeRequest request, String ready, List<String> texts) async {
    // A window of a computer screen: the buttons are all in sight.
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final page in pages()) {
      container
          .read(workspaceProvider.notifier)
          .edit(
            page.id,
            (p) => p.copyWith(
              blocks: [
                for (final (i, t) in texts.indexed) TextBlock(xyxy: BBox(10, 5 + i * 25, 50, 25 + i * 25), text: t),
              ],
            ),
          );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showExchangeDialog(context, request), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    for (var i = 0; i < 80 && find.text(ready).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text(ready), findsOneWidget);
  }

  testWidgets('"Copy the text" copies the lines alone; an answer in the clipboard is offered on coming back', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final settings = fakeSettings();
    settings.exchange = settings.exchange.copyWith(answerFromClipboard: true);
    await tester.runAsync(() => start(settings));
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [pages().first.id], mode: ExchangeMode.translate),
      'Копировать текст',
      ['Hello', 'Bye'],
    );
    await tester.tap(find.text('Копировать текст'));
    await tester.pump();
    expect(clipboard, '[01-001] Hello\n[01-002] Bye');

    Future<void> comeBack() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
    }

    // What the window copied itself is no answer.
    await comeBack();
    expect(find.text('Вставить'), findsNothing);

    clipboard = 'Here you go:\n[01-001] Привет\n[01-002] Пока';
    await comeBack();
    expect(find.text('В буфере ответ чата: 2 из 2. Вставить?'), findsOneWidget);
    await tester.tap(find.text('Вставить'));
    await tester.pump();
    expect(find.text('Найдено ответов: 2 из 2'), findsOneWidget);
    // Offered once.
    await comeBack();
    expect(find.text('Вставить'), findsNothing);
  });

  testWidgets('the wheel over the pictures moves them, not the window', (tester) async {
    final settings = fakeSettings();
    settings.exchange = settings.exchange.copyWith(sheetPerPage: true);
    await tester.runAsync(() => start(settings));
    // Many pages: more sheets than the strip shows, and a window taller than the dialog.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        final path = p.join(dir.path, 'more$i.png');
        await ImageCodec.writeFile(path, RgbImage.filled(100, 60, 255, 255, 255));
        await container.read(workspaceProvider.notifier).addInputs([path]);
      });
    }
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [for (final p in pages()) p.id], mode: ExchangeMode.both),
      'Копировать картинки (8)',
      ['Hello'],
    );
    tester.view.physicalSize = const Size(1600, 700);
    await tester.pumpAndSettle();
    final strip = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
    final window = find.byWidgetPredicate((w) => w is SingleChildScrollView).first;
    double offset(Finder f) =>
        tester.state<ScrollableState>(find.descendant(of: f, matching: find.byType(Scrollable)).first).position.pixels;
    await tester.ensureVisible(strip);
    await tester.pumpAndSettle();
    final before = offset(window);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(strip), scrollDelta: const Offset(0, 200)),
    );
    await tester.pump();
    expect(offset(strip), greaterThan(0));
    expect(offset(window), before);
    // Back up: the window could go up too, but the strip has the wheel.
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(strip), scrollDelta: const Offset(0, -100)),
    );
    await tester.pump();
    expect(offset(strip), 100);
    expect(offset(window), before);
  });

  testWidgets('the pictures of one page: the list of pages over the pictures', (tester) async {
    final settings = fakeSettings();
    settings.exchange = settings.exchange.copyWith(sheetPerPage: true);
    await tester.runAsync(() => start(settings));
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [for (final p in pages()) p.id], mode: ExchangeMode.both),
      'Копировать картинки (2)',
      ['Hello'],
    );
    expect(find.text('стр. 1 · 1'), findsOneWidget);
    expect(find.text('стр. 2 · 2'), findsOneWidget);
    // At the bottom of the scrolled part of the window.
    await tester.ensureVisible(find.text('Все страницы (2)'));
    await tester.tap(find.text('Все страницы (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Страница 2 (1)').last);
    await tester.pumpAndSettle();
    expect(find.text('Копировать картинки (1)'), findsOneWidget);
    expect(find.text('стр. 1 · 1'), findsNothing);
    expect(find.text('стр. 2 · 2'), findsOneWidget);

    // The large view shows the same page and can pick another.
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    expect(find.textContaining('стр. 2 · 2'), findsNWidgets(2), reason: 'in the window and in the large view');
    await tester.tap(find.text('Страница 2 (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Страница 1 (1)').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('стр. 1 · 1'), findsNWidgets(2));
    expect(find.textContaining('стр. 2 · 2'), findsNothing);
  });

  testWidgets('one page picked while sheets mix pages: each page starts a sheet of its own', (tester) async {
    await tester.runAsync(() => start(fakeSettings()));
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [for (final p in pages()) p.id], mode: ExchangeMode.both),
      'стр. 1–2 · 1–2',
      ['Hello'],
    );
    await tester.ensureVisible(find.text('Все страницы (1)'));
    await tester.tap(find.text('Все страницы (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Страница 2 (1)').last);
    await tester.pump();
    expect(find.textContaining('Включено «Каждая страница с нового листа»'), findsOneWidget);
    expect(container.read(settingsProvider).exchange.sheetPerPage, isTrue);
    // The sheets are made again after a moment.
    for (var i = 0; i < 80 && find.text('стр. 2 · 2').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('стр. 2 · 2'), findsOneWidget);
    expect(find.text('стр. 1 · 1'), findsNothing);
    expect(find.textContaining('Включено «Каждая страница с нового листа»'), findsOneWidget, reason: 'it says why');

    // The large view has the switch too; off again, the sheets mix pages.
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    final perPage = find.widgetWithText(FilterChip, 'Каждая страница с нового листа');
    expect(perPage, findsNWidgets(2));
    await tester.tap(perPage.last);
    await tester.pump();
    expect(container.read(settingsProvider).exchange.sheetPerPage, isFalse);
    for (var i = 0; i < 80 && find.textContaining('стр. 1–2 · 1–2').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('стр. 1–2 · 1–2'), findsWidgets, reason: 'the large view follows the folder');
  });

  testWidgets('the mode can be switched when the chat button opened the window, not in "Translate all"', (
    tester,
  ) async {
    await tester.runAsync(() => start(fakeSettings()));
    final id = pages().first.id;
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [id], mode: ExchangeMode.translate, fromRun: true),
      'Копировать текст',
      ['Hello'],
    );
    expect(find.byType(SegmentedButton<ExchangeMode>), findsOneWidget);
    await tester.tap(find.text('Распознать'));
    for (var i = 0; i < 80 && find.text('Копировать картинки (1)').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text('Копировать картинки (1)'), findsOneWidget);
    expect(find.text('Применить и продолжить'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [id], mode: ExchangeMode.translate, fromRun: true, modeFixed: true),
      'Копировать текст',
      ['Hello'],
    );
    expect(find.byType(SegmentedButton<ExchangeMode>), findsNothing);
  });

  testWidgets('the glossary and the styles go into the instructions; words the chat suggests are added', (
    tester,
  ) async {
    await tester.runAsync(() => start(fakeSettings()));
    container.read(workspaceProvider.notifier).setGlossary('Kai --> Кай\n');
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [pages().first.id], mode: ExchangeMode.translate),
      'Копировать текст',
      ['KAI!', 'Bye'],
    );
    String promptFile() {
      final folder = Directory(p.join(dir.path, 'exchange')).listSync().single.path;
      return File(p.join(folder, 'prompt.txt')).readAsStringSync();
    }

    expect(promptFile(), contains('Kai → Кай'));
    expect(find.text('Словарь (1)'), findsOneWidget);

    // A style turned on goes into the instructions.
    await tester.tap(find.text('Смягчить грубости'));
    for (var i = 0; i < 40 && !promptFile().contains('Soften'); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(promptFile(), contains('Style of the translation: Soften rude words and swearing.'));
    expect(container.read(settingsProvider).exchange.activeStyles, ['soften']);
    // "No style": the built-in instructions as they are.
    await tester.tap(find.text('Без стиля'));
    await tester.pump();
    expect(container.read(settingsProvider).exchange.activeStyles, isEmpty);
    await tester.tap(find.text('Смягчить грубости'));
    await tester.pump();

    // The chat suggests a word: added with one button.
    await tester.enterText(
      find.byType(TextField).last,
      '[01-001] КАЙ!\n[01-002] Пока\n\nNEW: Maya --> Майя\nNEW: Kai --> Каи',
    );
    await tester.pump();
    expect(find.text('Найдено ответов: 2 из 2'), findsOneWidget);
    expect(find.text('Maya --> Майя'), findsOneWidget);
    expect(find.text('Kai --> Каи'), findsNothing, reason: 'the glossary has Kai');
    await tester.ensureVisible(find.text('Добавить в словарь'));
    await tester.tap(find.text('Добавить в словарь'));
    await tester.pump();
    expect(container.read(workspaceProvider).glossary, 'Kai --> Кай\nMaya --> Майя\n');
    expect(find.text('Добавлено в словарь: 1'), findsOneWidget);
  });

  test('translators over the network get the glossary and the styles with the context', () {
    final settings = fakeSettings()..extraContext = 'A comedy.';
    settings.exchange = settings.exchange.copyWith(activeStyles: ['lively']);
    final forWorker = settingsForTranslators(settings, 'Kai --> Кай');
    expect(forWorker.extraContext, startsWith('A comedy.\nStyle of the translation: Make it lively'));
    expect(forWorker.extraContext, contains('Kai → Кай'));
    expect(settings.extraContext, 'A comedy.', reason: 'the settings themselves stay');
    final plain = fakeSettings();
    expect(identical(settingsForTranslators(plain, ''), plain), isTrue);
  });

  testWidgets('"Export text": the pages chosen by number, the original or the translation, copied', (tester) async {
    await tester.runAsync(() => start(fakeSettings()));
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (n, page) in pages().indexed) {
      container
          .read(workspaceProvider.notifier)
          .edit(
            page.id,
            (p) => p.copyWith(
              blocks: [
                TextBlock(xyxy: const BBox(0, 0, 10, 10), text: 'Hi $n', translation: 'Привет $n')
                  ..speaker = Speaker.female,
                TextBlock(xyxy: const BBox(0, 20, 10, 30)),
              ],
            ),
          );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showTextExportDialog(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Пусто — все страницы (2)'), findsOneWidget);
    expect(
      find.text('Страница 1\n[01-001] [f] Hi 0\n[01-002]\n\nСтраница 2\n[02-001] [f] Hi 1\n[02-002]\n'),
      findsOneWidget,
    );

    // Only the second page, its translation, plain lines with a heading of the user.
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.tap(find.text('Перевод').first);
    await tester.tap(find.text('Метки перед строками: [01-003]'));
    await tester.tap(find.text('Кто говорит: [m] [f] [n]'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '--- {n} ---');
    await tester.pump();
    expect(find.text('Страниц: 1'), findsOneWidget);
    expect(find.text('--- 2 ---\nПривет 1\n'), findsOneWidget);
    await tester.tap(find.text('Копировать'));
    await tester.pump();
    expect(clipboard, '--- 2 ---\nПривет 1\n');
    expect(find.text('Скопировано. Вставьте: Ctrl+V.'), findsOneWidget);
    final remembered = container.read(settingsProvider).exchange.textExport;
    expect(
      (remembered.part, remembered.labels, remembered.speakers, remembered.heading),
      (TextExportPart.translation, false, false, '--- {n} ---'),
    );

    // A wrong number is told.
    await tester.enterText(find.byType(TextField).first, '7');
    await tester.pump();
    expect(find.text('Не понял «7»: страниц всего 2'), findsOneWidget);
  });

  testWidgets('another round for the missing pieces and the ones asked again; earlier answers stay', (tester) async {
    await tester.runAsync(() => start(fakeSettings()));
    await openWindow(
      tester,
      ExchangeRequest(pageIds: [for (final p in pages()) p.id], mode: ExchangeMode.translate),
      'Копировать текст',
      ['Hello', 'Bye'],
    );
    final folder = Directory(p.join(dir.path, 'exchange')).listSync().single.path;
    Future<void> waitFor(String text) async {
      for (var i = 0; i < 80 && find.textContaining(text).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.textContaining(text), findsOneWidget);
    }

    await tester.enterText(find.byType(TextField).last, '[01-001] плохо\n[01-002] Пока\n[02-001] Привет');
    await tester.pump();
    expect(find.text('Нет ответа: 02-002'), findsOneWidget);
    await tester.tap(find.text('Дослать недостающее (1)'));
    await waitFor('Досылка: пузырей — 1 (02-002)');
    expect(
      File(p.join(folder, 'again_1', 'prompt.txt')).readAsStringSync(),
      startsWith('Your previous answer had nothing for these labels: [02-002]. Answer only for it'),
    );
    expect(File(p.join(folder, 'again_1', 'ALL.txt')).readAsStringSync(), '[02-002] Bye -->\n');
    expect(find.text('Уже принято из прошлых ответов: 3 из 4'), findsOneWidget);
    expect(find.text('Найдено ответов: 3 из 4'), findsOneWidget);
    expect(find.text('Дослать недостающее (1)'), findsNothing, reason: 'not before the answer of this round');
    expect((tester.widget<TextField>(find.byType(TextField).last)).controller!.text, isEmpty);

    // The answer of this round: all of them.
    await tester.enterText(find.byType(TextField).last, '[02-002] Пока-пока');
    await tester.pump();
    expect(find.text('Найдено ответов: 4 из 4'), findsOneWidget);

    // Asked again: a wrong label is told, a good one makes another round.
    final again = find.widgetWithText(TextField, 'Ещё спросить');
    await tester.enterText(again, '01-001, abc');
    await tester.pump();
    expect(find.text('Это не метка: «abc»'), findsOneWidget);
    await tester.enterText(again, '01-001 09-001');
    await tester.pump();
    expect(find.text('Таких меток не было: 09-001'), findsOneWidget);
    await tester.enterText(again, '01-001');
    await tester.pump();
    await tester.tap(find.text('Спросить ещё раз (1)'));
    await waitFor('Досылка: пузырей — 1 (01-001)');
    expect(
      File(p.join(folder, 'again_2', 'prompt.txt')).readAsStringSync(),
      startsWith('Answer again for these labels, the previous answer was not good: [01-001].'),
    );
    expect(find.text('Уже принято из прошлых ответов: 4 из 4'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '[01-001] Здравствуй');
    await tester.pump();

    // Back to the whole exchange: the answers taken stay.
    await tester.tap(find.text('Вернуться к полной выгрузке'));
    await tester.pump();
    expect(find.textContaining('Досылка'), findsNothing);
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(
      [
        for (final page in pages())
          for (final b in page.blocks) b.translation,
      ],
      ['Здравствуй', 'Пока', 'Привет', 'Пока-пока'],
    );
  });
}
