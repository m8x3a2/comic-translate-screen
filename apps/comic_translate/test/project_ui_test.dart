// Projects in the window: recent projects, asking before unsaved work goes.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/project.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
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
    dir = Directory.systemTemp.createTempSync('cts_project_ui_test_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: fakeRegistry());
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  Future<ProviderContainer> start(WidgetTester tester, AppSettings settings) async {
    tester.view.physicalSize = const Size(1400, 900);
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
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('the start screen lists recent projects; missing ones can be removed', (tester) async {
    final saved = p.join(dir.path, 'Глава 1.ctsproj');
    await tester.runAsync(() async {
      final image = p.join(dir.path, 'a.png');
      await ImageCodec.writeFile(image, RgbImage.filled(20, 20, 255, 255, 255));
      ProjectFile.save(saved, ProjectData(pages: [ProjectPage(id: '0', name: 'a.png', image: image)]));
    });
    final container = await start(
      tester,
      fakeSettings()..recentProjects.addAll([saved, p.join(dir.path, 'gone.ctsproj')]),
    );
    expect(find.text('Недавние проекты'), findsOneWidget);
    expect(find.text('Глава 1'), findsOneWidget);
    expect(find.textContaining('Файл не найден'), findsOneWidget);
    expect(find.text('Открыть проект…'), findsOneWidget);

    await tester.tap(find.byTooltip('Убрать из списка').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).recentProjects, [saved]);
  });

  testWidgets('closing unsaved pages asks first; "Don\'t save" closes them', (tester) async {
    final container = await start(tester, fakeSettings());
    await tester.runAsync(() async {
      final image = p.join(dir.path, 'a.png');
      await ImageCodec.writeFile(image, RgbImage.filled(20, 20, 255, 255, 255));
      await container.read(workspaceProvider.notifier).addInputs([image]);
    });
    await tester.pumpAndSettle();
    expect(container.read(projectProvider).dirty, isTrue);
    expect(find.textContaining('Ещё не сохранено в проект'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрыть все страницы'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить изменения?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).pages, hasLength(1));

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрыть все страницы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не сохранять'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).pages, isEmpty);
    expect(container.read(projectProvider).dirty, isFalse);
  });
}
