import 'dart:io';

import 'package:path/path.dart' as p;

/// Locations of everything the app writes. GUI and CLI share one data dir.
class AppPaths {
  AppPaths(String root) : root = Directory(p.normalize(p.absolute(root)));

  static const dataDirEnv = 'CTS_DATA_DIR';
  static const windowsFolderName = 'ComicTranslateScreen';

  final Directory root;

  Directory get logs => _dir('logs');
  Directory get runs => _dir('runs');
  Directory get models => _dir('models');
  Directory get reports => _dir('reports');
  Directory get cache => _dir('cache');
  File get settingsFile => File(p.join(root.path, 'settings.json'));
  File get appLog => File(p.join(logs.path, 'app.jsonl'));

  /// The local usage counter of paid services ([UsageLog]).
  File get usageFile => File(p.join(root.path, 'usage.json'));

  Directory _dir(String name) => Directory(p.join(root.path, name));

  /// Resolution order: explicit [override] (CLI `--data-dir`), the
  /// `CTS_DATA_DIR` environment variable, then the platform default.
  ///
  /// On Windows the default is `%LOCALAPPDATA%\ComicTranslateScreen`: local,
  /// not roaming, because models are hundreds of megabytes. Mobile platforms
  /// pass an override obtained from path_provider.
  static AppPaths resolve({String? override, Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    if (override != null && override.isNotEmpty) return AppPaths(override);
    final fromEnv = env[dataDirEnv];
    if (fromEnv != null && fromEnv.isNotEmpty) return AppPaths(fromEnv);
    if (Platform.isWindows) {
      final local = env['LOCALAPPDATA'] ?? p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Local');
      return AppPaths(p.join(local, windowsFolderName));
    }
    final home = env['HOME'] ?? '.';
    return AppPaths(p.join(home, '.comic_translate_screen'));
  }

  /// The user's home directory, masked in diagnostics.
  static String? homeDir({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    return env['USERPROFILE'] ?? env['HOME'];
  }
}
