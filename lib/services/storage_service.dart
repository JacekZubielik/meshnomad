import 'dart:convert';
import '../models/delivery_observation.dart';
import '../models/path_history.dart';
import '../storage/prefs_manager.dart';
import 'secure_key_value_store.dart';

class StorageService {
  static const String _pathHistoryPrefix = 'path_history_';
  static const String _pendingMessagesKey = 'pending_messages';
  static const String _legacyRepeaterPasswordsKey = 'repeater_passwords';
  static const String _repeaterPasswordKeyPrefix = 'repeater_password_';
  static const String _repeaterAutoClockSyncAfterLoginKey =
      'repeater_auto_clock_sync_after_login';
  static const String _deliveryObservationsKey = 'delivery_observations';

  StorageService({SecureKeyValueStore? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureKeyValueStore();

  final SecureKeyValueStore _secureStorage;

  /// Scopes path-history keys to the connected device, same pattern as
  /// MessageStore/ContactStore/etc. in lib/storage/*.dart — without it, the
  /// same contact seen from two different radios overwrites one shared,
  /// unscoped history entry.
  ///
  /// Deliberately NOT applied to repeater passwords (below): a repeater's
  /// login password belongs to that remote node, not to whichever local
  /// radio the phone happens to be connected through right now.
  String publicKeyHex = '';
  set setPublicKeyHex(String value) =>
      publicKeyHex = value.length > 10 ? value.substring(0, 10) : '';

  Future<Map<String, bool>> _loadRepeaterAutoClockSyncAfterLogin() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_repeaterAutoClockSyncAfterLoginKey);

    if (jsonStr == null) return {};

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      return {};
    }
  }

  Future<bool> getRepeaterAutoClockSyncAfterLoginEnabled(
    String repeaterPubKeyHex,
  ) async {
    final settings = await _loadRepeaterAutoClockSyncAfterLogin();
    return settings[repeaterPubKeyHex] ?? false;
  }

  Future<void> setRepeaterAutoClockSyncAfterLoginEnabled(
    String repeaterPubKeyHex,
    bool enabled,
  ) async {
    final prefs = PrefsManager.instance;
    final settings = await _loadRepeaterAutoClockSyncAfterLogin();
    settings[repeaterPubKeyHex] = enabled;
    final jsonStr = jsonEncode(settings);
    await prefs.setString(_repeaterAutoClockSyncAfterLoginKey, jsonStr);
  }

  String get _pathHistoryKeyPrefix => '$_pathHistoryPrefix${publicKeyHex}_';

  Future<void> savePathHistory(
    String contactPubKeyHex,
    ContactPathHistory history,
  ) async {
    final prefs = PrefsManager.instance;
    final key = '$_pathHistoryKeyPrefix$contactPubKeyHex';
    final jsonStr = jsonEncode(history.toJson());
    await prefs.setString(key, jsonStr);
  }

  Future<ContactPathHistory?> loadPathHistory(String contactPubKeyHex) async {
    final prefs = PrefsManager.instance;
    final key = '$_pathHistoryKeyPrefix$contactPubKeyHex';
    final legacyKey = '$_pathHistoryPrefix$contactPubKeyHex';
    var jsonStr = prefs.getString(key);

    if (jsonStr == null) {
      // Migrate a pre-device-scoping entry on first read, same pattern as
      // MessageStore.loadMessages.
      final legacyJsonStr = prefs.getString(legacyKey);
      if (legacyJsonStr != null) {
        await prefs.setString(key, legacyJsonStr);
        await prefs.remove(legacyKey);
        jsonStr = legacyJsonStr;
      }
    }

    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ContactPathHistory.fromJson(contactPubKeyHex, json);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearPathHistory(String contactPubKeyHex) async {
    final prefs = PrefsManager.instance;
    final key = '$_pathHistoryKeyPrefix$contactPubKeyHex';
    await prefs.remove(key);
  }

  Future<void> clearAllPathHistories() async {
    final prefs = PrefsManager.instance;
    final keys = prefs.getKeys();
    final pathHistoryKeys = keys.where(
      (key) => key.startsWith(_pathHistoryKeyPrefix),
    );

    for (final key in pathHistoryKeys) {
      await prefs.remove(key);
    }
  }

  Future<Map<String, String>> loadPendingMessages() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_pendingMessagesKey);

    if (jsonStr == null) return {};

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      return {};
    }
  }

  Future<void> savePendingMessages(Map<String, String> pending) async {
    final prefs = PrefsManager.instance;
    final jsonStr = jsonEncode(pending);
    await prefs.setString(_pendingMessagesKey, jsonStr);
  }

  Future<void> clearPendingMessages() async {
    final prefs = PrefsManager.instance;
    await prefs.remove(_pendingMessagesKey);
  }

  /// Save a repeater password, encrypted at rest (OS keystore-backed).
  Future<void> saveRepeaterPassword(
    String repeaterPubKeyHex,
    String password,
  ) async {
    await _secureStorage.write(
      '$_repeaterPasswordKeyPrefix$repeaterPubKeyHex',
      password,
    );
    await _removeLegacyRepeaterPassword(repeaterPubKeyHex);
  }

  /// Get a specific repeater's saved password. Migrates a pre-encryption
  /// plaintext entry (if any) into secure storage on first read.
  Future<String?> getRepeaterPassword(String repeaterPubKeyHex) async {
    final fromSecureStorage = await _secureStorage.read(
      '$_repeaterPasswordKeyPrefix$repeaterPubKeyHex',
    );
    if (fromSecureStorage != null) return fromSecureStorage;

    final legacy = await _loadLegacyRepeaterPasswords();
    final legacyPassword = legacy[repeaterPubKeyHex];
    if (legacyPassword == null) return null;

    await _secureStorage.write(
      '$_repeaterPasswordKeyPrefix$repeaterPubKeyHex',
      legacyPassword,
    );
    await _removeLegacyRepeaterPassword(repeaterPubKeyHex);
    return legacyPassword;
  }

  /// Remove a saved repeater password
  Future<void> removeRepeaterPassword(String repeaterPubKeyHex) async {
    await _secureStorage.delete(
      '$_repeaterPasswordKeyPrefix$repeaterPubKeyHex',
    );
    await _removeLegacyRepeaterPassword(repeaterPubKeyHex);
  }

  /// Clear all saved repeater passwords
  Future<void> clearAllRepeaterPasswords() async {
    final all = await _secureStorage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_repeaterPasswordKeyPrefix)) {
        await _secureStorage.delete(key);
      }
    }
    final prefs = PrefsManager.instance;
    await prefs.remove(_legacyRepeaterPasswordsKey);
  }

  Future<Map<String, String>> _loadLegacyRepeaterPasswords() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_legacyRepeaterPasswordsKey);
    if (jsonStr == null) return {};

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      return {};
    }
  }

  Future<void> _removeLegacyRepeaterPassword(String repeaterPubKeyHex) async {
    final legacy = await _loadLegacyRepeaterPasswords();
    if (!legacy.containsKey(repeaterPubKeyHex)) return;

    legacy.remove(repeaterPubKeyHex);
    final prefs = PrefsManager.instance;
    if (legacy.isEmpty) {
      await prefs.remove(_legacyRepeaterPasswordsKey);
    } else {
      await prefs.setString(_legacyRepeaterPasswordsKey, jsonEncode(legacy));
    }
  }

  Future<void> saveDeliveryObservations(
    List<DeliveryObservation> observations,
  ) async {
    final prefs = PrefsManager.instance;
    final jsonStr = jsonEncode(observations.map((o) => o.toJson()).toList());
    await prefs.setString(_deliveryObservationsKey, jsonStr);
  }

  Future<List<DeliveryObservation>> loadDeliveryObservations() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_deliveryObservationsKey);

    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => DeliveryObservation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearDeliveryObservations() async {
    final prefs = PrefsManager.instance;
    await prefs.remove(_deliveryObservationsKey);
  }
}
