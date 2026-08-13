import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import '../models/app_settings.dart';
import '../models/custom_style_overrides.dart';
import '../models/translation_support.dart';
import '../storage/prefs_manager.dart';
import '../theme/styles/style_registry.dart';
import '../utils/app_logger.dart';
import '../helpers/cyr2lat.dart';

class AppSettingsService extends ChangeNotifier {
  static const String _settingsKey = 'app_settings';

  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  /// The active theme+profile's RESOLVED overrides: the shipped seed
  /// (StyleRegistry) with the user's saved edits merged on top, field by
  /// field. This is the single read path `main.dart._activeStyle` and the
  /// editor's displayed swatches must use — it always reflects what
  /// actually renders, whether or not the user has edited anything.
  CustomStyleOverrides get activeProfileOverrides {
    final seed = StyleRegistry.profileSeed(
      _settings.activeThemeId,
      _settings.activeProfileId,
    ).overrides;
    final saved = _settings.profiles[_activeProfileKey];
    if (saved == null) return seed;
    return CustomStyleOverrides(
      colorOverrides: {...seed.colorOverrides, ...saved.colorOverrides},
      fontSizeOverrides: {
        ...seed.fontSizeOverrides,
        ...saved.fontSizeOverrides,
      },
      spacingOverrides: {...seed.spacingOverrides, ...saved.spacingOverrides},
      radiusOverrides: {...seed.radiusOverrides, ...saved.radiusOverrides},
      cardElevated: saved.cardElevated ?? seed.cardElevated,
    );
  }

  /// The user's OWN saved edits for the active profile — empty when the
  /// user hasn't customized this profile yet, even though the profile's
  /// shipped seed may itself set some fields (e.g. Green's `bg`/`primary`
  /// identity colors). Every `setCustom*`/`resetCustom*` mutation reads and
  /// writes THIS, never [activeProfileOverrides], so editing or resetting
  /// one field never silently bakes the seed's other fields into the user's
  /// copy. The editor also reads this to decide whether a field's reset
  /// affordance should be enabled.
  CustomStyleOverrides get activeProfileSavedOverrides =>
      _settings.profiles[_activeProfileKey] ?? const CustomStyleOverrides();

  String get _activeProfileKey =>
      '${_settings.activeThemeId}:${_settings.activeProfileId}';

  int resolvedGpsIntervalSeconds(Map<String, String>? deviceCustomVars) {
    final deviceValue = int.tryParse(deviceCustomVars?['gps_interval'] ?? '');
    if (deviceValue != null && deviceValue >= 0) {
      return deviceValue;
    }
    return _settings.gpsIntervalSeconds;
  }

  String batteryChemistryForDevice(String deviceId) {
    final stored = _settings.batteryChemistryByDeviceId[deviceId];
    if (stored == 'liion') return 'nmc';
    return stored ?? 'nmc';
  }

  String batteryChemistryForRepeater(String repeaterPubKeyHex) {
    final stored = _settings.batteryChemistryByRepeaterId[repeaterPubKeyHex];
    if (stored == 'liion') return 'nmc';
    return stored ?? 'nmc';
  }

