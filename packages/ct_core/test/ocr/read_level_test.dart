import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

/// "the" is very common; "potion" and "grateful" are common enough;
/// "zyxt" is not (Zipf below 2.5 for a total of about 10^9.4 words).
const _list =
    'the 1000000000\nyou 500000000\nbe 500000000\nshould 400000000\npotion 1000\ngrateful 2000\n'
    'dad 3000\nzyxt 1\n';

/// Reads every block as the next of [texts] and remembers what it was given.
class _Ocr implements OcrEngine {
  _Ocr(this.id, this.texts);

  final String id;
  final List<String> texts;
  final read = <List<String>>[];

  @override
  PluginInfo get info => PluginInfo(id: id, displayName: id, kind: PluginKind.ocr, privacy: Privacy.local);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    read.add([for (final b in blocks) b.text]);
    for (final (i, b) in blocks.indexed) {
      b
        ..text = texts[i]
        ..texts = [texts[i]];
    }
  }

  @override
  Future<void> dispose() async {}
}

class _Failing extends _Ocr {
  _Failing() : super('vlm', const []);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async => throw StateError('out of memory');
}

TextBlock _block() => TextBlock(xyxy: const BBox(0, 0, 10, 10));

final _context = PluginContext(log: EventLog.silent());
final _image = RgbImage.filled(10, 10, 255, 255, 255);

void main() {
  final words = EnglishWords.parse(_list);

  test('common words by word frequency', () {
    expect(words.isWord('THE'), isTrue);
    expect(words.isWord('Potion'), isTrue);
    expect(words.isWord('zyxt'), isFalse);
    expect(words.isWord('a'), isTrue);
    expect(words.isWord('x'), isFalse);
    expect(words.isWord('42'), isTrue);
    expect(words.isWord('T2E'), isFalse);
    expect(words.isWord("DON'T"), isTrue, reason: 'contraction');
    expect(words.isWord("DAD'S"), isTrue, reason: 'word + suffix');
    expect(words.isWord("ZYXT'S"), isFalse);
  });

  test('score: share of words, more words win a tie', () {
    expect(words.score('YOU SHOULD BE GRATEFUL!!'), closeTo(1.004, 1e-9));
    expect(words.score('YOU SHOULD BE GRATE-FUL!!'), closeTo(0.754, 1e-9), reason: '"GRATE" and "FUL" are not words');
    expect(words.score('...'), 0);
    expect(words.doubtful(''), isTrue);
    expect(words.doubtful('YOU SHOULD BE GRATEFUL!!'), isFalse);
    expect(words.doubtful('YOU SHOULD ZYXT'), isTrue);
  });

  test('medium: the reading with more words wins, the first one on a tie', () async {
    final base = _Ocr('ppocr', ['YOU SHOULD ZYXT', 'THE POTION', '']);
    final second = _Ocr('second', ['YOU SHOULD BE', 'THE POTION!', 'DAD']);
    final ocr = LeveledOcr(base, ReadLevel.medium, words, second: second);
    final blocks = [_block(), _block(), _block()];
    await ocr.recognize(_image, blocks, sourceLanguage: 'English', context: _context);
    expect([for (final b in blocks) b.text], ['YOU SHOULD BE', 'THE POTION', 'DAD']);
    expect(blocks[0].texts, ['YOU SHOULD BE']);
  });

  test('high: the slow reader reads blocks either reader is unsure of; an empty reading is not taken', () async {
    final base = _Ocr('ppocr', ['YOU SHOULD ZYXT', 'THE POTION', 'ZYXT', 'YOU', 'THE']);
    final second = _Ocr('second', ['THE', 'THE POTION', 'ZYXT', 'ZYXT YOU', 'THE']);
    final vlm = _Ocr('vlm', ['YOU SHOULD BE', '', 'YOU!']);
    final ocr = LeveledOcr(base, ReadLevel.high, words, second: second, vlm: vlm);
    final blocks = [for (var i = 0; i < 5; i++) _block()];
    await ocr.recognize(_image, blocks, sourceLanguage: 'English', context: _context);
    expect(vlm.read.single, ['THE', 'ZYXT', 'YOU']);
    expect([for (final b in blocks) b.text], ['YOU SHOULD BE', 'THE POTION', 'ZYXT', 'YOU!', 'THE']);
  });

  test('ultra: the slow reader reads every block', () async {
    final base = _Ocr('ppocr', ['THE POTION', 'YOU']);
    final vlm = _Ocr('vlm', ['THE POTION!', 'YOU!']);
    final ocr = LeveledOcr(base, ReadLevel.ultra, words, vlm: vlm);
    final blocks = [_block(), _block()];
    await ocr.recognize(_image, blocks, sourceLanguage: 'English', context: _context);
    expect([for (final b in blocks) b.text], ['THE POTION!', 'YOU!']);
  });

  test('a slow reader that fails leaves the fast readings', () async {
    final base = _Ocr('ppocr', ['ZYXT']);
    final ocr = LeveledOcr(base, ReadLevel.ultra, words, vlm: _Failing());
    final blocks = [_block()];
    await ocr.recognize(_image, blocks, sourceLanguage: 'English', context: _context);
    expect(blocks.single.text, 'ZYXT');
  });

  test('other languages: the chosen OCR alone', () async {
    final base = _Ocr('ppocr', ['ZYXT']);
    final second = _Ocr('second', ['THE']);
    final ocr = LeveledOcr(base, ReadLevel.medium, words, second: second);
    final blocks = [_block()];
    await ocr.recognize(_image, blocks, sourceLanguage: 'French', context: _context);
    expect(blocks.single.text, 'ZYXT');
    expect(second.read, isEmpty);
  });

  test('settings keep a level per content kind', () {
    final s = AppSettings.fromJson({
      'tools': {'read_level': 'high', 'screen_read_level': 'simple'},
    });
    expect(s.activeReadLevel, ReadLevel.high);
    s.contentKind = ContentKind.screens;
    expect(s.activeReadLevel, ReadLevel.simple);
    expect(AppSettings.fromJson(s.toJson()).screenReadLevel, ReadLevel.simple);
    expect(AppSettings().readLevel, ReadLevel.medium);
    expect(readLevelPlugins(AppSettings(), 'English'), [secondReaderId]);
    expect(readLevelPlugins(AppSettings(), 'Russian'), isEmpty);
    expect(readLevelPlugins(AppSettings()..ocr = 'windows_ocr', 'English'), isEmpty);
  });
}
