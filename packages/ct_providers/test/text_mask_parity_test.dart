// comic-text-detector letters against the Python procedure of the night
// experiment (tools/reference gen_reference.py --only text_mask). Needs the
// model (`cts models download comic-text-detector`); skipped otherwise.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

void main() {
  final models = ModelManager(AppPaths.resolve().models);
  final model = models.fileOf(ModelCatalog.comicTextDetector, 'comic-text-detector.onnx');
  final refs = (jsonDecode(
    File(p.join(repoRoot, 'test_data', 'reference', 'text_mask.json')).readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  ComicTextDetector? ctd;
  tearDownAll(() async => ctd?.dispose());

  for (final r in refs) {
    test(
      '${r['page']}',
      () async {
        ctd ??= ComicTextDetector.open(model.path);
        final image = await ImageCodec.readFile(
          p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '${r['page']}.jpg'),
        );
        final letters = await ctd!.letters(image, PluginContext(log: EventLog([])));
        expect([letters.width, letters.height], r['size']);
        final count = letters.data.where((v) => v != 0).length;
        if (sha256.convert(letters.data).toString() != r['letters_sha256']) {
          // Another ONNX Runtime build may round a few pixels differently.
          final expected = r['letters'] as int;
          expect((count - expected).abs(), lessThanOrEqualTo(expected ~/ 1000 + 1), reason: '$count vs $expected');
        }
        expect(count, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: model.existsSync() ? false : 'model not downloaded',
    );
  }
}
