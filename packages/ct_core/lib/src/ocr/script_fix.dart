/// Post-OCR clean-up of mixed scripts. Not in the original: recognizers for
/// Cyrillic often return Latin look-alikes in all-caps words ("HET" for
/// "НЕТ"). Visually identical, but translators and search see a different
/// word.
library;

import '../model/text_block.dart';

/// Latin letters with a Cyrillic twin of the same shape.
const _cyrillicTwins = {
  'A': 'А', 'B': 'В', 'C': 'С', 'E': 'Е', 'H': 'Н', 'K': 'К', 'M': 'М', 'O': 'О', 'P': 'Р', 'T': 'Т', 'X': 'Х', //
  'Y': 'У', 'a': 'а', 'c': 'с', 'e': 'е', 'k': 'к', 'o': 'о', 'p': 'р', 'x': 'х', 'y': 'у',
};

/// Languages written in Cyrillic (source language codes).
const cyrillicLanguageCodes = {'ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk', 'mn'};

final _word = RegExp(r'[\p{L}]+', unicode: true);
final _cyrillic = RegExp(r'\p{Script=Cyrillic}', unicode: true);
final _latin = RegExp(r'\p{Script=Latin}', unicode: true);

/// Replaces Latin look-alikes with Cyrillic letters in [text] when it is in a
/// Cyrillic language: always inside mixed words, and in all-look-alike Latin
/// words when the text also has Cyrillic words (so English-only captions
/// stay untouched). [context] is the text that decides whether Cyrillic is
/// present (defaults to [text]; blocks pass their whole text for each line).
String fixCyrillicLookalikes(String text, {String? context}) {
  final hasCyrillic = _cyrillic.hasMatch(context ?? text);
  return text.replaceAllMapped(_word, (m) {
    final w = m[0]!;
    if (!_latin.hasMatch(w)) return w;
    final allTwins = w.split('').every((c) => _cyrillicTwins.containsKey(c) || _cyrillic.hasMatch(c));
    if (!allTwins) return w;
    final mixed = _cyrillic.hasMatch(w);
    if (!mixed && !hasCyrillic) return w;
    return w.split('').map((c) => _cyrillicTwins[c] ?? c).join();
  });
}

/// Applies the script fixes for the source language to every block's text.
void fixOcrScript(List<TextBlock> blocks, String sourceLanguageCode) {
  if (!cyrillicLanguageCodes.contains(sourceLanguageCode.toLowerCase())) return;
  for (final b in blocks) {
    final context = b.text;
    b.texts = [for (final t in b.texts) fixCyrillicLookalikes(t, context: context)];
    b.text = fixCyrillicLookalikes(b.text);
  }
}
