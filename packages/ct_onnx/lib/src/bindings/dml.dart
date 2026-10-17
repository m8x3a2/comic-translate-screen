// Hand-written bindings for the parts of dml_provider_factory.h we use. The
// header itself cannot be parsed without the D3D12/DirectML SDK headers.
// Layout follows ONNX Runtime 1.24 (Copyright (c) Microsoft Corporation, MIT).

import 'dart:ffi' as ffi;

import 'ort_bindings.g.dart';

/// `OrtDmlPerformancePreference`.
abstract final class OrtDmlPerformancePreference {
  static const defaultPreference = 0;
  static const highPerformance = 1;
  static const minimumPower = 2;
}

/// `OrtDmlDeviceFilter` (without NPU enumeration).
abstract final class OrtDmlDeviceFilter {
  static const gpu = 1;
}

final class OrtDmlDeviceOptions extends ffi.Struct {
  @ffi.Uint32()
  external int preference;

  @ffi.Uint32()
  external int filter;
}

typedef _AppendDmlNative = ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, ffi.Int);
typedef _AppendDml2Native = ffi.Pointer<OrtStatus> Function(
    ffi.Pointer<OrtSessionOptions>, ffi.Pointer<OrtDmlDeviceOptions>);

/// `struct OrtDmlApi`, obtained with `GetExecutionProviderApi("DML", ...)`.
final class OrtDmlApi extends ffi.Struct {
  external ffi.Pointer<ffi.NativeFunction<_AppendDmlNative>> SessionOptionsAppendExecutionProvider_DML;
  external ffi.Pointer<ffi.Void> SessionOptionsAppendExecutionProvider_DML1;
  external ffi.Pointer<ffi.Void> CreateGPUAllocationFromD3DResource;
  external ffi.Pointer<ffi.Void> FreeGPUAllocation;
  external ffi.Pointer<ffi.Void> GetD3D12ResourceFromAllocation;
  external ffi.Pointer<ffi.NativeFunction<_AppendDml2Native>> SessionOptionsAppendExecutionProvider_DML2;
  external ffi.Pointer<ffi.Void> GetDMLDevice;
}

extension OrtDmlApiCalls on OrtDmlApi {
  ffi.Pointer<OrtStatus> appendByIndex(ffi.Pointer<OrtSessionOptions> options, int deviceId) =>
      SessionOptionsAppendExecutionProvider_DML
          .asFunction<ffi.Pointer<OrtStatus> Function(ffi.Pointer<OrtSessionOptions>, int)>()(options, deviceId);

  ffi.Pointer<OrtStatus> appendWithOptions(
          ffi.Pointer<OrtSessionOptions> options, ffi.Pointer<OrtDmlDeviceOptions> deviceOptions) =>
      SessionOptionsAppendExecutionProvider_DML2.asFunction<
          ffi.Pointer<OrtStatus> Function(
              ffi.Pointer<OrtSessionOptions>, ffi.Pointer<OrtDmlDeviceOptions>)>()(options, deviceOptions);
}
