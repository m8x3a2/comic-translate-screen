// Parity of page inpainting with the original: mask, fast bubble fill,
// patch/full routing and the AOT / LaMa results. Needs the models
// (`cts models download aot-inpainting lama-manga`); skipped otherwise.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

Map<String, Object?> loadJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

String sha(List<int> data) => sha256.convert(data).toString();

double psnr(RgbImage a, RgbImage b) {
  var se = 0.0;
  for (var i = 0; i < a.data.length; i++) {
    final d = a.data[i] - b.data[i];
    se += d * d;
  }
  if (se == 0) return double.infinity;
  final mse = se / a.data.length;
  return 10 * math.log(255 * 255 / mse) / math.ln10;
}

void main() {
  final models = ModelManager(AppPaths.resolve().models);
  final refs = Directory(p.join(repoRoot, 'test_data', 'reference', 'inpaint')).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final inpainters = <String, InpaintModel>{};

  for (final file in refs) {
    final r = loadJson(file.path);
    final page = r['page'] as String;
    final modelName = r['model'] as String;
    final (spec, fileName) = modelName == 'aot'
        ? (ModelCatalog.aot, 'aot.onnx')
        : (ModelCatalog.lamaManga, 'lama-manga-dynamic.onnx');
    final installed = models.fileOf(spec, fileName).existsSync();

    test('$page $modelName ${r['strategy']}', () async {
      final image = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$page.jpg'));
      final det = loadJson(p.join(repoRoot, 'test_data', 'reference', 'detection', '$page.json'));
      final blocks = [
        for (final b in (det['blocks'] as List).cast<Map<String, Object?>>())
          TextBlock.fromJson(b)
            ..text = 'text'
            ..translation = 'x',
      ];
      final mask = generateMask(image, blocks);
      expect(sha(mask.data), r['mask_sha256'], reason: 'mask');

      final (fastImage, residual, cleaned) = applyFastBubbleCleanup(image, mask, blocks);
      expect(cleaned, r['fast_filled_blocks'], reason: 'fast-filled blocks');
      expect(sha(residual.data), r['residual_mask_sha256'], reason: 'residual mask');
      expect(sha(fastImage.data), r['fast_fill_image_sha256'], reason: 'fast fill pixels');

      final model = inpainters[modelName] ??= (modelName == 'aot'
              ? AotInpainter.open(models.fileOf(spec, fileName).path).model
              : LamaInpainter.open(models.fileOf(spec, fileName).path).model);
      final config = switch (r['strategy']) {
        'Resize' => const InpaintConfig(strategy: HdStrategy.resize, resizeLimit: 960),
        'Crop' => const InpaintConfig(strategy: HdStrategy.crop, cropMargin: 512, cropTriggerSize: 512),
        _ => const InpaintConfig(strategy: HdStrategy.original),
      };
      final report = InpaintReport();
      final result = await inpaintPage(image, mask, config, (img, m) async => model.call(img, m, config), blocks: blocks, report: report);
      final expectedMode = r['mode'] == 'none' ? 'fast-fill-only' : r['mode'];
      expect(report.mode, expectedMode, reason: 'routing');

      if (sha(result.data) == r['result_sha256']) return;
      // Not bit-exact: the network outputs differ slightly; compare pixels.
      final region = r['result_region'] as Map?;
      expect(region?['png'], isNotNull, reason: 'result differs from the original and no reference pixels are stored');
      final box = (region!['box'] as List).cast<int>();
      final expected = ImageCodec.decode(base64Decode(region['png'] as String));
      final actual = result.crop(BBox(box[0], box[1], box[2], box[3]));
      final value = psnr(actual, expected);
      printOnFailure('PSNR $value dB');
      expect(value, greaterThan(45), reason: 'result too different from the original (PSNR $value dB)');
    }, skip: installed ? false : 'model ${spec.id} not downloaded', timeout: const Timeout(Duration(minutes: 5)));
  }
}
