import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  // Most frequent first, like the SymSpell list.
  final words = GluedWords.parse(
    [
      'the 1000000',
      'is 900000',
      'a 800000',
      'i 700000',
      'my 600000',
      'real 500000',
      'life 400000',
      'rent 300000',
      'instincts 20000',
      'cleared 9000',
      'off 8000',
      // Short words below the first thousand are no pieces of a split.
      for (var i = 0; i < 1000; i++) 'filler$i 100',
      'sec 10',
    ].join('\n'),
  );

  test('splits glued words into dictionary words, keeping the case', () {
    expect(words.splitWord('REALLIFE'), 'REAL LIFE');
    expect(words.splitWord('MyInstincts'), 'MyInstincts', reason: 'capitals inside: a name like "YouTube"');
    expect(words.splitWord('myinstincts'), 'my instincts');
    expect(words.splitWord('CLEAREDOFF'), 'CLEARED OFF');
  });

  test('leaves words, short words and garbage alone', () {
    expect(words.splitWord('LIFE'), 'LIFE');
    expect(words.splitWord('ISA'), 'ISA', reason: 'shorter than 4 letters');
    expect(words.splitWord('SECLRE'), 'SECLRE', reason: 'not made of words');
    expect(words.splitWord('SECREAL'), 'SECREAL', reason: 'a rare short word is not a piece');
    expect(words.splitWord('ARENT'), 'ARENT', reason: 'a contraction without its apostrophe');
    expect(words.splitWord("ISN'T"), "ISN'T");
  });

  test('splits text and counts the words', () {
    final (text, n) = words.splitText('THIS ISREALLIFE!\nMYINSTINCTS...');
    expect(text, 'THIS IS REAL LIFE!\nMY INSTINCTS...');
    expect(n, 2);
    final same = 'NOTHING HERE';
    expect(identical(words.splitText(same).$1, same), isTrue);
  });

  test('only English blocks are split', () {
    TextBlock block(String text, [String lang = '']) =>
        TextBlock(xyxy: const BBox(0, 0, 10, 10), texts: [text])..sourceLang = lang;
    final en = block('REALLIFE');
    expect(words.splitBlocks([en], sourceLanguage: 'English'), 1);
    expect(en.text, 'REAL LIFE');
    expect(en.texts, ['REAL LIFE']);

    final fr = block('REALLIFE');
    expect(words.splitBlocks([fr], sourceLanguage: 'French'), 0);
    expect(fr.text, 'REALLIFE');

    final auto = [block('REALLIFE', 'en'), block('REALLIFE', 'ru')];
    expect(words.splitBlocks(auto, sourceLanguage: Languages.auto), 1);
    expect([for (final b in auto) b.text], ['REAL LIFE', 'REALLIFE']);
  });

  test('very small text is told by the line thickness', () {
    final b = TextBlock(xyxy: const BBox(0, 0, 10, 10));
    expect(isSmallText(b), isFalse, reason: 'not read yet');
    expect(isSmallText(b..linePx = 12), isTrue);
    expect(isSmallText(b..linePx = 20), isFalse);
    expect(TextBlock.fromJson((b..linePx = 12).toJson()).linePx, 12);
    expect(b.copy().linePx, 12);
  });
}
