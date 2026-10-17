import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/dml.dart';
import 'bindings/ort_bindings.g.dart' hide OrtSession;
import 'bindings/ort_bindings.g.dart' as b show OrtSession;
import 'native_release.dart';

/// Error reported by ONNX Runtime.
class OrtException implements Exception {
  OrtException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'OrtException($code): $message';
}

/// Element types we exchange with models (`ONNXTensorElementDataType`).
enum OrtElementType {
  float32(1, 4),
  uint8(2, 1),
  int8(3, 1),
  int32(6, 4),
  int64(7, 8),
  bool_(9, 1),
  float64(11, 8);

  const OrtElementType(this.onnxId, this.byteSize);

  final int onnxId;
  final int byteSize;

  static OrtElementType? fromOnnx(int id) {
    for (final t in values) {
      if (t.onnxId == id) return t;
    }
    return null;
  }
}

/// A dense tensor held in Dart memory.
class OrtTensor {
  OrtTensor._(this.type, this.shape, this.data) {
    final expected = shape.fold<int>(1, (a, b) => a * b);
    final actual = data.lengthInBytes ~/ type.byteSize;
    if (expected != actual) {
      throw ArgumentError('Shape $shape needs $expected elements, data has $actual');
    }
  }

  OrtTensor.float32(Float32List data, List<int> shape) : this._(OrtElementType.float32, List.unmodifiable(shape), data);
  OrtTensor.int64(Int64List data, List<int> shape) : this._(OrtElementType.int64, List.unmodifiable(shape), data);
  OrtTensor.int32(Int32List data, List<int> shape) : this._(OrtElementType.int32, List.unmodifiable(shape), data);
  OrtTensor.uint8(Uint8List data, List<int> shape) : this._(OrtElementType.uint8, List.unmodifiable(shape), data);
  OrtTensor.float64(Float64List data, List<int> shape) : this._(OrtElementType.float64, List.unmodifiable(shape), data);

  final OrtElementType type;
  final List<int> shape;
  final TypedData data;

  int get elementCount => shape.fold(1, (a, b) => a * b);

  Float32List get asFloat32 => data as Float32List;
  Int64List get asInt64 => data as Int64List;
  Int32List get asInt32 => data as Int32List;
  Uint8List get asUint8 => data as Uint8List;
  Float64List get asFloat64 => data as Float64List;

  Uint8List get _bytes => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  @override
  String toString() => 'OrtTensor(${type.name}, $shape)';
}

/// Input or output description of a model.
class OrtTensorInfo {
  OrtTensorInfo(this.name, this.type, this.elementTypeId, this.shape);

  final String name;

  /// Null when the element type is not one of [OrtElementType].
  final OrtElementType? type;
  final int elementTypeId;

  /// Dimensions; -1 for dynamic ones.
  final List<int> shape;

  @override
  String toString() => '$name: ${type?.name ?? 'type#$elementTypeId'} $shape';
}

enum OrtDevice {
  cpu,

  /// GPU through DirectML (Windows). Falls back to CPU when unavailable.
  directml,
}

class OrtSessionConfig {
  const OrtSessionConfig({
    this.intraOpThreads = 0,
    this.interOpThreads = 0,
    this.sequential = true,
    this.optimizationLevel = 99,
    this.memPattern = true,
    this.cpuArena = true,
    this.logSeverity = 3,
    this.dmlHighPerformance = true,
  });

  /// 0 lets ONNX Runtime choose.
  final int intraOpThreads;
  final int interOpThreads;
  final bool sequential;

  /// `GraphOptimizationLevel`: 0 disabled, 1 basic, 2 extended, 99 all.
  final int optimizationLevel;
  final bool memPattern;
  final bool cpuArena;

  /// 0 verbose … 3 error, 4 fatal.
  final int logSeverity;

  /// Prefer the high-performance GPU (discrete card on laptops with two GPUs).
  final bool dmlHighPerformance;
}

