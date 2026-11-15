// The search through the settings: found by words, gone to, lit.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/settings/settings_search.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

void main() {
  group('matching', () {
    test('a long word matches without its ending; "ё" is "е"', () {
      expect(queryStems('Переводы'), ['перево']);
      expect(queryStems('шрифт ёж'), ['шриф', 'еж']);
    });

    test('the matched beginnings are bold', () {
      const bold = TextStyle(fontWeight: FontWeight.bold);
      final spans = highlightSpans('Автосохранение проекта', queryStems('проект'), bold);
      expect(spans.map((s) => s.text).join(), 'Автосохранение проекта');
      expect(spans.where((s) => s.style == bold).map((s) => s.text), ['прое']);
    });

    test('a long text is cut around the words found', () {
      final text = '${'слово ' * 60}находка ${'конец ' * 30}';
      final piece = snippetOf(text, queryStems('находка'));
      expect(piece, contains('находка'));
      expect(piece.length, lessThan(160));
      expect(piece, startsWith('…'));
    });
  });

  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_settings_search_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    services.appLog.info('test_start');
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  Future<void> search(WidgetTester tester, String words) async {
    await tester.enterText(find.byKey(const ValueKey('settings-search')), words);
    await tester.pump();
    // Gathered from the sections built out of sight after a frame.
    await tester.pump();
    await tester.pump();
  }

  Finder hits(String section) => find.byWidgetPredicate(
    (w) => w is ListTile && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('hit/$section/'),
  );

  testWidgets('words find settings in every section; a click opens the setting, Esc clears', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    // Go to another section first: the setting is in "General".
    await tester.tap(find.widgetWithText(ListTile, 'Клавиши'));
    await tester.pumpAndSettle();

    // By the beginnings of words, in any order.
    await search(tester, 'проект автосохр');
    expect(hits('general'), findsWidgets);
    expect(find.textContaining('Найдено:'), findsOneWidget);
    // The keys: found by what they do.
    await search(tester, 'вставить страницы');
    expect(hits('keys'), findsWidgets);
    // Icon buttons are named by their tooltips, not by the letter of the icon.
    await search(tester, 'шрифт');
    final icons = RegExp('[-]');
    final names = [
      for (final w in tester.widgetList<ListTile>(hits('text'))) ((w.title! as Text).textSpan!.toPlainText()),
    ];
    expect(names, isNotEmpty);
    expect(names.where(icons.hasMatch), isEmpty);
    // Nothing; Enter keeps the words to be changed.
    await search(tester, 'щщщзз');
    expect(find.textContaining('Ничего не нашлось'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final field = find.byKey(const ValueKey('settings-search'));
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    // Ctrl+F finds the field wherever the focus is.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

    // A click goes to the setting.
    await search(tester, 'автосохранение');
    await tester.tap(hits('general').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Автосохранение проекта'), findsOneWidget);
    expect(hits('general'), findsNothing, reason: 'the section is shown, not the list');

    // Enter goes to the first one; Esc clears the words.
    await tester.tap(find.byKey(const ValueKey('settings-search')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(hits('general'), findsWidgets, reason: 'the list is back with the words');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('settings-search'))).controller!.text, isEmpty);
    expect(hits('general'), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  });
}
