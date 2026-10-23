/// Offline translation between English and Russian with OPUS-MT (Marian
/// models of Helsinki-NLP, int8 ONNX exports of Xenova): nothing leaves the
/// computer, no key. New in this project.
///
/// Comic text is prepared first: lines in capitals go in sentence case,
/// words broken by a hyphen at a line end are joined, and each sentence is
/// translated on its own (the models drop sentences of long inputs).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const opusMtInfo = PluginInfo(
  id: 'opus_mt',
  displayName: 'Offline (OPUS-MT)',
  description:
      'Translates between English and Russian on this computer: no internet, no key. Simpler than large '
      'online models.',
  kind: PluginKind.translator,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  settings: [
    ChoiceSetting(
      key: 'quality',
      label: 'Quality',
      help: 'Better compares four variants of each sentence.',
      info:
          'Fast: about 0.4 s per bubble on a weak laptop. Better: the model weighs four variants of each '
          'sentence and keeps the best; about 1.7 times slower, noticeably fewer odd phrases.',
      options: {'fast': 'Fast', 'better': 'Better'},
      defaultValue: 'better',
    ),
  ],
  models: ['opus-mt-en-ru'],
  modelsForLanguage: opusMtModelsFor,
);

final opusMtFactory = PluginFactory<Translator>(opusMtInfo, (config, env) async {
  return OpusMtTranslator(env.models, beams: config.value<String>('quality') == 'fast' ? 1 : 4, log: env.log);
});

/// The model for each direction, by source language.
const opusMtModels = {'English': (ModelCatalog.opusMtEnRu, 'Russian'), 'Russian': (ModelCatalog.opusMtRuEn, 'English')};

/// The model translating from [sourceLanguage] (English or Russian).
List<String> opusMtModelsFor(String sourceLanguage) {
  final m = opusMtModels[sourceLanguage] ?? (throw UnsupportedError('OPUS-MT: no model from $sourceLanguage'));
  return [m.$1.id];
}

class OpusMtTranslator implements Translator {
  OpusMtTranslator(this._models, {this.beams = 4, this.log});

  final ModelManager _models;
  final int beams;
  final EventLog? log;
  final _engines = <String, OpusMtEngine>{};

  @override
  PluginInfo get info => opusMtInfo;

  Future<OpusMtEngine> engine(ModelSpec spec) async {
    final made = _engines[spec.id];
    if (made != null) return made;
    Future<String> file(String name) => _models.ensureFile(spec, name);
    final engine = OpusMtEngine(
      MarianTokenizer.fromFiles(
        await File(await file('source.spm')).readAsBytes(),
        await File(await file('vocab.json')).readAsString(),
      ),
      encoder: await file('encoder_model_quantized.onnx'),
      decoder: await file('decoder_model_merged_quantized.onnx'),
    );
    log?.info('translator_session', {'model': spec.id});
    return _engines[spec.id] = engine;
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    final pair = opusMtModels[request.sourceLanguage];
    if (pair == null || pair.$2 != request.targetLanguage) {
      throw TranslationException(
        'OPUS-MT translates only English to Russian and Russian to English, not '
        '${request.sourceLanguage} to ${request.targetLanguage}.',
        kind: TranslationErrorKind.config,
      );
    }
    final e = await engine(pair.$1);
    final done = <String, String>{};
    final sw = Stopwatch()..start();
    var sentences = 0;
    for (final b in request.blocks) {
      final parts = <String>[];
      for (final s in splitSentences(prepareComicText(b.text))) {
        await context.cancel.checkpoint();
        parts.add(done[s] ??= e.translate(s, beams: beams));
        sentences++;
      }
      b.translation = parts.join(' ');
    }
    context.log.info('opus_mt_done', {'sentences': sentences, 'ms': sw.elapsedMilliseconds, 'beams': beams});
  }

  @override
  Future<void> dispose() async {
    for (final e in _engines.values) {
      e.dispose();
    }
    _engines.clear();
  }
}

final _brokenWord = RegExp(r'(\p{L})-\s+(?=\p{Ll})', unicode: true);

/// Comic text ready for the model: one line, sentence case for capitals,
/// words broken at a line end ("DANGER- OUS") joined.
String prepareComicText(String text) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return sentenceCase(oneLine).replaceAllMapped(_brokenWord, (m) => m[1]!);
}

