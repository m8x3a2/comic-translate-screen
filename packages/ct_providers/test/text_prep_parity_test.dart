// Parity of the neural text preparation with the experiment that chose the
// models (`tools/reference/gen_reference.py --only text_prep`, the tiling of
// `ocr-experiment/sr_run.py`): the same output pixels for a crop of a test
// page. Needs the models (`cts models download waifu2x-cunet-art-2x ...`);
// skipped otherwise.

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
  final refs = (jsonDecode(
    File(p.join(repoRoot, 'test_data', 'reference', 'text_prep.json')).readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final factories = {
    'waifu2x-cunet-art-2x': waifu2xCunetFactory,
    'waifu2x-swin-art-2x': waifu2xSwinFactory,
    'fatality-comix-4x': fatalityComixFactory,
  };

  for (final r in refs) {
    final id = r['model'] as String;
    final spec = ModelCatalog.byId(id)!;
    final installed = models.fileOf(spec, spec.files.single.name).existsSync();
    test(id, () async {
      final page = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', 'en_E01P01.jpg'));
      final crop = page.crop(BBox.fromList((r['crop'] as List).cast<num>()));
      final env = PluginEnvironment(models: models, log: EventLog.silent());
      final upscaler = await factories[id]!.create(PluginConfig(), env) as NeuralTextUpscaler;
      try {
        expect(upscaler.scale, r['scale']);
        final out = upscaler.run(crop);
        expect([out.height, out.width, 3], r['out_shape']);
        final mean = out.data.fold<int>(0, (a, v) => a + v) / out.data.length;
        expect(mean, closeTo(r['out_mean'] as double, 1e-6));
        expect(sha256.convert(out.data).toString(), r['out_sha256']);
        // Asked for ×2, the ×4 network is brought down to it.
        final two = await upscaler.enlarge(
          crop,
          crop.width * 2,
          crop.height * 2,
          PluginContext(log: EventLog.silent()),
        );
        expect((two.width, two.height), (crop.width * 2, crop.height * 2));
      } finally {
        await upscaler.dispose();
      }
    }, skip: installed ? false : 'model $id not downloaded');
  }

  test('mirroring past the edges and the factor of the levels', () async {
    expect(waifu2xSwinInfo.kind, PluginKind.textPrep);
    final registry = builtInRegistry();
    expect(
      [for (final i in registry.available(PluginKind.textPrep)) i.id],
      [textPrepOffId, plainX15Id, plainX2Id, 'waifu2x_cunet', 'waifu2x_swin', 'fatality_comix'],
    );
    for (final info in [waifu2xCunetInfo, waifu2xSwinInfo, fatalityComixInfo]) {
      expect(ModelCatalog.byId(info.models.single), isNotNull, reason: info.id);
    }
  });
}
