// The webtoon strip in the window: pages one below the other, the current
// page follows the scrolling, a click picks the page to edit, the mode is
// kept in the project.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/state/project.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/shell_full/page_canvas.dart';
import 'package:comic_translate/ui/shell_full/webtoon_strip.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_webtoon_ui_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
  });

  tearDown(() async {
    await services.settingsStore.flush();
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Images shown by the widgets may still be open; the folder is in temp.
    }
  });

  test('the strip centres pages on each other and finds the page at a height', () {
    final layout = StripLayout.of(const [Size(100, 300), Size(80, 200), Size(100, 100)]);
    expect(layout.rects, [
      const Rect.fromLTWH(0, 0, 100, 300),
      const Rect.fromLTWH(10, 300, 80, 200),
      const Rect.fromLTWH(0, 500, 100, 100),
    ]);
    expect((layout.width, layout.height), (100, 600));
    expect(
      [
        for (final y in [-5.0, 0.0, 299.0, 300.0, 550.0, 900.0]) layout.pageAt(y),
      ],
      [0, 0, 0, 1, 2, 2],
    );
  });

  testWidgets('pages as one strip: the wheel scrolls, the page in the middle is current', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final files = [for (var i = 0; i < 5; i++) p.join(dir.path, 'p$i.png')];
    await tester.runAsync(() async {
      for (final f in files) {
        await ImageCodec.writeFile(f, RgbImage.filled(800, 400, 255, 255, 255));
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
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs(files));
    await tester.pump();

    await tester.tap(find.text('Вебтун'));
    // Page sizes are read from the files.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(container.read(workspaceProvider).webtoon, isTrue);
    expect(find.byType(WebtoonStrip), findsOneWidget);
    // Fitted to the width: the first page and a half show; the pages within
    // a screen below are ready, those further down are not built.
    expect(find.byType(PageCanvas), findsNWidgets(4));
    expect(container.read(workspaceProvider).current, 0);

    final strip = tester.getCenter(find.byType(WebtoonStrip));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(strip));
    for (var i = 0; i < 12; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    }
    await tester.pump();
    final after = container.read(workspaceProvider).current;
    expect(after, greaterThan(0), reason: 'scrolled down past the first page');

    // A click in the page list scrolls the strip to that page.
    container.read(workspaceProvider.notifier).select(3);
    await tester.pump();
    await tester.pump();
    expect(container.read(workspaceProvider).current, 3);
    expect(find.byKey(ValueKey(container.read(workspaceProvider).pages[3].id)), findsOneWidget);

    // Drawing a box on the page above the current one makes it current.
    container.read(editorProvider.notifier).setTool(EditorTool.boxes);
    container.read(workspaceProvider.notifier).select(1);
    await tester.pump();
    await tester.pump();
    final second = find.byKey(ValueKey(container.read(workspaceProvider).pages[1].id));
    final third = find.byKey(ValueKey(container.read(workspaceProvider).pages[2].id));
    expect(third, findsOneWidget);
    final at = tester.getTopLeft(third) + const Offset(150, 40);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(at);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    final ws = container.read(workspaceProvider);
    expect(ws.current, 2);
    expect(ws.pages[2].blocks, hasLength(1));
    expect(ws.pages[1].blocks, isEmpty);
    expect(second, findsOneWidget);

    // Ctrl + wheel zooms.
    final before = tester.getSize(third).width;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(tester.getSize(third).width, before, reason: 'layout size is in page pixels');
    final shown = tester.getRect(third);
    expect(shown.width, isNot(closeTo(before, 1)), reason: 'but drawn larger on screen');

    // The mode is kept in the project file.
    final data = projectDataOf(container.read(workspaceProvider));
    expect(data.state['webtoon'], isTrue);
    await tester.tap(find.text('Вебтун'));
    await tester.pump();
    expect(find.byType(WebtoonStrip), findsNothing);
  });
}