/// One OPUS-MT direction: encoder and decoder (with past keys and values)
/// on the processor. The int8 models do not run on DirectML.
class OpusMtEngine {
  OpusMtEngine(this.tokenizer, {required String encoder, required String decoder})
    : _encoder = OrtSession.open(encoder, config: _config),
      _decoder = OrtSession.open(decoder, config: _config) {
    _pastNames = [
      for (final i in _decoder.inputs)
        if (i.name.startsWith('past_key_values.')) i.name,
    ];
    final shape = _decoder.inputs.firstWhere((i) => i.name == _pastNames.first).shape;
    _heads = shape[1];
    _headDim = shape[3];
  }

  static const _config = OrtSessionConfig(intraOpThreads: 4, interOpThreads: 1);

  /// Longest output, in tokens, for an input of n tokens.
  static int maxLengthFor(int n) => 3 * n + 10;

  final MarianTokenizer tokenizer;
  final OrtSession _encoder;
  final OrtSession _decoder;
  late final List<String> _pastNames;
  late final int _heads;
  late final int _headDim;

  /// [text] translated (one sentence is best).
  String translate(String text, {int beams = 4}) => tokenizer.decode(generate(tokenizer.encode(text), beams: beams));

  /// Output tokens for the input tokens [ids] (`</s>` left out).
  List<int> generate(List<int> ids, {int beams = 4}) {
    final n = ids.length;
    final encoded = _encoder.run({
      'input_ids': OrtTensor.int64(Int64List.fromList(ids), [1, n]),
      'attention_mask': OrtTensor.int64(Int64List(n)..fillRange(0, n, 1), [1, n]),
    })[_encoder.outputs.first.name]!;
    final hidden = encoded.asFloat32;
    final dim = encoded.shape[2];

    // Past keys and values of the live hypotheses, by input name.
    var past = <String, OrtTensor>{};
    List<Float32List> step(List<int> last, List<int> parents) {
      final b = last.length;
      final first = parents.first < 0;
      final feeds = <String, OrtTensor>{
        'encoder_attention_mask': OrtTensor.int64(Int64List(b * n)..fillRange(0, b * n, 1), [b, n]),
        'input_ids': OrtTensor.int64(Int64List.fromList(last), [b, 1]),
        'encoder_hidden_states': OrtTensor.float32(_repeat(hidden, b), [b, n, dim]),
        'use_cache_branch': OrtTensor.bool_(Uint8List.fromList([first ? 0 : 1]), [1]),
        for (final name in _pastNames)
          name: first ? OrtTensor.float32(Float32List(0), [b, _heads, 0, _headDim]) : _pick(past[name]!, parents),
      };
      final out = _decoder.run(feeds);
      final next = <String, OrtTensor>{};
      for (final name in _pastNames) {
        final present = name.replaceFirst('past_key_values', 'present');
        // The encoder's keys and values come out once and stay.
        next[name] = !first && name.contains('.encoder.') ? _pick(past[name]!, parents) : out[present]!;
      }
      past = next;
      final logits = out['logits']!;
      final vocab = logits.shape[2];
      final data = logits.asFloat32;
      return [for (var i = 0; i < b; i++) logSoftmax(Float32List.fromList(data.sublist(i * vocab, (i + 1) * vocab)))];
    }

    return beamSearch(
      step,
      startToken: tokenizer.padId,
      eos: tokenizer.eosId,
      maxLength: maxLengthFor(n),
      beams: beams,
      banned: {tokenizer.padId},
    );
  }

  void dispose() {
    _encoder.dispose();
    _decoder.dispose();
  }
}

/// [data] (one row) repeated [times] times.
Float32List _repeat(Float32List data, int times) {
  final out = Float32List(data.length * times);
  for (var i = 0; i < times; i++) {
    out.setRange(i * data.length, (i + 1) * data.length, data);
  }
  return out;
}

/// The rows [rows] of [t] (first dimension), in that order.
OrtTensor _pick(OrtTensor t, List<int> rows) {
  final src = t.asFloat32;
  final row = src.length ~/ t.shape.first;
  final out = Float32List(row * rows.length);
  for (final (i, r) in rows.indexed) {
    out.setRange(i * row, (i + 1) * row, src, r * row);
  }
  return OrtTensor.float32(out, [rows.length, ...t.shape.skip(1)]);
}
