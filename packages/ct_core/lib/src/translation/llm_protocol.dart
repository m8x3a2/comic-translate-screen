/// The LLM translation protocol of the original: prompts, the `block_N` JSON
/// exchange and the shared post-processing. Ports of
/// `modules/translation/base.py`, `modules/translation/llm/base.py`,
/// `modules/translation/processor.py` and `modules/utils/translator_utils.py`.
library;

import 'dart:convert';

import '../model/text_block.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';

part 'py_case_tables.g.dart';

/// Sampling settings the original uses for every LLM.
const llmDefaultTemperature = 1.0;
const llmDefaultMaxTokens = 5000;

/// `LLMTranslation.get_system_prompt`, verbatim (including its indentation).
String llmSystemPrompt(String sourceLanguage, String targetLanguage) =>
    '''You are an expert translator who translates $sourceLanguage to $targetLanguage. You pay attention to style, formality, idioms, slang etc and try to convey it in the way a $targetLanguage speaker would understand.
        BE MORE NATURAL. NEVER USE 당신, 그녀, 그 or its Japanese equivalents.
        Specifically, you will be translating text OCR'd from a comic. The OCR is not perfect and as such you may receive text with typos or other mistakes.
        To aid you and provide context, You may be given the image of the page and/or extra context about the comic. You will be given a json string of the detected text blocks and the text to translate. Return the json string with the texts translated. DO NOT translate the keys of the json. For each block:
        - If it's already in $targetLanguage or looks like gibberish, OUTPUT IT AS IT IS instead
        - DO NOT give explanations
        Do Your Best! I'm really counting on you.''';

/// `get_raw_text`: `{"block_0": text, ...}` as Python's
/// `json.dumps(..., ensure_ascii=False, indent=4)`.
String blocksToJson(List<TextBlock> blocks) =>
    const JsonEncoder.withIndent('    ').convert({for (final (i, b) in blocks.indexed) 'block_$i': b.text});

/// The user message of `BaseLLMTranslation.translate`.
String llmUserPrompt(String extraContext, String blocksJson) =>
    '$extraContext\nMake the translation sound as natural as possible.\nTranslate this:\n$blocksJson';

final _jsonObject = RegExp(r'\{[\s\S]*\}');

/// Warning of [applyTranslationsJson] when the reply has no JSON object.
const noJsonWarning = 'No JSON found in the reply.';

/// `set_texts_from_json`: takes the outermost `{...}` of a model reply and
/// stores `block_N` values as translations. Returns warnings (missing keys,
/// no JSON); throws [FormatException] for malformed JSON.
///
/// Unlike the original, when the outermost braces are not valid JSON (the
/// model wrote more braces after its answer) the first balanced, valid JSON
/// object is used instead of failing the whole page.
List<String> applyTranslationsJson(List<TextBlock> blocks, String reply) {
  final match = _jsonObject.firstMatch(reply);
  if (match == null) return [noJsonWarning];
  Object? decoded;
  try {
    decoded = jsonDecode(match[0]!);
  } on FormatException {
    decoded = _firstJsonObject(reply);
    if (decoded == null) rethrow;
  }
  if (decoded is! Map) throw const FormatException('The reply JSON is not an object.');
  final warnings = <String>[];
  for (final (i, b) in blocks.indexed) {
    final key = 'block_$i';
    if (decoded.containsKey(key)) {
      final v = decoded[key];
      b.translation = v is String ? v : (v == null ? '' : '$v');
    } else {
      warnings.add('$key not found in the reply.');
    }
  }
  return warnings;
}

/// The first `{...}` span (braces balanced outside JSON strings) that decodes
/// to a JSON object.
Map? _firstJsonObject(String s) {
  for (var start = s.indexOf('{'); start >= 0; start = s.indexOf('{', start + 1)) {
    var depth = 0;
    var inString = false;
    for (var i = start; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (inString) {
        if (c == 0x5c) {
          i++; // skip the escaped character
        } else if (c == 0x22) {
          inString = false;
        }
        continue;
      }
      if (c == 0x22) {
        inString = true;
      } else if (c == 0x7b) {
        depth++;
      } else if (c == 0x7d && --depth == 0) {
        try {
          final v = jsonDecode(s.substring(start, i + 1));
          if (v is Map) return v;
        } on FormatException {
          // try the next opening brace
        }
        break;
      }
    }
  }
  return null;
}

final _alnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// `has_translatable_content`: the text has a letter or digit.
bool hasTranslatableContent(String? text) => text != null && _alnum.hasMatch(text);

/// `Translator.translate` of the original processor: blocks without letters
/// or digits get an empty translation; the rest go to [translator] in one
/// request. Returns the blocks that were sent.
Future<List<TextBlock>> translateBlocks(Translator translator, TranslationRequest request, PluginContext context) async {
  final translatable = <TextBlock>[];
  for (final b in request.blocks) {
    if (hasTranslatableContent(b.text)) {
      translatable.add(b);
    } else {
      b.translation = '';
    }
  }
  if (translatable.isEmpty) return translatable;
  await translator.translate(
    TranslationRequest(
      blocks: translatable,
      sourceLanguage: request.sourceLanguage,
      targetLanguage: request.targetLanguage,
      pageImage: request.pageImage,
      extraContext: request.extraContext,
    ),
    context,
  );
  return translatable;
}

/// `set_upper_case`: upper-cases translations, or turns all-caps ones into
/// sentence case when [upperCase] is off.
void setUpperCase(List<TextBlock> blocks, bool upperCase) {
  for (final b in blocks) {
    final t = b.translation;
    if (upperCase && !pyIsUpper(t)) {
      b.translation = pyUpper(t);
    } else if (!upperCase && pyIsUpper(t)) {
      b.translation = pyCapitalize(pyLower(t));
    }
  }
}

String _mapRunes(String s, Map<int, String> special, String Function(String) simple) {
  final out = StringBuffer();
  for (final r in s.runes) {
    out.write(special[r] ?? simple(String.fromCharCode(r)));
  }
  return out.toString();
}

/// Python `str.upper()` (full Unicode mapping, e.g. ß → SS).
String pyUpper(String s) => _mapRunes(s, _pyUpperSpecial, (c) => c.toUpperCase());

/// Python `str.lower()`.
String pyLower(String s) => _mapRunes(s, _pyLowerSpecial, (c) => c.toLowerCase());

/// Python `str.isupper()`: has a cased character and no lower- or
/// title-case one.
bool pyIsUpper(String s) {
  var cased = false;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (pyUpper(c) != c) return false; // lower or title case
    if (pyLower(c) != c) cased = true;
  }
  return cased;
}

/// Python `str.capitalize()`: first character in title case, the rest lower.
String pyCapitalize(String s) {
  if (s.isEmpty) return s;
  final runes = s.runes.toList();
  final first = runes.first;
  final head = _pyTitleSpecial[first] ?? pyUpper(String.fromCharCode(first));
  return head + pyLower(String.fromCharCodes(runes.skip(1)));
}
