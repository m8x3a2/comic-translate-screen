/// The LLM translation protocol of the original: prompts, the `block_N` JSON
/// exchange and the shared post-processing. Ports of
/// `modules/translation/base.py`, `modules/translation/llm/base.py`,
/// `modules/translation/processor.py` and `modules/utils/translator_utils.py`.
library;

import 'dart:convert';

import '../model/language.dart';
import '../exchange/exchange_answer.dart';
import '../image/raster.dart';
import '../model/text_block.dart';
import '../ocr/auto_language.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';

part 'py_case_tables.g.dart';

/// Sampling settings the original uses for every LLM.
const llmDefaultTemperature = 1.0;
const llmDefaultMaxTokens = 5000;

/// `LLMTranslation.get_system_prompt`, verbatim (including its indentation).
/// An unresolved "Auto" source (Latin-script or mixed pages) is worded as
/// "text in any language" rather than the original's literal "Auto".
String llmSystemPrompt(String sourceLanguage, String targetLanguage) =>
    '''You are an expert translator who translates ${sourceLanguage == Languages.auto ? 'text in any language' : sourceLanguage} to $targetLanguage. You pay attention to style, formality, idioms, slang etc and try to convey it in the way a $targetLanguage speaker would understand.
        BE MORE NATURAL. NEVER USE 당신, 그녀, 그 or its Japanese equivalents.
        Specifically, you will be translating text OCR'd from a comic. The OCR is not perfect and as such you may receive text with typos or other mistakes.
        To aid you and provide context, You may be given the image of the page and/or extra context about the comic. You will be given a json string of the detected text blocks and the text to translate. Return the json string with the texts translated. DO NOT translate the keys of the json. For each block:
        - If it's already in $targetLanguage or looks like gibberish, OUTPUT IT AS IT IS instead
        - DO NOT give explanations
        Do Your Best! I'm really counting on you.''';

