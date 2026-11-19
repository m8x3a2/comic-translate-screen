/// Pinned llama.cpp binaries fetched by `hook/build.dart`.
///
/// Windows uses the official CPU build: ggml picks the backend of the
/// processor at run time (`ggml-cpu-<generation>.dll`), so every variant is
/// bundled.
///
/// To upgrade: change the version and SHA-256 here, replace the headers in
/// `third_party/llama.cpp/include` with those of the same release, run
/// `dart run tool/ffigen.dart` and check `lib/src/bindings/mtmd.dart`
/// against `mtmd.h`.
abstract final class LlamaNativeRelease {
  static const version = 'b12527';

  static const windowsZipUrl =
      'https://github.com/ggml-org/llama.cpp/releases/download/$version/llama-$version-bin-win-cpu-x64.zip';

  static const windowsZipSha256 = '815758c855b6f561104a3d9e17ae599ba830065ff7807a0e1ce1f9656c4601b0';

  /// Libraries the vision reader needs (the processor backends are found by
  /// [isCpuBackend]).
  static const windowsLibraries = ['llama.dll', 'mtmd.dll', 'ggml.dll', 'ggml-base.dll', 'libomp.dll'];

  static bool isCpuBackend(String fileName) => fileName.startsWith('ggml-cpu-') && fileName.endsWith('.dll');
}
