// The question of "Translate" about frames without text.

import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/ui/shell_full/batch_dialogs.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('frames without text: the choice, remembered or not, or stop', (tester) async {
    ({EmptyFrames choice, bool remember})? answer;
    var answered = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await DialogBatchUi(context).confirmEmptyFrames(3);
                answered = true;
              },
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
    Future<void> ask() async {
      answered = false;
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Рамок без текста: 3'), findsOneWidget);
    }

    await ask();
    await tester.tap(find.text('Распознать их'));
    await tester.pumpAndSettle();
    expect((answered, answer), (true, (choice: EmptyFrames.read, remember: false)));

    await ask();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Перевести без них'));
    await tester.pumpAndSettle();
    expect((answered, answer), (true, (choice: EmptyFrames.skip, remember: true)));

    await ask();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect((answered, answer), (true, null), reason: 'stopped, nothing remembered');
  });
}
