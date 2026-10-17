import 'package:ct_core/ct_core.dart';

import 'app_info.dart';

/// Shared services created once per process, for both GUI and CLI.
class AppServices {
  AppServices._(this.paths, this.redactor, this.appLog, this._appLogSink);

  final AppPaths paths;
  final Redactor redactor;

  /// Process-wide log (`logs/app.jsonl`), always on and always redacted.
  final EventLog appLog;
  final JsonlFileSink _appLogSink;

  static AppServices create({String? dataDirOverride, List<LogSink> extraSinks = const []}) {
    final paths = AppPaths.resolve(override: dataDirOverride);
    final redactor = Redactor(homeDir: AppPaths.homeDir());
    final sink = JsonlFileSink(paths.appLog, redactor);
    final log = EventLog([sink, ...extraSinks]);
    return AppServices._(paths, redactor, log, sink);
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
