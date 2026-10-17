import 'package:ct_core/ct_core.dart';

import 'app_info.dart';
import 'services/secure_secret_store.dart';

/// Shared services created once per process, for both GUI and CLI.
class AppServices {
  AppServices._(
    this._appLogSink, {
    required this.paths,
    required this.redactor,
    required this.appLog,
    required this.secrets,
    required this.models,
    required this.settingsStore,
  });

  final AppPaths paths;
  final Redactor redactor;

  /// Process-wide log (`logs/app.jsonl`), always on and always redacted.
  final EventLog appLog;

  /// Secure storage; every secret read or written is masked in diagnostics.
  final RedactingSecretStore secrets;
  final ModelManager models;
  final SettingsStore settingsStore;
  final JsonlFileSink _appLogSink;

  /// [secretStore] defaults to the OS secure storage; tests pass a
  /// [MemorySecretStore]. Extra log sinks are built with the shared
  /// [Redactor] so they mask every registered secret too.
  static AppServices create({
    String? dataDirOverride,
    List<LogSink Function(Redactor redactor)> extraSinks = const [],
    SecretStore? secretStore,
  }) {
    final paths = AppPaths.resolve(override: dataDirOverride);
    final redactor = Redactor(homeDir: AppPaths.homeDir());
    final sink = JsonlFileSink(paths.appLog, redactor);
    final log = EventLog([sink, for (final build in extraSinks) build(redactor)]);
    return AppServices._(
      sink,
      paths: paths,
      redactor: redactor,
      appLog: log,
      secrets: RedactingSecretStore(secretStore ?? SecureSecretStore(), redactor),
      models: ModelManager(paths.models, log: log),
      settingsStore: SettingsStore(paths.settingsFile, log: log),
    );
  }

  /// Masks all stored secrets from the start; call once after creation.
  Future<void> init() async {
    try {
      await secrets.primeRedactor();
    } catch (e, st) {
      appLog.error('secret_store_unavailable', e, st);
    }
  }

  Map<String, Object?> environment([Map<String, Object?> extra = const {}]) => EnvInfo.collect(
        appVersion: AppInfo.version,
        gitSha: AppInfo.gitSha,
        flutterVersion: AppInfo.flutterVersion,
        extra: {
          'data_dir': paths.root.path,
          ...extra,
        },
      );

  Future<void> dispose() => _appLogSink.close();
}
