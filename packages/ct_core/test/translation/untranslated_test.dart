// Bubbles the translator's answer had nothing for: marked, kept in the
// project, and their lettering is not cleaned.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  TextBlock block(String text, [String translation = '']) =>
      TextBlock(xyxy: const BBox(0, 0, 10, 10), text: text, translation: translation);

  test('the answer marks the blocks it left out; an empty translation is an answer', () {
    final blocks = [block('Hi'), block('...'), block('Bye')];
    final warnings = applyTranslationsJson(blocks, '{"block_0": "Привет", "block_1": ""}');
    expect(warnings, ['block_2 not found in the reply.']);
    expect([for (final b in blocks) b.untranslated], [false, false, true]);
    // Answered later: unmarked.
    applyTranslationsJson([blocks[2]], '{"block_0": "Пока"}');
    expect((blocks[2].untranslated, blocks[2].translation), (false, 'Пока'));
    // No JSON at all: all of them.
    applyTranslationsJson(blocks, 'Sorry, I cannot help.');
    expect(blocks.every((b) => b.untranslated), isTrue);
  });

  test('kept in the project file and in copies', () {
    final b = block('Hi')..untranslated = true;
    expect(TextBlock.fromJson(b.toJson()).untranslated, isTrue);
    expect(b.copy().untranslated, isTrue);
    expect(block('Hi').toJson().containsKey('untranslated'), isFalse);
  });

  test('their lettering is not cleaned', () {
    final blocks = [block('Hi', 'Привет'), block('Bye')..untranslated = true];
    expect(selectInpaintBlocks(blocks).map((b) => b.text), ['Hi']);
    // Nothing translated at all: nothing is cleaned.
    expect(selectInpaintBlocks([block('Bye')..untranslated = true]), isEmpty);
  });

  test('translating again starts unmarked; translators that can tell mark again', () async {
    final blocks = [block('Hi')..untranslated = true, block('!!')..untranslated = true];
    await translateBlocks(
      _Upper(),
      TranslationRequest(blocks: blocks, sourceLanguage: 'English', targetLanguage: 'Russian'),
      PluginContext(log: EventLog.silent()),
    );
    expect([for (final b in blocks) b.untranslated], [false, false]);
  });

  test('several pages in one request: the blocks named by their labels, pictures along', () async {
    final seen = _Seen();
    final picture = RgbImage.filled(4, 4, 0, 0, 0);
    await translatePack(
      seen,
      [
        PackPage(2, [block('Hi'), block('!!'), block('Bye')], image: picture),
        PackPage(5, [block('Well')]),
      ],
      PluginContext(log: EventLog.silent()),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      extraContext: 'A comedy.',
    );
    final r = seen.request!;
    expect(r.keys, ['02-001', '02-003', '05-001'], reason: 'the block without letters is not sent');
    expect(r.pageImages.length, 1);
    expect(r.extraContext, startsWith('A comedy.\n$packTranslatorNote'));
    expect(blocksToJson(r.blocks, keys: r.keys), contains('"05-001": "Well"'));
    final only = r.only([r.blocks[2]]);
    expect(only.keys, ['05-001']);
    expect(only.blocks.single.text, 'Well');
    applyTranslationsJson(r.blocks, '{"02-001": "Привет", "05-001": "Ну"}', keys: r.keys);
    expect([for (final b in r.blocks) b.untranslated], [false, true, false]);
  });
}

/// Upper-cases the text; tells nothing about left-out blocks.
class _Upper implements Translator {
  @override
  PluginInfo get info =>
      const PluginInfo(id: 'upper', displayName: 'Upper', kind: PluginKind.translator, privacy: Privacy.local);

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    for (final b in request.blocks) {
      b.translation = b.text.toUpperCase();
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Keeps what it was asked.
class _Seen implements Translator {
  TranslationRequest? request;

  @override
  PluginInfo get info =>
      const PluginInfo(id: 'seen', displayName: 'Seen', kind: PluginKind.translator, privacy: Privacy.local);

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async => this.request = request;

  @override
  Future<void> dispose() async {}
}
