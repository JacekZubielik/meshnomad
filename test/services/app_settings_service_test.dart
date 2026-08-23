import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
  });

  group('activeProfileOverrides', () {
    // Root cause (2026-08-23) of "Show borders" switch and the Buttons
    // section's line-style control silently having no effect: this merge
    // omitted buttonBorder/borderOverride entirely, so a saved value never
    // reached the actual rendered theme (main.dart._activeStyle reads only
    // this getter, never activeProfileSavedOverrides directly).
    test(
      'a saved buttonBorder value is reflected in activeProfileOverrides',
      () async {
        expect(settingsService.activeProfileOverrides.buttonBorder, isNull);
        await settingsService.setCustomButtonBorder('dotted');
        expect(settingsService.activeProfileOverrides.buttonBorder, 'dotted');
      },
    );

    test(
      'a saved borderOverride value is reflected in activeProfileOverrides',
      () async {
        expect(settingsService.activeProfileOverrides.borderOverride, isNull);
        await settingsService.setCustomBorderOverride(true);
        expect(settingsService.activeProfileOverrides.borderOverride, true);
        await settingsService.setCustomBorderOverride(false);
        expect(settingsService.activeProfileOverrides.borderOverride, false);
      },
    );

    test('a saved cardElevated value is reflected in activeProfileOverrides '
        '(already-working sibling field, kept as a control case)', () async {
      await settingsService.setCustomCardElevated(false);
      expect(settingsService.activeProfileOverrides.cardElevated, false);
    });
  });
}
