import '../utils/app_logger.dart';
import 'prefs_manager.dart';

class ChannelSettingsStore {
  static const String _keyPrefix = 'channel_smaz_';
  static const String _cyr2latKeyPrefix = 'channel_cyr2lat_';
  static const String _favoriteKeyPrefix = 'channel_favorite_';
  static const String _translationKeyPrefix = 'channel_translation_';

  String publicKeyHex = '';
  set setPublicKeyHex(String value) =>
      publicKeyHex = value.length > 10 ? value.substring(0, 10) : '';

  String get keyFor => '$_keyPrefix$publicKeyHex';
  String get keyForCyr2Lat => '$_cyr2latKeyPrefix$publicKeyHex';
  String get keyForFavorite => '$_favoriteKeyPrefix$publicKeyHex';
  String get keyForTranslation => '$_translationKeyPrefix$publicKeyHex';

  Future<bool> loadSmazEnabled(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel settings.',
      );
      return false;
    }
    final prefs = PrefsManager.instance;
    final key = '$keyFor$channelIndex';
    final oldKey = '$_keyPrefix$channelIndex';
    bool? enabled = prefs.getBool(key);
    if (enabled == null) {
      // Attempt migration from legacy unscoped key on first load
      enabled = prefs.getBool(oldKey);
      prefs.remove(oldKey);
      if (enabled != null) {
        appLogger.info(
          'Migrating channel settings from legacy key $oldKey to scoped key $key',
        );
        await prefs.setBool(key, enabled);
      }
    }
    return enabled ?? false;
  }

  Future<void> saveSmazEnabled(int channelIndex, bool enabled) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel settings.',
      );
      return;
    }
    final prefs = PrefsManager.instance;
    final key = '$keyFor$channelIndex';
    await prefs.setBool(key, enabled);
  }

  Future<bool> loadCyr2LatEnabled(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel Cyr2Lat settings.',
      );
      return false;
    }
    final prefs = PrefsManager.instance;
    final key = '$keyForCyr2Lat$channelIndex';
    return prefs.getBool(key) ?? false;
  }

  Future<void> saveCyr2LatEnabled(int channelIndex, bool enabled) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel Cyr2Lat settings.',
      );
      return;
    }
    final prefs = PrefsManager.instance;
    final key = '$keyForCyr2Lat$channelIndex';
    await prefs.setBool(key, enabled);
  }

  Future<String?> loadCyr2LatProfileId(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel settings.',
      );
      return null;
    }
    final prefs = PrefsManager.instance;
    final key = '${keyForCyr2Lat}profile_$channelIndex';
    return prefs.getString(key);
  }

  Future<void> saveCyr2LatProfileId(int channelIndex, String? profileId) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel settings.',
      );
      return;
    }
    final prefs = PrefsManager.instance;
    final key = '${keyForCyr2Lat}profile_$channelIndex';
    if (profileId == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, profileId);
    }
  }

  Future<bool> loadFavorite(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel favorite.',
      );
      return false;
    }
    return PrefsManager.instance.getBool('$keyForFavorite$channelIndex') ??
        false;
  }

  Future<void> saveFavorite(int channelIndex, bool favorite) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel favorite.',
      );
      return;
    }
    await PrefsManager.instance.setBool(
      '$keyForFavorite$channelIndex',
      favorite,
    );
  }

  /// Per-channel translation target language; null = inherit the app-wide
  /// setting ("Use app language").
  Future<String?> loadTranslationLanguage(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel translation settings.',
      );
      return null;
    }
    return PrefsManager.instance.getString(
      '${keyForTranslation}lang_$channelIndex',
    );
  }

  Future<void> saveTranslationLanguage(
    int channelIndex,
    String? languageCode,
  ) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel translation settings.',
      );
      return;
    }
    final key = '${keyForTranslation}lang_$channelIndex';
    if (languageCode == null) {
      await PrefsManager.instance.remove(key);
    } else {
      await PrefsManager.instance.setString(key, languageCode);
    }
  }

  Future<bool> loadTranslateBeforeSending(int channelIndex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load channel translation settings.',
      );
      return false;
    }
    return PrefsManager.instance.getBool(
          '${keyForTranslation}send_$channelIndex',
        ) ??
        false;
  }

  Future<void> saveTranslateBeforeSending(
    int channelIndex,
    bool enabled,
  ) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save channel translation settings.',
      );
      return;
    }
    await PrefsManager.instance.setBool(
      '${keyForTranslation}send_$channelIndex',
      enabled,
    );
  }
}