  Future<void> loadSettings() async {
    final prefs = PrefsManager.instance;
    final jsonStr = prefs.getString(_settingsKey);

    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
        Cyr2Lat.setCharMap(_settings.cyr2latCharMap);
        notifyListeners();
      } catch (e) {
        // If parsing fails, use defaults
        _settings = AppSettings();
        Cyr2Lat.setCharMap(_settings.cyr2latCharMap);
      }
    } else {
      _settings = AppSettings();
      Cyr2Lat.setCharMap(_settings.cyr2latCharMap);
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    Cyr2Lat.setCharMap(_settings.cyr2latCharMap);
    notifyListeners();

    final prefs = PrefsManager.instance;
    final jsonStr = jsonEncode(_settings.toJson());
    await prefs.setString(_settingsKey, jsonStr);
  }

  Future<void> setClearPathOnMaxRetry(bool value) async {
    await updateSettings(_settings.copyWith(clearPathOnMaxRetry: value));
  }

  Future<void> setMapShowRepeaters(bool value) async {
    await updateSettings(_settings.copyWith(mapShowRepeaters: value));
  }

  Future<void> setMapShowChatNodes(bool value) async {
    await updateSettings(_settings.copyWith(mapShowChatNodes: value));
  }

  Future<void> setMapShowOtherNodes(bool value) async {
    await updateSettings(_settings.copyWith(mapShowOtherNodes: value));
  }

  Future<void> setMapShowOverlaps(bool value) async {
    await updateSettings(_settings.copyWith(mapShowOverlaps: value));
  }

  Future<void> setMapTimeFilterHours(double value) async {
    await updateSettings(_settings.copyWith(mapTimeFilterHours: value));
  }

  Future<void> setMapKeyPrefixEnabled(bool value) async {
    await updateSettings(_settings.copyWith(mapKeyPrefixEnabled: value));
  }

  Future<void> setMapKeyPrefix(String value) async {
    await updateSettings(_settings.copyWith(mapKeyPrefix: value));
  }

  Future<void> setMapShowMarkers(bool value) async {
    await updateSettings(_settings.copyWith(mapShowMarkers: value));
  }

  Future<void> setMapShowGuessedLocations(bool value) async {
    await updateSettings(_settings.copyWith(mapShowGuessedLocations: value));
  }

  Future<void> setEnableMessageTracing(bool value) async {
    await updateSettings(_settings.copyWith(enableMessageTracing: value));
  }

  Future<void> setMapCacheBounds(Map<String, double>? value) async {
    await updateSettings(_settings.copyWith(mapCacheBounds: value));
  }

  Future<void> setMapCacheZoomRange(int minZoom, int maxZoom) async {
    final safeMin = minZoom <= maxZoom ? minZoom : maxZoom;
    final safeMax = minZoom <= maxZoom ? maxZoom : minZoom;
    await updateSettings(
      _settings.copyWith(mapCacheMinZoom: safeMin, mapCacheMaxZoom: safeMax),
    );
  }

  Future<void> setMapRasterSourceId(String value) async {
    await updateSettings(_settings.copyWith(mapRasterSourceId: value));
  }

  Future<void> setMapTileEndpointId(String value) async {
    await updateSettings(_settings.copyWith(mapTileEndpointId: value));
  }

  Future<void> setMapTileApiKey(String? value) async {
    final normalized = value?.trim();
    await updateSettings(
      _settings.copyWith(
        mapTileApiKey: (normalized == null || normalized.isEmpty)
            ? null
            : normalized,
      ),
    );
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await updateSettings(_settings.copyWith(notificationsEnabled: value));
  }

  Future<void> setNotifyOnNewMessage(bool value) async {
    await updateSettings(_settings.copyWith(notifyOnNewMessage: value));
  }

  Future<void> setNotifyOnNewChannelMessage(bool value) async {
    await updateSettings(_settings.copyWith(notifyOnNewChannelMessage: value));
  }

  Future<void> setNotifyOnNewAdvert(bool value) async {
    await updateSettings(_settings.copyWith(notifyOnNewAdvert: value));
  }

  Future<void> setAutoSendZeroHopAdvertOnGpsUpdate(bool value) async {
    await updateSettings(
      _settings.copyWith(autoSendZeroHopAdvertOnGpsUpdate: value),
    );
  }

  Future<void> setGpsIntervalSeconds(
    int value, {
    Future<void> Function(int value)? writeToDevice,
  }) async {
    await updateSettings(_settings.copyWith(gpsIntervalSeconds: value));
    if (writeToDevice == null) return;
    try {
      await writeToDevice(value);
    } catch (e) {
      appLogger.warn(
        'Failed to write GPS interval to device: $e',
        tag: 'AppSettings',
      );
    }
  }

  Future<void> setMessageHistoryLimit(int value) async {
    await updateSettings(_settings.copyWith(messageHistoryLimit: value));
  }

  Future<void> setTxDutyCyclePercent(int value) async {
    await updateSettings(
      _settings.copyWith(txDutyCyclePercent: value.clamp(1, 100)),
    );
  }

  Future<void> setAutoRouteRotationEnabled(bool value) async {
    await updateSettings(_settings.copyWith(autoRouteRotationEnabled: value));
  }

  Future<void> setMaxRouteWeight(double value) async {
    await updateSettings(_settings.copyWith(maxRouteWeight: value));
  }

  Future<void> setInitialRouteWeight(double value) async {
    await updateSettings(_settings.copyWith(initialRouteWeight: value));
  }

  Future<void> setRouteWeightSuccessIncrement(double value) async {
    await updateSettings(
      _settings.copyWith(routeWeightSuccessIncrement: value),
    );
  }

  Future<void> setRouteWeightFailureDecrement(double value) async {
    await updateSettings(
      _settings.copyWith(routeWeightFailureDecrement: value),
    );
  }

  Future<void> setMaxMessageRetries(int value) async {
    await updateSettings(_settings.copyWith(maxMessageRetries: value));
  }

  Future<void> setActiveTheme(
    String themeId, {
    required String profileId,
  }) async {
    await updateSettings(
      _settings.copyWith(activeThemeId: themeId, activeProfileId: profileId),
    );
  }

  Future<void> setActiveProfile(String profileId) async {
    await updateSettings(_settings.copyWith(activeProfileId: profileId));
  }

  /// Writes [updated] into the active theme+profile's saved copy, leaving
  /// which profile is active untouched. Shared by every `setCustom*`/
  /// `resetCustom*` mutation below.
  Future<void> _updateActiveProfile(CustomStyleOverrides updated) async {
    final profiles = Map<String, CustomStyleOverrides>.from(_settings.profiles)
      ..[_activeProfileKey] = updated;
    await updateSettings(_settings.copyWith(profiles: profiles));
  }

  Future<void> setCustomColorOverride(String key, Color value) async {
    final current = activeProfileSavedOverrides;
    final colors = Map<String, int>.from(current.colorOverrides)
      ..[key] = value.toARGB32();
    await _updateActiveProfile(current.copyWith(colorOverrides: colors));
  }

  Future<void> setCustomFontSizeOverride(String key, double value) async {
    final current = activeProfileSavedOverrides;
    final fontSizes = Map<String, double>.from(current.fontSizeOverrides)
      ..[key] = value;
    await _updateActiveProfile(current.copyWith(fontSizeOverrides: fontSizes));
  }

  Future<void> resetCustomColorOverride(String key) async {
    final current = activeProfileSavedOverrides;
    final colors = Map<String, int>.from(current.colorOverrides)..remove(key);
    await _updateActiveProfile(current.copyWith(colorOverrides: colors));
  }

  Future<void> resetCustomFontSizeOverride(String key) async {
    final current = activeProfileSavedOverrides;
    final fontSizes = Map<String, double>.from(current.fontSizeOverrides)
      ..remove(key);
    await _updateActiveProfile(current.copyWith(fontSizeOverrides: fontSizes));
  }

  Future<void> setCustomSpacingOverride(String key, double value) async {
    final current = activeProfileSavedOverrides;
    final spacing = Map<String, double>.from(current.spacingOverrides)
      ..[key] = value;
    await _updateActiveProfile(current.copyWith(spacingOverrides: spacing));
  }

  Future<void> resetCustomSpacingOverride(String key) async {
    final current = activeProfileSavedOverrides;
    final spacing = Map<String, double>.from(current.spacingOverrides)
      ..remove(key);
    await _updateActiveProfile(current.copyWith(spacingOverrides: spacing));
  }

  Future<void> setCustomRadiusOverride(String key, double value) async {
    final current = activeProfileSavedOverrides;
    final radii = Map<String, double>.from(current.radiusOverrides)
      ..[key] = value;
    await _updateActiveProfile(current.copyWith(radiusOverrides: radii));
  }

  Future<void> resetCustomRadiusOverride(String key) async {
    final current = activeProfileSavedOverrides;
    final radii = Map<String, double>.from(current.radiusOverrides)
      ..remove(key);
    await _updateActiveProfile(current.copyWith(radiusOverrides: radii));
  }

  Future<void> setCustomCardElevated(bool value) async {
    await _updateActiveProfile(
      activeProfileSavedOverrides.withCardElevated(value),
    );
  }

  Future<void> resetCustomCardElevated() async {
    await _updateActiveProfile(
      activeProfileSavedOverrides.withCardElevated(null),
    );
  }

  /// Discards the user's edited copy of the active profile, reverting to
  /// its shipped seed (StyleRegistry). Used by the editor's "Reset" action.
  Future<void> resetActiveProfileToSeed() async {
    final profiles = Map<String, CustomStyleOverrides>.from(_settings.profiles)
      ..remove(_activeProfileKey);
    await updateSettings(_settings.copyWith(profiles: profiles));
  }

  Future<void> setLanguageOverride(String? value) async {
    await updateSettings(_settings.copyWith(languageOverride: value));
  }

  Future<void> setAppDebugLogEnabled(bool value) async {
    await updateSettings(_settings.copyWith(appDebugLogEnabled: value));
    // Update the global logger
    appLogger.setEnabled(value);
  }

  Future<void> setMapShowDiscoveryContacts(bool value) async {
    await updateSettings(_settings.copyWith(mapShowDiscoveryContacts: value));
  }

  Future<void> setBatteryChemistryForDevice(
    String deviceId,
    String chemistry,
  ) async {
    final updated = Map<String, String>.from(
      _settings.batteryChemistryByDeviceId,
    );
    updated[deviceId] = chemistry;
    await updateSettings(
      _settings.copyWith(batteryChemistryByDeviceId: updated),
    );
  }

  Future<void> setBatteryChemistryForRepeater(
    String repeaterPubKeyHex,
    String chemistry,
  ) async {
    final updated = Map<String, String>.from(
      _settings.batteryChemistryByRepeaterId,
    );
    updated[repeaterPubKeyHex] = chemistry;
    await updateSettings(
      _settings.copyWith(batteryChemistryByRepeaterId: updated),
    );
  }

  Future<void> setUnitSystem(UnitSystem value) async {
    await updateSettings(_settings.copyWith(unitSystem: value));
  }

  bool isChannelMuted(String channelName) {
    return _settings.mutedChannels.contains(channelName);
  }

  Future<void> muteChannel(String channelName) async {
    final updated = Set<String>.from(_settings.mutedChannels)..add(channelName);
    await updateSettings(_settings.copyWith(mutedChannels: updated));
  }

  Future<void> unmuteChannel(String channelName) async {
    final updated = Set<String>.from(_settings.mutedChannels)
      ..remove(channelName);
    await updateSettings(_settings.copyWith(mutedChannels: updated));
  }

  Future<void> setTcpServerAddress(String value) async {
    await updateSettings(_settings.copyWith(tcpServerAddress: value));
  }

  Future<void> setTcpServerPort(int value) async {
    await updateSettings(_settings.copyWith(tcpServerPort: value));
  }

  Future<void> setJumpToOldestUnread(bool value) async {
    await updateSettings(_settings.copyWith(jumpToOldestUnread: value));
  }

  Future<void> setTranslationEnabled(bool value) async {
    await updateSettings(_settings.copyWith(translationEnabled: value));
  }

  Future<void> setAutoTranslateIncomingMessages(bool value) async {
    await updateSettings(
      _settings.copyWith(autoTranslateIncomingMessages: value),
    );
  }

  Future<void> setTranslationTargetLanguageCode(String? value) async {
    await updateSettings(
      _settings.copyWith(translationTargetLanguageCode: value),
    );
  }

  Future<void> setComposerTranslationEnabled(bool value) async {
    await updateSettings(_settings.copyWith(composerTranslationEnabled: value));
  }

  Future<void> setTranslationModelSourceUrl(String? value) async {
    await updateSettings(_settings.copyWith(translationModelSourceUrl: value));
  }

  Future<void> setTranslationSelectedModelId(String? value) async {
    await updateSettings(_settings.copyWith(translationSelectedModelId: value));
  }

  Future<void> setTranslationDownloadedModels(
    List<TranslationModelRecord> value,
  ) async {
    await updateSettings(
      _settings.copyWith(translationDownloadedModels: value),
    );
  }

  Cyr2LatProfile getSelectedCyr2LatProfile() {
    return _settings.cyr2latProfiles.firstWhere(
      (p) => p.id == _settings.selectedCyr2latProfileId,
      orElse: () => _settings.cyr2latProfiles.first,
    );
  }

  Cyr2LatProfile? getCyr2LatProfileById(String profileId) {
    return _settings.cyr2latProfiles.cast<Cyr2LatProfile?>().firstWhere(
      (p) => p?.id == profileId,
      orElse: () => null,
    );
  }

  Future<void> setSelectedCyr2LatProfile(String profileId) async {
    await updateSettings(
      _settings.copyWith(selectedCyr2latProfileId: profileId),
    );
  }

  Future<void> addCyr2LatProfile(Cyr2LatProfile profile) async {
    final updated = List<Cyr2LatProfile>.from(_settings.cyr2latProfiles)
      ..add(profile);
    await updateSettings(_settings.copyWith(cyr2latProfiles: updated));
  }

  Future<void> updateCyr2LatProfile(Cyr2LatProfile updatedProfile) async {
    final updated = _settings.cyr2latProfiles
        .map((p) => p.id == updatedProfile.id ? updatedProfile : p)
        .toList();
    await updateSettings(_settings.copyWith(cyr2latProfiles: updated));
  }

  Future<void> removeCyr2LatProfile(String profileId) async {
    if (_settings.cyr2latProfiles.length <= 1) {
      return; // Don't remove the last profile
    }
    final updated = _settings.cyr2latProfiles
        .where((p) => p.id != profileId)
        .toList();
    var newSelectedId = _settings.selectedCyr2latProfileId;
    if (newSelectedId == profileId) {
      newSelectedId = updated.first.id;
    }
    await updateSettings(
      _settings.copyWith(
        cyr2latProfiles: updated,
        selectedCyr2latProfileId: newSelectedId,
      ),
    );
  }
}
