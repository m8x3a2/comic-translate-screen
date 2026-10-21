// Parity of script identification ("Auto" source language) with the original
// comic-translate on the detected blocks of every test page: the OSD model's
// best path and the script label of each block. Needs the script model
// (`cts models download osd-script-id`); skipped otherwise. The model inputs
// are checked in packages/ct_core/test/parity/script_test.dart.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

Map<String, Object?> loadJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

RgbImage invert(RgbImage src) =>
    RgbImage(src.width, src.height, Uint8List.fromList([for (final v in src.data) 255 - v]));

void main() {
  final models = ModelManager(AppPaths.resolve().models);
  const spec = ModelCatalog.osdScript;
  final installed = models.fileOf(spec, 'osd_lstm.onnx').existsSync();
  final ref = loadJson(p.join(repoRoot, 'test_data', 'reference', 'script.json'));
  final labels = (ref['labels'] as List).cast<String>();
  final scripts = ScriptIdentifier(models);
  OrtSession? session;

  tearDownAll(() {
    session?.dispose();
    scripts.dispose();
  });

  for (final page in (ref['pages'] as List).cast<Map<String, Object?>>()) {
    final name = page['page'] as String;
    final variants = (page['variants'] as Map).cast<String, Map<String, Object?>>();
    for (final MapEntry(key: variant, value: expected) in variants.entries) {
      test('$name $variant', () async {
        var image = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$name.jpg'));
        if (variant == 'inverted') image = invert(image);
        final det = loadJson(p.join(repoRoot, 'test_data', 'reference', 'detection', '$name.json'));
        final blocks = [
          for (final b in (det['blocks'] as List).cast<Map<String, Object?>>())
            if (variant == 'no_lines')
              (TextBlock.fromJson(b)
                ..lines = []
                ..direction = TextDirection.unknown)
            else
              TextBlock.fromJson(b),
        ];
        session ??= OrtSession.open(
          await models.ensureFile(spec, 'osd_lstm.onnx'),
          config: ScriptIdentifier.sessionConfig,
        );
        final entries = (expected['blocks'] as List).cast<Map<String, Object?>>();
        for (final (i, b) in blocks.indexed) {
          final e = entries[i];
          final input = scriptInputForBlock(image, b);
          if (e['ids'] != null) {
            final out = session!.run({
              'image': OrtTensor.float32(input!.data, [1, 1, scriptInputHeight, input.width]),
            })['scores']!;
            expect(out.shape, e['scores_shape'], reason: 'block $i scores');
            final [steps, classes] = out.shape;
            final scores = out.asFloat32;
            final ids = [
              for (var t = 0; t < steps; t++)
                () {
                  var best = 0;
                  for (var c = 1; c < classes; c++) {
                    if (scores[t * classes + c] > scores[t * classes + best]) best = c;
                  }
                  return best;
                }(),
            ];
            expect(ids, e['ids'], reason: 'block $i best path');
            expect(dominantScript(scores, steps, classes, labels), e['script'], reason: 'block $i');
          }
          expect(await scripts.identify(image, b), e['script'], reason: 'block $i script');
        }
      }, skip: installed ? false : 'script model not downloaded');
    }
  }
}
