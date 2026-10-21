/// The "Auto" source language: routing blocks by the script the OSD model
/// found in them. Port of the script helpers of
/// `modules/utils/language_utils.py` and of `_set_source_language` /
/// `_process_auto` in `modules/ocr/processor.py`.
library;

import '../model/language.dart';
import '../model/text_block.dart';

/// OCR "bucket" (one recognizer each) per supported script.
const scriptOcrBuckets = {
  'Latin': 'latin',
  'Cyrillic': 'cyrillic',
  'Japanese': 'japanese',
  'Hangul': 'korean',
  'HanS': 'chinese',
  'HanT': 'chinese',
};

const _scriptLanguageCodes = {
  'Latin': 'en',
  'Cyrillic': 'ru',
  'Japanese': 'ja',
  'Hangul': 'ko',
  'HanS': 'zh',
  'HanT': 'zh',
};

/// Source language told to the translator per script. Latin is left out: the
/// script alone does not tell which Latin-script language a page is in.
const _scriptSourceLanguages = {
  'Cyrillic': 'Russian',
  'Japanese': 'Japanese',
  'Hangul': 'Korean',
  'HanS': 'Chinese',
  'HanT': 'Chinese',
};

/// [script] without the OSD `_vert` / `-dn` suffixes.
String normalizeScript(String script) {
  var base = script;
  while (true) {
    if (base.endsWith('-dn')) {
      base = base.substring(0, base.length - 3);
    } else if (base.endsWith('_vert')) {
      base = base.substring(0, base.length - 5);
    } else {
      return base;
    }
  }
}

/// The OCR bucket for [script]; Chinese when the script is not supported.
String ocrBucketForScript(String script) => scriptOcrBuckets[normalizeScript(script)] ?? 'chinese';

/// The language code for [script]; `zh` when the script is not supported.
String languageCodeForScript(String script) => _scriptLanguageCodes[normalizeScript(script)] ?? 'zh';

/// The source language name for [script]; [Languages.auto] when unknown
/// (and for Latin).
String sourceLanguageForScript(String script) => _scriptSourceLanguages[normalizeScript(script)] ?? Languages.auto;

/// Whether [script] maps onto an OCR bucket.
bool isSupportedScript(String script) => scriptOcrBuckets.containsKey(normalizeScript(script));

double _blockArea(TextBlock b) {
  final w = (b.xyxy.x2 - b.xyxy.x1).toDouble(), h = (b.xyxy.y2 - b.xyxy.y1).toDouble();
  return (w < 1.0 ? 1.0 : w) * (h < 1.0 ? 1.0 : h);
}

/// The script covering at least [threshold] of the area of the blocks with a
/// supported script; empty for a mixed page or when no block has one.
String dominantPageScript(List<TextBlock> blocks, {double threshold = 0.7}) {
  final areas = <String, double>{};
  var total = 0.0;
  for (final b in blocks) {
    final script = normalizeScript(b.script);
    if (!isSupportedScript(script)) continue;
    final area = _blockArea(b);
    areas[script] = (areas[script] ?? 0.0) + area;
    total += area;
  }
  if (areas.isEmpty || total <= 0.0) return '';
  var best = areas.keys.first;
  for (final e in areas.entries) {
    if (e.value > areas[best]!) best = e.key;
  }
  return areas[best]! / total < threshold ? '' : best;
}

/// [sourceLanguage], with [Languages.auto] resolved from the scripts of
/// [blocks] when they tell the language (not for Latin or mixed pages).
String resolveAutoSourceLanguage(List<TextBlock> blocks, String sourceLanguage) {
  if (sourceLanguage != Languages.auto) return sourceLanguage;
  var dominant = dominantPageScript(blocks);
  if (dominant.isEmpty) dominant = dominantPageScript(blocks, threshold: 0.0);
  return dominant.isEmpty ? Languages.auto : sourceLanguageForScript(dominant);
}

/// The script a block is read as: its own when supported, else the page's.
String _resolvedScript(TextBlock b, String dominant) {
  final script = normalizeScript(b.script);
  if (isSupportedScript(script)) return script;
  return dominant.isEmpty ? script : dominant;
}

/// Blocks grouped by OCR bucket (in order of first appearance), each block's
/// `sourceLang` set from its script. [blocks] must have their `script`.
Map<String, List<TextBlock>> autoOcrGroups(List<TextBlock> blocks) {
  final dominant = dominantPageScript(blocks);
  final groups = <String, List<TextBlock>>{};
  for (final b in blocks) {
    final script = _resolvedScript(b, dominant);
    b.sourceLang = languageCodeForScript(script);
    groups.putIfAbsent(ocrBucketForScript(script), () => []).add(b);
  }
  return groups;
}
