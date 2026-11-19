import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/llama_bindings.g.dart';
import 'vision_model.dart';

/// `struct llama_chat_message { const char * role; const char * content; }`
/// (the generated bindings know it only as an opaque type).
final class _ChatMessage extends ffi.Struct {
  external ffi.Pointer<ffi.Char> role;
  external ffi.Pointer<ffi.Char> content;
}

/// How the next token is chosen. Temperature 0: always the most likely one
/// (the same answer every time); else the model's recommended sampling.
class TextSampling {
  const TextSampling({
    this.temperature = 0,
    this.topK = 0,
    this.topP = 1,
    this.repeatPenalty = 1,
    this.penaltyLastN = 64,
    this.maxTokens = 1024,
    this.seed = 42,
  });

  final double temperature;
  final int topK;
  final double topP;
  final double repeatPenalty;
  final int penaltyLastN;
  final int maxTokens;
  final int seed;
}

/// What [TextModel.generate] gives back.
class TextReply {
  TextReply(this.text, {required this.promptTokens, required this.tokens, required this.stopped});

  final String text;
  final int promptTokens;
  final int tokens;

  /// Stopped from outside (time limit, cancel) before the model finished.
  final bool stopped;
}

/// A text model of llama.cpp (one GGUF file), for the offline translator.
/// Not thread-safe: one answer at a time.
class TextModel {
  TextModel._(this._model, this._ctx, this._vocab, this.contextSize);

  final ffi.Pointer<llama_model> _model;
  final ffi.Pointer<llama_context> _ctx;
  final ffi.Pointer<llama_vocab> _vocab;
  final int contextSize;
  var _disposed = false;

  /// Opens [modelPath]; [gpuLayers] 0 keeps everything on the processor.
  factory TextModel.open(String modelPath, {int threads = 4, int contextSize = 4096, int gpuLayers = 0}) {
    VisionModel.initBackends();
    final mp = llama_model_default_params()..n_gpu_layers = gpuLayers;
    final path = modelPath.toNativeUtf8();
    final model = llama_model_load_from_file(path.cast(), mp);
    malloc.free(path);
    if (model == ffi.nullptr) throw LlamaException('cannot load $modelPath');
    final cp = llama_context_default_params()
      ..n_ctx = contextSize
      ..n_batch = 2048
      ..n_threads = threads
      ..n_threads_batch = threads;
    final ctx = llama_init_from_model(model, cp);
    if (ctx == ffi.nullptr) {
      llama_model_free(model);
      throw LlamaException('cannot create a context for $modelPath');
    }
    return TextModel._(model, ctx, llama_model_get_vocab(model), contextSize);
  }

  /// The chat template stored in the model file (Jinja text), if any.
  String? get chatTemplate {
    final t = llama_model_chat_template(_model, ffi.nullptr);
    return t == ffi.nullptr ? null : t.cast<Utf8>().toDartString();
  }

  /// [messages] (role, text) as the model's chat prompt, ending where the
  /// assistant's answer starts. llama.cpp knows the common templates by
  /// their marks (ChatML of Qwen, Hunyuan…); a reasoning model ("<think>"
  /// in its template) gets an empty reasoning block, so it answers at once
  /// (what `enable_thinking: false` does on a server).
  String chatPrompt(List<(String role, String content)> messages) {
    final template = chatTemplate;
    final tmpl = template?.toNativeUtf8();
    final chat = malloc<_ChatMessage>(messages.length);
    final strings = <ffi.Pointer<Utf8>>[];
    try {
      for (var i = 0; i < messages.length; i++) {
        final role = messages[i].$1.toNativeUtf8();
        final content = messages[i].$2.toNativeUtf8();
        strings
          ..add(role)
          ..add(content);
        chat[i]
          ..role = role.cast()
          ..content = content.cast();
      }
      var size = 4096 + messages.fold<int>(0, (a, m) => a + utf8.encode(m.$2).length * 2);
      for (var attempt = 0; attempt < 2; attempt++) {
        final buf = malloc<ffi.Uint8>(size);
        try {
          final n = llama_chat_apply_template(
            tmpl?.cast() ?? ffi.nullptr,
            chat.cast<llama_chat_message>(),
            messages.length,
            true,
            buf.cast(),
            size,
          );
          if (n < 0) throw LlamaException('the chat template of the model is not supported by llama.cpp');
          if (n > size) {
            size = n + 1;
            continue;
          }
          var prompt = utf8.decode(buf.asTypedList(n), allowMalformed: true);
          if (template != null && template.contains('<think>') && !prompt.trimRight().endsWith('</think>')) {
            prompt += '<think>\n\n</think>\n\n';
          }
          return prompt;
        } finally {
          malloc.free(buf);
        }
      }
      throw LlamaException('the chat prompt did not fit');
    } finally {
      for (final s in strings) {
        malloc.free(s);
      }
      malloc.free(chat);
      if (tmpl != null) malloc.free(tmpl);
    }
  }

