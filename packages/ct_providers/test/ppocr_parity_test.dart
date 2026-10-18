// Parity of PaddleOCR recognition with the original comic-translate on the
// detected blocks of every test page: line crops, recognizer inputs, raw
// texts and the final block texts. Needs the PP-OCR models
// (`cts models download ppocr-v5-rec-en ...`); skipped otherwise.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

Map<String, Object?> loadJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  final models = ModelManager(AppPaths.resolve().models);
  final refs = Directory(p.join(repoRoot, 'test_data', 'reference', 'ocr')).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final recognizers = <String, PpocrRecognizer>{};

  tearDownAll(() {
    for (final r in recognizers.values) {
      r.dispose();
    }
  });

  for (final file in refs) {
    final r = loadJson(file.path);
    final page = r['page'] as String;
    final lang = r['lang'] as String;
    final (spec, modelName, dictName) = ppocrRecModels[lang]!;
    final installed = models.fileOf(spec, modelName).existsSync();

    test('$page $lang', () async {
      final image = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$page.jpg'));
      final det = loadJson(p.join(repoRoot, 'test_data', 'reference', 'detection', '$page.json'));
      final blocks = [
        for (final b in (det['blocks'] as List).cast<Map<String, Object?>>())
          TextBlock.fromJson(b)..sourceLang = r['source_lang'] as String,
      ];

      // Line crops: same pixels as the original.
      final perBlock = [for (final b in blocks) blockLineCrops(image, b)];
      final crops = [for (final pb in perBlock) ...pb.crops];
      final expectedCrops = (r['crops'] as List).cast<Map>();
      expect(crops.length, expectedCrops.length, reason: 'crop count');
      for (final (i, c) in crops.indexed) {
        final e = expectedCrops[i];
        expect([c.width, c.height], [e['w'], e['h']], reason: 'crop $i size');
        expect(sha256.convert(c.data).toString(), e['sha256'], reason: 'crop $i pixels');
      }

      // Recognizer inputs (Lanczos resize, BGR, normalisation, padding), in
      // the order the original builds its width buckets.
      final buckets = <int, List<int>>{};
      for (final (i, c) in crops.indexed) {
        buckets.putIfAbsent(recTargetWidth(c), () => []).add(i);
      }
      final inputs = [
        for (final MapEntry(key: w, value: idxs) in buckets.entries)
          for (final i in idxs) recResizeNorm(crops[i], w / ppocrRecHeight),
      ];
      final expectedInputs = (r['inputs_in_bucket_order'] as List).cast<Map>();
      for (final (i, input) in inputs.indexed) {
        expect([3, ppocrRecHeight, input.width], expectedInputs[i]['input_shape'], reason: 'input $i shape');
        expect(sha256.convert(input.data.buffer.asUint8List(input.data.offsetInBytes, input.data.lengthInBytes)).toString(),
            expectedInputs[i]['input_sha256'], reason: 'input $i values');
      }

      final rec = recognizers[lang] ??= PpocrRecognizer.open(
        await models.ensureFile(spec, modelName),
        File(await models.ensureFile(spec, dictName)).readAsStringSync(),
        lang: lang,
      );
      final results = rec.recognize(crops);
      final confs = (r['rec_confs'] as List).cast<num>();
      expect([for (final x in results) x.text], r['rec_texts']);
      for (final (i, x) in results.indexed) {
        expect(x.confidence, closeTo(confs[i].toDouble(), 1e-4), reason: 'confidence $i');
      }

      rec.recognizeBlocks(image, blocks);
      final expectedBlocks = (r['blocks'] as List).cast<Map>();
      for (final (i, b) in blocks.indexed) {
        expect(b.texts, expectedBlocks[i]['texts'], reason: 'block $i texts');
        expect(b.text, expectedBlocks[i]['text'], reason: 'block $i text');
      }
    }, skip: installed ? false : 'model ${spec.id} not downloaded');
  }
}
