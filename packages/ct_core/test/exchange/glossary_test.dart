// The glossary of a project and the styles of translation: for the chat's
// instructions and translators over the network.

import 'dart:convert';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  const text = '# my own remark\nKai --> Кай\nSenpai -> семпай\n\nThe heroes are on first-name terms.\nbroken -->\n';

  test('words, notes and remarks', () {
    final g = Glossary.parse(text);
    expect([for (final e in g.entries) e.line], ['Kai --> Кай', 'Senpai --> семпай']);
    expect(g.notes, ['The heroes are on first-name terms.', 'broken -->']);
    expect(g.has('kai'), isTrue);
    expect(g.has('Maya'), isFalse);
    expect(Glossary.parse('  \n# only a remark').isEmpty, isTrue);
  });

  test('for the instructions: the words in the text, all notes', () {
    final g = Glossary.parse(text);
    final some = g.forPrompt(texts: ['KAI! WAIT!']);
    expect(some, contains('Kai → Кай'));
    expect(some, isNot(contains('Senpai')));
    expect(some, contains('The heroes are on first-name terms.'));
    expect(g.forPrompt(), contains('Senpai → семпай'), reason: 'no text: every word');
    expect(Glossary.parse('').forPrompt(), '');
    expect(Glossary.parse('Kai --> Кай').forPrompt(texts: ['Hello']), '', reason: 'nothing that fits');
  });

  test('words added at the end, the ones it has left out', () {
    final added = Glossary.add(text, const [GlossaryEntry('KAI', 'Каи'), GlossaryEntry('Maya', 'Майя')]);
    expect(added, endsWith('broken -->\nMaya --> Майя\n'));
    expect(Glossary.add('', const [GlossaryEntry('Maya', 'Майя')]), 'Maya --> Майя\n');
  });

  test('words a chat suggests; they are no answer for a piece', () {
    const answer = '[01-001] Привет, Кай!\n[01-002] Пока\n\nNEW: Kai --> Кай\n**New:** Old Tom → Старина Том\nNEW: x\n';
    expect(exchangeNewTerms(answer), const [GlossaryEntry('Kai', 'Кай'), GlossaryEntry('Old Tom', 'Старина Том')]);
    final a = parseExchangeAnswer('[01-001] Hi\nNEW: Kai --> Кай\n[01-002] Bye', ExchangeMode.translate);
    expect(a.replies[const ExchangeLabel(1, 1)]!.translation, 'Hi', reason: 'the NEW line is not joined to it');
  });

  group('instructions', () {
    final items = [
      ExchangeItem(
        label: const ExchangeLabel(1, 1),
        pageId: 'a',
        blockIndex: 0,
        box: const BBox(0, 0, 1, 1),
        text: 'KAI!',
      ),
    ];
    String prompt(ExchangePrompt kind, {String template = '', List<PromptStyle> styles = const []}) => exchangePrompt(
      kind,
      items,
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      glossary: text,
      template: template,
      styles: styles,
    );

    test('the glossary and the request for new words when translating', () {
      final t = prompt(ExchangePrompt.translate);
      expect(t, contains('Kai → Кай'));
      expect(t, isNot(contains('Senpai')), reason: 'only the words in the text sent');
      expect(t, contains('NEW: word --> translation'));
      expect(prompt(ExchangePrompt.both), contains('Senpai → семпай'), reason: 'the chat reads: every word');
      expect(prompt(ExchangePrompt.recognize), isNot(contains('Glossary')));
    });

    test('styles; own instructions get what they lack at the end', () {
      final t = prompt(ExchangePrompt.translate, styles: [builtInPromptStyles.first, const PromptStyle('own_1', '')]);
      expect(t, contains('Style of the translation: ${builtInPromptStyles.first.text}\n'));
      final own = prompt(ExchangePrompt.translate, template: 'Mine: {lines}', styles: [builtInPromptStyles[1]]);
      expect(own, startsWith('Mine: [01-001] KAI!'));
      expect(own, contains('Style of the translation'));
      expect(own, contains('Kai → Кай'));
      expect(prompt(ExchangePrompt.recognize, styles: [builtInPromptStyles.first]), isNot(contains('Style')));
    });
  });

  test('own and chosen styles survive the settings file', () {
    const s = ExchangeSettings(
      ownStyles: [PromptStyle('own_1', 'Use rhymes.', name: 'Стихи')],
      activeStyles: ['own_1', 'soften'],
    );
    final back = ExchangeSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.toJson(), s.toJson());
    expect([for (final st in back.chosenStyles) st.id], ['soften', 'own_1']);
    expect(promptStyleLine(back.chosenStyles), 'Style of the translation: Soften rude words and swearing. Use rhymes.');
  });
}
