// The models screen: groups, explanations, several models at once.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/common/info_hint.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

void main() {
  late Directory dir;
  late AppServices services;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_models_ui_test_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: fakeRegistry());
  });
  tearDown(() async {
    await services.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('an "i" explains a setting on click, without changing it', (tester) async {
    await openSettings(tester);
    final testMode = find.widgetWithText(SwitchListTile, 'Режим тестирования');
    final hint = find.descendant(of: testMode, matching: find.byType(InfoHint));
    await tester.tap(hint);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Повторите то же действие'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(testMode).value, isFalse, reason: 'the switch stays as it was');
    await tester.pump(const Duration(seconds: 20));

    await tester.tap(find.widgetWithText(ListTile, 'Распознавание и очистка'));
    await tester.pumpAndSettle();
    expect(find.text('Как очищать большие страницы'), findsOneWidget);
    expect(find.byType(InfoHint), findsAtLeastNWidgets(3), reason: 'confidence, small text, large pages, size');
  });

  testWidgets('models are grouped, explained, and can be downloaded together', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Модели'));
    await tester.pumpAndSettle();
    // The status of each model is read from the disk.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    for (final group in ['Основные (нужны всегда)', 'Распознавание текста по языкам', 'Дополнительно']) {
      expect(find.text(group), findsOneWidget);
    }
    expect(find.text('Японский (manga-ocr)'), findsOneWidget);
    expect(find.text('Определение языка'), findsNothing, reason: 'not used yet');
    expect(find.byType(InfoHint), findsNWidgets(ModelCatalog.all.length - 1));
    expect(find.text('Скачано 0 из ${ModelCatalog.all.length - 1} · 0 B на диске'), findsOneWidget);

    // "Download all" shows what comes from where first; nothing starts on Cancel.
    await tester.tap(find.text('Скачать все'));
    await tester.pumpAndSettle();
    expect(find.text('Скачать модели?'), findsOneWidget);
    expect(find.text('Очистка текста, качественнее (LaMa)'), findsNWidgets(2));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
