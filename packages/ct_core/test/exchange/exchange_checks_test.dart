import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  ExchangeItem item(int block, String text) => ExchangeItem(
    pageId: 'p',
    blockIndex: block - 1,
    label: ExchangeLabel(1, block),
    box: const BBox(0, 0, 10, 10),
    text: text,
  );

  test('a translation that is the original again, or in its letters, was not translated', () {
    final items = [
      item(1, 'I AM LATE!'),
      item(2, 'WAIT.'),
      item(3, 'BOOM!'),
      item(4, 'OK'),
      item(5, 'Run!'),
      item(6, 'Hi'),
    ];
    final replies = {
      const ExchangeLabel(1, 1): const ExchangeReply(translation: 'Я ОПОЗДАЛ!'),
      const ExchangeLabel(1, 2): const ExchangeReply(translation: 'Wait.'),
      const ExchangeLabel(1, 3): const ExchangeReply(translation: 'БУМ!'),
      const ExchangeLabel(1, 4): const ExchangeReply(translation: 'OK'),
      const ExchangeLabel(1, 5): const ExchangeReply(translation: 'Run, run away!'),
      const ExchangeLabel(1, 6): const ExchangeReply(translation: ''),
    };
    expect(untranslatedReplies(items, replies, targetLanguage: 'Russian'), [
      const ExchangeLabel(1, 2),
      const ExchangeLabel(1, 4),
      const ExchangeLabel(1, 5),
    ]);
  });

  test('the same letters on both sides: only the same text counts', () {
    final items = [item(1, 'Hello'), item(2, 'Wait')];
    final replies = {
      const ExchangeLabel(1, 1): const ExchangeReply(translation: 'Hola'),
      const ExchangeLabel(1, 2): const ExchangeReply(translation: 'wait!'),
    };
    expect(untranslatedReplies(items, replies, targetLanguage: 'Spanish'), [const ExchangeLabel(1, 2)]);
  });

  test('the original of the answer counts when there is one; Japanese kana and kanji are one writing', () {
    final items = [item(1, '')];
    expect(
      untranslatedReplies(items, {
        const ExchangeLabel(1, 1): const ExchangeReply(original: 'まって', translation: 'まって'),
      }, targetLanguage: 'Russian'),
      [const ExchangeLabel(1, 1)],
    );
    expect(
      untranslatedReplies(items, {
        const ExchangeLabel(1, 1): const ExchangeReply(original: 'Wait for me', translation: '待ってください'),
      }, targetLanguage: 'Japanese'),
      isEmpty,
    );
  });
}
