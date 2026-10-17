import 'dart:io';

/// Snapshot of the runtime environment for `env.json` and `cts doctor`.
///
/// Platform-specific facts that need native code (GPU, ONNX Runtime providers,
/// OCR languages) are added by the app layer through [extra].
class EnvInfo {
  static Map<String, Object?> collect({
    required String appVersion,
    String? gitSha,
    String? flutterVersion,
    Map<String, Object?> extra = const {},
  }) {
    final env = Platform.environment;
    return {
      'app': {
        'name': 'Comic Translate Screen',
        'version': appVersion,
        if (gitSha != null && gitSha.isNotEmpty) 'git_sha': gitSha,
      },
      'runtime': {
        'dart': Platform.version,
        'flutter': ?flutterVersion,
        'executable': Platform.resolvedExecutable,
      },
      'os': {
        'name': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      },
      'cpu': {
        'logical_processors': Platform.numberOfProcessors,
        if (env['PROCESSOR_IDENTIFIER'] != null) 'identifier': env['PROCESSOR_IDENTIFIER'],
        if (env['PROCESSOR_ARCHITECTURE'] != null) 'arch': env['PROCESSOR_ARCHITECTURE'],
      },
      ...extra,
    };
  }
}
