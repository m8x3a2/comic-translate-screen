/// Offline translation between English and Russian with OPUS-MT (the big
/// "tc-big" Marian models of Helsinki-NLP, converted to int8 ONNX by this
/// project; the small ones of Xenova, the former "Fast" and "Better" levels,
/// were dropped as worse): nothing leaves the computer, no key. New in this
/// project.
///
/// Comic text is prepared first: lines in capitals go in sentence case,
/// words broken by a hyphen at a line end are joined, and each sentence is
/// translated on its own (the models drop sentences of long inputs).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

import 'offline_llm.dart';

const opusMtInfo = PluginInfo(
  id: 'opus_mt',
  displayName: 'Offline',
  description:
      'Translates on this computer: no internet, no key. Low: OPUS-MT (English and Russian, about 0.5 s per '
      'bubble); Medium, High, Ultra: the Index-Translate models of llama.cpp (more natural, follow the '
      'glossary and notes; seconds per bubble, more memory).',
  kind: PluginKind.translator,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  settings: [
    ChoiceSetting(
      key: 'level',
      label: 'Level',
      help: 'Automatically: the highest level that fits the memory of this device.',
      info:
          'Low: OPUS-MT tc-big (370 MB per direction, about 1.3 GB of memory, under a second per bubble, English '
          'and Russian only). Medium: Index-Translate-2B (1.3 GB, about 2.4 GB of memory, 3-5 s per bubble on a '
          'weak laptop). High: Index-Translate-9B (5.8 GB, about 6.6 GB of memory). Ultra: Index-Translate-9B '
          'closer to the full model (7.6 GB, about 8.4 GB). Licences: CC-BY 4.0 (Helsinki-NLP), Apache-2.0 '
          '(bilibili Index).',
      options: {'auto': 'Automatically', 'low': 'Low', 'medium': 'Medium', 'high': 'High', 'ultra': 'Ultra'},
      defaultValue: 'auto',
    ),
    BoolSetting(
      key: 'follow_notes',
      label: 'Follow the glossary and notes',
      help: 'Medium and up: the glossary, who speaks and the notes of the comic go to the model.',
      defaultValue: true,
    ),
  ],
  models: ['opus-mt-tc-big-en-ru'],
  modelsForLanguage: opusMtModelsFor,
  modelsForConfig: offlineModelsForConfig,
);

final opusMtFactory = PluginFactory<Translator>(opusMtInfo, (config, env) async {
  final spec = offlineLevelModels[resolveOfflineLevel(config.value<String>('level'))];
  if (spec == null) return OpusMtTranslator(env.models, big: true, log: env.log);
  return OfflineLlmTranslator(
    env.models,
    spec,
    info: opusMtInfo,
    followNotes: config.value<bool>('follow_notes'),
    log: env.log,
  );
});

/// The models of the offline translator at the level of [config].
List<String> offlineModelsForConfig(String sourceLanguage, PluginConfig config) {
  final spec = offlineLevelModels[resolveOfflineLevel(config.value<String>('level'))];
  return spec == null ? opusMtModelsFor(sourceLanguage) : [spec.id];
}

/// The small models (the former "Fast" and "Better" levels, removed by the
/// owner on 2026-11-19 as worse): kept for the parity test only.
const opusMtModels = {
  'English': (ModelCatalog.opusMtEnRu, 'Russian', null),
  'Russian': (ModelCatalog.opusMtRuEn, 'English', null),
};

/// The models of the translator, by source language, with the token that
/// asks for the target language (none for a model with one); the English one
/// also does Belarusian and Ukrainian, so it is asked for Russian.
const opusMtBigModels = {
  'English': (ModelCatalog.opusMtBigEnRu, 'Russian', '>>rus<<'),
  'Russian': (ModelCatalog.opusMtBigRuEn, 'English', null),
};

/// The model translating from [sourceLanguage] (English or Russian).
List<String> opusMtModelsFor(String sourceLanguage, {bool big = true}) {
  final m =
      (big ? opusMtBigModels : opusMtModels)[sourceLanguage] ??
      (throw UnsupportedError('OPUS-MT: no model from $sourceLanguage'));
  return [m.$1.id];
}

class OpusMtTranslator implements Translator {
  OpusMtTranslator(this._models, {this.beams = 4, this.big = false, this.log});

  final ModelManager _models;
  final int beams;

  /// The big models ("High").
  final bool big;
  final EventLog? log;
  final _engines = <String, OpusMtEngine>{};

  @override
  PluginInfo get info => opusMtInfo;

  /// The engine of [spec]; [target] is the token asking for the target
  /// language, for a model with several.
  Future<OpusMtEngine> engine(ModelSpec spec, {String? target}) async {
    final made = _engines[spec.id];
    if (made != null) return made;
    Future<String> file(String name) => _models.ensureFile(spec, name);
    final tokenizer = MarianTokenizer.fromFiles(
      await File(await file('source.spm')).readAsBytes(),
      await File(await file('vocab.json')).readAsString(),
    );
    final engine = OpusMtEngine(
      tokenizer,
      encoder: await file('encoder_model_quantized.onnx'),
      decoder: await file('decoder_model_merged_quantized.onnx'),
      targetToken: target == null ? null : tokenizer.vocab[target],
    );
    log?.info('translator_session', {'model': spec.id});
    return _engines[spec.id] = engine;
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    final pair = (big ? opusMtBigModels : opusMtModels)[request.sourceLanguage];
    if (pair == null || pair.$2 != request.targetLanguage) {
      throw TranslationException(
        'OPUS-MT translates only English to Russian and Russian to English, not '
        '${request.sourceLanguage} to ${request.targetLanguage}.',
        kind: TranslationErrorKind.config,
      );
    }
    final e = await engine(pair.$1, target: pair.$3);
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
  OpusMtEngine(this.tokenizer, {required String encoder, required String decoder, this.targetToken})
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

  /// Put before the source tokens to ask a model of several target
  /// languages for one (`>>rus<<`); null for a model with one.
  final int? targetToken;
  final OrtSession _encoder;
  final OrtSession _decoder;
  late final List<String> _pastNames;
  late final int _heads;
  late final int _headDim;

  /// [text] translated (one sentence is best).
  String translate(String text, {int beams = 4}) =>
      tokenizer.decode(generate([?targetToken, ...tokenizer.encode(text)], beams: beams));

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