  /// The tokens of [text] (special marks of the template read as such).
  List<int> tokenize(String text) {
    final bytes = utf8.encode(text);
    final p = malloc<ffi.Uint8>(bytes.length + 1);
    p.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    var cap = bytes.length + 16;
    try {
      while (true) {
        final out = malloc<ffi.Int32>(cap);
        try {
          final n = llama_tokenize(_vocab, p.cast(), bytes.length, out, cap, true, true);
          if (n >= 0) return List.of(out.asTypedList(n));
          cap = -n;
        } finally {
          malloc.free(out);
        }
      }
    } finally {
      malloc.free(p);
    }
  }

  /// The answer to [prompt] (already in the chat template, see
  /// [chatPrompt]). [onToken] is awaited before every written token with
  /// the count so far; false stops (time limit, cancel).
  Future<TextReply> generate(
    String prompt, {
    TextSampling sampling = const TextSampling(),
    Future<bool> Function(int tokens)? onToken,
  }) async {
    if (_disposed) throw StateError('TextModel is disposed');
    llama_memory_clear(llama_get_memory(_ctx), true);
    final tokens = tokenize(prompt);
    if (tokens.length + sampling.maxTokens > contextSize) {
      throw LlamaException('the text is too long for the model (${tokens.length} tokens)');
    }
    final sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    final batch = malloc<ffi.Int32>(2048);
    final one = malloc<ffi.Int32>();
    final piece = malloc<ffi.Char>(256);
    try {
      if (sampling.repeatPenalty != 1) {
        llama_sampler_chain_add(
          sampler,
          llama_sampler_init_penalties(
            llama_vocab_n_tokens(_vocab),
            sampling.penaltyLastN,
            sampling.repeatPenalty,
            0,
            0,
          ),
        );
        for (final t in tokens) {
          llama_sampler_accept(sampler, t);
        }
      }
      if (sampling.temperature <= 0) {
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
      } else {
        if (sampling.topK > 0) llama_sampler_chain_add(sampler, llama_sampler_init_top_k(sampling.topK));
        if (sampling.topP < 1) llama_sampler_chain_add(sampler, llama_sampler_init_top_p(sampling.topP, 1));
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(sampling.temperature));
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(sampling.seed));
      }
      for (var start = 0; start < tokens.length; start += 2048) {
        final end = start + 2048 < tokens.length ? start + 2048 : tokens.length;
        batch.asTypedList(end - start).setAll(0, tokens.sublist(start, end));
        // ignore: deprecated_member_use_from_same_package
        if (llama_decode(_ctx, llama_batch_get_one(batch, end - start)) != 0) {
          throw LlamaException('the prompt could not be read (llama_decode)');
        }
      }
      final out = BytesBuilder();
      var written = 0;
      var stopped = false;
      while (written < sampling.maxTokens) {
        if (onToken != null && !await onToken(written)) {
          stopped = true;
          break;
        }
        final t = llama_sampler_sample(sampler, _ctx, -1);
        if (llama_vocab_is_eog(_vocab, t)) break;
        final len = llama_token_to_piece(_vocab, t, piece, 256, 0, false);
        if (len > 0) out.add(piece.cast<ffi.Uint8>().asTypedList(len));
        written++;
        one.value = t;
        // ignore: deprecated_member_use_from_same_package
        if (llama_decode(_ctx, llama_batch_get_one(one, 1)) != 0) throw LlamaException('llama_decode failed');
      }
      return TextReply(
        utf8.decode(out.takeBytes(), allowMalformed: true),
        promptTokens: tokens.length,
        tokens: written,
        stopped: stopped,
      );
    } finally {
      llama_sampler_free(sampler);
      malloc
        ..free(batch)
        ..free(one)
        ..free(piece);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    llama_free(_ctx);
    llama_model_free(_model);
  }
}
