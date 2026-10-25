// The editor in the window: steps, shortcuts, text fields, find and
// replace.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/shell_full/page_canvas.dart';
import 'package:comic_translate/ui/shell_full/run_editor.dart';
import 'package:comic_translate/ui/shell_full/text_panel.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

class _YesUi implements BatchUi {
  @override
  Future<bool> exchange(ExchangeRequest request) async => false;

  final errors = <Object>[];

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

  /// Pages changed by hand: what to answer.
  HandEditedChoice handEdited = HandEditedChoice.translate;
  int handEditedAsked = 0;

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async {
    handEditedAsked = count;
    return handEdited;
  }
}

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_editor_ui_test_');
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

  testWidgets('with Ctrl or Space held, the left button moves the page in any tool', (tester) async {
    final container = await openTranslatedPage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    // The page image is decoded for real before the canvas appears.
    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    Matrix4 view() => tester.widget<PageCanvas>(canvas).transform.value.clone();
    int boxes() => container.read(workspaceProvider).currentPage!.blocks.length;
    Offset start() => tester.getCenter(canvas) + const Offset(20, 10);
    // The mouse is over the page (Space is taken only there).
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: start());
    await mouse.moveTo(start());
    await tester.pump();
    Future<void> drag() async {
      final at = start();
      await mouse.moveTo(at);
      await tester.pump();
      await mouse.down(at);
      for (var i = 0; i < 4; i++) {
        await mouse.moveBy(const Offset(40, 24));
        await tester.pump();
      }
      await mouse.up();
      await tester.pump();
    }

    for (final key in [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.space]) {
      final before = view();
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      await drag();
      await tester.sendKeyUpEvent(key);
      await tester.pump();
      expect(boxes(), 1, reason: '$key: no box is drawn');
      expect(view().getTranslation().x - before.getTranslation().x, closeTo(160, 1), reason: '$key moves the page');
    }

    // Without the key the tool works again: a box is drawn, the page stays.
    final before = view();
    await drag();
    expect(view(), before);
    expect(boxes(), 2);
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

  testWidgets('a selected word gets a look of its own; it moves with the text typed before it', (tester) async {
    final container = await openTranslatedPage(tester);
    final ws = container.read(workspaceProvider.notifier);
    ws.selectBlock(0);
    await tester.pump();
    final field = find.widgetWithText(TextField, 'Перевод');
    final controller = tester.widget<TextField>(field).controller!;
    final text = controller.text;
    expect(find.byIcon(Icons.format_bold), findsOneWidget, reason: 'the look of the whole bubble only');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();
    final bold = find.descendant(of: find.byType(RunBar), matching: find.byTooltip('Жирный'));
    await tester.ensureVisible(bold);
    await tester.pump();
    await tester.tap(bold);
    await tester.pump();
    List<StyledRun>? runs() => container.read(workspaceProvider).currentPage!.blocks.single.style?.runs;
    expect(runs(), [const StyledRun(0, 4, RunStyle(bold: true))]);
    await tester.enterText(field, 'Ну $text');
    await tester.pump();
    expect(runs(), [const StyledRun(3, 7, RunStyle(bold: true))]);
    // Drawn: the word in bold, the marks never shown as text.
    expect(container.read(workspaceProvider).currentPage!.blocks.single.translation, 'Ну $text');
  });

  testWidgets('who speaks is set in the card of the bubble and shown when it is closed', (tester) async {
    final container = await openTranslatedPage(tester);
    final ws = container.read(workspaceProvider.notifier);
    ws.selectBlock(0);
    await tester.pump();
    Speaker? speaker() => container.read(workspaceProvider).currentPage!.blocks.single.speaker;
    expect(find.text('Кто говорит'), findsOneWidget);
    await tester.ensureVisible(find.text('Ж'));
    await tester.pump();
    await tester.tap(find.text('Ж'));
    await tester.pump();
    expect(speaker(), Speaker.female);
    ws.selectBlock(null);
    await tester.pump();
    expect(find.text('Ж'), findsOneWidget, reason: 'the closed card shows it');
    ws.selectBlock(0);
    await tester.pump();
    await tester.ensureVisible(find.text('—'));
    await tester.pump();
    await tester.tap(find.text('—'));
    await tester.pump();
    expect(speaker(), isNull);
  });

  testWidgets('the look menu: capitals for the page, back to the automatic look', (tester) async {
    final container = await openTranslatedPage(tester);
    await tester.tap(find.byTooltip('Оформление текста'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ЗАГЛАВНЫЕ ↔ обычные'));
    await tester.pumpAndSettle();
    final block = container.read(workspaceProvider).currentPage!.blocks.single;
    expect(block.style?.upperCase, isNotNull);
    await tester.tap(find.byTooltip('Оформление текста'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Сбросить оформление'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).currentPage!.blocks.single.style, isNull);
  });

  testWidgets('glued words are split by the button, very small text is pointed out', (tester) async {
    final container = await openTranslatedPage(tester);
    final ws = container.read(workspaceProvider.notifier);
    ws.changeBlock(0, (b) => b..text = 'THIS ISREALLIFE');
    await tester.pump();
    expect(find.textContaining('Очень мелкий текст'), findsNothing);
    ws.changeBlock(0, (b) => b.linePx = 11);
    await tester.pump();
    expect(find.textContaining('строки около 11 точек'), findsOneWidget);
    expect(find.textContaining('Включите уровень «Высокий»'), findsOneWidget, reason: 'advice, not only a warning');
    container.read(settingsProvider.notifier).change((s) => s.textPrep = 'fatality_comix');
    await tester.pump();
    expect(find.textContaining('Сделайте снимок крупнее'), findsOneWidget, reason: 'the highest level is on already');

    final split = find.byWidgetPredicate(
      (w) => w is IconButton && (w.tooltip ?? '').startsWith('Разделить слипшиеся слова на этой странице'),
    );
    expect(tester.widget<IconButton>(split).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(split);
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    await tester.pump();
    expect(container.read(workspaceProvider).currentPage!.blocks.single.text, 'THIS IS REAL LIFE');
    expect(find.textContaining('Разделено слов: 1'), findsOneWidget);
    ws.undo();
    expect(container.read(workspaceProvider).currentPage!.blocks.single.text, 'THIS ISREALLIFE');
  });

  testWidgets('the editor shows how much the page is enlarged for drawing', (tester) async {
    final container = await openTranslatedPage(tester);
    container.read(settingsProvider.notifier).change((s) => s.upscale = s.upscale.copyWith(mode: UpscaleMode.off));
    await tester.pump();
    expect(find.textContaining('×'), findsNothing);

    container.read(settingsProvider.notifier).change((s) => s.upscale = s.upscale.copyWith(mode: UpscaleMode.x2));
    await tester.pump();
    expect(find.text('×2'), findsOneWidget);
    expect(find.byTooltip('Увеличена ×2 для чёткого текста'), findsOneWidget);
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

  testWidgets('in the smallest window the note about picked pages stays in sight', (tester) async {
    final container = await openTranslatedPage(tester);
    tester.view.physicalSize = const Size(1024, 640);
    final second = p.join(dir.path, 'second.png');
    await tester.runAsync(() => ImageCodec.writeFile(second, RgbImage.filled(120, 80, 255, 255, 255)));
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs([second]));
    container.read(workspaceProvider.notifier).select(1, toggle: true);
    await tester.pump();

    final note = find.text('для выбранных страниц: 2');
    expect(note, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(note).didExceedMaxLines, isFalse, reason: 'not cut short');
    expect(tester.getRect(note).right, lessThanOrEqualTo(tester.getRect(find.byType(TextPanel)).left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page taken away while the mouse button is down is no error', (tester) async {
    final container = await openTranslatedPage(tester);
    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: tester.getCenter(canvas));
    await mouse.down(tester.getCenter(canvas));
    await tester.pump();
    // The page goes (another page opened, pages removed) while the button is held.
    container.read(workspaceProvider.notifier).remove(container.read(workspaceProvider).currentPage!.id);
    await tester.pump();
    await mouse.cancel();
    await mouse.removePointer();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
