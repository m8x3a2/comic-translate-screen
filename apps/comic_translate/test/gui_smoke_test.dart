import 'dart:io';

import 'package:comic_translate/app_info.dart';
import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/import/pdf_pages.dart';
import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/export.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/settings/settings_screen.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

/// Answers every question of a run with yes.
class _YesUi implements BatchUi {
  final errors = <Object>[];
  final missingKeys = <String>[];

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async => missingKeys.add(host);

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

  /// Pages changed by hand: what to answer.
  HandEditedChoice handEdited = HandEditedChoice.translate;
  int handEditedAsked = 0;

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async {
    handEditedAsked = count;
    return handEdited;
  }
}

/// The window size of a laptop screen (the minimum window is 1024 wide).
void desktopWindow(WidgetTester tester, {Size size = const Size(1280, 720)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  // Real file IO must not run inside testWidgets' fake-async zone, so
  // services are created and disposed outside of it (or in runAsync).
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_gui_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Images shown by the widgets may still be open; the folder is in temp.
    }
  });

  Widget app(AppSettings settings) => ProviderScope(
    overrides: [
      servicesProvider.overrideWithValue(services),
      initialSettingsProvider.overrideWithValue(settings),
      workerRegistryProvider.overrideWithValue(fakeRegistry),
    ],
    child: const ComicTranslateApp(),
  );

  testWidgets('start screen in Russian, with the privacy note', (tester) async {
    await tester.pumpWidget(app(fakeSettings()));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.text('Открыть файлы…'), findsOneWidget);
    expect(find.text('Открыть папку…'), findsOneWidget);
    expect(find.textContaining('ничего никуда не отправляется'), findsOneWidget);
  });

  testWidgets('settings open on every section and switch the interface language', (tester) async {
    desktopWindow(tester);
    await tester.pumpWidget(app(fakeSettings()));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    for (final title in [
      'Переводчик',
      'Распознавание и очистка',
      'Текст',
      'Увеличение',
      'Экспорт',
      'О программе',
      'Общие',
    ]) {
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
    }
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
      await container.read(settingsProvider.notifier).change((s) => s.uiLanguage = 'en');
    });
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    final saved = await tester.runAsync(services.settingsStore.load);
    expect(saved!.uiLanguage, 'en', reason: 'changes are saved at once');
  });

  testWidgets('translate all: pages are processed in the background and shown', (tester) async {
    desktopWindow(tester);
    final pages = Directory(p.join(dir.path, 'chapter'))..createSync();
    await tester.runAsync(() async {
      for (final n in ['page2.png', 'page1.png']) {
        await ImageCodec.writeFile(p.join(pages.path, n), RgbImage.filled(120, 80, 255, 255, 255));
      }
    });
    await tester.pumpWidget(app(fakeSettings()));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([pages.path]));
    await tester.pump();
    expect(find.text('page1.png'), findsOneWidget);
    expect(find.text('Перевести всё'), findsOneWidget);

    final ui = _YesUi();
    await tester.runAsync(() => container.read(batchProvider.notifier).run(ui));
    await tester.pump();
    expect(ui.errors, isEmpty);
    final ws = container.read(workspaceProvider);
    expect(ws.pages.map((p) => p.status), [PageStatus.done, PageStatus.done]);
    expect(File(ws.pages.first.translatedPath!).existsSync(), isTrue);
    expect(ws.pages.first.blocks.single.translation, contains('HELLO'));
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect([report.done, report.total, report.skipped.length, report.cancelled], [2, 2, 0, false]);

    await tester.pumpAndSettle();
    expect(find.text('Перевести заново'), findsOneWidget);
    expect(find.textContaining('[ru] HELLO'), findsOneWidget, reason: 'text panel shows the translation');

    // Export writes the translated pages under their original names.
    final out = Directory(p.join(dir.path, 'out'));
    final ids = [for (final page in ws.pages) page.id];
    final result = await tester.runAsync(
      () =>
          exportOpenPages(container.read, ids, const ExportOptions(imageFormat: 'jpg'), out.path, bookName: 'chapter'),
    );
    expect(result!.pages, 2);
    expect(out.listSync().map((f) => p.basename(f.path)).toList()..sort(), ['page1.jpg', 'page2.jpg']);

    // A PDF of the chapter opens again as its pages (PDFium reads it).
    final pdf = p.join(dir.path, 'chapter.pdf');
    await tester.runAsync(
      () =>
          exportOpenPages(container.read, ids, const ExportOptions(container: ExportContainer.pdf), pdf, bookName: 'c'),
    );
    final back = await tester.runAsync(
      () => importPages([pdf], cacheDir: Directory(p.join(dir.path, 'reopen')), pdf: rasterizePdf),
    );
    expect(back, hasLength(2));
  });

  testWidgets('the smallest window still fits the toolbar and panels', (tester) async {
    desktopWindow(tester, size: const Size(1024, 640));
    final page = File(p.join(dir.path, 'a page with a rather long file name.png'));
    await tester.runAsync(() => ImageCodec.writeFile(page.path, RgbImage.filled(60, 90, 255, 255, 255)));
    await tester.pumpWidget(
      app(
        fakeSettings()
          ..sourceLanguage = 'Japanese'
          ..targetLanguage = 'Brazilian Portuguese',
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([page.path]));
    await tester.pump();
    expect(find.text('Перевести всё'), findsOneWidget);
  });

  testWidgets('"Auto" is the first source language and explains itself', (tester) async {
    desktopWindow(tester);
    await tester.pumpWidget(app(fakeSettings()..sourceLanguage = Languages.auto));
    final page = File(p.join(dir.path, 'auto.png'));
    await tester.runAsync(() => ImageCodec.writeFile(page.path, RgbImage.filled(60, 90, 255, 255, 255)));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([page.path]));
    await tester.pump();
    expect(find.text('Авто'), findsOneWidget);
    expect(find.byTooltip(lookupAppLocalizations(const Locale('ru')).languageAutoHint), findsOneWidget);

    await tester.tap(find.text('Авто'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).sourceLanguage, 'English');
    expect(container.read(workspaceProvider).currentPage!.sourceOf(container.read(settingsProvider)), 'English');
  });

  Future<(ProviderContainer, Directory)> openPages(WidgetTester tester, AppSettings settings, int count) async {
    final pages = Directory(p.join(dir.path, 'pages'))..createSync();
    await tester.runAsync(() async {
      for (var i = 1; i <= count; i++) {
        await ImageCodec.writeFile(p.join(pages.path, 'p$i.png'), RgbImage.filled(120, 80, 255, 255, 255));
      }
    });
    await tester.pumpWidget(app(settings));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([pages.path]));
    return (container, pages);
  }

  testWidgets('an internet translator without a key is explained before anything runs', (tester) async {
    desktopWindow(tester);
    final (container, _) = await openPages(tester, fakeSettings()..translator = 'fake_cloud', 1);
    final ui = _YesUi();
    await tester.runAsync(() => container.read(batchProvider.notifier).run(ui));
    expect(ui.missingKeys, ['cloud.example']);
    expect(container.read(workspaceProvider).pages.single.status, PageStatus.pending);
  });

  testWidgets('an error every page would repeat stops the run at once, with the reason', (tester) async {
    desktopWindow(tester);
    final (container, _) = await openPages(tester, fakeSettings()..translator = 'fake_fail', 4);
    await tester.runAsync(() => container.read(batchProvider.notifier).run(_YesUi()));
    await tester.pump();
    final report = (container.read(batchProvider) as BatchIdle).last!;
    final reason = report.stoppedBy as TranslationFailedReason;
    expect([reason.kind, report.skipped.length], [TranslationErrorKind.credits, 1]);
    expect(reason.message, contains('HTTP 402'));
    expect(container.read(workspaceProvider).pages.where((p) => p.status == PageStatus.pending), hasLength(3));
    // The report says it in plain words, with the details.
    await tester.tap(find.text('Отчёт'));
    await tester.pumpAndSettle();
    expect(find.textContaining('закончились деньги'), findsWidgets);
    expect(find.textContaining('HTTP 402'), findsWidgets);
    expect(find.text('Открыть настройки'), findsOneWidget);
  });

  testWidgets('page-by-page errors are skipped, but three in a row stop the run', (tester) async {
    desktopWindow(tester);
    final (container, _) = await openPages(tester, fakeSettings()..translator = 'fake_bad_reply', 5);
    await tester.runAsync(() => container.read(batchProvider.notifier).run(_YesUi()));
    await tester.pump();
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect(report.skipped, hasLength(3));
    expect((report.stoppedBy as TranslationFailedReason).kind, TranslationErrorKind.badReply);
    expect(container.read(workspaceProvider).pages.map((p) => p.status).toList(), [
      PageStatus.skipped,
      PageStatus.skipped,
      PageStatus.skipped,
      PageStatus.pending,
      PageStatus.pending,
    ]);
  });

  testWidgets('exported pages are not counted as unsaved', (tester) async {
    desktopWindow(tester);
    final (container, _) = await openPages(tester, fakeSettings(), 2);
    await tester.runAsync(() => container.read(batchProvider.notifier).run(_YesUi()));
    final ws = container.read(workspaceProvider.notifier);
    expect(container.read(workspaceProvider).unexportedCount, 2);
    ws.markExported([container.read(workspaceProvider).pages.first.id]);
    expect(container.read(workspaceProvider).unexportedCount, 1);
    // A new translation of an exported page is unsaved again.
    final first = container.read(workspaceProvider).pages.first;
    ws.updatePage(first.id, (p) => p.copyWith(translatedPath: '${p.translatedPath}.new'));
    expect(container.read(workspaceProvider).unexportedCount, 2);
  });

  testWidgets('a page that cannot be read is skipped and reported', (tester) async {
    desktopWindow(tester);
    final bad = File(p.join(dir.path, 'broken.png'))..writeAsStringSync('not an image');
    await tester.pumpWidget(app(fakeSettings()));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([bad.path]));
    await tester.runAsync(() => container.read(batchProvider.notifier).run(_YesUi()));
    await tester.pump();
    final page = container.read(workspaceProvider).pages.single;
    expect(page.status, PageStatus.skipped);
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect(report.skipped.single.name, 'broken.png');
  });
}
