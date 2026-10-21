import 'package:flutter/services.dart';

/// Static facts about this build.
abstract final class AppInfo {
  static const name = 'Comic Translate Screen';

  /// Must match `version:` in pubspec.yaml (checked by test/app_info_test.dart).
  static const version = '0.1.2';

  /// Injected by release builds: `--dart-define=CTS_GIT_SHA=$(git rev-parse --short HEAD)`.
  static const gitSha = String.fromEnvironment('CTS_GIT_SHA');

  static String? get flutterVersion => FlutterVersion.version;
}
