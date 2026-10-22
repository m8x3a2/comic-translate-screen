// Panels that fold away and the grid of all pages.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/common/panels.dart';
import 'package:comic_translate/ui/shell_full/page_grid.dart';
import 'package:comic_translate/ui/shell_full/page_list.dart';
import 'package:comic_translate/ui/shell_full/text_panel.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_panels_test_');
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

  Future<ProviderContainer> openPages(WidgetTester tester, int count) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final paths = [for (var i = 1; i <= count; i++) p.join(dir.path, 'page$i.png')];
    await tester.runAsync(() async {
      for (final path in paths) {
        await ImageCodec.writeFile(path, RgbImage.filled(60, 80, 255, 255, 255));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(fakeSettings()),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
        ],
        child: const ComicTranslateApp(),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs(paths));
    await tester.pump();
    return container;
  }

  Finder toggle(String tooltip) => find.byTooltip(tooltip);

  testWidgets('the side panels and the tool bar fold away and come back', (tester) async {
    final container = await openPages(tester, 2);
    expect(find.byType(PageList), findsOneWidget);
    await tester.tap(toggle('Скрыть: Страницы'));
    await tester.pump();
    expect(find.byType(PageList), findsNothing);
    expect(find.byType(FoldedSidePanel), findsOneWidget);
    expect(container.read(settingsProvider).hiddenPanels, {Panels.pages});

    await tester.tap(toggle('Скрыть: Текст'));
    await tester.tap(toggle('Скрыть: Инструменты'));
    await tester.pump();
    expect(find.byType(TextPanel), findsNothing);
    expect(find.byType(FoldedToolBar), findsOneWidget);
    // What goes into settings.json.
    final saved = AppSettings.fromJson(container.read(settingsProvider).toJson());
    expect(saved.hiddenPanels, {Panels.pages, Panels.text, Panels.tools});

    await tester.tap(toggle('Показать: Страницы'));
    await tester.tap(toggle('Показать: Текст'));
    await tester.tap(toggle('Показать: Инструменты'));
    await tester.pump();
    expect(find.byType(PageList), findsOneWidget);
    expect(find.byType(TextPanel), findsOneWidget);
    expect(container.read(settingsProvider).hiddenPanels, isEmpty);
  });

  testWidgets('the grid of pages ticks pages without Ctrl and opens one', (tester) async {
    final container = await openPages(tester, 3);
    await tester.tap(find.byTooltip('Все страницы на всё окно'));
    await tester.pump();
    expect(find.byType(PageGrid), findsOneWidget);
    expect(find.text('Отмечено: 1'), findsOneWidget, reason: 'the current page');

    await tester.tap(find.text('3. page3.png'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(workspaceProvider).stepPages.map((p) => p.name), ['page1.png', 'page3.png']);
    await tester.tap(find.text('Отметить все'));
    await tester.pump();
    expect(container.read(workspaceProvider).stepPages, hasLength(3));

    await tester.tap(find.text('Снять отметки'));
    await tester.pump();
    final second = find.text('2. page2.png');
    await tester.tap(second);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.byType(PageGrid), findsNothing);
    expect(container.read(workspaceProvider).currentPage!.name, 'page2.png');
  });

  testWidgets('a page dragged in the grid moves', (tester) async {
    final container = await openPages(tester, 3);
    container.read(pageGridOpenProvider.notifier).set(true);
    await tester.pump();
    await tester.drag(
      find.text('3. page3.png'),
      tester.getCenter(find.text('1. page1.png')) - tester.getCenter(find.text('3. page3.png')),
    );
    await tester.pumpAndSettle();
    expect([for (final p in container.read(workspaceProvider).pages) p.name], ['page3.png', 'page1.png', 'page2.png']);
    expect(container.read(workspaceProvider).currentPage!.name, 'page1.png', reason: 'the current page stays');
  });

  test('a moved webtoon page drops the part of a cut bubble that no longer fits', () {
    final container = ProviderContainer(overrides: [servicesProvider.overrideWithValue(services)]);
    addTearDown(container.dispose);
    final ws = container.read(workspaceProvider.notifier);
    ws.loadPages([
      PageEntry(id: 'a', path: 'a.png', name: 'a', overflowPath: 'patch.png', translatedPath: 'a_t.png'),
      PageEntry(id: 'b', path: 'b.png', name: 'b', translatedPath: 'b_t.png'),
      PageEntry(id: 'c', path: 'c.png', name: 'c', translatedPath: 'c_t.png'),
    ], webtoon: true);
    ws.movePage(2, 1);
    final pages = container.read(workspaceProvider).pages;
    expect([for (final p in pages) p.id], ['a', 'c', 'b']);
    expect(pages[0].overflowPath, isNull);
    expect([for (final p in pages) p.translatedPath], [null, null, null]);
    expect(container.read(batchProvider), isNot(isA<BatchRunning>()));
  });
}
