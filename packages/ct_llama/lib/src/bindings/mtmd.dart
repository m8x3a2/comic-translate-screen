// The functions of mtmd.dll and ggml.dll the vision reader uses, written by
// hand from mtmd.h, mtmd-helper.h and ggml-backend.h (llama.cpp, MIT
// license); llama.dll comes from llama_bindings.g.dart.
// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi' as ffi;

import 'llama_bindings.g.dart';

const _mtmd = 'package:ct_llama/mtmd';
const _ggml = 'package:ct_llama/ggml';
const _ggmlBase = 'package:ct_llama/ggml-base';
const _omp = 'package:ct_llama/libomp';

final class mtmd_context extends ffi.Opaque {}

final class mtmd_bitmap extends ffi.Opaque {}

final class mtmd_input_chunks extends ffi.Opaque {}

final class mtmd_input_chunk extends ffi.Opaque {}

/// `MTMD_INPUT_CHUNK_TYPE_TEXT`.
const mtmdChunkText = 0;

final class mtmd_context_params extends ffi.Struct {
  @ffi.Bool()
  external bool use_gpu;
  external ffi.Pointer<ffi.Void> device;
  @ffi.Bool()
  external bool print_timings;
  @ffi.Int()
  external int n_threads;
  external ffi.Pointer<ffi.Char> image_marker;
  external ffi.Pointer<ffi.Char> media_marker;
  @ffi.Int()
  external int flash_attn_type;
  @ffi.Bool()
  external bool warmup;
  @ffi.Int()
  external int image_min_tokens;
  @ffi.Int()
  external int image_max_tokens;
  external ffi.Pointer<ffi.Void> cb_eval;
  external ffi.Pointer<ffi.Void> cb_eval_user_data;
  @ffi.Int32()
  external int batch_max_tokens;
  external ffi.Pointer<ffi.Void> progress_callback;
  external ffi.Pointer<ffi.Void> progress_callback_user_data;
}

final class mtmd_input_text extends ffi.Struct {
  external ffi.Pointer<ffi.Char> text;
  @ffi.Size()
  external int text_len;
  @ffi.Bool()
  external bool add_special;
  @ffi.Bool()
  external bool parse_special;
}

@ffi.Native<ffi.Pointer<ffi.Char> Function()>(assetId: _mtmd)
external ffi.Pointer<ffi.Char> mtmd_default_marker();

@ffi.Native<mtmd_context_params Function()>(assetId: _mtmd)
external mtmd_context_params mtmd_context_params_default();

@ffi.Native<ffi.Pointer<mtmd_context> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<llama_model>, mtmd_context_params)>(
  assetId: _mtmd,
)
external ffi.Pointer<mtmd_context> mtmd_init_from_file(
  ffi.Pointer<ffi.Char> mmprojFname,
  ffi.Pointer<llama_model> textModel,
  mtmd_context_params params,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<mtmd_context>)>(assetId: _mtmd)
external void mtmd_free(ffi.Pointer<mtmd_context> ctx);

@ffi.Native<ffi.Pointer<mtmd_bitmap> Function(ffi.Uint32, ffi.Uint32, ffi.Pointer<ffi.UnsignedChar>)>(assetId: _mtmd)
external ffi.Pointer<mtmd_bitmap> mtmd_bitmap_init(int nx, int ny, ffi.Pointer<ffi.UnsignedChar> data);

@ffi.Native<ffi.Void Function(ffi.Pointer<mtmd_bitmap>)>(assetId: _mtmd)
external void mtmd_bitmap_free(ffi.Pointer<mtmd_bitmap> bitmap);

@ffi.Native<ffi.Pointer<mtmd_input_chunks> Function()>(assetId: _mtmd)
external ffi.Pointer<mtmd_input_chunks> mtmd_input_chunks_init();

@ffi.Native<ffi.Size Function(ffi.Pointer<mtmd_input_chunks>)>(assetId: _mtmd)
external int mtmd_input_chunks_size(ffi.Pointer<mtmd_input_chunks> chunks);

