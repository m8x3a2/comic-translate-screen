/// PaddleOCR (PP-OCRv5/v6 ONNX) — the default local OCR. Port of
/// `modules/ocr/ppocr/engine.py` and the language routing of
/// `modules/ocr/factory.py`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

import 'script_id.dart';

const ppocrInfo = PluginInfo(
  id: 'ppocr',
  displayName: 'PaddleOCR',
  description: 'Recognizes text on your computer with PP-OCR models (one small model per script).',
  kind: PluginKind.ocr,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['ppocr-v5-rec-en'],
  modelsForLanguage: ppocrModelsFor,
);

final ppocrFactory = PluginFactory<OcrEngine>(ppocrInfo, (config, env) async {
  return PpocrEngine(env.models, device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu, log: env.log);
});

/// Recognizer model per PP-OCR language (`LANG_TO_REC_MODEL`).
const ppocrRecModels = <String, (ModelSpec, String, String)>{
  'en': (ModelCatalog.ppocrRecEn, 'en_PP-OCRv5_rec_mobile_infer.onnx', 'ppocrv5_en_dict.txt'),
  'latin': (ModelCatalog.ppocrRecLatin, 'latin_PP-OCRv5_rec_mobile_infer.onnx', 'ppocrv5_latin_dict.txt'),
  'ru': (ModelCatalog.ppocrRecEslav, 'eslav_PP-OCRv5_rec_mobile_infer.onnx', 'ppocrv5_eslav_dict.txt'),
  'ko': (ModelCatalog.ppocrRecKorean, 'korean_PP-OCRv5_rec_mobile_infer.onnx', 'ppocrv5_korean_dict.txt'),
  'ch': (ModelCatalog.ppocrRecChinese, 'PP-OCRv6_small_rec.onnx', 'PP-OCRv6_small_rec.txt'),
  'ja': (ModelCatalog.ppocrRecChinese, 'PP-OCRv6_small_rec.onnx', 'PP-OCRv6_small_rec.txt'),
};

/// PP-OCR language for a source language (`OCRFactory._create_new_engine`).
/// "Auto" has none: its blocks are routed by script ([ppocrLanguageForBucket]).
String ppocrLanguageFor(String sourceLanguage) => switch (sourceLanguage) {
  'English' => 'en',
  'Korean' => 'ko',
  'Chinese' => 'ch',
  'Russian' => 'ru',
  'Japanese' => 'ja',
  'French' || 'Spanish' || 'Italian' || 'German' || 'Dutch' => 'latin',
  _ => throw UnsupportedError('No OCR model for source language "$sourceLanguage".'),
};

/// PP-OCR language for an "Auto" OCR bucket (`script_factories`).
String ppocrLanguageForBucket(String bucket) => switch (bucket) {
  'latin' => 'latin',
  'cyrillic' => 'ru',
  'japanese' => 'ja',
  'korean' => 'ko',
  _ => 'ch',
};

/// The recognizer model for [sourceLanguage]; for "Auto", the script model
/// and a recognizer for every script.
List<String> ppocrModelsFor(String sourceLanguage) {
  if (sourceLanguage == Languages.auto) {
    return {
      scriptModelId,
      for (final bucket in scriptOcrBuckets.values) ppocrRecModels[ppocrLanguageForBucket(bucket)]!.$1.id,
    }.toList();
  }
  return [ppocrRecModels[ppocrLanguageFor(sourceLanguage)]!.$1.id];
}

/// Sets every block's source language code, as the original OCR processor
/// does before recognition.
void applySourceLanguage(List<TextBlock> blocks, String sourceLanguage) {
  final code = Languages.byName(sourceLanguage)?.code ?? 'en';
  for (final b in blocks) {
    b.sourceLang = code;
  }
}

class PpocrEngine implements OcrEngine {
  PpocrEngine(this._models, {this.device = OrtDevice.cpu, this.log});

  final ModelManager _models;
  final OrtDevice device;
  final EventLog? log;
  final _recognizers = <String, PpocrRecognizer>{};

  /// Script model for the "Auto" source language.
  late final scripts = ScriptIdentifier(_models, log: log);

  @override
  PluginInfo get info => ppocrInfo;

