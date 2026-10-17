import 'package:ct_core/ct_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecretStore] backed by the OS secure storage: DPAPI-protected storage on
/// Windows, Android Keystore on Android.
class SecureSecretStore implements SecretStore {
  SecureSecretStore() : _storage = const FlutterSecureStorage();

  /// Prefix keeps our entries separate from anything else in the store.
  static const _prefix = 'cts.';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) => _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  @override
  Future<List<String>> keys() async {
    final all = await _storage.readAll();
    return [
      for (final k in all.keys)
        if (k.startsWith(_prefix)) k.substring(_prefix.length),
    ]..sort();
  }
}
