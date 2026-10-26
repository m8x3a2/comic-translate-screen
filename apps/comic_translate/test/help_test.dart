import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/l10n/app_localizations.dart';
import 'package:comic_translate/ui/common/help_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI names the exchange help must call by their current wording, so the
/// help follows when a button is renamed.
const _exchangeNames = [
  'chatMenuBoth',
  'chatMenuRecognize',
  'chatMenuTranslate',
  'chatMenuFolder',
  'glossaryMenu',
  'textExportMenu',
  'chatModeBoth',
  'chatModeRecognize',
  'chatModeTranslate',
  'chatCopyPictures',
  'chatCopyPrompt',
  'chatCopyText',
  'chatCopyOne',
  'chatGalleryOpen',
  'chatSheets',
  'chatSheetSize',
  'chatGroups',
  'chatSheetPerPage',
  'chatContextImage',
  'chatShowPrompt',
  'chatPromptTemplate',
  'chatPaste',
  'chatFromFiles',
  'chatOpenTxt',
  'chatOpenFolder',
  'chatApply',
  'chatApplyContinue',
  'chatAskAgain',
  'chatResendMissing',
  'chatResendAgain',
  'chatRoundBack',
  'chatNewTermsAdd',
  'chatStylesOwn',
  'chatSharedTexts',
  'chatAnswerFromClipboard',
  'chatPlaceholder',
  'chatSeparator',
  'chatTogether',
  'chatApart',
  'chatTextFiles',
  'chatPromptsTitle',
  'chatPromptDefault',
  'styleNone',
  'styleLiteral',
  'styleLively',
  'styleSoften',
  'styleKeepSwearing',
  'styleHonorifics',
];

/// A UI string without its placeholders: "Copy the pictures ({count})" is
/// "Copy the pictures".
String _bare(String s) => s.replaceAll(RegExp(r'\s*\(\{\w+\}\)'), '').replaceAll(RegExp(r'\{\w+\}'), '').trim();

void main() {
  for (final language in helpLanguages) {
    test('the exchange help in "$language" names the buttons as the app does', () {
      // Lines of the page are broken anywhere.
      final help = File(helpAsset(HelpTopic.exchange, language)).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final arb = jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, dynamic>;
      final missing = [
        for (final key in _exchangeNames)
          if (!help.contains(_bare(arb[key] as String))) '$key: ${_bare(arb[key] as String)}',
      ];
      expect(missing, isEmpty);
    });
  }

  test('the help pages of every language have the same sections', () {
    final counts = {
      for (final language in helpLanguages)
        language: helpSections(File(helpAsset(HelpTopic.exchange, language)).readAsStringSync()).length,
    };
    expect(counts.values.toSet(), hasLength(1), reason: '$counts');
    expect(counts.values.first, greaterThan(10));
  });

  test('a help page is cut at its second-level headings', () {
    final sections = helpSections('# Title\n\nIntro.\n\n## One\n\nText.\n### Inner\nMore.\n## Two\nEnd.\n');
    expect([for (final s in sections) s.title], ['', 'One', 'Two']);
    expect(sections[1].text, '## One\n\nText.\n### Inner\nMore.');
  });

  test('other languages get the English help', () {
    expect(helpAsset(HelpTopic.exchange, 'ja'), 'assets/help/exchange.en.md');
    expect(helpAsset(HelpTopic.exchange, 'ru'), 'assets/help/exchange.ru.md');
  });

  testWidgets('the help window shows the page with its contents', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) =>
                TextButton(onPressed: () => showHelp(context, HelpTopic.exchange), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Справка'), findsOneWidget);
    // In the contents on the side and as a heading of the page.
    expect(find.text('«Открыть прошлую выгрузку…»', findRichText: true), findsWidgets);
    expect(find.text('Открыть в другой программе'), findsOneWidget);

    // The last part, far below: the contents scroll to it.
    final heading = find.descendant(of: find.byType(MarkdownBody), matching: find.text('Советы', findRichText: true));
    expect(tester.getTopLeft(heading).dy, greaterThan(1000));
    await tester.tap(find.widgetWithText(ListTile, 'Советы'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(heading).dy, lessThan(500));
  });
}
