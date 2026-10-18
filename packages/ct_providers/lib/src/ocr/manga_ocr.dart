/// manga-ocr (mobile ONNX) — Japanese OCR. Port of
/// `modules/ocr/manga_ocr/mobile/onnx_engine.py`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

import 'ppocr.dart' show applySourceLanguage;

const mangaOcrInfo = PluginInfo(
  id: 'manga_ocr',
  displayName: 'manga-ocr (Japanese)',
  description: 'Japanese OCR trained on manga; reads each block as a whole. Runs locally.',
  kind: PluginKind.ocr,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['manga-ocr-mobile'],
);

final mangaOcrFactory = PluginFactory<OcrEngine>(mangaOcrInfo, (config, env) async {
  return MangaOcrEngine(env.models, log: env.log);
});

class MangaOcrEngine implements OcrEngine {
  MangaOcrEngine(this._models, {this.log});

  final ModelManager _models;
  final EventLog? log;
  MangaOcrModel? _model;

  @override
  PluginInfo get info => mangaOcrInfo;

  Future<MangaOcrModel> model() async {
    final existing = _model;
    if (existing != null) return existing;
    const spec = ModelCatalog.mangaOcr;
    final m = MangaOcrModel.open(
      encoder: await _models.ensureFile(spec, 'encoder.onnx'),
      decoderInit: await _models.ensureFile(spec, 'decoder_init.onnx'),
      decoderStep: await _models.ensureFile(spec, 'decoder_step.onnx'),
      vocab: File(await _models.ensureFile(spec, 'vocab.txt')).readAsStringSync(),
    );
    log?.info('ocr_session', {'engine': 'manga_ocr', 'model': spec.id, 'device': 'cpu'});
    return _model = m;
  }

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    applySourceLanguage(blocks, sourceLanguage);
    final m = await model();
    m.recognizeBlocks(image, blocks, context: context);
  }

  @override
  Future<void> dispose() async {
    _model?.dispose();
    _model = null;
  }
}

/// The three manga-ocr sessions (encoder, first and next decoder steps).
class MangaOcrModel {
  MangaOcrModel._(this._encoder, this._decoderInit, this._decoderStep, this.text);

  /// The decoder makes many tiny calls; one CPU thread is fastest (as in the
  /// original, which always runs manga-ocr on the CPU).
  static const sessionConfig = OrtSessionConfig(
    intraOpThreads: 1,
    interOpThreads: 1,
    sequential: true,
    optimizationLevel: 99,
    cpuArena: true,
    memPattern: true,
  );

  factory MangaOcrModel.open({
    required String encoder,
    required String decoderInit,
    required String decoderStep,
    required String vocab,
  }) {
    OrtSession open(String path) => OrtSession.open(path, config: sessionConfig);
    return MangaOcrModel._(open(encoder), open(decoderInit), open(decoderStep), MangaOcrText.fromVocabFile(vocab));
  }

  final OrtSession _encoder;
  final OrtSession _decoderInit;
  final OrtSession _decoderStep;
  final MangaOcrText text;

  static const _layers = 4, _heads = 4, _headDim = 64;

  /// `process_image`: each block is read from its whole box; blocks outside
  /// the image get empty text.
  void recognizeBlocks(RgbImage image, List<TextBlock> blocks, {PluginContext? context}) {
    for (final b in blocks) {
      final x = b.xyxy;
      if (x.x1 < x.x2 && x.y1 < x.y2 && x.x1 >= 0 && x.y1 >= 0 && x.x2 <= image.width && x.y2 <= image.height) {
        context?.cancel.throwIfCancelled();
        try {
          b.text = read(image.crop(x));
        } catch (e, st) {
          context?.log.error('manga_ocr_failed', e, st);
          b.text = '';
        }
      } else {
        b.text = '';
      }
    }
  }

  /// `process_single`: greedy decoding of one crop.
  String read(RgbImage crop) {
    final hidden = _encoder.run({
      _encoder.inputs.first.name: OrtTensor.float32(mangaOcrPreprocess(crop), [1, 3, mangaOcrImageSize, mangaOcrImageSize]),
    })[_encoder.outputs.first.name]!;
    final hiddenData = Float32List.fromList(hidden.asFloat32);
    final hiddenShape = hidden.shape;

    const maxLen = mangaOcrMaxSequenceLength;
    const slot = _headDim;
    final selfK = Float32List(_layers * _heads * maxLen * _headDim);
    final selfV = Float32List(_layers * _heads * maxLen * _headDim);
    void store(Float32List cache, Float32List slice, int position) {
      // slice: (layers, 1, heads, 1, dim) -> cache[:, :, :, position, :]
      for (var lh = 0; lh < _layers * _heads; lh++) {
        cache.setRange((lh * maxLen + position) * slot, (lh * maxLen + position + 1) * slot, slice, lh * slot);
      }
    }

    final initNames = [for (final i in _decoderInit.inputs) i.name];
    final init = _decoderInit.run({
      initNames[0]: OrtTensor.float32(hiddenData, hiddenShape),
      initNames[1]: OrtTensor.int64(Int64List.fromList([mangaOcrStartToken]), [1, 1]),
    });
    final initOuts = [for (final o in _decoderInit.outputs) init[o.name]!];
    store(selfK, initOuts[1].asFloat32, 0);
    store(selfV, initOuts[2].asFloat32, 0);
    final crossK = Float32List.fromList(initOuts[3].asFloat32);
    final crossV = Float32List.fromList(initOuts[4].asFloat32);
    final crossShape = initOuts[3].shape;

    final vocabSize = text.vocab.length;
    int argmax(Float32List logits) {
      var best = 0;
      final n = vocabSize < logits.length ? vocabSize : logits.length;
      for (var i = 1; i < n; i++) {
        if (logits[i] > logits[best]) best = i;
      }
      return best;
    }

    final tokens = [mangaOcrStartToken];
    var next = argmax(initOuts[0].asFloat32);
    if (next != mangaOcrEndToken) {
      tokens.add(next);
      var cacheLen = 1;
      var current = next;
      final stepNames = [for (final i in _decoderStep.inputs) i.name];
      final cacheShape = [_layers, 1, _heads, maxLen, _headDim];
      while (tokens.length < maxLen && cacheLen < maxLen) {
        final position = cacheLen + 1 < mangaOcrMaxPositionId ? cacheLen + 1 : mangaOcrMaxPositionId;
        final step = _decoderStep.run({
          stepNames[0]: OrtTensor.float32(hiddenData, hiddenShape),
          stepNames[1]: OrtTensor.int64(Int64List.fromList([current]), [1, 1]),
          stepNames[2]: OrtTensor.int64(Int64List.fromList([position]), [1, 1]),
          stepNames[3]: OrtTensor.float32(selfK, cacheShape),
          stepNames[4]: OrtTensor.float32(selfV, cacheShape),
          stepNames[5]: OrtTensor.float32(crossK, crossShape),
          stepNames[6]: OrtTensor.float32(crossV, crossShape),
        });
        final outs = [for (final o in _decoderStep.outputs) step[o.name]!];
        store(selfK, outs[1].asFloat32, cacheLen);
        store(selfV, outs[2].asFloat32, cacheLen);
        cacheLen++;
        next = argmax(outs[0].asFloat32);
        if (next == mangaOcrEndToken) break;
        tokens.add(next);
        current = next;
      }
    }
    return text.decode(tokens);
  }

  void dispose() {
    _encoder.dispose();
    _decoderInit.dispose();
    _decoderStep.dispose();
  }
}
