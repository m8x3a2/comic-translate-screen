/// Declarative settings of a plugin. The settings page is generated from this
/// schema; values are validated and defaulted through it.
sealed class SettingField {
  const SettingField({required this.key, required this.label, this.help = '', this.info = ''});

  final String key;
  final String label;
  final String help;

  /// A longer explanation, shown behind an "i" next to the field.
  final String info;

  /// Default value, or null when the field has none (secrets).
  Object? get defaultValue;

  /// Coerces a stored value to this field's type, falling back to the default.
  Object? coerce(Object? value);
}

class TextSetting extends SettingField {
  const TextSetting({
    required super.key,
    required super.label,
    super.help,
    super.info,
    this.defaultValue = '',
    this.placeholder = '',
    this.multiline = false,
    this.isUrl = false,
  });

  @override
  final String defaultValue;
  final String placeholder;
  final bool multiline;
  final bool isUrl;

  @override
  Object? coerce(Object? value) => value is String ? value : defaultValue;
}

/// A secret (API key, token). Never stored in settings.json: values live in
/// the OS secure storage under `plugin.<pluginId>.<key>`.
class SecretSetting extends SettingField {
  const SecretSetting({required super.key, required super.label, super.help, super.info, this.optional = false});

  final bool optional;

  @override
  Object? get defaultValue => null;

  @override
  Object? coerce(Object? value) => value is String ? value : null;
}

class ChoiceSetting extends SettingField {
  const ChoiceSetting({
    required super.key,
    required super.label,
    super.help,
    super.info,
    required this.options,
    required this.defaultValue,
  });

  /// value → label.
  final Map<String, String> options;

  @override
  final String defaultValue;

  @override
  Object? coerce(Object? value) => value is String && options.containsKey(value) ? value : defaultValue;
}

class IntSetting extends SettingField {
  const IntSetting({
    required super.key,
    required super.label,
    super.help,
    super.info,
    required this.defaultValue,
    this.min,
    this.max,
  });

  @override
  final int defaultValue;
  final int? min;
  final int? max;

  @override
  Object? coerce(Object? value) {
    final v = value is num ? value.toInt() : (value is String ? int.tryParse(value) : null);
    if (v == null) return defaultValue;
    if (min != null && v < min!) return min;
    if (max != null && v > max!) return max;
    return v;
  }
}

class DoubleSetting extends SettingField {
  const DoubleSetting({
    required super.key,
    required super.label,
    super.help,
    super.info,
    required this.defaultValue,
    this.min,
    this.max,
  });

  @override
  final double defaultValue;
  final double? min;
  final double? max;

  @override
  Object? coerce(Object? value) {
    final v = value is num ? value.toDouble() : (value is String ? double.tryParse(value) : null);
    if (v == null || v.isNaN) return defaultValue;
    if (min != null && v < min!) return min;
    if (max != null && v > max!) return max;
    return v;
  }
}

class BoolSetting extends SettingField {
  const BoolSetting({required super.key, required super.label, super.help, super.info, this.defaultValue = false});

  @override
  final bool defaultValue;

  @override
  Object? coerce(Object? value) => value is bool ? value : defaultValue;
}

/// Resolved settings for one plugin instance: validated values plus secrets.
class PluginConfig {
  PluginConfig({Map<String, Object?> values = const {}, Map<String, String> secrets = const {}})
    : values = Map.unmodifiable(values),
      secrets = Map.unmodifiable(secrets);

  final Map<String, Object?> values;
  final Map<String, String> secrets;

  T value<T>(String key) => values[key] as T;
  String? secret(String key) => secrets[key];

  /// Builds a config from raw stored values, applying the schema's types and
  /// defaults. Unknown keys are dropped.
  factory PluginConfig.resolve(
    List<SettingField> schema,
    Map<String, Object?> stored, {
    Map<String, String> secrets = const {},
  }) {
    final values = <String, Object?>{};
    final secretValues = <String, String>{};
    for (final field in schema) {
      if (field is SecretSetting) {
        final s = secrets[field.key];
        if (s != null && s.isNotEmpty) secretValues[field.key] = s;
      } else {
        values[field.key] = field.coerce(stored[field.key]);
      }
    }
    return PluginConfig(values: values, secrets: secretValues);
  }

  /// Stable fingerprint for instance caching (secrets included: changing a
  /// key must create a new instance). Never logged.
  String get cacheKey {
    final keys = [...values.keys, ...secrets.keys.map((k) => 's:$k')]..sort();
    return keys.map((k) => k.startsWith('s:') ? '$k=${secrets[k.substring(2)].hashCode}' : '$k=${values[k]}').join('|');
  }
}