@ffi.Native<ffi.Pointer<mtmd_input_chunk> Function(ffi.Pointer<mtmd_input_chunks>, ffi.Size)>(assetId: _mtmd)
external ffi.Pointer<mtmd_input_chunk> mtmd_input_chunks_get(ffi.Pointer<mtmd_input_chunks> chunks, int idx);

@ffi.Native<ffi.Void Function(ffi.Pointer<mtmd_input_chunks>)>(assetId: _mtmd)
external void mtmd_input_chunks_free(ffi.Pointer<mtmd_input_chunks> chunks);

@ffi.Native<ffi.Int Function(ffi.Pointer<mtmd_input_chunk>)>(assetId: _mtmd)
external int mtmd_input_chunk_get_type(ffi.Pointer<mtmd_input_chunk> chunk);

@ffi.Native<ffi.Pointer<ffi.Int32> Function(ffi.Pointer<mtmd_input_chunk>, ffi.Pointer<ffi.Size>)>(assetId: _mtmd)
external ffi.Pointer<ffi.Int32> mtmd_input_chunk_get_tokens_text(
  ffi.Pointer<mtmd_input_chunk> chunk,
  ffi.Pointer<ffi.Size> nTokens,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Pointer<mtmd_context>,
    ffi.Pointer<mtmd_input_chunks>,
    ffi.Pointer<mtmd_input_text>,
    ffi.Pointer<ffi.Pointer<mtmd_bitmap>>,
    ffi.Size,
  )
>(assetId: _mtmd)
external int mtmd_tokenize(
  ffi.Pointer<mtmd_context> ctx,
  ffi.Pointer<mtmd_input_chunks> output,
  ffi.Pointer<mtmd_input_text> text,
  ffi.Pointer<ffi.Pointer<mtmd_bitmap>> bitmaps,
  int nBitmaps,
);

@ffi.Native<ffi.Size Function(ffi.Pointer<mtmd_input_chunks>)>(assetId: _mtmd)
external int mtmd_helper_get_n_tokens(ffi.Pointer<mtmd_input_chunks> chunks);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Pointer<mtmd_context>,
    ffi.Pointer<llama_context>,
    ffi.Pointer<mtmd_input_chunks>,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Bool,
    ffi.Pointer<ffi.Int32>,
  )
>(assetId: _mtmd)
external int mtmd_helper_eval_chunks(
  ffi.Pointer<mtmd_context> ctx,
  ffi.Pointer<llama_context> lctx,
  ffi.Pointer<mtmd_input_chunks> chunks,
  int nPast,
  int seqId,
  int nBatch,
  bool logitsLast,
  ffi.Pointer<ffi.Int32> newNPast,
);

typedef LogCallback = ffi.Void Function(ffi.UnsignedInt level, ffi.Pointer<ffi.Char> text, ffi.Pointer<ffi.Void> user);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeFunction<LogCallback>>, ffi.Pointer<ffi.Void>)>(assetId: _mtmd)
external void mtmd_helper_log_set(ffi.Pointer<ffi.NativeFunction<LogCallback>> callback, ffi.Pointer<ffi.Void> user);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Char>)>(assetId: _ggml)
external void ggml_backend_load_all_from_path(ffi.Pointer<ffi.Char> dirPath);

@ffi.Native<ffi.Size Function()>(assetId: _ggml)
external int ggml_backend_dev_count();

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeFunction<LogCallback>>, ffi.Pointer<ffi.Void>)>(assetId: _ggmlBase)
external void ggml_log_set(ffi.Pointer<ffi.NativeFunction<LogCallback>> callback, ffi.Pointer<ffi.Void> user);

/// Any function of ggml-base.dll: calling it loads the library first.
@ffi.Native<ffi.Void Function()>(assetId: _ggmlBase)
external void ggml_time_init();

/// Any function of libomp.dll: calling it loads the library first.
@ffi.Native<ffi.Int Function()>(assetId: _omp)
external int omp_get_max_threads();
