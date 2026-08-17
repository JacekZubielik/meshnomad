import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin seam over an OS-keystore-backed key/value store (Android Keystore /
/// iOS Keychain via `flutter_secure_storage`), narrowed to what
/// [StorageService] needs. Exists so tests can inject an in-memory fake
/// instead of exercising real platform channels — same spirit as
/// `FakeStorageService` in test/services/path_history_service_test.dart.
abstract class SecureKeyValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}
