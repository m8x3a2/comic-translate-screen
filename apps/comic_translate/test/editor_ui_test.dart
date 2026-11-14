// The editor in the window: steps, shortcuts, text fields, find and
// replace.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/background.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/state/pipette.dart';
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
  Future<({EmptyFrames choice, bool remember})?> confirmEmptyFrames(int count) async =>
      (choice: EmptyFrames.read, remember: false);

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

  /// The tool bar may take another row: the page moves on in the frames after.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
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

  testWidgets('Shift + click draws a straight line of the mask from the last stroke', (tester) async {
    final container = await openTranslatedPage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await settle(tester);
    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await settle(tester);
    List<MaskStroke> strokes() => container.read(workspaceProvider).currentPage!.strokes;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final rect = tester.getRect(canvas);
    Offset at(double x, double y) => rect.topLeft + Offset(rect.width * x, rect.height * y);
    final a = at(0.2, 0.3);
    await mouse.addPointer(location: a);
    Future<void> click(Offset at) async {
      await mouse.moveTo(at);
      await tester.pump();
      await mouse.down(at);
      await tester.pump();
      await mouse.up();
      await tester.pump();
    }

    // Nothing painted yet: Shift + click is an ordinary dot.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await click(a);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(strokes().single.points, hasLength(1));
    final dot = strokes().single.points.single;

    // A click without Shift: another dot, not joined.
    final b = at(0.6, 0.3);
    await click(b);
    expect(strokes(), hasLength(2));
    expect(strokes().last.points, hasLength(1));
    final second = strokes().last.points.single;
    expect(second.x, greaterThan(dot.x));

    // Shift + click: one straight stroke from the last dot.
    final c = at(0.6, 0.7);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await click(c);
    expect(strokes(), hasLength(3));
    final line = strokes().last;
    expect(line.points, hasLength(2));
    expect(line.points.first, second);
    expect(line.points.last.x, closeTo(second.x, 0.01));
    expect(line.points.last.y, greaterThan(second.y));
    expect(line.erase, isFalse);

    // The eraser draws its line from the end of the last one; the end follows the mouse while held.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await mouse.moveTo(a);
    await tester.pump();
    await mouse.down(a);
    for (var i = 0; i < 3; i++) {
      await mouse.moveBy(Offset(rect.width * 0.05, rect.height * 0.05));
      await tester.pump();
    }
    await mouse.up();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final erased = strokes().last;
    expect(erased.erase, isTrue);
    expect(erased.points, hasLength(2), reason: 'still a straight line');
    expect(erased.points.first, line.points.last);
    expect(erased.points.last.x, greaterThan(dot.x));

    // Ctrl+Z takes back one line at a time.
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(strokes(), hasLength(3));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(strokes(), hasLength(2));
  });

  testWidgets('"Fit to letters": a click fits one piece; Shift + click picks pieces for the button', (tester) async {
    final container = await openTranslatedPage(tester);
    final page = container.read(workspaceProvider).currentPage!;
    // Letters: three bars; the same again farther right.
    bool letter(int x, int y) =>
        y >= 31 && y <= 41 && ((x >= 22 && x <= 40) || (x >= 82 && x <= 100)) && (x - 22) % 8 < 3;
    final data = Uint8List(120 * 80 * 3)..fillRange(0, 120 * 80 * 3, 255);
    for (var i = 0; i < 120 * 80; i++) {
      if (letter(i % 120, i ~/ 120)) data.fillRange(i * 3, i * 3 + 3, 0);
    }
    await tester.runAsync(() => ImageCodec.writeFile(page.path, RgbImage(120, 80, data)));
    final ws = container.read(workspaceProvider.notifier)..clearMask();
    // Two rough pieces of the brush over the two words.
    ws.addStroke(const MaskStroke(points: [Point2(25, 36), Point2(37, 36)], width: 22));
    ws.addStroke(const MaskStroke(points: [Point2(85, 36), Point2(97, 36)], width: 22));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.fit);
    await settle(tester);
    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await settle(tester);
    final rect = tester.getRect(canvas);
    Offset at(double x, double y) => rect.topLeft + Offset(rect.width * x / 120, rect.height * y / 80);
    PageEntry current() => container.read(workspaceProvider).currentPage!;
    // The fitting draws the mask with dart:ui: it runs in real time.
    Future<void> fitBy(Future<void> Function() act) async {
      await tester.runAsync(() async {
        await act();
        for (var i = 0; i < 100 && !container.read(stepsProvider).running; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        for (var i = 0; i < 3000 && container.read(stepsProvider).running; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }

    Future<GrayImage> mask() async => (await tester.runAsync(() => readGrayInBackground(current().maskPath!)))!;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: at(18, 28));
    Future<void> click(Offset where) async {
      await mouse.moveTo(where);
      await tester.pump();
      await mouse.down(where);
      await tester.pump();
      await mouse.up();
      await tester.pump();
    }

    // A click on the first piece: it shrinks to its letters, the second stays.
    expect(find.text('Прижать все'), findsOneWidget);
    await fitBy(() async {
      await mouse.moveTo(at(18, 28));
      await mouse.down(at(18, 28));
      await mouse.up();
    });
    expect(current().strokes, isEmpty);
    var m = await mask();
    expect(m.data[35 * 120 + 23], 255, reason: 'a letter');
    expect(m.data[30 * 120 + 18], 0, reason: 'away from the letters');
    expect(m.data[30 * 120 + 78], 255, reason: 'the other piece as painted');

    // One undo step brings the strokes back.
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(current().strokes, hasLength(2));
    expect(current().maskPath, isNull);

    // Shift + click picks; again on the same place unpicks.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await click(at(18, 28));
    await click(at(78, 28));
    expect(find.text('Прижать (2)'), findsOneWidget);
    await click(at(18, 28));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(find.text('Прижать (1)'), findsOneWidget);
    expect(current().strokes, hasLength(2), reason: 'picking changes nothing');

    // The button fits the picked piece only.
    await fitBy(() => tester.tap(find.text('Прижать (1)')));
    m = await mask();
    expect(m.data[30 * 120 + 18], 255, reason: 'not picked: as painted');
    expect(m.data[30 * 120 + 78], 0);
    expect(m.data[35 * 120 + 83], 255);
    expect(find.text('Прижать все'), findsOneWidget, reason: 'the picks are gone');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mask view: opened by the mask tools; "mask only" on black', (tester) async {
    final container = await openTranslatedPage(tester);
    EditorState editor() => container.read(editorProvider);
    final view = find.descendant(of: find.byType(SegmentedButton<ViewMode>), matching: find.text('Маска'));
    expect(view, findsOneWidget);

    for (final (key, wanted) in [
      (LogicalKeyboardKey.keyB, ViewMode.mask),
      (LogicalKeyboardKey.keyT, ViewMode.result),
      (LogicalKeyboardKey.keyE, ViewMode.mask),
      (LogicalKeyboardKey.keyH, ViewMode.mask),
      (LogicalKeyboardKey.keyG, ViewMode.mask),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(editor().view, wanted, reason: '$key');
    }

    // "Mask only": a black page instead of the picture.
    for (var i = 0; i < 50 && find.byType(PageCanvas).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    Finder black() => find.descendant(
      of: find.byType(PageCanvas),
      matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.black),
    );
    expect(black(), findsNothing);
    await tester.tap(find.byIcon(Icons.contrast));
    await tester.pump();
    expect(editor().maskOnly, isTrue);
    expect(black(), findsOneWidget);

    // The text tool has nothing to edit in the mask view; the translation view shows it again.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.tap(view);
    await tester.pump();
    expect(editor().tool, EditorTool.pan);
    await tester.tap(find.text('Перевод'));
    await tester.pump();
    expect(find.byIcon(Icons.contrast), findsNothing);
    expect(black(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mask pipette: clicked colours join the mask, one undo step; Auto / Off are the setting', (
    tester,
  ) async {
    final container = await openTranslatedPage(tester);
    final page = container.read(workspaceProvider).currentPage!;
    // Orange paper, dark red letters on the left, black drawing on the right.
    bool red(int x, int y) => y >= 30 && y < 50 && x >= 20 && x < 50 && x % 6 < 2;
    bool black(int x, int y) => y >= 30 && y < 50 && x >= 70 && x < 100 && x % 6 < 2;
    final data = Uint8List(120 * 80 * 3);
    for (var i = 0; i < 120 * 80; i++) {
      final x = i % 120, y = i ~/ 120;
      data.setAll(i * 3, red(x, y) ? [150, 20, 20] : (black(x, y) ? [0, 0, 0] : [240, 160, 60]));
    }
    await tester.runAsync(() => ImageCodec.writeFile(page.path, RgbImage(120, 80, data)));
    container.read(workspaceProvider.notifier)
      ..clearMask()
      ..deleteAllBlocks();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.pick);
    expect(container.read(editorProvider).view, ViewMode.mask);
    expect(find.text('вся страница'), findsOneWidget, reason: 'no boxes: the whole page');
    expect(find.text('Щёлкните по букве'), findsOneWidget);
    // Where to look: a menu at the label; letters in the boxes by default.
    expect(container.read(pipetteProvider).scope, PipetteScope.letters);
    await tester.tap(find.text('вся страница'));
    await tester.pumpAndSettle();
    expect(find.text('Буквы в рамках'), findsOneWidget);
    await tester.tap(find.text('Всё в рамках').last);
    await tester.pumpAndSettle();
    expect(container.read(pipetteProvider).scope, PipetteScope.boxes);

    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await settle(tester);
    final rect = tester.getRect(canvas);
    Offset at(double x, double y) => rect.topLeft + Offset(rect.width * x / 120, rect.height * y / 80);
    PageEntry current() => container.read(workspaceProvider).currentPage!;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: at(1, 1));
    // The pipette reads the page and writes the mask in real time.
    Future<void> settled(Future<void> Function() act) async {
      final before = current().maskPath;
      await tester.runAsync(() async {
        await act();
        for (var i = 0; i < 500 && (current().maskPath == before || container.read(pipetteProvider).busy); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }

    Future<void> click(double x, double y) => settled(() async {
      await mouse.moveTo(at(x, y));
      await mouse.down(at(x, y));
      await mouse.up();
    });
    Future<GrayImage> mask() async => (await tester.runAsync(() => readGrayInBackground(current().maskPath!)))!;
    int count(GrayImage m, bool Function(int x, int y) where) {
      var n = 0;
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 120; x++) {
          if (where(x, y) && m.data[y * 120 + x] != 0) n++;
        }
      }
      return n;
    }

    // A click on a red letter: the red letters, not the black drawing.
    await click(24.5, 40);
    var m = await mask();
    expect(count(m, red), 5 * 2 * 20);
    expect(count(m, black), 0);
    expect(find.byTooltip('#961414 — щелчок убирает этот цвет'), findsOneWidget);
    expect(tester.getRect(canvas), rect, reason: 'the page stays under the mouse');

    // Black too: one more colour.
    await click(72.5, 40);
    m = await mask();
    expect(count(m, black), 5 * 2 * 20);

    // The cross on the red colour takes it away again.
    await settled(() => tester.tap(find.byTooltip('#961414 — щелчок убирает этот цвет')));
    m = await mask();
    expect(count(m, red), 0);
    expect(count(m, black), 5 * 2 * 20);

    // A wider margin around the letters: the mask grows, on the same letters.
    expect(find.text('1 px'), findsOneWidget);
    bool anywhere(int x, int y) => true;
    final narrow = count(m, anywhere);
    await settled(() async => container.read(pipetteProvider.notifier).setMargin(3));
    expect(find.text('3 px'), findsOneWidget);
    m = await mask();
    expect(count(m, anywhere), greaterThan(narrow));
    expect(count(m, red), 0);
    // Bars at x 72–97 (two wide, four apart), rows 30–49, grown by 3 px:
    // x 69–100, rows 27–52, the gaps closed.
    expect(count(m, (x, y) => y >= 27 && y < 53 && x >= 69 && x <= 100), 26 * 32);
    expect(count(m, anywhere), 26 * 32);

    // The whole go of the pipette is one undo step.
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(current().maskPath, isNull);
    expect(find.text('Щёлкните по букве'), findsOneWidget, reason: 'the colours go with it');

    // Off: the setting, and back to the brush.
    await tester.tap(find.text('Выкл'));
    await tester.pump();
    expect(container.read(settingsProvider).colourLetters, isFalse);
    expect(container.read(editorProvider).tool, EditorTool.brush);
    expect(find.text('Авто'), findsNothing, reason: 'the switch is the pipette\'s');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    await tester.tap(find.text('Авто'));
    await tester.pump();
    expect(container.read(settingsProvider).colourLetters, isTrue);
    expect(tester.takeException(), isNull);
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

  testWidgets('a bubble without a translation is marked until one is typed', (tester) async {
    final container = await openTranslatedPage(tester);
    final ws = container.read(workspaceProvider.notifier);
    ws.changeBlock(0, (b) {
      b.translation = '';
      b.untranslated = true;
    });
    await tester.pump();
    expect(find.text('нет перевода'), findsOneWidget);
    ws.selectBlock(0);
    await tester.pump();
    expect(find.textContaining('В ответе переводчика для этого пузыря ничего не было'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Перевод'), 'Привет');
    await tester.pump();
    expect(container.read(workspaceProvider).currentPage!.blocks.single.untranslated, isFalse);
    ws.selectBlock(null);
    await tester.pump();
    expect(find.text('нет перевода'), findsNothing);
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
    // The step button (the view "Маска" has the same word).
    final maskStep = find.byIcon(Icons.layers_outlined);
    expect(maskStep, findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(maskStep);
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
    expect(container.read(editorProvider).view, ViewMode.mask, reason: 'the mask is shown to correct it');
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

  testWidgets('"Suggest a font" opens the fonts, or tells why it cannot', (tester) async {
    final container = await openTranslatedPage(tester);
    final block = container.read(workspaceProvider).currentPage!.blocks.single;
    await tester.tap(find.textContaining('[ru] HELLO'));
    await tester.pump();
    // The bubble's look is open from the start.
    Future<void> suggest() async {
      await tester.ensureVisible(find.byTooltip('Подобрать шрифт…'));
      await tester.tap(find.byTooltip('Подобрать шрифт…'));
      await tester.pump();
    }

    // The letters were never measured.
    await suggest();
    expect(find.textContaining('не измерены'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(TextPanel))).removeCurrentSnackBar();
    await tester.pump();

    // Too small to measure the strokes: the size is said.
    block.sourceStyle = const SourceStyle(letterPx: 6, inkWidthPx: 40);
    await suggest();
    expect(find.textContaining('около 6 точек, а нужно хотя бы 10'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(TextPanel))).removeCurrentSnackBar();
    await tester.pump();

    // Measured: the original is cut out in another isolate (the window's
    // state cannot go there) and the fonts are ranked.
    block.sourceStyle = const SourceStyle(letterPx: 14, strokePx: 2.5, inkWidthPx: 50);
    await suggest();
    expect(find.text('Похожие шрифты'), findsOneWidget);
    final crop = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Image));
    for (var i = 0; i < 200 && (find.byType(Card).evaluate().isEmpty || crop.evaluate().isEmpty); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.byType(Card), findsWidgets);
    expect(crop, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// The translated page with three bubbles: «Один», «Два», «Три».
  Future<ProviderContainer> openThreeBubbles(WidgetTester tester) async {
    final container = await openTranslatedPage(tester);
    final page = container.read(workspaceProvider).currentPage!;
    final first = page.blocks.single;
    container
        .read(workspaceProvider.notifier)
        .edit(
          page.id,
          (p) => p.copyWith(
            blocks: [
              for (final (k, word) in ['Один', 'Два', 'Три'].indexed)
                first.copy()
                  ..xyxy = BBox(4 + 38 * k, 10, 36 + 38 * k, 40)
                  ..translation = word,
            ],
          ),
        );
    await tester.pump();
    return container;
  }

  /// Scrolls the text panel to the card with [word] (an open card may push
  /// it out of sight) and clicks it, holding [key] when given.
  Future<void> clickCard(WidgetTester tester, String word, [LogicalKeyboardKey? key]) async {
    final list = find.descendant(of: find.byType(TextPanel), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text(word), 120, scrollable: list);
    await tester.pump();
    if (key != null) await tester.sendKeyDownEvent(key);
    await tester.tap(find.text(word));
    if (key != null) await tester.sendKeyUpEvent(key);
    await tester.pump();
  }

  testWidgets('Ctrl / Shift + click picks bubbles; their look and speaker change together', (tester) async {
    final container = await openThreeBubbles(tester);
    WorkspaceState ws() => container.read(workspaceProvider);
    List<TextBlock> blocks() => ws().currentPage!.blocks;
    container.read(workspaceProvider.notifier).selectBlock(0);
    await tester.pump();

    // Ctrl + click on the third card: the first and the third.
    await clickCard(tester, 'Три', LogicalKeyboardKey.controlLeft);
    expect(ws().blockSelection, [0, 2]);
    expect(ws().selectedBlock, 2);
    expect(find.text('Выбрано пузырей: 2 (1, 3)'), findsOneWidget);
    // Shift + click on the second: everything from the third to it.
    await clickCard(tester, 'Два', LogicalKeyboardKey.shiftLeft);
    expect(ws().blockSelection, [0, 1, 2]);
    expect(find.text('Выбрано пузырей: 3 (1, 2, 3)'), findsOneWidget);

    // Bold for all three as one undo step.
    final bold = find.byTooltip('Жирный');
    await tester.ensureVisible(bold);
    await tester.pump();
    await tester.tap(bold);
    await tester.pump();
    expect([for (final b in blocks()) b.style?.bold], [true, true, true]);
    container.read(workspaceProvider.notifier).undo();
    expect([for (final b in blocks()) b.style?.bold], [null, null, null]);

    // Who speaks: mixed shows no choice; a click sets it for all.
    container.read(workspaceProvider.notifier).changeBlock(1, (b) => b.speaker = Speaker.male);
    container.read(workspaceProvider.notifier).pickAllBlocks();
    await tester.pump();
    final female = find.descendant(of: find.byType(SegmentedButton<Speaker?>), matching: find.text('Ж'));
    await tester.ensureVisible(female);
    await tester.pump();
    await tester.tap(female);
    await tester.pump();
    expect([for (final b in blocks()) b.speaker], [Speaker.female, Speaker.female, Speaker.female]);

    // Ctrl + click on a picked card takes it out; one left is a plain selection.
    await clickCard(tester, 'Два', LogicalKeyboardKey.controlLeft);
    expect(ws().blockSelection, [0, 2]);
    container.read(workspaceProvider.notifier).pickBlock(0);
    expect(ws().pickedBlocks, isEmpty);
    expect(ws().blockSelection, [2]);

    // Delete takes all the picked boxes, Ctrl+Z brings them back.
    container.read(workspaceProvider.notifier).pickAllBlocks();
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(blocks(), isEmpty);
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(blocks().length, 3);
    expect(ws().pickedBlocks, isEmpty);
  });

  testWidgets('"Apply to others": the ticked parts of one bubble\'s look go to the page', (tester) async {
    final container = await openThreeBubbles(tester);
    final ws = container.read(workspaceProvider.notifier);
    List<TextBlock> blocks() => container.read(workspaceProvider).currentPage!.blocks;
    ws.styleBlock(1, (s) => s.copyWith(fontSizePt: 7, italic: true));
    ws.styleBlock(0, (s) => s.copyWith(color: 0xFFD32F2F, bold: true, fontSizePt: 30, angle: 10.0));
    ws.selectBlock(0);
    await tester.pump();
    final apply = find.text('Применить к другим…');
    await tester.ensureVisible(apply);
    await tester.pump();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.text('Оформление пузыря 1 — другим пузырям'), findsOneWidget);
    expect(find.text('Все пузыри этой страницы (3)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Применить'));
    await tester.pumpAndSettle();
    final b = blocks();
    // The look went, the size and the turn stayed each bubble's own.
    expect(
      [for (final x in b.skip(1)) (x.style?.color, x.style?.bold, x.style?.italic)],
      [(0xFFD32F2F, true, null), (0xFFD32F2F, true, null)],
    );
    expect((b[1].style?.fontSizePt, b[1].style?.angle, b[2].style?.fontSizePt), (7, null, null));
    expect(b[0].style?.fontSizePt, 30);
    expect(find.textContaining('Оформление изменено у пузырей: 2'), findsOneWidget);
  });

  testWidgets('on the page: Ctrl + click picks boxes, a picked box drags the others along', (tester) async {
    final container = await openThreeBubbles(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(container.read(editorProvider).tool, EditorTool.boxes);
    await settle(tester);
    final canvas = find.byType(PageCanvas);
    for (var i = 0; i < 50 && canvas.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await settle(tester);
    final rect = tester.getRect(canvas);
    Offset at(double x, double y) => rect.topLeft + Offset(rect.width * x / 120, rect.height * y / 80);
    WorkspaceState ws() => container.read(workspaceProvider);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: at(2, 70));
    Future<void> click(Offset where, [LogicalKeyboardKey? key]) async {
      if (key != null) await tester.sendKeyDownEvent(key);
      await mouse.moveTo(where);
      await tester.pump();
      await mouse.down(where);
      await tester.pump();
      await mouse.up();
      if (key != null) await tester.sendKeyUpEvent(key);
      await tester.pump();
    }

    await click(at(20, 25));
    expect(ws().selectedBlock, 0);
    await click(at(96, 25), LogicalKeyboardKey.controlLeft);
    expect(ws().blockSelection, [0, 2]);
    // A plain click on a picked box keeps the picks; dragging it moves both.
    final start = at(96, 25);
    await mouse.moveTo(start);
    await mouse.down(start);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await mouse.moveBy(Offset(0, rect.height * 2.5 / 80));
      await tester.pump();
    }
    await mouse.up();
    await tester.pump();
    final boxes = [for (final b in ws().currentPage!.blocks) b.xyxy];
    expect([boxes[0].y1, boxes[1].y1, boxes[2].y1], [20, 10, 20]);
    expect(ws().blockSelection, [0, 2]);
    // One undo step for the move.
    container.read(workspaceProvider.notifier).undo();
    expect([for (final b in ws().currentPage!.blocks) b.xyxy.y1], [10, 10, 10]);
    // Esc drops the picks.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(ws().blockSelection, isEmpty);
  });
}
