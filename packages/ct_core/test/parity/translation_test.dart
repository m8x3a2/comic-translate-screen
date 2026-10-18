// Parity of the LLM translation protocol with the original: prompts, the
// block JSON, reply parsing, the "worth translating" filter and upper case.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

import 'reference.dart';

void main() {
  final ref = loadReference('translation.json');

  test('system prompt', () {
    for (final p in (ref['prompts'] as List).cast<Map>()) {
      expect(llmSystemPrompt(p['source'] as String, p['target'] as String), p['system']);
    }
  });

  test('block JSON and user prompt', () {
    for (final r in (ref['raw'] as List).cast<Map>()) {
      final blocks = [
        for (final t in (r['texts'] as List).cast<String>()) TextBlock(xyxy: const BBox(0, 0, 1, 1), text: t),
      ];
      final json = blocksToJson(blocks);
      expect(json, r['json']);
      expect(llmUserPrompt('A comic about witches.', json), r['user_prompt']);
    }
  });

  test('reply parsing', () {
    for (final r in (ref['replies'] as List).cast<Map>()) {
      final blocks = [for (var i = 0; i < 3; i++) TextBlock(xyxy: const BBox(0, 0, 1, 1), text: 't$i')..translation = 'old'];
      final reply = r['reply'] as String;
      applyTranslationsJson(blocks, reply);
      final got = [for (final b in blocks) b.translation];
      if (r['error'] != null) {
        // The original fails here; we recover the first valid JSON object.
        expect(got, ['a', 'old', 'c'], reason: reply);
        continue;
      }
      final expected = [for (final v in r['translations'] as List) v == null ? '' : '$v'];
      expect(got, expected, reason: reply);
    }
    expect(() => applyTranslationsJson([TextBlock(xyxy: const BBox(0, 0, 1, 1))], '{"block_0": }'),
        throwsFormatException);
  });

  test('translatable content', () {
    for (final c in (ref['translatable'] as List).cast<Map>()) {
      expect(hasTranslatableContent(c['text'] as String), c['result'], reason: '"${c['text']}"');
    }
  });

  test('upper case', () {
    for (final c in (ref['upper_case'] as List).cast<Map>()) {
      final b = TextBlock(xyxy: const BBox(0, 0, 1, 1))..translation = c['in'] as String;
      setUpperCase([b], c['upper'] as bool);
      expect(b.translation, c['out'], reason: '${c['in']} upper=${c['upper']}');
    }
  });
}
