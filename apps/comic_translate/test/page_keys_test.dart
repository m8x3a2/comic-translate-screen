// The arrow keys and Page Up / Page Down go through the pages; the list of
// pages follows the current page.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/common/key_bindings.dart';
import 'package:ct_core/ct_core.dart';
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
    dir = Directory.systemTemp.createTempSync('cts_page_keys_test_');
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

  test('the arrows go through the pages by default, as Page Up / Page Down', () {
    final keys = KeyBindings.of(AppSettings());
    expect(keys.actionOf(const KeyCombo(LogicalKeyboardKey.arrowDown)), ShortcutAction.nextPage);
    expect(keys.actionOf(const KeyCombo(LogicalKeyboardKey.arrowUp)), ShortcutAction.previousPage);
    expect(keys.labelOf(ShortcutAction.nextPage), 'PageDown, ↓');
    // Settings written before the arrows had their own names.
    expect(KeyCombo.parse('Arrow Down'), const KeyCombo(LogicalKeyboardKey.arrowDown));
    expect(KeyCombo.parse('↓'), const KeyCombo(LogicalKeyboardKey.arrowDown));
  });

  testWidgets('the arrows change the page, and the list scrolls to it', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pages = [for (var i = 0; i < 20; i++) p.join(dir.path, 'page_${i.toString().padLeft(2, '0')}.png')];
    await tester.runAsync(() async {
      for (final page in pages) {
        await ImageCodec.writeFile(page, RgbImage.filled(60, 80, 255, 255, 255));
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
    await tester.runAsync(() => container.read(workspaceProvider.notifier).addInputs(pages));
    await tester.pump();
    expect(container.read(workspaceProvider).current, 0);

    ScrollPosition list() => tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(ReorderableListView), matching: find.byType(Scrollable)).first,
        )
        .position;
    expect(list().pixels, 0);

    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).current, 15, reason: 'one page a press, from the first one');
    final pos = list();
    const tile = 92.0;
    expect(pos.pixels, greaterThan(0));
    expect(6 + 16 * tile, lessThanOrEqualTo(pos.pixels + pos.viewportDimension + 0.5), reason: 'page 16 is in sight');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).current, 13);

    // Back to the first page: the list goes back to its top.
    container.read(workspaceProvider.notifier).select(0);
    await tester.pumpAndSettle();
    expect(list().pixels, 0);
  });
}
