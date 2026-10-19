import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:ct_providers/ct_providers.dart';

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

  /// Downloaded models; the folder follows `AppSettings.modelsDir`.
  ModelManager models;
  final SettingsStore settingsStore;

  /// All built-in plugins and their live instances.
  final PluginRegistry registry = builtInRegistry();
  final JsonlFileSink _appLogSink;

  /// Resolves the configuration of plugin [id]: stored values from
  /// [settings], then [overrides], plus its secrets from secure storage.
  Future<PluginConfig> pluginConfig(String id, AppSettings settings, {Map<String, Object?> overrides = const {}}) async {
    final info = registry.info(id);
    final secrets = <String, String>{};
    for (final field in info.settings.whereType<SecretSetting>()) {
      final value = await this.secrets.read(pluginSecretKey(id, field.key));
      if (value != null && value.isNotEmpty) secrets[field.key] = value;
    }
    return PluginConfig.resolve(info.settings, {...settings.pluginValues(id), ...overrides}, secrets: secrets);
  }

  /// Creates (or reuses) plugin [id] as configured in [settings].
  Future<T> plugin<T extends Plugin>(
    String id,
    AppSettings settings, {
    Map<String, Object?> overrides = const {},
    bool? useGpu,
    EventLog? log,
  }) async {
    final config = await pluginConfig(id, settings, overrides: overrides);
    final env = PluginEnvironment(models: models, log: log ?? appLog, useGpu: useGpu ?? settings.useGpu);
    return registry.instance<T>(id, config, env);
  }

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

  /// Masks all stored secrets from the start and applies the models folder
  /// setting; call once after creation.
  Future<void> init() async {
    try {
      await secrets.primeRedactor();
    } catch (e, st) {
      appLog.error('secret_store_unavailable', e, st);
    }
    useModelsDir((await settingsStore.load()).modelsDir);
  }

  /// Switches to the models folder [dir] (empty: the default folder).
  void useModelsDir(String dir) {
    final root = dir.trim().isEmpty ? paths.models : Directory(dir.trim());
    if (p.equals(root.path, models.root.path)) return;
    models = ModelManager(root, log: appLog);
    appLog.info('models_dir', {'path': root.path});
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

  Future<void> dispose() async {
    await registry.disposeInstances();
    await _appLogSink.close();
  }
}
