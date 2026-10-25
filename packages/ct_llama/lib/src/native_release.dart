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
  static const version = 'b11858';

  static const windowsZipUrl =
      'https://github.com/ggml-org/llama.cpp/releases/download/$version/llama-$version-bin-win-cpu-x64.zip';

  static const windowsZipSha256 = '5c6d23b10d04c5592acdd6508e0730457c3bba76dc7aa0a25cd06be99fe13c7d';

  /// Libraries the vision reader needs (the processor backends are found by
  /// [isCpuBackend]).
  static const windowsLibraries = ['llama.dll', 'mtmd.dll', 'ggml.dll', 'ggml-base.dll', 'libomp.dll'];

  static bool isCpuBackend(String fileName) => fileName.startsWith('ggml-cpu-') && fileName.endsWith('.dll');
}