  /// Loads (once) the recognizer for a PP-OCR language.
  Future<PpocrRecognizer> recognizer(String lang) async {
    final existing = _recognizers[lang];
    if (existing != null) return existing;
    final (spec, model, dict) = ppocrRecModels[lang]!;
    final modelPath = await _models.ensureFile(spec, model);
    final dictPath = await _models.ensureFile(spec, dict);
    final r = PpocrRecognizer.open(modelPath, File(dictPath).readAsStringSync(), lang: lang, device: device);
    log?.info('ocr_session', {
      'engine': 'ppocr',
      'lang': lang,
      'model': spec.id,
      'device': r.device.name,
      if (r.fallbackReason != null) 'fallback': r.fallbackReason,
    });
    return _recognizers[lang] = r;
  }

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    if (sourceLanguage == Languages.auto) {
      return recognizeAuto(scripts, image, blocks, context, (bucket, group) async {
        (await recognizer(ppocrLanguageForBucket(bucket))).recognizeBlocks(image, group);
      });
    }
    applySourceLanguage(blocks, sourceLanguage);
    final rec = await recognizer(ppocrLanguageFor(sourceLanguage));
    context.cancel.throwIfCancelled();
    rec.recognizeBlocks(image, blocks);
  }

  @override
  Future<void> dispose() async {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
    scripts.dispose();
  }
}

/// One PP-OCR recognition model with its dictionary.
class PpocrRecognizer {
  PpocrRecognizer._(this._session, this.decoder);

  factory PpocrRecognizer.open(
    String modelPath,
    String dictionary, {
    required String lang,
    OrtDevice device = OrtDevice.cpu,
  }) {
    final threads = switch (lang) {
      'latin' => 3,
      'ko' => 6,
      _ => 4,
    };
    final session = OrtSession.open(
      modelPath,
      device: device,
      config: OrtSessionConfig(
        intraOpThreads: threads,
        interOpThreads: 1,
        sequential: true,
        optimizationLevel: 99,
        cpuArena: true,
        memPattern: true,
      ),
    );
    return PpocrRecognizer._(session, CtcDecoder.fromDictionary(dictionary));
  }

  final OrtSession _session;
  final CtcDecoder decoder;

  OrtDevice get device => _session.device;
  String? get fallbackReason => _session.fallbackReason;

  /// `process_image` with text lines: recognizes every line of every block in
  /// one pass (crops batched by padded width across the page) and fills the
  /// blocks' texts. Blocks without lines are read as a whole.
  void recognizeBlocks(RgbImage image, List<TextBlock> blocks) {
    final perBlock = [for (final b in blocks) blockLineCrops(image, b)];
    final texts = recognize([for (final p in perBlock) ...p.crops]).map((r) => r.text).toList();
    var offset = 0;
    for (var i = 0; i < blocks.length; i++) {
      final n = perBlock[i].crops.length;
      assignBlockTexts(blocks[i], perBlock[i].lines, texts.sublist(offset, offset + n));
      offset += n;
    }
  }

  /// `_rec_infer`: text and confidence for each crop.
  List<({String text, double confidence})> recognize(List<RgbImage> crops) {
    final results = List<({String text, double confidence})>.filled(crops.length, (text: '', confidence: 0.0));
    final buckets = <int, List<int>>{};
    for (final (i, crop) in crops.indexed) {
      buckets.putIfAbsent(recTargetWidth(crop), () => []).add(i);
    }
    for (final MapEntry(key: targetW, value: idxs) in buckets.entries) {
      final maxRatio = targetW / ppocrRecHeight.toDouble();
      final inputs = [for (final i in idxs) recResizeNorm(crops[i], maxRatio)];
      final width = inputs.first.width;
      final per = 3 * ppocrRecHeight * width;
      final batch = Float32List(per * inputs.length);
      for (final (k, input) in inputs.indexed) {
        batch.setRange(k * per, (k + 1) * per, input.data);
      }
      final out = _session.run({
        _session.inputs.first.name: OrtTensor.float32(batch, [inputs.length, 3, ppocrRecHeight, width]),
      })[_session.outputs.first.name]!;
      var logits = out.asFloat32;
      var [n, t, c] = out.shape;
      if (t > c) {
        // (N, C, T) -> (N, T, C)
        final transposed = Float32List(logits.length);
        for (var b = 0; b < n; b++) {
          for (var x = 0; x < t; x++) {
            for (var y = 0; y < c; y++) {
              transposed[(b * c + y) * t + x] = logits[(b * t + x) * c + y];
            }
          }
        }
        logits = transposed;
        (t, c) = (c, t);
      }
      final decoded = decoder.decode(logits, n, t, c);
      for (final (k, i) in idxs.indexed) {
        results[i] = decoded[k];
      }
    }
    return results;
  }

  void dispose() => _session.dispose();
}
