import 'dart:convert';
import 'dart:io';

import '../diagnostics/event_log.dart';
import 'app_settings.dart';

/// Loads and saves [AppSettings] as JSON, atomically.
class SettingsStore {
  SettingsStore(this.file, {EventLog? log}) : _log = log ?? EventLog.silent();

  final File file;
  final EventLog _log;

  /// Missing file → defaults. Unreadable file → it is kept as
  /// `settings.json.bad-<timestamp>` for inspection and defaults are used.
  Future<AppSettings> load() async {
    if (!file.existsSync()) return AppSettings();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) throw const FormatException('settings root is not an object');
      return AppSettings.fromJson(json.cast<String, Object?>());
    } catch (e) {
      final backup = File('${file.path}.bad-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(backup.path);
      _log.warn('settings_unreadable', {'error': e.toString(), 'backup': backup.path});
      return AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()), flush: true);
    if (file.existsSync()) await file.delete();
    await tmp.rename(file.path);
  }
}
