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
import 'package:comic_translate/ui/shell_full/exchange_dialog.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
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
    expect(File(p.join(folders.single.path, 'ALL.txt')).readAsStringSync(), '[01-001] Hello\n[01-002] Bye\n');

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
}
