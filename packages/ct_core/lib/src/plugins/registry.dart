import '../diagnostics/event_log.dart';
import '../models/model_manager.dart';
import 'plugin.dart';
import 'settings_schema.dart';

/// Shared services a plugin may need when it is created.
class PluginEnvironment {
  PluginEnvironment({
    required this.models,
    required this.log,
    this.useGpu = false,
  });

  final ModelManager models;
  final EventLog log;

  /// User preference "Use GPU"; plugins fall back to CPU when unavailable.
  final bool useGpu;
}

typedef PluginCreator<T extends Plugin> = Future<T> Function(PluginConfig config, PluginEnvironment env);

/// Describes and creates one plugin. Each provider file exposes one of these
/// and adds it to the registry with a single line.
class PluginFactory<T extends Plugin> {
  const PluginFactory(this.info, this.create);

  final PluginInfo info;
  final PluginCreator<T> create;
}

class UnknownPluginException implements Exception {
  UnknownPluginException(this.id, this.kind);

  final String id;
  final PluginKind? kind;

  @override
  String toString() => 'Unknown ${kind?.name ?? 'plugin'} "$id"';
}

/// All available plugins and a cache of live instances.
///
/// Instances are cached by plugin id and configuration (like the engine
/// caches of the original factories), so repeated pages reuse loaded models.
class PluginRegistry {
  final Map<String, PluginFactory> _factories = {};
  final Map<String, Plugin> _instances = {};
  final Map<String, Future<Plugin>> _pending = {};

  void register(PluginFactory factory) {
    final id = factory.info.id;
    if (_factories.containsKey(id)) {
      throw StateError('Plugin "$id" is registered twice');
    }
    _factories[id] = factory;
  }

  Iterable<PluginInfo> get all => _factories.values.map((f) => f.info);

  /// Plugins of [kind] available on [platform] (all platforms when null).
  List<PluginInfo> available(PluginKind kind, {PlatformId? platform}) => [
        for (final f in _factories.values)
          if (f.info.kind == kind && (platform == null || f.info.platforms.contains(platform))) f.info,
      ];

  PluginInfo info(String id) => (_factories[id] ?? (throw UnknownPluginException(id, null))).info;

  bool contains(String id) => _factories.containsKey(id);

  /// Returns a cached or new instance of plugin [id] for [config].
  Future<T> instance<T extends Plugin>(String id, PluginConfig config, PluginEnvironment env) async {
    final factory = _factories[id] ?? (throw UnknownPluginException(id, null));
    final key = '$id#${env.useGpu}#${config.cacheKey}';
    final cached = _instances[key];
    if (cached != null) return cached as T;
    final pending = _pending[key];
    if (pending != null) return await pending as T;

    // Only one configuration of a plugin stays loaded: drop stale instances.
    for (final staleKey in _instances.keys.where((k) => k.startsWith('$id#')).toList()) {
      await _instances.remove(staleKey)!.dispose();
    }

    final future = factory.create(config, env);
    _pending[key] = future;
    try {
      final plugin = await future;
      if (plugin is! T) {
        await plugin.dispose();
        throw StateError('Plugin "$id" is a ${plugin.runtimeType}, expected $T');
      }
      _instances[key] = plugin;
      env.log.info('plugin_loaded', {'plugin': id, 'gpu': env.useGpu});
      return plugin;
    } finally {
      _pending.remove(key);
    }
  }

  /// Releases all loaded instances (e.g. after a batch, to reduce memory).
  Future<void> disposeInstances() async {
    final instances = _instances.values.toList();
    _instances.clear();
    for (final p in instances) {
      await p.dispose();
    }
  }
}
