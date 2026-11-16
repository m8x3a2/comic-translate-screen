// The offline dictionary window: a word of the original looked up, a Russian
// word put into the glossary, a word it does not know; the glossary list.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/dictionary.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/shell_full/dictionary_dialog.dart';
import 'package:comic_translate/ui/shell_full/glossary_dialog.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'support/fake_plugins.dart';

String _dictionary(Directory dir) {
  final path = p.join(dir.path, 'dictionary.sqlite');
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
  db.execute('CREATE TABLE entry(w TEXT PRIMARY KEY, word TEXT, data TEXT)');
  db.execute('CREATE TABLE form(f TEXT, lemma TEXT, note TEXT)');
  db.execute("INSERT INTO meta VALUES('format', '1')");
  db.execute('INSERT INTO entry VALUES(?,?,?)', [
    'give up',
    'give up',
    jsonEncode({
      'verb': {
        'tr': {
          'surrender': ['сдаваться', 'сдаться'],
        },
        'en': [
          {'g': 'To surrender.', 't': <String>[], 'x': <String>[]},
        ],
      },
    }),
  ]);
  db.execute('INSERT INTO entry VALUES(?,?,?)', [
    'gimme',
    'gimme',
    jsonEncode({
      'verb': {
        'en': [
          {
            'g': 'Give me.',
            't': ['informal'],
            'x': <String>[],
          },
        ],
      },
    }),
  ]);
  db.execute("INSERT INTO form VALUES('gave up', 'give up', 'past')");
  db.close();
  return path;
}

void main() {
  test('the word at the cursor or the selected words', () {
    const text = "I GAVE UP, y'know?";
    expect(dictionaryQueryAt(text, 4, 4), 'GAVE');
    expect(dictionaryQueryAt(text, 2, 9), 'GAVE UP');
    expect(dictionaryQueryAt(text, 13, 13), "y'know");
    expect(dictionaryQueryAt(text, 9, 9), 'UP');
    expect(dictionaryQueryAt(text, 30, 30), '');
  });

  late Directory dir;
  late AppServices services;
  late OfflineDictionary dict;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_dictionary_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    services.appLog.info('test_start');
    dict = OfflineDictionary.open(_dictionary(dir));
  });

  tearDown(() async {
    dict.dispose();
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  Future<ProviderContainer> open(WidgetTester tester, Future<void> Function(BuildContext) show) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(fakeSettings()),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
          dictionaryProvider.overrideWith((ref) async => dict),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox(key: key)),
        ),
      ),
    );
    unawaited(show(key.currentContext!));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(key.currentContext!);
  }

  testWidgets('a phrase of the original found; a Russian word goes into the glossary', (tester) async {
    final container = await open(tester, (c) => showDictionary(c, query: 'GAVE UP!'));
    expect(find.text('give up'), findsOneWidget);
    expect(find.text('past'), findsOneWidget);
    expect(find.text('— surrender'), findsOneWidget);
    // English explanations are folded when there is Russian.
    expect(find.text('По-английски (1)'), findsOneWidget);
    expect(find.textContaining('To surrender.'), findsNothing);

    await tester.tap(find.widgetWithText(ActionChip, 'сдаться'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).glossary, 'give up --> сдаться\n');
    expect(find.text('Добавлено в словарь терминов: give up → сдаться'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'сдаваться'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).glossary, 'give up --> сдаться\n');
    expect(find.text('«give up» уже есть в словаре терминов'), findsOneWidget);
  });

  testWidgets('English explanations open by themselves without Russian; unknown words', (tester) async {
    await open(tester, (c) => showDictionary(c, query: 'gimme'));
    expect(find.textContaining('Give me.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'giv');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('«giv» нет в словаре.'), findsOneWidget);
    expect(find.text('Перевести офлайн'), findsOneWidget);
    // Words starting the same way lead to their cards.
    await tester.tap(find.widgetWithText(ActionChip, 'give up'));
    await tester.pumpAndSettle();
    expect(find.text('— surrender'), findsOneWidget);
  });

  testWidgets('English explanations turned off in the settings', (tester) async {
    final container = await open(tester, (c) async {});
    await tester.runAsync(() => container.read(settingsProvider.notifier).change((s) => s.dictShowEnglish = false));
    unawaited(showDictionary(tester.element(find.byType(Scaffold)), query: 'gimme'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Give me.'), findsNothing);
    expect(find.text('Есть только английские толкования (выключены в «Настройки → Переводчик»).'), findsOneWidget);
  });

  testWidgets('the glossary as a list: search and delete a line', (tester) async {
    final container = await open(tester, (c) async {});
    container.read(workspaceProvider.notifier).setGlossary('Kai --> Кай\n# заметка\nguy --> парень\n');
    unawaited(showGlossaryDialog(tester.element(find.byType(Scaffold))));
    await tester.pumpAndSettle();
    expect(find.text('Kai --> Кай'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'пар');
    await tester.pumpAndSettle();
    expect(find.text('Kai --> Кай'), findsNothing);
    await tester.tap(find.byTooltip('Удалить строку'));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).glossary, 'Kai --> Кай\n# заметка\n');
  });
}
