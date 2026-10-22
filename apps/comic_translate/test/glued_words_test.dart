// Splitting glued words with the bundled English word list, on readings
// from the step 2 experiment (screenshots with 5–7 px letters).

import 'package:comic_translate/pipeline/word_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the bundled word list splits real OCR mistakes and keeps the rest', () async {
    final words = (await loadGluedWords())!;
    expect(words.length, greaterThan(70000));
    for (final (glued, split) in [
      ('REALLIFE', 'REAL LIFE'),
      ('MYINSTINCTS', 'MY INSTINCTS'),
      ('WAITINGFOR', 'WAITING FOR'),
      ('YOURFIRSTMISSION', 'YOUR FIRST MISSION'),
      ('THERESTOF', 'THE REST OF'),
      ('BUTIDUNNO', 'BUT I DUNNO'),
      ('CLEARLYISNT', 'CLEARLY ISNT'),
      ("I'MDONE", "I'M DONE"),
      ("DON'TKNOW", "DON'T KNOW"),
    ]) {
      expect(words.splitText(glued).$1, split);
    }
    // Words, contractions without the apostrophe and misread letters stay.
    for (final word in [
      'INSTINCTS',
      'ARENT',
      'DONT',
      'SECLRE',
      'DELMERY',
      'KRAKOOM',
      'YouTube',
      "I'M",
      "DON'T",
      "O'BRIEN",
    ]) {
      expect(words.splitText(word).$1, word);
    }
  });
}