/// Process-wide ONNX Runtime entry point (one per isolate).
class OrtRuntime {
  OrtRuntime._(this._api, this._env);

  static OrtRuntime? _instance;

  static OrtRuntime get instance => _instance ??= _create();

  final ffi.Pointer<OrtApi> _api;
  final ffi.Pointer<OrtEnv> _env;

  static OrtRuntime _create() {
    final base = OrtGetApiBase();
    if (base == ffi.nullptr) throw StateError('OrtGetApiBase returned null');
    final getApi = base.ref.GetApi.asFunction<ffi.Pointer<OrtApi> Function(int)>();
    final api = getApi(ORT_API_VERSION);
    if (api == ffi.nullptr) {
      throw StateError('ONNX Runtime does not support API version $ORT_API_VERSION '
          '(loaded ${versionOf(base)}, expected ${OrtNativeRelease.version})');
    }
    return using((arena) {
      final out = arena<ffi.Pointer<OrtEnv>>();
      _checkWith(api, api.ref.CreateEnv.asFunction<
          ffi.Pointer<OrtStatus> Function(int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Pointer<OrtEnv>>)>()(
        3, // ORT_LOGGING_LEVEL_ERROR
        'comic_translate_screen'.toNativeUtf8(allocator: arena).cast(),
        out,
      ));
      return OrtRuntime._(api, out.value);
    });
  }

  static String versionOf(ffi.Pointer<OrtApiBase> base) =>
      base.ref.GetVersionString.asFunction<ffi.Pointer<ffi.Char> Function()>()().cast<Utf8>().toDartString();

  /// Version of the loaded native library, e.g. `1.24.4`.
  String get version => versionOf(OrtGetApiBase());

  /// Execution providers compiled into the library, e.g.
  /// `[DmlExecutionProvider, CPUExecutionProvider]`.
  List<String> get availableProviders => using((arena) {
        final out = arena<ffi.Pointer<ffi.Pointer<ffi.Char>>>();
        final len = arena<ffi.Int>();
        _check(_api.ref.GetAvailableProviders.asFunction<
            ffi.Pointer<OrtStatus> Function(ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Char>>>, ffi.Pointer<ffi.Int>)>()(
          out,
          len,
        ));
        final result = [for (var i = 0; i < len.value; i++) out.value[i].cast<Utf8>().toDartString()];
        _check(_api.ref.ReleaseAvailableProviders.asFunction<
            ffi.Pointer<OrtStatus> Function(ffi.Pointer<ffi.Pointer<ffi.Char>>, int)>()(out.value, len.value));
        return result;
      });

  bool get hasDirectML => availableProviders.contains('DmlExecutionProvider');

  void _check(ffi.Pointer<OrtStatus> status) => _checkWith(_api, status);

  static void _checkWith(ffi.Pointer<OrtApi> api, ffi.Pointer<OrtStatus> status) {
    if (status == ffi.nullptr) return;
    final code = api.ref.GetErrorCode.asFunction<int Function(ffi.Pointer<OrtStatus>)>()(status);
    final message = decodeNativeMessage(
        api.ref.GetErrorMessage.asFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<OrtStatus>)>()(status).cast());
    api.ref.ReleaseStatus.asFunction<void Function(ffi.Pointer<OrtStatus>)>()(status);
    throw OrtException(code, message);
  }
}

/// Decodes a NUL-terminated native message. ONNX Runtime passes through
/// Windows system messages in the local code page (e.g. cp1251), which are
/// not valid UTF-8; invalid sequences become U+FFFD instead of throwing.
String decodeNativeMessage(ffi.Pointer<ffi.Uint8> ptr) {
  if (ptr == ffi.nullptr) return '';
  var length = 0;
  while (ptr[length] != 0 && length < 1 << 16) {
    length++;
  }
  return utf8.decode(ptr.asTypedList(length), allowMalformed: true);
}

