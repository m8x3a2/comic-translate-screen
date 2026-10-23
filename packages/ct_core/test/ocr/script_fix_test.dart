import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('Latin look-alikes become Cyrillic in Russian text', () {
    expect(fixCyrillicLookalikes('HET! Даже не думай об этом'), 'НЕТ! Даже не думай об этом');
    expect(fixCyrillicLookalikes('пpивeт'), 'привет', reason: 'mixed word');
    expect(fixCyrillicLookalikes('ТОЧHO'), 'ТОЧНО');
  });

  test('Latin words that are not look-alikes, and English-only text, stay', () {
    expect(fixCyrillicLookalikes('Wow, это круто'), 'Wow, это круто');
    expect(fixCyrillicLookalikes('HET'), 'HET', reason: 'no Cyrillic context');
    expect(fixCyrillicLookalikes('THE END'), 'THE END');
  });

  test('only for Cyrillic source languages', () {
    final ru = TextBlock(xyxy: const BBox(0, 0, 1, 1), texts: ['HET!', 'Даже'])..sourceLang = 'ru';
    fixOcrScript([ru], 'ru');
    expect(ru.texts, ['НЕТ!', 'Даже']);
    expect(ru.text, 'НЕТ! Даже');
    final en = TextBlock(xyxy: const BBox(0, 0, 1, 1), texts: ['HET Даже']);
    fixOcrScript([en], 'en');
    expect(en.text, 'HET Даже');
  });
}
