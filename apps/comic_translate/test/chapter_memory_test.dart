// "Remember earlier pages of the chapter": what goes to the translator.

import 'dart:typed_data';

import 'package:comic_translate/pipeline/page_pipeline.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

TextBlock _b(String text, String translation) =>
    TextBlock(xyxy: const BBox(0, 0, 1, 1), text: text, translation: translation);

/// A translator that writes down the context it got and translates by a
/// table.
class _Recorder implements Translator {
  final contexts = <String>[];

  @override
  PluginInfo get info => const PluginInfo(
    id: 'recorder',
    displayName: 'Recorder',
    description: '',
    kind: PluginKind.translator,
    privacy: Privacy.local,
  );

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    contexts.add(request.extraContext);
    for (final b in request.blocks) {
      b.translation = '[${b.text}]';
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('off: nothing is remembered in the note; on: the last pages of the chapter, oldest first', () {
    final m = ChapterMemory()
      ..remember('ch1', [_b('Hi, Ash.', 'Привет, Эш.')])
      ..remember('ch1', [_b('Run!', 'Беги!'), _b('', '')]);
    expect(m.noteFor('ch1', 0), isEmpty);
    final note = m.noteFor('ch1', 2);
    expect(note, contains('Hi, Ash. → Привет, Эш.'));
    expect(note.indexOf('Hi, Ash.'), lessThan(note.indexOf('Run!')));
    expect(m.noteFor('ch1', 1), isNot(contains('Ash')));
    // Another chapter: nothing; remembering it starts afresh.
    expect(m.noteFor('ch2', 2), isEmpty);
    m.remember('ch2', [_b('New.', 'Новое.')]);
    expect(m.noteFor('ch2', 5), isNot(contains('Ash')));
  });

  test('the note stays short: older pages drop first', () {
    final m = ChapterMemory();
    for (var i = 0; i < 8; i++) {
      m.remember('c', [_b('Line $i ${'x' * 300}', 'Строка $i')]);
    }
    final note = m.noteFor('c', 8);
    expect(note.length, lessThan(ChapterMemory.maxChars + 400));
    expect(note, contains('Line 7'));
    expect(note, isNot(contains('Line 0')));
  });

  test('pages translated one after another carry the earlier ones to the translator', () async {
    final t = _Recorder();
    final m = ChapterMemory();
    final settings = AppSettings()
      ..extraContext = 'Glossary: Ash → Эш'
      ..rememberPages = 2;
    final image = RgbImage(1, 1, Uint8List(3));
    for (final text in ['One.', 'Two.', 'Three.']) {
      await translatePageBlocks(
        t,
        image,
        [_b(text, '')],
        settings,
        PluginContext(log: EventLog.silent()),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        memory: m,
        chapter: 'ch',
      );
    }
    expect(t.contexts[0], 'Glossary: Ash → Эш');
    expect(t.contexts[1], contains('One. → [One.]'));
    expect(t.contexts[2], allOf(contains('One.'), contains('Two. → [Two.]'), startsWith('Glossary')));
    // Off: the context is the settings' only.
    settings.rememberPages = 0;
    await translatePageBlocks(
      t,
      image,
      [_b('Four.', '')],
      settings,
      PluginContext(log: EventLog.silent()),
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      memory: m,
      chapter: 'ch',
    );
    expect(t.contexts.last, 'Glossary: Ash → Эш');
  });

  test('the chapter of a page is its folder or archive', () {
    expect(chapterOfPath(null), '');
    expect(chapterOfPath('C:/manga/ch01/003.png'), 'C:/manga/ch01');
  });
}