/// A loaded model.
class OrtSession {
  OrtSession._(this._rt, this._session, this._options, this.device, this.fallbackReason, this.modelPath) {
    inputs = _describe(input: true);
    outputs = _describe(input: false);
  }

  final OrtRuntime _rt;
  ffi.Pointer<b.OrtSession> _session;
  ffi.Pointer<OrtSessionOptions> _options;
  final String modelPath;

  /// Device actually used (may be CPU when DirectML was requested).
  final OrtDevice device;

  /// Why DirectML was not used, if it was requested and failed.
  final String? fallbackReason;

  late final List<OrtTensorInfo> inputs;
  late final List<OrtTensorInfo> outputs;

  bool get isDisposed => _session == ffi.nullptr;

  /// Loads [modelPath]. With [OrtDevice.directml] the session falls back to
  /// CPU if the DirectML provider cannot be created.
  static OrtSession open(String modelPath,
      {OrtDevice device = OrtDevice.cpu, OrtSessionConfig config = const OrtSessionConfig()}) {
    if (!File(modelPath).existsSync()) throw ArgumentError('Model file not found: $modelPath');
    final rt = OrtRuntime.instance;
    if (device == OrtDevice.directml) {
      try {
        return _open(rt, modelPath, OrtDevice.directml, config, null);
      } on OrtException catch (e) {
        return _open(rt, modelPath, OrtDevice.cpu, config, 'DirectML unavailable: ${e.message}');
      }
    }
    return _open(rt, modelPath, OrtDevice.cpu, config, null);
  }

