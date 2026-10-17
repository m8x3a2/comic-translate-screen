import '../diagnostics/redactor.dart';

/// Storage for API keys and other secrets. The app implementation uses the OS
/// secure storage (DPAPI/Credential Manager on Windows, Keystore on Android);
/// secrets never go to settings.json or logs.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Keys currently stored (values are not returned).
  Future<List<String>> keys();
}

/// Key under which a plugin secret is stored.
String pluginSecretKey(String pluginId, String field) => 'plugin.$pluginId.$field';

/// In-memory store for tests and for runs without secure storage.
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<List<String>> keys() async => _values.keys.toList()..sort();
}

/// Registers every secret that passes through with the [Redactor], so it is
/// masked in all diagnostics from that moment on.
class RedactingSecretStore implements SecretStore {
  RedactingSecretStore(this._inner, this._redactor);

  final SecretStore _inner;
  final Redactor _redactor;

  @override
  Future<String?> read(String key) async {
    final value = await _inner.read(key);
    _redactor.addSecret(value);
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    _redactor.addSecret(value);
    await _inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<List<String>> keys() => _inner.keys();

  /// Reads every stored secret once so all of them are masked from startup.
  Future<void> primeRedactor() async {
    for (final k in await _inner.keys()) {
      _redactor.addSecret(await _inner.read(k));
    }
  }
}
