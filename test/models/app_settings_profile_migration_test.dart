import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/app_settings.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';

void main() {
  group('AppSettings legacy style_id/customStyleOverrides migration', () {
    test(
      'style_id "custom" migrates its overrides into profiles["default:green"]',
      () {
        final decoded = AppSettings.fromJson({
          'style_id': 'custom',
          'custom_style_overrides': {
            'colors': {'primary': 0xFFEF4444},
            'spacing': {'spacingMd': 20.0},
          },
        });

        expect(decoded.activeThemeId, 'default');
        expect(decoded.activeProfileId, 'green');
        expect(decoded.profiles.containsKey('default:green'), isTrue);
        final migrated = decoded.profiles['default:green']!;
        expect(migrated.colorOverrides['primary'], 0xFFEF4444);
        expect(migrated.spacingOverrides['spacingMd'], 20.0);
      },
    );

    test('style_id "default" (no customization) yields the green profile with '
        'no saved copy (renders from its seed)', () {
      final decoded = AppSettings.fromJson({'style_id': 'default'});

      expect(decoded.activeThemeId, 'default');
      expect(decoded.activeProfileId, 'green');
      expect(decoded.profiles, isEmpty);
    });

    test('new-shape JSON round-trips through toJson/fromJson unchanged', () {
      final original = AppSettings(
        activeThemeId: 'default',
        activeProfileId: 'blue',
        profiles: const {
          'default:blue': CustomStyleOverrides(
            colorOverrides: {'ink': 0xFFF8FAFC},
          ),
        },
      );

      final decoded = AppSettings.fromJson(original.toJson());

      expect(decoded.activeThemeId, original.activeThemeId);
      expect(decoded.activeProfileId, original.activeProfileId);
      expect(
        decoded.profiles['default:blue']!.colorOverrides,
        original.profiles['default:blue']!.colorOverrides,
      );
    });
  });
}
