import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/ui/common/labels.dart';
import 'package:comic_translate/ui/shell_full/batch_dialogs.dart';
import 'package:comic_translate/ui/shell_full/page_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a context in [locale] and gives it to [check].
Future<void> inLocale(WidgetTester tester, String locale, void Function(BuildContext context) check) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          check(context);
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  testWidgets('times of steps in plain words', (tester) async {
    await inLocale(tester, 'ru', (context) {
      expect(formatStepTime(context, 40), '0,1 с');
      expect(formatStepTime(context, 3240), '3,2 с');
      expect(formatStepTime(context, 3000), '3 с');
      expect(formatStepTime(context, 12400), '12 с');
      expect(formatStepTime(context, 65000), '1 мин 05 с');

      expect(
        stepResultLine(
          context,
          const StepResult(step: ManualStep.recognize, pages: 1, count: 12, ms: {ManualStep.recognize: 3200}),
        ),
        'Распознано пузырей: 12 — за 3,2 с',
      );
      expect(
        stepResultLine(
          context,
          const StepResult(
            step: ManualStep.translate,
            pages: 2,
            count: 20,
            ms: {ManualStep.detect: 2000, ManualStep.recognize: 6000, ManualStep.translate: 4000},
          ),
        ),
        'Переведено пузырей: 20 — за 12 с, 2 стр., в среднем 6 с на страницу '
        '(Найти текст 2 с · Распознать 6 с · Перевести 4 с)',
      );
      expect(
        stageTimesLine(context, {'01_detect': 2000, '02_ocr': 30000, '06_render': 1000}, 2),
        'Найти текст 1 с · Распознать 15 с · Наложение перевода 0,5 с · всего 17 с',
      );
    });
    await inLocale(tester, 'en', (context) {
      expect(formatStepTime(context, 3240), '3.2 s');
      expect(
        stepResultLine(
          context,
          const StepResult(step: ManualStep.clean, pages: 1, count: 0, ms: {ManualStep.clean: 900}),
        ),
        'Cleaning done in 0.9 s',
      );
    });
  });
}
