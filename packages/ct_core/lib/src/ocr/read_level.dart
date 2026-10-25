/// Recognition levels of the settings (new in this project): how many
/// readers look at each English block. Chosen by the night experiment of
/// 2026-10-25 (`self\rec-experiment`): PP-OCRv5 and PP-OCRv6 small make
/// different mistakes, and the reading with more dictionary words is the
/// right one far more often; PaddleOCR-VL reads best of all but slowly, so
/// "High" lets it read only the blocks the fast readers are unsure of.
library;

import 'dart:math' as math;

import '../cancel.dart';
import '../image/raster.dart';
import '../model/text_block.dart';
import '../models/model_manager.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';
import '../plugins/registry.dart';
import '../plugins/settings_schema.dart';
import '../settings/app_settings.dart';

/// PP-OCRv6 small reading English: the second reader.
const secondReaderId = 'ppocr_v6_small';

/// PaddleOCR-VL: the slow reader of "High" and "Ultra".
const vlmReaderId = 'paddleocr_vl';

/// The OCR plugins the levels add readers to (both read English with
/// PP-OCRv5).
const leveledOcrIds = {'default', 'ppocr'};

enum ReadLevel {
  /// The chosen OCR alone.
  simple,

  /// PP-OCRv6 small reads every block too; the reading with more dictionary
  /// words wins.
  medium,

  /// "Medium", then PaddleOCR-VL reads the blocks where either fast reading
  /// has a word missing from the dictionary (about half): nearly "Ultra" in
  /// half the time.
  high,

  /// PaddleOCR-VL reads every block.
  ultra;

  /// The reader plugins this level adds.
  List<String> get readers => switch (this) {
    simple => const [],
    medium => const [secondReaderId],
    high => const [secondReaderId, vlmReaderId],
    ultra => const [vlmReaderId],
  };
}

/// Contractions as dictionaries list them without the apostrophe.
const _contractions = {
  'arent', 'isnt', 'wasnt', 'werent', 'dont', 'doesnt', 'didnt', 'wont', 'wouldnt', 'couldnt', 'shouldnt', //
  'havent', 'hasnt', 'hadnt', 'mustnt', 'neednt', 'aint', 'cant', 'im', 'ive', 'youre', 'youve', 'youll', 'youd',
  'theyre', 'theyve', 'theyll', 'theyd', 'weve', 'thats', 'theres', 'heres', 'whos', 'whats', 'wheres', 'lets',
};

/// What may follow the apostrophe of a word in the dictionary ("DAD'S",
/// "IT'LL").
const _suffixes = {'s', 't', 'll', 're', 've', 'm', 'd'};

/// Stripped from both ends of a word before it is looked up.
const _punctuation = '.,!?;:"()[]…-—–~*';

final _letters = RegExp(r"^[A-Za-z']+$");
final _digits = RegExp(r'^[0-9]+$');

/// Common English words (word frequency, as `wordfreq` with a Zipf value of
/// at least 2.5 in the experiment): tells a right reading from a wrong one.
class EnglishWords {
  EnglishWords._(this._common);

  final Set<String> _common;

  int get length => _common.length;

  /// A list of `word count` lines (the SymSpell frequency dictionary of
  /// `assets/dict`); words at least [minZipf] common (log10 of the
  /// occurrences per billion words) are kept.
  factory EnglishWords.parse(String text, {double minZipf = 2.5}) {
    final words = <(String, int)>[];
    var total = 0;
    for (final line in text.split('\n')) {
      final space = line.indexOf(' ');
      if (space <= 0) continue;
      final count = int.tryParse(line.substring(space + 1).trim());
      if (count == null || count <= 0) continue;
      words.add((line.substring(0, space).toLowerCase(), count));
      total += count;
    }
    final least = total * math.pow(10, minZipf - 9);
    return EnglishWords._({
      for (final (w, count) in words)
        if (count >= least) w,
    });
  }

  /// A real English word or a plain number; letters mixed with digits
  /// ("T2E") are not.
  bool isWord(String word) {
    if (_digits.hasMatch(word)) return true;
    if (!_letters.hasMatch(word)) return false;
    final w = _stripChars(word, "'").toLowerCase();
    if (w.length == 1) return w == 'a' || w == 'i';
    if (w.isEmpty) return false;
    if (_common.contains(w)) return true;
    final apostrophe = w.indexOf("'");
    if (apostrophe < 0) return false;
    if (_contractions.contains(w.replaceAll("'", ''))) return true;
    final head = w.substring(0, apostrophe);
    return _suffixes.contains(w.substring(apostrophe + 1)) && _common.contains(head);
  }

  /// The share of dictionary words in [text], plus a thousandth per word:
  /// of two readings with the same share, the one with more words wins.
  double score(String text) {
    final words = [
      for (final w in text.split(RegExp(r'\s+')))
        if (_stripChars(w, _punctuation) case final s when s.isNotEmpty) s,
    ];
    if (words.isEmpty) return 0;
    var ok = 0;
    for (final w in words) {
      if (isWord(w) || w.split('-').where((p) => p.isNotEmpty).every(isWord)) ok++;
    }
    return ok / words.length + 0.001 * words.length;
  }

