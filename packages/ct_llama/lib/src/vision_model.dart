import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/llama_bindings.g.dart';
import 'bindings/mtmd.dart';

/// Error reported by llama.cpp.
class LlamaException implements Exception {
  LlamaException(this.message);

  final String message;

  @override
  String toString() => 'LlamaException: $message';
}

/// What [VisionModel.read] gives back.
class VisionReading {
  VisionReading(this.text, {required this.promptTokens, required this.tokens, required this.stopped});

  final String text;

  /// Tokens of the prompt, the picture's included.
  final int promptTokens;

  /// Tokens written.
  final int tokens;

  /// Stopped from outside (time limit, cancel) before the model finished.
  final bool stopped;
}

/// Sampling of the readings: the penalties of llama-server (64 last tokens,
/// the prompt's text included) and then the most likely token — what the
/// server does at temperature 0.
class VisionSampling {
  const VisionSampling({this.repeatPenalty = 1.05, this.penaltyLastN = 64, this.maxTokens = 1024});

  final double repeatPenalty;
  final int penaltyLastN;
  final int maxTokens;
}

/// A vision-language model of llama.cpp (a GGUF model and its `mmproj`
/// picture encoder) on the processor. Not thread-safe: one reading at a
/// time.
class VisionModel {
  VisionModel._(this._model, this._ctx, this._mtmd, this._vocab, this.threads);

  final ffi.Pointer<llama_model> _model;
  final ffi.Pointer<llama_context> _ctx;
  final ffi.Pointer<mtmd_context> _mtmd;
  final ffi.Pointer<llama_vocab> _vocab;
  final int threads;
  var _disposed = false;

  /// The marker that stands for the picture in a prompt.
  static String get marker {
    _init();
    return mtmd_default_marker().cast<Utf8>().toDartString();
  }

  static var _ready = false;
  // Kept so the callback stays alive while llama.cpp holds it.
  // ignore: unused_field
  static ffi.NativeCallable<LogCallback>? _logSink;

  /// Told when llama.cpp logs an error (its other lines are dropped).
  static void Function(String line)? onError;

  /// Loads the libraries in dependency order (each by its full path, so
  /// that the next one finds the ones it imports) and the processor
  /// backends from the folder of ggml.dll.
  static void _init() {
    if (_ready) return;
    omp_get_max_threads();
    ggml_time_init();
    // The callback runs later on this isolate, when llama.cpp has freed the
    // line already: only the level is used.
    final sink = ffi.NativeCallable<LogCallback>.listener((
      int level,
      ffi.Pointer<ffi.Char> _,
      ffi.Pointer<ffi.Void> _,
    ) {
      // GGML_LOG_LEVEL_ERROR = 4.
      if (level == 4) onError?.call('llama.cpp reported an error');
    });
    sink.keepIsolateAlive = false;
    _logSink = sink;
    ggml_log_set(sink.nativeFunction, ffi.nullptr);
    final dir = _moduleDir('ggml.dll', () => ggml_backend_dev_count());
    if (dir != null) {
      final p = dir.toNativeUtf8();
      try {
        ggml_backend_load_all_from_path(p.cast());
      } finally {
        malloc.free(p);
      }
    }
    if (ggml_backend_dev_count() == 0) throw LlamaException('no processor backend found next to ggml.dll');
    llama_log_set(sink.nativeFunction.cast(), ffi.nullptr);
    mtmd_helper_log_set(sink.nativeFunction, ffi.nullptr);
    llama_backend_init();
    _ready = true;
  }

