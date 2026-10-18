// Parity of manga-ocr (mobile ONNX) with the original on the blocks of a
// Japanese and an English page: model input, decoded tokens and text. Needs
// `cts models download manga-ocr-mobile`; skipped otherwise.

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
  const spec = ModelCatalog.mangaOcr;
  final installed = models.fileOf(spec, 'decoder_step.onnx').existsSync();
  final ref = (jsonDecode(File(p.join(repoRoot, 'test_data', 'reference', 'manga_ocr.json')).readAsStringSync()) as Map)
      .cast<String, Object?>();
  late MangaOcrModel model;

  setUpAll(() async {
    if (!installed) return;
    model = MangaOcrModel.open(
      encoder: await models.ensureFile(spec, 'encoder.onnx'),
      decoderInit: await models.ensureFile(spec, 'decoder_init.onnx'),
      decoderStep: await models.ensureFile(spec, 'decoder_step.onnx'),
      vocab: File(await models.ensureFile(spec, 'vocab.txt')).readAsStringSync(),
    );
  });
  tearDownAll(() {
    if (installed) model.dispose();
  });

  for (final pageRef in (ref['pages'] as List).cast<Map>()) {
    final page = pageRef['page'] as String;
    test(page, () async {
      expect(model.text.vocab.length, ref['vocab_size']);
      final image = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$page.jpg'));
      for (final (i, b) in (pageRef['blocks'] as List).cast<Map>().indexed) {
        final box = (b['xyxy'] as List).cast<int>();
        final crop = image.crop(BBox(box[0], box[1], box[2], box[3]));
        final input = mangaOcrPreprocess(crop);
        expect(sha256.convert(input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes)).toString(),
            b['input_sha256'], reason: 'block $i input');
        expect(model.read(crop), b['text'], reason: 'block $i text');
      }
    }, skip: installed ? false : 'model ${spec.id} not downloaded');
  }
}