  /// Nothing read, or a word missing from the dictionary (in a short block):
  /// worth a second look by the slow reader.
  bool doubtful(String text) => text.trim().isEmpty || score(text) < 0.999;

  static String _stripChars(String s, String chars) {
    var a = 0, b = s.length;
    while (a < b && chars.contains(s[a])) {
      a++;
    }
    while (b > a && chars.contains(s[b - 1])) {
      b--;
    }
    return s.substring(a, b);
  }
}

/// The chosen OCR with the readers of a recognition level (English only;
/// other languages are read by the chosen OCR alone).
class LeveledOcr implements OcrEngine {
  LeveledOcr(this.base, this.level, this.words, {this.second, this.vlm});

  final OcrEngine base;
  final ReadLevel level;
  final EnglishWords words;
  final OcrEngine? second;
  final OcrEngine? vlm;

  @override
  PluginInfo get info => base.info;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    await base.recognize(image, blocks, sourceLanguage: sourceLanguage, context: context);
    if (sourceLanguage != 'English' || blocks.isEmpty) return;
    final sw = Stopwatch()..start();
    var secondWon = 0;
    // Blocks either reader is unsure of: the slow reader looks at them again.
    final unsure = <TextBlock>{};
    final second = this.second;
    if (second != null) {
      await context.cancel.checkpoint();
      final other = [for (final b in blocks) b.copy()];
      await second.recognize(image, other, sourceLanguage: sourceLanguage, context: context);
      for (final (i, b) in blocks.indexed) {
        if (words.doubtful(b.text) || words.doubtful(other[i].text)) unsure.add(b);
        if (words.score(other[i].text) > words.score(b.text)) {
          _take(b, other[i]);
          secondWon++;
        }
      }
    }
    var vlmRead = 0;
    final vlm = this.vlm;
    if (vlm != null) {
      final todo = [
        for (final b in blocks)
          if (level == ReadLevel.ultra || unsure.contains(b) || words.doubtful(b.text)) b,
      ];
      if (todo.isNotEmpty) {
        await context.cancel.checkpoint();
        final copies = [for (final b in todo) b.copy()];
        try {
          await vlm.recognize(image, copies, sourceLanguage: sourceLanguage, context: context);
          for (final (i, b) in todo.indexed) {
            if (copies[i].text.trim().isEmpty) continue;
            _take(b, copies[i]);
            vlmRead++;
          }
        } on CancelledException {
          rethrow;
        } catch (e, st) {
          // The fast readings stay.
          context.log.error('vlm_failed', e, st);
        }
      }
    }
    context.log.info('read_level', {
      'level': level.name,
      'blocks': blocks.length,
      if (second != null) 'second_won': secondWon,
      if (vlm != null) 'vlm_read': vlmRead,
      'ms': sw.elapsedMilliseconds,
    });
  }

  static void _take(TextBlock to, TextBlock from) {
    to
      ..texts = from.texts
      ..text = from.text
      ..skippedSmallTexts = from.skippedSmallTexts;
  }

  /// The readers belong to the registry, which releases them.
  @override
  Future<void> dispose() async {}
}

/// [base] with the readers of recognition [level], or [base] itself: level
/// "Simple", an OCR the levels do not apply to, or no word list. A reader
/// whose model is not downloaded is left out.
Future<OcrEngine> withReadLevel(
  PluginRegistry registry,
  ReadLevel level,
  OcrEngine base,
  EnglishWords? words,
  PluginEnvironment env, {
  Map<String, PluginConfig> configs = const {},
}) async {
  if (level == ReadLevel.simple || words == null || !leveledOcrIds.contains(base.info.id)) return base;
  Future<OcrEngine?> reader(String id) async {
    if (!level.readers.contains(id) || !registry.contains(id)) return null;
    try {
      return await registry.instance<OcrEngine>(id, configs[id] ?? PluginConfig(), env);
    } on ModelNotInstalledException catch (e) {
      env.log.warn('reader_model_missing', {'id': id, 'error': e.toString()});
      return null;
    } catch (e, st) {
      // A reader is an improvement: one that cannot start (no memory, no
      // library on this system) leaves the reading to the others.
      env.log.error('reader_failed', e, st);
      return null;
    }
  }

  final second = await reader(secondReaderId);
  final vlm = await reader(vlmReaderId);
  if (second == null && vlm == null) return base;
  return LeveledOcr(base, level, words, second: second, vlm: vlm);
}

/// The reader plugins the recognition level of [settings] needs for
/// [sourceLanguage] (their models are downloaded with the OCR's).
List<String> readLevelPlugins(AppSettings settings, String sourceLanguage) =>
    leveledOcrIds.contains(settings.ocr) && sourceLanguage == 'English' ? settings.activeReadLevel.readers : const [];
