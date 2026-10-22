// The OPUS-MT translator against the Python `sentencepiece` package and the
// same ONNX models run greedily from Python (test_data/reference/opus_mt.json).
// Needs the downloaded models (`cts models download opus-mt-en-ru opus-mt-ru-en`);
// skipped otherwise (e.g. on CI).

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

void main() {
  final models = ModelManager(AppPaths.resolve().models);
  final reference = (jsonDecode(
    File(p.join(repoRoot, 'test_data', 'reference', 'opus_mt.json')).readAsStringSync(),
  ) as Map).cast<String, Object?>();

  for (final spec in [ModelCatalog.opusMtEnRu, ModelCatalog.opusMtRuEn]) {
    final installed = models.fileOf(spec, 'decoder_model_merged_quantized.onnx').existsSync();
    group(spec.id, () {
      late OpusMtEngine engine;
      setUpAll(() async {
        if (!installed) return;
        engine = await OpusMtTranslator(models).engine(spec);
      });

      for (final c in (reference[spec.id] as List).cast<Map<String, Object?>>()) {
        final text = c['text'] as String;
        test(jsonEncode(text), () {
          final sp = engine.tokenizer.source;
          expect(sp.normalize(text), c['normalized'], reason: 'normalization');
          expect(sp.encodeAsPieces(text), c['pieces'], reason: 'pieces');
          expect(engine.tokenizer.encode(text), c['ids'], reason: 'ids');
          final greedy = (c['greedy'] as List?)?.cast<int>();
          if (greedy != null) {
            expect(engine.generate((c['ids'] as List).cast<int>(), beams: 1), [
              for (final id in greedy)
                if (id != engine.tokenizer.eosId) id,
            ]);
          }
        }, skip: installed ? false : 'models not downloaded');
      }
    });
  }

  test('comic text is prepared for the model', () {
    expect(
      prepareComicText('IF ANYTHING DANGER-\nOUS LOCKS ON TO ME, I\'M DONE FOR!'),
      "If anything dangerous locks on to me, I'm done for!",
    );
    expect(prepareComicText('Hello there.'), 'Hello there.');
    expect(splitSentences('What? No... Not here! Fine.'), ['What?', 'No...', 'Not here!', 'Fine.']);
    expect(sentenceCase('ВСЁ ХОРОШО. ДА?'), 'Всё хорошо. Да?');
  });
}
