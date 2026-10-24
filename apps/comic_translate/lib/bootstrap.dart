import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';
import 'package:path/path.dart' as p;
import 'package:ct_providers/ct_providers.dart';

import 'app_info.dart';
import 'services/secure_secret_store.dart';
import 'state/gpu_check.dart' show shortGpuReason;

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
    required this.registry,
    required this.usage,
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

  /// All plugins and their live instances.
  final PluginRegistry registry;

  /// The local usage counter of paid services (`usage.json`).
  final UsageLog usage;
  final JsonlFileSink _appLogSink;

  /// Resolves the configuration of plugin [id]: stored values from
  /// [settings], then [overrides], plus its secrets from secure storage.
  Future<PluginConfig> pluginConfig(
    String id,
    AppSettings settings, {
    Map<String, Object?> overrides = const {},
  }) async {
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

  /// The text preparation [id] (default: the one of the settings' content
  /// kind), see `loadTextPrep`.
  Future<TextUpscaler> textPrep(AppSettings settings, {String? id, bool? useGpu, EventLog? log}) async {
    final prep = id ?? settings.activeTextPrep;
    final config = registry.contains(prep) ? await pluginConfig(prep, settings) : null;
    final env = PluginEnvironment(models: models, log: log ?? appLog, useGpu: useGpu ?? settings.useGpu);
    return loadTextPrep(registry, prep, config, env);
  }

  /// The line detector that checks comic lines, or null (see
  /// `loadLineChecker`).
  Future<LineDetector?> lineChecker(AppSettings settings, {bool? useGpu, EventLog? log}) async {
    final config = registry.contains(lineCheckerId) ? await pluginConfig(lineCheckerId, settings) : null;
    final env = PluginEnvironment(models: models, log: log ?? appLog, useGpu: useGpu ?? settings.useGpu);
    return loadLineChecker(registry, settings, config, env);
  }

  /// The text masker of the cleaning level, or null (see `loadTextMasker`).
  Future<TextMasker?> textMasker(AppSettings settings, {bool? useGpu, EventLog? log}) async {
    final id = settings.textMask;
    final config = registry.contains(id) ? await pluginConfig(id, settings) : null;
    final env = PluginEnvironment(models: models, log: log ?? appLog, useGpu: useGpu ?? settings.useGpu);
    return loadTextMasker(registry, settings, config, env);
  }

  /// [secretStore] defaults to the OS secure storage; tests pass a
  /// [MemorySecretStore]. Extra log sinks are built with the shared
  /// [Redactor] so they mask every registered secret too.
  static AppServices create({
    String? dataDirOverride,
    List<LogSink Function(Redactor redactor)> extraSinks = const [],
    SecretStore? secretStore,
    PluginRegistry? registry,
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
      registry: registry ?? builtInRegistry(),
      usage: UsageLog(paths.usageFile),
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
    final settings = await settingsStore.load();
    useModelsDir(settings.modelsDir);
    OrtSession.cpuOnlyModels = settings.gpuCpuModels.keys.toSet();
  }

  /// Remembers in the settings that [model] failed on the graphics card, so
  /// it opens on the processor from now on (`cts`; the window goes through
  /// its settings provider).
  Future<void> rememberGpuFailure(String model, String reason) async {
    final settings = await settingsStore.load();
    settings.gpuCpuModels[model] = shortGpuReason(reason);
    await settingsStore.save(settings);
    OrtSession.cpuOnlyModels.add(model);
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
    extra: {'data_dir': paths.root.path, ...extra},
  );

  /// A bug report zip (logs, environment with the graphics adapters,
  /// settings without secrets), as the GUI buttons build it.
  ///
  /// An [auto] report (built by itself after an unexpected error) is named
  /// `bugreport-auto-…`; only the newest [keepAutoReports] of those stay.
  Future<File> buildBugReport({String? note, bool auto = false}) async {
    await appLog.flush();
    final now = DateTime.now();
    String two(int v) => '$v'.padLeft(2, '0');
    final output = auto
        ? File(
            p.join(
              paths.reports.path,
              'bugreport-auto-${now.year}${two(now.month)}${two(now.day)}-'
              '${two(now.hour)}${two(now.minute)}${two(now.second)}.zip',
            ),
          )
        : null;
    final zip = await BugReportBuilder(
      paths: paths,
      redactor: redactor,
    ).build(environment: await environmentWithGpu(), userNote: note, output: output);
    appLog.info('bug_report', {'file': zip.path, 'with_images': false, 'auto': auto});
    if (auto) _pruneAutoReports();
    return zip;
  }

  static const keepAutoReports = 20;

  void _pruneAutoReports() {
    final old = [
      for (final f in paths.reports.listSync().whereType<File>())
        if (p.basename(f.path).startsWith('bugreport-auto-')) f,
    ]..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final f in old.skip(keepAutoReports)) {
      try {
        f.deleteSync();
      } on FileSystemException {
        // Open elsewhere: next time.
      }
    }
  }

  /// [environment] with the graphics adapters (slower: asks Windows).
  Future<Map<String, Object?>> environmentWithGpu() async => environment({
    'gpu': [for (final g in await GpuInfo.list()) g.toJson()],
  });

  Future<void> dispose() async {
    await registry.disposeInstances();
    await _appLogSink.close();
  }
}
