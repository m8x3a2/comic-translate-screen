// The editor in the window: steps, shortcuts, text fields, find and
// replace.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

class _YesUi implements BatchUi {
  final errors = <Object>[];

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async {}

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async => true;

  @override
  Future<NetworkChoice> confirmNetwork(PluginInfo translator, PluginEndpoint endpoint, {required bool sendsImage}) async =>
      NetworkChoice.once;

  @override
  void showError(Object error) => errors.add(error);
}

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_editor_ui_test_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: fakeRegistry());
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Images shown by the widgets may still be open; the folder is in temp.
    }
  });

  Future<ProviderContainer> openTranslatedPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = p.join(dir.path, 'page.png');
    await tester.runAsync(() => ImageCodec.writeFile(page, RgbImage.filled(120, 80, 255, 255, 255)));
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
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([page]));
    await tester.pump();
    await tester.runAsync(() => container.read(stepsProvider.notifier).run(ManualStep.translate, _YesUi()));
    await tester.pump();
    return container;
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('tool keys work, except while typing in a field', (tester) async {
    final container = await openTranslatedPage(tester);
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, contains('HELLO'));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.brush);

    // Selecting a block opens its fields; the keys still switch tools.
    await tester.tap(find.textContaining('[ru] HELLO'));
    await tester.pump();
    expect(container.read(workspaceProvider).selectedBlock, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.text);

    // Typing a translation: letters go into the field.
    final field = find.widgetWithText(TextField, 'Перевод');
    await tester.showKeyboard(field);
    await tester.enterText(field, 'Привет');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.text, reason: 'b is typed, not a tool');
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, 'Привет');

    // Leave the field: Delete removes the box, Ctrl+Z brings it back.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(container.read(workspaceProvider).currentPage!.blocks, isEmpty);
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, 'Привет');
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, contains('HELLO'));
    await ctrl(tester, LogicalKeyboardKey.keyY);
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, 'Привет');
  });

  testWidgets('F1 lists the keyboard shortcuts', (tester) async {
    await openTranslatedPage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.text('Горячие клавиши'), findsOneWidget);
    expect(find.text('Ctrl+Z'), findsOneWidget);
    expect(find.text('F11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('find and replace in the translations', (tester) async {
    final container = await openTranslatedPage(tester);
    await ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.pump();
    final find_ = find.widgetWithText(TextField, 'Найти');
    expect(find_, findsOneWidget);
    await tester.enterText(find_, 'hello');
    await tester.pump();
    expect(find.textContaining('Найдено: 1'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Заменить на'), 'мир');
    await tester.tap(find.text('Заменить все'));
    await tester.pump();
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, '[ru] мир');
    expect(find.textContaining('Заменено: 1'), findsOneWidget);
    // In the find field Ctrl+Z undoes typing; outside it, the page.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, contains('HELLO'));
  });

  testWidgets('the step buttons run on the current page', (tester) async {
    final container = await openTranslatedPage(tester);
    container.read(workspaceProvider.notifier).clearMask();
    await tester.pump();
    expect(find.text('Маска'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Маска'));
      for (var i = 0; i < 100 && !container.read(stepsProvider).running; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      for (var i = 0; i < 500 && container.read(stepsProvider).running; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(container.read(workspaceProvider).currentPage!.maskPath, isNotNull);
    expect(container.read(editorProvider).tool, EditorTool.brush);
    expect(tester.takeException(), isNull);
  });
}
