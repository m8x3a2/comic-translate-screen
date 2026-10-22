import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  const l13 = ExchangeLabel(1, 3), l14 = ExchangeLabel(1, 4), l21 = ExchangeLabel(2, 1);

  group('labels', () {
    test('page and block with leading zeros, read back in any form', () {
      expect(l13.code, '01-003');
      expect('$l13', '[01-003]');
      expect(const ExchangeLabel(123, 1234).code, '123-1234');
      expect(ExchangeLabel.tryParse('[1-3]'), l13);
      expect(ExchangeLabel.tryParse(' 01-003 '), l13);
      expect(ExchangeLabel.tryParse('01_003'), isNull);
      expect(ExchangeLabel.tryParse('text'), isNull);
    });
  });

  group('the answer of the chat', () {
    test('one line per label, with --> between the original and the translation', () {
      final a = parseExchangeAnswer(
        '[01-003] I\'M LATE! --> Я ОПОЗДАЛ!\n[01-004] Wait. --> Подожди.',
        ExchangeMode.both,
      );
      expect(a.replies.keys, [l13, l14]);
      expect(a.replies[l13]!.original, "I'M LATE!");
      expect(a.replies[l13]!.translation, 'Я ОПОЗДАЛ!');
      expect(a.replies[l14]!.translation, 'Подожди.');
    });

    test('other arrows, markdown, quotes, numbering, code blocks and remarks of the chat', () {
      const answer = '''
Sure! Here are the lines:

```
1. **[01-003]** "Hi there" → «Привет»
- 01-004: Bye => Пока
```
【02-001】 Run! -> Беги!

Let me know if you need anything else.''';
      final a = parseExchangeAnswer(answer, ExchangeMode.both);
      expect(a.replies.keys, [l13, l14, l21]);
      expect(a.replies[l13]!.original, 'Hi there');
      expect(a.replies[l13]!.translation, 'Привет');
      expect(a.replies[l14]!.original, 'Bye');
      expect(a.replies[l14]!.translation, 'Пока');
      expect(a.replies[l21]!.translation, 'Беги!');
    });

    test('a piece over several lines becomes one line; the label may stand on its own line', () {
      final a = parseExchangeAnswer('[01-003]\nI\'M\nLATE!\n[01-004] ok', ExchangeMode.recognize);
      expect(a.replies[l13]!.original, "I'M LATE!");
      expect(a.replies[l14]!.original, 'ok');
    });

    test('a label with nothing after it means no text; repeated labels keep the first answer', () {
      final a = parseExchangeAnswer('[01-003]\n[01-004] one\n[01-004] two', ExchangeMode.recognize);
      expect(a.replies[l13]!.isEmpty, isTrue);
      expect(a.replies[l14]!.original, 'one');
      expect(a.repeated, [l14]);
    });

    test('translate: an answer that repeats the original keeps only the translation', () {
      final a = parseExchangeAnswer('[01-003] Hello --> Привет\n[01-004] Пока', ExchangeMode.translate);
      expect(a.replies[l13]!.translation, 'Привет');
      expect(a.replies[l14]!.translation, 'Пока');
    });

    test('both, but without an arrow: all of it is the translation, marked', () {
      final a = parseExchangeAnswer('[01-003] Привет', ExchangeMode.both);
      expect(a.replies[l13]!.translation, 'Привет');
      expect(a.replies[l13]!.original, isNull);
      expect(a.replies[l13]!.missingArrow, isTrue);
    });

    test('several labels on one line', () {
      final a = parseExchangeAnswer('[01-003] A --> А [01-004] B --> Б', ExchangeMode.both);
      expect(a.replies[l13]!.translation, 'А');
      expect(a.replies[l14]!.original, 'B');
    });

    test('numbers inside the text are not labels', () {
      final a = parseExchangeAnswer('[01-003] Call me at 555-1234 tomorrow', ExchangeMode.recognize);
      expect(a.replies.keys, [l13]);
      expect(a.replies[l13]!.original, 'Call me at 555-1234 tomorrow');
    });

    test('ellipsis at the start of a line stays', () {
      final a = parseExchangeAnswer('[01-003] ...and then --> ...а потом', ExchangeMode.both);
      expect(a.replies[l13]!.original, '...and then');
      expect(a.replies[l13]!.translation, '...а потом');
    });
  });

  group('matching with what was sent', () {
    final items = [
      ExchangeItem(label: l13, pageId: 'a', blockIndex: 2, box: const BBox(0, 0, 10, 10), text: 'Hello'),
      ExchangeItem(label: l14, pageId: 'a', blockIndex: 3, box: const BBox(20, 0, 30, 10), text: 'Bye'),
    ];

    test('missing and unknown labels are told', () {
      final m = matchExchangeAnswer(
        items,
        parseExchangeAnswer('[01-003] Привет\n[05-001] ?', ExchangeMode.translate),
        ExchangeMode.translate,
      );
      expect(m.replies.keys, [l13]);
      expect(m.missing, [l14]);
      expect(m.unknown, [const ExchangeLabel(5, 1)]);
    });

    test('lines of a text file left as they were count as missing', () {
      final m = matchExchangeAnswer(
        items,
        parseExchangeAnswer('[01-003] Hello\n[01-004] Пока', ExchangeMode.translate),
        ExchangeMode.translate,
        ignoreUnchanged: true,
      );
      expect(m.replies.keys, [l14]);
      expect(m.missing, [l13]);
    });

    test('the block is found again after blocks were added before it', () {
      final blocks = [TextBlock(xyxy: const BBox(100, 100, 120, 120)), TextBlock(xyxy: const BBox(0, 0, 10, 10))];
      expect(findExchangeBlock(blocks, items[0]), 1);
      expect(findExchangeBlock(blocks, items[1]), isNull);
    });

    test('replies go into the text or the translation; the placeholder fills what is missing', () {
      final b = TextBlock(xyxy: const BBox(0, 0, 1, 1), text: 'old', translation: 'старый');
      expect(
        applyExchangeReply(b, const ExchangeReply(original: 'Hi', translation: 'Привет'), ExchangeMode.both),
        isTrue,
      );
      expect((b.text, b.translation), ('Hi', 'Привет'));
      expect(applyExchangeReply(b, null, ExchangeMode.translate), isFalse);
      expect(applyExchangeReply(b, null, ExchangeMode.translate, placeholder: '⟦пусто⟧'), isTrue);
      expect(b.translation, '⟦пусто⟧');
      applyExchangeReply(b, const ExchangeReply(original: ''), ExchangeMode.recognize);
      expect(b.text, '');
      // Mode both without an arrow keeps the text that was read.
      final c = TextBlock(xyxy: const BBox(0, 0, 1, 1), text: 'Hi');
      applyExchangeReply(c, const ExchangeReply(translation: 'Привет', missingArrow: true), ExchangeMode.both);
      expect((c.text, c.translation), ('Hi', 'Привет'));
    });
  });

  group('own grouping of the sheets', () {
    test('ranges and single pieces, counted from 1', () {
      expect(parseSheetGroups('1-4, 5-6; 8', 9), [
        [0, 1, 2, 3],
        [4, 5],
        [7],
      ]);
      expect(parseSheetGroups('  ', 3), isEmpty);
    });

    test('wrong parts are named', () {
      expect(
        () => parseSheetGroups('1-4, x', 9),
        throwsA(isA<FormatException>().having((e) => e.message, 'part', 'x')),
      );
      expect(() => parseSheetGroups('5-3', 9), throwsFormatException);
      expect(() => parseSheetGroups('1-10', 9), throwsFormatException);
      expect(() => parseSheetGroups('1-3, 2', 9), throwsFormatException);
    });
  });

  group('instructions', () {
    final items = [
      ExchangeItem(label: l13, pageId: 'a', blockIndex: 2, box: const BBox(0, 0, 1, 1), text: 'Hello\nthere'),
      ExchangeItem(label: l14, pageId: 'a', blockIndex: 3, box: const BBox(0, 0, 1, 1), text: 'Bye'),
    ];

    test('translate: languages, context and the lines with labels', () {
      final s = exchangePrompt(
        ExchangeMode.translate,
        items,
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        extraContext: 'A school story.',
      );
      expect(s, contains('from English into Russian'));
      expect(s, contains('About the comic: A school story.'));
      expect(s, contains('[01-003] Hello there\n[01-004] Bye'));
      expect(s, isNot(contains('{')));
    });

    test('both: the labels to answer and the --> form; own instructions replace the built-in ones', () {
      final s = exchangePrompt(
        ExchangeMode.both,
        items,
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        screens: true,
      );
      expect(s, contains('Labels: [01-003] [01-004]'));
      expect(s, contains('original text --> translation'));
      expect(s, contains('screenshots of a site or a game'));
      final own = exchangePrompt(
        ExchangeMode.both,
        items,
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        template: 'Do {source} to {target}: {labels} {unknown}',
      );
      expect(own, 'Do English to Russian: [01-003] [01-004] {unknown}\n');
    });
  });
}
