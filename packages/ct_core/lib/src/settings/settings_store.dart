import 'dart:convert';
import 'dart:io';

import '../diagnostics/event_log.dart';
import 'app_settings.dart';

/// Loads and saves [AppSettings] as JSON, atomically.
class SettingsStore {
  SettingsStore(this.file, {EventLog? log}) : _log = log ?? EventLog.silent();

  final File file;
  final EventLog _log;

  /// The version a [load] moved the settings file from (it is saved as the
  /// current one); null: it was current.
  int? upgradedFrom;

  /// Missing file → defaults. Unreadable file → it is kept as
  /// `settings.json.bad-<timestamp>` for inspection and defaults are used.
  Future<AppSettings> load() async {
    if (!file.existsSync()) return AppSettings();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) throw const FormatException('settings root is not an object');
      final settings = AppSettings.fromJson(json.cast<String, Object?>());
      // Moved to the current version once: saved so.
      final version = json['schema_version'];
      if (version is! num || version < AppSettings.schemaVersion) {
        upgradedFrom = version is num ? version.toInt() : 1;
        await save(settings);
        _log.info('settings_upgraded', {'from': version, 'to': AppSettings.schemaVersion});
      }
      return settings;
    } catch (e) {
      final backup = File('${file.path}.bad-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(backup.path);
      _log.warn('settings_unreadable', {'error': e.toString(), 'backup': backup.path});
      return AppSettings();
    }
  }

  Future<void> _queue = Future.value();

  /// Saves run one after another (two at once would share the temporary
  /// file); the settings are taken as they are when [save] is called.
  Future<void> save(AppSettings settings) {
    final json = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    // A failed save is reported to its caller and does not stop the next.
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      if (file.existsSync()) await file.delete();
      await tmp.rename(file.path);
    });
  }

  /// Completes when the saves started so far are written (failed or not).
  Future<void> flush() => _queue.catchError((Object _) {});
}
