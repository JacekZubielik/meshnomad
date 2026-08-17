import 'dart:convert';
import '../models/delivery_observation.dart';
import '../models/path_history.dart';
import '../storage/prefs_manager.dart';

class StorageService {
  static const String _pathHistoryPrefix = 'path_history_';
  static const String _pendingMessagesKey = 'pending_messages';
  static const String _repeaterPasswordsKey = 'repeater_passwords';
  static const String _repeaterAutoClockSyncAfterLoginKey =
      'repeater_auto_clock_sync_after_login';
  static const String _deliveryObservationsKey = 'delivery_observations';

  /// Scopes path-history keys to the connected device, same pattern as
  /// MessageStore/ContactStore/etc. in lib/storage/*.dart — without it, the
  /// same contact seen from two different radios overwrites one shared,
  /// unscoped history entry.
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

  /// Save a repeater password by public key hex
  Future<void> saveRepeaterPassword(
    String repeaterPubKeyHex,
    String password,
  ) async {
    final prefs = PrefsManager.instance;
    final passwords = await loadRepeaterPasswords();
    passwords[repeaterPubKeyHex] = password;
    final jsonStr = jsonEncode(passwords);
    await prefs.setString(_repeaterPasswordsKey, jsonStr);
  }

  /// Load all saved repeater passwords (map of pubKeyHex -> password)
  Future<Map<String, String>> loadRepeaterPasswords() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_repeaterPasswordsKey);

    if (jsonStr == null) return {};

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      return {};
    }
  }

  /// Get a specific repeater's saved password
  Future<String?> getRepeaterPassword(String repeaterPubKeyHex) async {
    final passwords = await loadRepeaterPasswords();
    return passwords[repeaterPubKeyHex];
  }

  /// Remove a saved repeater password
  Future<void> removeRepeaterPassword(String repeaterPubKeyHex) async {
    final prefs = PrefsManager.instance;
    final passwords = await loadRepeaterPasswords();
    passwords.remove(repeaterPubKeyHex);
    final jsonStr = jsonEncode(passwords);
    await prefs.setString(_repeaterPasswordsKey, jsonStr);
  }

  /// Clear all saved repeater passwords
  Future<void> clearAllRepeaterPasswords() async {
    final prefs = PrefsManager.instance;
    await prefs.remove(_repeaterPasswordsKey);
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
