/// Letter case of the drawn translation: as in the source, all capitals, or
/// ordinary sentence case. Not in the original, which has one switch for
/// all pages (`set_upper_case`).
library;

import '../model/text_block.dart';
import '../translation/llm_protocol.dart';
import 'source_style.dart';

enum TextCase {
  /// Capitals where the source text is in capitals (most comics), ordinary
  /// letters elsewhere.
  source,

  /// All capitals.
  upper,

  /// Ordinary letters: a translation in capitals becomes sentence case.
  normal,
}

/// [text] in sentence case: small letters, a capital at the start and after
/// the end of a sentence (an ellipsis does not end one, and text starting
/// with one goes on from the bubble before), English "I" kept.
String toSentenceCase(String text) {
  final lower = pyLower(text);
  final out = StringBuffer();
  final start = lower.trimLeft();
  var capNext = !(start.startsWith('.') || start.startsWith('…'));
  final runes = lower.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final c = String.fromCharCode(runes[i]);
    if (capNext && c.toUpperCase() != c) {
      out.write(pyUpper(c));
      capNext = false;
      continue;
    }
    if (c.toUpperCase() != c.toLowerCase()) capNext = false;
    out.write(c);
    if (c == '!' || c == '?') {
      capNext = true;
    } else if (c == '.') {
      final prev = i > 0 ? String.fromCharCode(runes[i - 1]) : '';
      final next = i + 1 < runes.length ? String.fromCharCode(runes[i + 1]) : '';
      if (prev != '.' && next != '.') capNext = true;
    }
  }
  return out.toString().replaceAllMapped(_lowerI, (m) => 'I');
}

/// English "i" on its own (also "i'm", "i'll").
final _lowerI = RegExp(r"(?<![\p{L}\p{N}])i(?=$|[\s'’,.!?…:;)\-])", unicode: true);

/// The translation of [block] in [mode]; [upperCase] (a block's own choice)
/// wins over it: true for capitals, false for ordinary letters.
String casedTranslation(TextBlock block, TextCase mode, {bool? upperCase}) {
  final t = block.translation;
  final upper =
      upperCase ??
      switch (mode) {
        TextCase.upper => true,
        TextCase.normal => false,
        TextCase.source => isMostlyUpperCase(block.text),
      };
  if (upper) return pyIsUpper(t) ? t : pyUpper(t);
  return pyIsUpper(t) ? toSentenceCase(t) : t;
}