  /// The folder of the loaded module [name] (after [load] loaded it).
  static String? _moduleDir(String name, void Function() load) {
    load();
    if (!Platform.isWindows) return null;
    final kernel = ffi.DynamicLibrary.open('kernel32.dll');
    final getHandle = kernel
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf16>),
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf16>)
        >('GetModuleHandleW');
    final getName = kernel
        .lookupFunction<
          ffi.Uint32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf16>, ffi.Uint32),
          int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf16>, int)
        >('GetModuleFileNameW');
    final n = name.toNativeUtf16();
    final buf = malloc<ffi.Uint16>(1024);
    try {
      final h = getHandle(n);
      if (h == ffi.nullptr) return null;
      final len = getName(h, buf.cast(), 1024);
      if (len == 0) return null;
      final path = buf.cast<Utf16>().toDartString(length: len);
      return File(path).parent.path;
    } finally {
      malloc.free(n);
      malloc.free(buf);
    }
  }

  /// Opens [modelPath] with its picture encoder [mmprojPath].
  factory VisionModel.open(String modelPath, String mmprojPath, {int threads = 4, int contextSize = 8192}) {
    _init();
    final mp = llama_model_default_params()..n_gpu_layers = 0;
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
    final mparams = mtmd_context_params_default()
      ..use_gpu = false
      ..print_timings = false
      ..n_threads = threads
      ..flash_attn_type = cp.flash_attn_typeAsInt;
    final proj = mmprojPath.toNativeUtf8();
    final mtmd = mtmd_init_from_file(proj.cast(), model, mparams);
    malloc.free(proj);
    if (mtmd == ffi.nullptr) {
      llama_free(ctx);
      llama_model_free(model);
      throw LlamaException('cannot load the picture encoder $mmprojPath');
    }
    return VisionModel._(model, ctx, mtmd, llama_model_get_vocab(model), threads);
  }

  /// Reads the [width]×[height] picture [rgb] (3 bytes a pixel) with
  /// [prompt], which holds [marker] where the picture goes. [onToken] is
  /// awaited before every written token with the count so far, [onText] is
  /// told the text so far after every [textEvery] tokens; false from either
  /// stops the reading (time limit, cancel, a model caught in a loop).
  Future<VisionReading> read(
    Uint8List rgb,
    int width,
    int height,
    String prompt, {
    VisionSampling sampling = const VisionSampling(),
    Future<bool> Function(int tokens)? onToken,
    bool Function(String text)? onText,
    int textEvery = 16,
  }) async {
    if (_disposed) throw StateError('VisionModel is disposed');
    if (rgb.length != width * height * 3) throw ArgumentError('rgb holds ${rgb.length} bytes, not $width×$height×3');
    llama_memory_clear(llama_get_memory(_ctx), true);
    final pixels = malloc<ffi.UnsignedChar>(rgb.length);
    pixels.cast<ffi.Uint8>().asTypedList(rgb.length).setAll(0, rgb);
    final bitmap = mtmd_bitmap_init(width, height, pixels);
    malloc.free(pixels);
    final bitmaps = malloc<ffi.Pointer<mtmd_bitmap>>()..value = bitmap;
    final promptBytes = utf8.encode(prompt);
    final text = promptBytes.length;
    final promptPtr = malloc<ffi.Uint8>(text + 1);
    promptPtr.asTypedList(text + 1)
      ..setAll(0, promptBytes)
      ..[text] = 0;
    final input = malloc<mtmd_input_text>();
    input.ref
      ..text = promptPtr.cast()
      ..text_len = text
      ..add_special = true
      ..parse_special = true;
    final chunks = mtmd_input_chunks_init();
    final sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    final nPast = malloc<ffi.Int32>();
    final token = malloc<ffi.Int32>();
    final piece = malloc<ffi.Char>(256);
    try {
      final res = mtmd_tokenize(_mtmd, chunks, input, bitmaps, 1);
      if (res != 0) throw LlamaException('mtmd_tokenize failed ($res)');
      llama_sampler_chain_add(
        sampler,
        llama_sampler_init_penalties(llama_vocab_n_tokens(_vocab), sampling.penaltyLastN, sampling.repeatPenalty, 0, 0),
      );
      llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
      // The prompt's text counts for the penalties, as in llama-server.
      final n = malloc<ffi.Size>();
      for (var i = 0; i < mtmd_input_chunks_size(chunks); i++) {
        final chunk = mtmd_input_chunks_get(chunks, i);
        if (mtmd_input_chunk_get_type(chunk) != mtmdChunkText) continue;
        final tokens = mtmd_input_chunk_get_tokens_text(chunk, n);
        for (var k = 0; k < n.value; k++) {
          llama_sampler_accept(sampler, tokens[k]);
        }
      }
      malloc.free(n);
      final promptTokens = mtmd_helper_get_n_tokens(chunks);
      if (mtmd_helper_eval_chunks(_mtmd, _ctx, chunks, 0, 0, 2048, true, nPast) != 0) {
        throw LlamaException('the prompt could not be read (mtmd_helper_eval_chunks)');
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
        if (onText != null && written % textEvery == 0 && !onText(utf8.decode(out.toBytes(), allowMalformed: true))) {
          stopped = true;
          break;
        }
        token.value = t;
        if (llama_decode(_ctx, llama_batch_get_one(token, 1)) != 0) throw LlamaException('llama_decode failed');
      }
      return VisionReading(
        utf8.decode(out.takeBytes(), allowMalformed: true),
        promptTokens: promptTokens,
        tokens: written,
        stopped: stopped,
      );
    } finally {
      llama_sampler_free(sampler);
      mtmd_input_chunks_free(chunks);
      mtmd_bitmap_free(bitmap);
      malloc
        ..free(bitmaps)
        ..free(promptPtr)
        ..free(input)
        ..free(nPast)
        ..free(token)
        ..free(piece);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mtmd_free(_mtmd);
    llama_free(_ctx);
    llama_model_free(_model);
  }
}
