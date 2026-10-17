import '../cancel.dart';
import '../diagnostics/event_log.dart';
import '../diagnostics/run_recorder.dart';
import 'settings_schema.dart';

/// What a plugin does in the pipeline.
enum PluginKind { detector, ocr, translator, inpainter }

/// Where a plugin sends data. Anything other than [local] is marked in the UI
/// and requires the user's confirmation before first use.
enum Privacy {
  /// Nothing leaves the device.
  local,

  /// Data is sent to a machine on the local network (e.g. own PC as server).
  lan,

  /// Data is sent to an internet service.
  cloud;

  bool get sendsData => this != local;
}

enum PlatformId {
  windows,
  android,
  linux,
  macos,
  ios;

  static PlatformId? fromOperatingSystem(String os) => switch (os) {
        'windows' => windows,
        'android' => android,
        'linux' => linux,
        'macos' => macos,
        'ios' => ios,
        _ => null,
      };
}

/// Static description of a plugin, available before it is instantiated.
class PluginInfo {
  const PluginInfo({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.privacy,
    this.description = '',
    this.platforms = const {...PlatformId.values},
    this.settings = const [],
    this.models = const [],
  });

  /// Stable identifier stored in settings and logs, e.g. `openai_compatible`.
  final String id;
  final String displayName;
  final PluginKind kind;
  final Privacy privacy;
  final String description;
  final Set<PlatformId> platforms;

  /// Settings schema; the settings UI is generated from it.
  final List<SettingField> settings;

  /// Ids of models (see `ModelCatalog`) required before first use.
  final List<String> models;

  SettingField? field(String key) {
    for (final f in settings) {
      if (f.key == key) return f;
    }
    return null;
  }
}

/// Runtime context passed to every plugin call.
class PluginContext {
  PluginContext({
    required this.log,
    CancelToken? cancel,
    this.recorder,
    this.page,
  }) : cancel = cancel ?? CancelToken.none;

  final EventLog log;
  final CancelToken cancel;

  /// Present in test mode; plugins may save extra artifacts through it.
  final RunRecorder? recorder;

  /// Name of the page being processed, for logs and artifacts.
  final String? page;

  PluginContext forPage(String page) =>
      PluginContext(log: log.child(page: page), cancel: cancel, recorder: recorder, page: page);
}

/// Base interface of all plugin instances.
abstract interface class Plugin {
  PluginInfo get info;

  /// Releases native resources (ONNX sessions, OCR engines, HTTP clients).
  Future<void> dispose();
}