/// `get_raw_text`: `{"block_0": text, ...}` as Python's
/// `json.dumps(..., ensure_ascii=False, indent=4)`; with [keys], those
/// instead of `block_N` (several pages in one request).
String blocksToJson(List<TextBlock> blocks, {List<String>? keys}) => const JsonEncoder.withIndent('    ')
    .convert({for (final (i, b) in blocks.indexed) (keys?[i] ?? 'block_$i'): b.text});

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
///
/// Blocks the reply has nothing for are marked [TextBlock.untranslated] (the
/// others unmarked).
List<String> applyTranslationsJson(List<TextBlock> blocks, String reply, {List<String>? keys}) {
  final match = _jsonObject.firstMatch(reply);
  if (match == null) {
    for (final b in blocks) {
      b.untranslated = true;
    }
    return [noJsonWarning];
  }
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
    final key = keys?[i] ?? 'block_$i';
    if (decoded.containsKey(key)) {
      final v = decoded[key];
      b.translation = v is String ? v : (v == null ? '' : '$v');
      b.untranslated = false;
    } else {
      b.untranslated = true;
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
Future<List<TextBlock>> translateBlocks(
  Translator translator,
  TranslationRequest request,
  PluginContext context,
) async {
  final translatable = <TextBlock>[];
  final keys = <String>[];
  for (final (i, b) in request.blocks.indexed) {
    // Translators that can tell mark again what their answer left out.
    b.untranslated = false;
    if (hasTranslatableContent(b.text)) {
      translatable.add(b);
      keys.add(request.keyOf(i));
    } else {
      b.translation = '';
    }
  }
  if (translatable.isEmpty) return translatable;
  final named = request.keys == null ? null : keys;
  await translator.translate(
    TranslationRequest(
      blocks: translatable,
      // "Auto": the language the block scripts tell (as the original's own
      // service does), when they tell one.
      sourceLanguage: resolveAutoSourceLanguage(request.blocks, request.sourceLanguage),
      targetLanguage: request.targetLanguage,
      pageImage: request.pageImage,
      extraContext: [
        request.extraContext,
        speakersForTranslator(translatable, keys: named),
      ].where((s) => s.trim().isNotEmpty).join('\n'),
      keys: named,
      pageImages: request.pageImages,
    ),
    context,
  );
  return translatable;
}

/// One page of several translated in one request: its place among all
/// pages (from 1, the first part of the labels), its blocks and picture.
class PackPage {
  const PackPage(this.number, this.blocks, {this.image});

  final int number;
  final List<TextBlock> blocks;
  final RgbImage? image;
}

/// Told to the translator when several pages go in one request (not in the
/// original).
const packTranslatorNote =
    'Several pages of the comic follow one another here. The keys are labels: 01-003 is page 1, block 3. '
    'Keep every key as it is.';

/// Several pages in one request (the owner's idea): the blocks of [pages]
/// named by their labels (`01-003`, as in the exchange with a chat), the
/// pages' pictures when given. Blocks the answer left out are marked as
/// with one page. Returns the blocks that were sent.
Future<List<TextBlock>> translatePack(
  Translator translator,
  List<PackPage> pages,
  PluginContext context, {
  required String sourceLanguage,
  required String targetLanguage,
  String extraContext = '',
}) => translateBlocks(
  translator,
  TranslationRequest(
    blocks: [for (final page in pages) ...page.blocks],
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    extraContext: [extraContext, packTranslatorNote].where((s) => s.trim().isNotEmpty).join('\n'),
    keys: [
      for (final page in pages)
        for (var i = 0; i < page.blocks.length; i++) ExchangeLabel(page.number, i + 1).code,
    ],
    pageImages: [
      for (final page in pages) ?page.image,
    ],
  ),
  context,
);

/// Who says which block (`block_N` as in [blocksToJson], or its key), when
/// the user told; empty otherwise. Not in the original.
String speakersForTranslator(List<TextBlock> blocks, {List<String>? keys}) {
  final told = [
    for (final (i, b) in blocks.indexed)
      if (b.speaker case final s?) '${keys?[i] ?? 'block_$i'}: ${s.words}',
  ];
  return told.isEmpty
      ? ''
      : 'Who speaks (use the grammatical gender that fits the speaker: verbs, adjectives): ${told.join('; ')}.';
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

/// Python `str.islower()`: has a cased character and no upper- or
/// title-case one.
bool pyIsLower(String s) {
  var cased = false;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (pyLower(c) != c) return false; // upper or title case
    if (pyUpper(c) != c) cased = true;
  }
  return cased;
}

bool _isCasedChar(String c) => pyUpper(c) != c || pyLower(c) != c;

/// Python `str.istitle()`: upper- and title-case characters only after
/// uncased ones, lower-case ones only after cased ones.
bool pyIsTitle(String s) {
  var cased = false, previousCased = false;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final lower = pyUpper(c) != c && pyLower(c) == c;
    if (_isCasedChar(c) && !lower) {
      if (previousCased) return false;
      previousCased = cased = true;
    } else if (lower) {
      if (!previousCased) return false;
      previousCased = cased = true;
    } else {
      previousCased = false;
    }
  }
  return cased;
}

/// Python `str.title()`: each run of cased characters starts in title case
/// and goes on in lower case ("they're" → "They'Re", as Python does).
String pyTitle(String s) {
  final out = StringBuffer();
  var previousCased = false;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    out.write(previousCased ? pyLower(c) : (_pyTitleSpecial[r] ?? pyUpper(c)));
    previousCased = _isCasedChar(c);
  }
  return out.toString();
}

/// Python `str.capitalize()`: first character in title case, the rest lower.
String pyCapitalize(String s) {
  if (s.isEmpty) return s;
  final runes = s.runes.toList();
  final first = runes.first;
  final head = _pyTitleSpecial[first] ?? pyUpper(String.fromCharCode(first));
  return head + pyLower(String.fromCharCodes(runes.skip(1)));
}
