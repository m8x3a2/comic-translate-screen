import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

/// Reads and changes settings.json by dotted path, e.g.
/// `cts settings set plugins.openai_compatible.api_url https://openrouter.ai/api/v1`.
/// Secrets are not settings: use `cts secrets`.
class SettingsCommand extends Command<int> {
  SettingsCommand(CliContextHolder holder) {
    addSubcommand(_SettingsShow(holder));
    addSubcommand(_SettingsGet(holder));
    addSubcommand(_SettingsSet(holder));
    addSubcommand(_SettingsPlugins(holder));
  }

  @override
  String get name => 'settings';

  @override
  String get description => 'Show or change settings (API keys are managed by `cts secrets`).';
}

Object? _lookup(Object? json, List<String> path) {
  var node = json;
  for (final key in path) {
    if (node is! Map || !node.containsKey(key)) return null;
    node = node[key];
  }
  return node;
}

class _SettingsShow extends CtsCommand {
  _SettingsShow(super.holder);

  @override
  String get name => 'show';

  @override
  String get description => 'Print all settings as JSON.';

  @override
  Future<int> run() async {
    ctx.printJson((await ctx.services.settingsStore.load()).toJson());
    return ExitCodes.ok;
  }
}

class _SettingsGet extends CtsCommand {
  _SettingsGet(super.holder);

  @override
  String get name => 'get';

  @override
  String get description => 'Print one setting, e.g. `cts settings get tools.translator`.';

  @override
  String get invocation => 'cts settings get <path>';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) usageException('Give one dotted path.');
    final json = (await ctx.services.settingsStore.load()).toJson();
    final value = _lookup(json, argResults!.rest.single.split('.'));
    ctx.printJson(value);
    return value == null ? ExitCodes.failure : ExitCodes.ok;
  }
}

class _SettingsSet extends CtsCommand {
  _SettingsSet(super.holder);

  @override
  String get name => 'set';

  @override
  String get description => 'Change one setting. The value is parsed as JSON when possible (true, 3, [..]), '
      'otherwise taken as text. Examples: tools.translator openai_compatible; languages.target Russian; '
      'plugins.openai_compatible.model openai/gpt-4.1-mini.';

  @override
  String get invocation => 'cts settings set <path> <value>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 2) usageException('Give a dotted path and a value.');
    final path = rest[0].split('.');
    if (path.any((p) => p.isEmpty)) usageException('Bad path "${rest[0]}".');
    Object? value;
    try {
      value = jsonDecode(rest[1]);
    } on FormatException {
      value = rest[1];
    }

    final store = ctx.services.settingsStore;
    final json = (await store.load()).toJson();
    Map<String, Object?> node = json;
    for (final key in path.take(path.length - 1)) {
      final child = node[key];
      if (child is Map) {
        node = node[key] = child.cast<String, Object?>();
      } else {
        node = node[key] = <String, Object?>{};
      }
    }
    node[path.last] = value;

    final updated = AppSettings.fromJson(json);
    final stored = _lookup(updated.toJson(), path);
    if (jsonEncode(stored) != jsonEncode(value)) {
      ctx.err.writeln('Setting "${rest[0]}" was not accepted (unknown key or wrong type); now: ${jsonEncode(stored)}');
      return ExitCodes.failure;
    }
    await store.save(updated);
    ctx.say('${rest[0]} = ${jsonEncode(value)}');
    if (ctx.json) ctx.printJson({'ok': true, 'path': rest[0], 'value': value});
    return ExitCodes.ok;
  }
}

class _SettingsPlugins extends CtsCommand {
  _SettingsPlugins(super.holder);

  @override
  String get name => 'plugins';

  @override
  String get description => 'List plugins with their settings, privacy and current values.';

  @override
  Future<int> run() async {
    final services = ctx.services;
    final settings = await services.settingsStore.load();
    final out = <Map<String, Object?>>[];
    for (final info in services.registry.all) {
      final config = await services.pluginConfig(info.id, settings);
      final endpoint = info.endpointFor(config);
      out.add({
        'id': info.id,
        'kind': info.kind.name,
        'name': info.displayName,
        'sends_data_to': endpoint == null ? null : {'privacy': endpoint.privacy.name, 'host': endpoint.host},
        'settings': {
          for (final f in info.settings)
            f.key: f is SecretSetting ? (config.secret(f.key) != null ? '<stored>' : '<not set>') : config.values[f.key],
        },
      });
      if (!ctx.json) {
        final privacy = endpoint == null
            ? 'local'
            : '${endpoint.privacy.name}: ${endpoint.host.isEmpty ? 'not configured' : endpoint.host}';
        ctx.say('${info.kind.name.padRight(10)} ${info.id.padRight(18)} [$privacy] ${info.displayName}');
        for (final f in info.settings) {
          final v = f is SecretSetting
              ? (config.secret(f.key) != null ? '<stored>' : '<not set>  (cts secrets set ${pluginSecretKey(info.id, f.key)})')
              : jsonEncode(config.values[f.key]);
          ctx.say('    plugins.${info.id}.${f.key} = $v');
        }
      }
    }
    if (ctx.json) ctx.printJson(out);
    return ExitCodes.ok;
  }
}
