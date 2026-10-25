import '../cancel.dart';
import '../diagnostics/event_log.dart';
import '../diagnostics/run_recorder.dart';
import '../usage/key_status.dart';
import '../usage/usage_log.dart';
import 'settings_schema.dart';

/// What a plugin does in the pipeline. [reader]: an OCR engine that the
/// recognition levels add to the chosen one (see `read_level.dart`); not
/// picked by hand.
enum PluginKind { detector, ocr, translator, inpainter, textPrep, textMask, reader }

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

/// Where a configured plugin sends data, for the privacy warning and the
/// user's approval (approvals are remembered per plugin and host).
class PluginEndpoint {
  const PluginEndpoint(this.privacy, this.host);

  final Privacy privacy;

  /// Host name shown to the user, e.g. `openrouter.ai`; empty if unknown.
  final String host;

  /// Key stored in `AppSettings.approvedNetworkPlugins`.
  String approvalKey(String pluginId) => '$pluginId@$host';
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
    this.modelsForLanguage,
    this.endpoint,
    this.keyStatus,
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

  /// For engines with one model per script (OCR): the models needed for a
  /// source language, used instead of [models].
  final List<String> Function(String sourceLanguage)? modelsForLanguage;

  /// Every model needed to run with [sourceLanguage].
  List<String> requiredModels(String sourceLanguage) {
    final forLanguage = modelsForLanguage;
    if (forLanguage == null) return models;
    try {
      return forLanguage(sourceLanguage);
    } on UnsupportedError {
      return models;
    }
  }

  /// For plugins whose destination depends on their settings (e.g. a server
  /// URL): where a configuration sends data. Defaults to [privacy].
  final PluginEndpoint Function(PluginConfig config)? endpoint;

  /// Where [config] sends data, or null when everything stays on the device.
  PluginEndpoint? endpointFor(PluginConfig config) {
    final e = endpoint?.call(config) ?? PluginEndpoint(privacy, '');
    return e.privacy.sendsData ? e : null;
  }

  /// For services that can tell what is left of the user's key: how to ask
  /// for a configuration, or null when its server cannot tell.
  final KeyStatusQuery? Function(PluginConfig config)? keyStatus;

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
    this.onUsage,
  }) : cancel = cancel ?? CancelToken.none;

  final EventLog log;
  final CancelToken cancel;

  /// Present in test mode; plugins may save extra artifacts through it.
  final RunRecorder? recorder;

  /// Name of the page being processed, for logs and artifacts.
  final String? page;

  /// Counts what requests to services used (the local usage counter).
  final UsageSink? onUsage;

  /// Plugins that call a service report each answered request here. Never
  /// throws.
  Future<void> reportUsage(ServiceUsage usage) async {
    try {
      await onUsage?.call(usage);
    } on Object catch (e) {
      log.warn('usage_not_counted', {'error': e.toString()});
    }
  }

  PluginContext forPage(String page) =>
      PluginContext(log: log.child(page: page), cancel: cancel, recorder: recorder, page: page, onUsage: onUsage);
}

/// Base interface of all plugin instances.
abstract interface class Plugin {
  PluginInfo get info;

  /// Releases native resources (ONNX sessions, OCR engines, HTTP clients).
  Future<void> dispose();
}
