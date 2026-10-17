/// Pinned ONNX Runtime binaries fetched by `hook/build.dart`.
///
/// Windows uses the official DirectML build from NuGet; it contains both the
/// DirectML and the CPU execution providers. DirectML.dll itself is not
/// bundled: Windows 10 1903+ ships it in System32, and if it is missing or
/// too old the session falls back to the CPU provider.
///
/// To upgrade: change the version and SHA-256 here, replace
/// `third_party/onnxruntime/include/onnxruntime_c_api.h` with the header of
/// the same release and run `dart run tool/ffigen.dart`.
abstract final class OrtNativeRelease {
  static const version = '1.24.4';

  static const windowsNupkgUrl =
      'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime.directml/$version/'
      'microsoft.ml.onnxruntime.directml.$version.nupkg';

  static const windowsNupkgSha256 =
      '57e9f11b73437bef7a309496135d4c1f96b1a8e9ddba60013fa27bfc1d788681';

  /// Files extracted from the nupkg for win-x64.
  static const windowsX64Files = [
    'runtimes/win-x64/native/onnxruntime.dll',
    'runtimes/win-x64/native/onnxruntime_providers_shared.dll',
  ];

  /// Code asset id of the main library (`@Native` bindings use it).
  static const assetId = 'package:ct_onnx/onnxruntime';
}