  static OrtSession _open(
      OrtRuntime rt, String path, OrtDevice device, OrtSessionConfig config, String? fallbackReason) {
    final api = rt._api.ref;
    final options = using((arena) {
      final out = arena<ffi.Pointer<OrtSessionOptions>>();
      rt._check(api.CreateSessionOptions
          .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<ffi.Pointer<OrtSessionOptions>>)>()(out));
      return out.value;
    });
    try {
      _configure(rt, options, device, config);
      final session = using((arena) {
        final out = arena<ffi.Pointer<b.OrtSession>>();
        final nativePath = Platform.isWindows
            ? path.toNativeUtf16(allocator: arena).cast<ffi.WChar>()
            : path.toNativeUtf8(allocator: arena).cast<ffi.WChar>();
        rt._check(api.CreateSession.asFunction<
            ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtEnv>, ffi.Pointer<ffi.WChar>, ffi.Pointer<OrtSessionOptions>,
                ffi.Pointer<ffi.Pointer<b.OrtSession>>)>()(rt._env, nativePath, options, out));
        return out.value;
      });
      return OrtSession._(rt, session, options, device, fallbackReason, path);
    } catch (_) {
      api.ReleaseSessionOptions.asFunction<void Function(ffi.Pointer<OrtSessionOptions>)>()(options);
      rethrow;
    }
  }

  static void _configure(
      OrtRuntime rt, ffi.Pointer<OrtSessionOptions> o, OrtDevice device, OrtSessionConfig c) {
    final api = rt._api.ref;
    rt._check(api.SetSessionLogSeverityLevel
        .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(o, c.logSeverity));
    rt._check(api.SetSessionGraphOptimizationLevel
        .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(o, c.optimizationLevel));
    if (c.intraOpThreads > 0) {
      rt._check(api.SetIntraOpNumThreads
          .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(o, c.intraOpThreads));
    }
    if (c.interOpThreads > 0) {
      rt._check(api.SetInterOpNumThreads
          .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(o, c.interOpThreads));
    }
    // DirectML requires sequential execution without memory patterns.
    final sequential = c.sequential || device == OrtDevice.directml;
    rt._check(api.SetSessionExecutionMode
        .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(o, sequential ? 0 : 1));
    if (!c.memPattern || device == OrtDevice.directml) {
      rt._check(api.DisableMemPattern.asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>)>()(o));
    }
    if (!c.cpuArena) {
      rt._check(api.DisableCpuMemArena.asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>)>()(o));
    }

    if (device == OrtDevice.directml) _appendDirectML(rt, o, c);
  }

  static void _appendDirectML(OrtRuntime rt, ffi.Pointer<OrtSessionOptions> o, OrtSessionConfig c) {
    if (!rt.hasDirectML) throw OrtException(-1, 'this ONNX Runtime build has no DirectML provider');
    using((arena) {
      final apiOut = arena<ffi.Pointer<ffi.Void>>();
      rt._check(rt._api.ref.GetExecutionProviderApi.asFunction<
          ffi.Pointer<OrtStatus> Function(ffi.Pointer<ffi.Char>, int, ffi.Pointer<ffi.Pointer<ffi.Void>>)>()(
        'DML'.toNativeUtf8(allocator: arena).cast(),
        ORT_API_VERSION,
        apiOut,
      ));
      final dml = apiOut.value.cast<OrtDmlApi>().ref;
      if (c.dmlHighPerformance) {
        final opts = arena<OrtDmlDeviceOptions>()
          ..ref.preference = OrtDmlPerformancePreference.highPerformance
          ..ref.filter = OrtDmlDeviceFilter.gpu;
        rt._check(dml.appendWithOptions(o, opts));
      } else {
        rt._check(dml.appendByIndex(o, 0));
      }
    });
  }

  List<OrtTensorInfo> _describe({required bool input}) {
    final api = _rt._api.ref;
    return using((arena) {
      final count = arena<ffi.Size>();
      _rt._check((input ? api.SessionGetInputCount : api.SessionGetOutputCount)
          .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<b.OrtSession>, ffi.Pointer<ffi.Size>)>()(
        _session,
        count,
      ));
      final allocator = _defaultAllocator(arena);
      final result = <OrtTensorInfo>[];
      for (var i = 0; i < count.value; i++) {
        final namePtr = arena<ffi.Pointer<ffi.Char>>();
        _rt._check((input ? api.SessionGetInputName : api.SessionGetOutputName).asFunction<
            ffi.Pointer<OrtStatus> Function(ffi.Pointer<b.OrtSession>, int, ffi.Pointer<OrtAllocator>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>)>()(_session, i, allocator, namePtr));
        final name = namePtr.value.cast<Utf8>().toDartString();
        _rt._check(api.AllocatorFree
            .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtAllocator>, ffi.Pointer<ffi.Void>)>()(
          allocator,
          namePtr.value.cast(),
        ));

        final typeInfo = arena<ffi.Pointer<OrtTypeInfo>>();
        _rt._check((input ? api.SessionGetInputTypeInfo : api.SessionGetOutputTypeInfo).asFunction<
            ffi.Pointer<OrtStatus> Function(
                ffi.Pointer<b.OrtSession>, int, ffi.Pointer<ffi.Pointer<OrtTypeInfo>>)>()(_session, i, typeInfo));
        try {
          final tensorInfo = arena<ffi.Pointer<OrtTensorTypeAndShapeInfo>>();
          _rt._check(api.CastTypeInfoToTensorInfo.asFunction<
              ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtTypeInfo>,
                  ffi.Pointer<ffi.Pointer<OrtTensorTypeAndShapeInfo>>)>()(typeInfo.value, tensorInfo));
          if (tensorInfo.value == ffi.nullptr) {
            result.add(OrtTensorInfo(name, null, 0, const []));
          } else {
            final (elem, shape) = _typeAndShape(tensorInfo.value, arena);
            result.add(OrtTensorInfo(name, OrtElementType.fromOnnx(elem), elem, shape));
          }
        } finally {
          api.ReleaseTypeInfo.asFunction<void Function(ffi.Pointer<OrtTypeInfo>)>()(typeInfo.value);
        }
      }
      return result;
    });
  }

  ffi.Pointer<OrtAllocator> _defaultAllocator(Arena arena) {
    final out = arena<ffi.Pointer<OrtAllocator>>();
    _rt._check(_rt._api.ref.GetAllocatorWithDefaultOptions
        .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<ffi.Pointer<OrtAllocator>>)>()(out));
    return out.value;
  }

  (int, List<int>) _typeAndShape(ffi.Pointer<OrtTensorTypeAndShapeInfo> info, Arena arena) {
    final api = _rt._api.ref;
    final elem = arena<ffi.UnsignedInt>();
    _rt._check(api.GetTensorElementType.asFunction<
        ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtTensorTypeAndShapeInfo>, ffi.Pointer<ffi.UnsignedInt>)>()(
      info,
      elem,
    ));
    final dimsCount = arena<ffi.Size>();
    _rt._check(api.GetDimensionsCount.asFunction<
        ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtTensorTypeAndShapeInfo>, ffi.Pointer<ffi.Size>)>()(
      info,
      dimsCount,
    ));
    final dims = arena<ffi.Int64>(dimsCount.value == 0 ? 1 : dimsCount.value);
    _rt._check(api.GetDimensions.asFunction<
        ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtTensorTypeAndShapeInfo>, ffi.Pointer<ffi.Int64>, int)>()(
      info,
      dims,
      dimsCount.value,
    ));
    return (elem.value, [for (var i = 0; i < dimsCount.value; i++) dims[i]]);
  }

  /// Runs the model. [outputNames] defaults to all outputs.
  Map<String, OrtTensor> run(Map<String, OrtTensor> feeds, {List<String>? outputNames}) {
    if (isDisposed) throw StateError('Session is disposed');
    final api = _rt._api.ref;
    final names = outputNames ?? [for (final o in outputs) o.name];
    return using((arena) {
      final memInfo = arena<ffi.Pointer<OrtMemoryInfo>>();
      _rt._check(api.CreateCpuMemoryInfo.asFunction<
          ffi.Pointer<OrtStatus> Function(int, int, ffi.Pointer<ffi.Pointer<OrtMemoryInfo>>)>()(
        0, // OrtDeviceAllocator
        0, // OrtMemTypeDefault
        memInfo,
      ));
      final inputValues = arena<ffi.Pointer<OrtValue>>(feeds.length);
      final inputNames = arena<ffi.Pointer<ffi.Char>>(feeds.length);
      final outputValues = arena<ffi.Pointer<OrtValue>>(names.length);
      final outputNamePtrs = arena<ffi.Pointer<ffi.Char>>(names.length);
      final releaseValue = api.ReleaseValue.asFunction<void Function(ffi.Pointer<OrtValue>)>();
      var created = 0;
      try {
        var i = 0;
        for (final MapEntry(key: name, value: tensor) in feeds.entries) {
          final bytes = tensor._bytes;
          final buffer = arena<ffi.Uint8>(bytes.isEmpty ? 1 : bytes.length);
          buffer.asTypedList(bytes.length).setAll(0, bytes);
          final shape = arena<ffi.Int64>(tensor.shape.isEmpty ? 1 : tensor.shape.length);
          for (var d = 0; d < tensor.shape.length; d++) {
            shape[d] = tensor.shape[d];
          }
          inputNames[i] = name.toNativeUtf8(allocator: arena).cast();
          _rt._check(api.CreateTensorWithDataAsOrtValue.asFunction<
              ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtMemoryInfo>, ffi.Pointer<ffi.Void>, int,
                  ffi.Pointer<ffi.Int64>, int, int, ffi.Pointer<ffi.Pointer<OrtValue>>)>()(
            memInfo.value,
            buffer.cast(),
            bytes.length,
            shape,
            tensor.shape.length,
            tensor.type.onnxId,
            inputValues + i,
          ));
          created++;
          i++;
        }
        for (var j = 0; j < names.length; j++) {
          outputNamePtrs[j] = names[j].toNativeUtf8(allocator: arena).cast();
          outputValues[j] = ffi.nullptr;
        }

        _rt._check(api.Run.asFunction<
            ffi.Pointer<OrtStatus> Function(
                ffi.Pointer<b.OrtSession>,
                ffi.Pointer<OrtRunOptions>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                ffi.Pointer<ffi.Pointer<OrtValue>>,
                int,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                int,
                ffi.Pointer<ffi.Pointer<OrtValue>>)>()(
          _session,
          ffi.nullptr,
          inputNames,
          inputValues,
          feeds.length,
          outputNamePtrs,
          names.length,
          outputValues,
        ));

        final results = <String, OrtTensor>{};
        try {
          for (var j = 0; j < names.length; j++) {
            results[names[j]] = _readTensor(outputValues[j], arena);
          }
        } finally {
          for (var j = 0; j < names.length; j++) {
            if (outputValues[j] != ffi.nullptr) releaseValue(outputValues[j]);
          }
        }
        return results;
      } finally {
        for (var k = 0; k < created; k++) {
          releaseValue(inputValues[k]);
        }
        api.ReleaseMemoryInfo.asFunction<void Function(ffi.Pointer<OrtMemoryInfo>)>()(memInfo.value);
      }
    });
  }

  OrtTensor _readTensor(ffi.Pointer<OrtValue> value, Arena arena) {
    final api = _rt._api.ref;
    final info = arena<ffi.Pointer<OrtTensorTypeAndShapeInfo>>();
    _rt._check(api.GetTensorTypeAndShape.asFunction<
        ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtValue>, ffi.Pointer<ffi.Pointer<OrtTensorTypeAndShapeInfo>>)>()(
      value,
      info,
    ));
    final (elem, shape) = (() {
      try {
        return _typeAndShape(info.value, arena);
      } finally {
        api.ReleaseTensorTypeAndShapeInfo
            .asFunction<void Function(ffi.Pointer<OrtTensorTypeAndShapeInfo>)>()(info.value);
      }
    })();
    final type = OrtElementType.fromOnnx(elem) ??
        (throw OrtException(-1, 'Unsupported output element type $elem'));
    final count = shape.fold<int>(1, (a, b) => a * b);
    final dataPtr = arena<ffi.Pointer<ffi.Void>>();
    _rt._check(api.GetTensorMutableData
        .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtValue>, ffi.Pointer<ffi.Pointer<ffi.Void>>)>()(
      value,
      dataPtr,
    ));
    final p = dataPtr.value;
    return switch (type) {
      OrtElementType.float32 => OrtTensor.float32(Float32List.fromList(p.cast<ffi.Float>().asTypedList(count)), shape),
      OrtElementType.int64 => OrtTensor.int64(Int64List.fromList(p.cast<ffi.Int64>().asTypedList(count)), shape),
      OrtElementType.int32 => OrtTensor.int32(Int32List.fromList(p.cast<ffi.Int32>().asTypedList(count)), shape),
      OrtElementType.uint8 || OrtElementType.bool_ || OrtElementType.int8 =>
        OrtTensor._(type, List.unmodifiable(shape), Uint8List.fromList(p.cast<ffi.Uint8>().asTypedList(count))),
      OrtElementType.float64 => OrtTensor.float64(Float64List.fromList(p.cast<ffi.Double>().asTypedList(count)), shape),
    };
  }

  void dispose() {
    if (isDisposed) return;
    final api = _rt._api.ref;
    api.ReleaseSession.asFunction<void Function(ffi.Pointer<b.OrtSession>)>()(_session);
    api.ReleaseSessionOptions.asFunction<void Function(ffi.Pointer<OrtSessionOptions>)>()(_options);
    _session = ffi.nullptr;
    _options = ffi.nullptr;
  }
}
