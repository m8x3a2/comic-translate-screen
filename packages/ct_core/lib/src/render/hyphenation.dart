/// Hyphenation of Russian (Cyrillic) words by syllables, for fitting long
/// words into narrow bubbles. Not in the original, which breaks words only
/// at their own hyphens.
///
/// Rules: each part keeps a vowel and at least two letters; one consonant
/// between vowels goes to the next line, of two or more the first stays
/// (с-т-р → с|тр); ь, ъ and й stay with the letter before them.
library;

const _vowels = 'аеёиоуыэюяАЕЁИОУЫЭЮЯ';
const _signs = 'ьъЬЪ';

final _digit = RegExp(r'\d');

bool _isCyrillic(int r) => (r >= 0x410 && r <= 0x44F) || r == 0x401 || r == 0x451;
bool _isVowel(String c) => _vowels.contains(c);
bool _isSign(String c) => _signs.contains(c);
bool _isShortI(String c) => c == 'й' || c == 'Й';

/// Positions (string indexes) where [word] may be broken with a hyphen:
/// the part before the position stays on the line. Words with other letters
/// than Cyrillic ones, or shorter than seven letters, are not broken (a
/// short word broken in a bubble reads worse than smaller letters).
/// Punctuation around the word stays with its part.
List<int> hyphenationPoints(String word) {
  var start = 0, end = word.length;
  bool letter(int i) => _isCyrillic(word.codeUnitAt(i));
  bool punctuation(int i) => word[i].toUpperCase() == word[i].toLowerCase() && !_digit.hasMatch(word[i]);
  while (start < end && punctuation(start)) {
    start++;
  }
  while (end > start && punctuation(end - 1)) {
    end--;
  }
  if (end - start < 7) return const [];
  for (var i = start; i < end; i++) {
    if (!letter(i)) return const [];
  }
  final core = word.substring(start, end);
  final vowelAt = [for (var i = 0; i < core.length; i++) _isVowel(core[i])];
  final points = <int>[];
  var prevVowel = -1;
  for (var i = 0; i < core.length; i++) {
    if (!vowelAt[i]) continue;
    if (prevVowel >= 0) {
      // Consonants between two vowels, as units: a letter with the signs
      // after it.
      final units = <(int, int)>[];
      var k = prevVowel + 1;
      while (k < i) {
        var e = k + 1;
        while (e < i && _isSign(core[e])) {
          e++;
        }
        units.add((k, e));
        k = e;
      }
      final int at;
      if (units.isEmpty) {
        at = i;
      } else if (units.length == 1) {
        at = _isShortI(core[units.first.$1]) ? units.first.$2 : units.first.$1;
      } else {
        at = units.first.$2;
      }
      if (at >= 2 && core.length - at >= 2 && !_isSign(core[at])) points.add(start + at);
    }
    prevVowel = i;
  }
  return points;
}
