import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';

void main() {
  group('CustomStyleOverrides JSON round-trip (v2, per-brightness)', () {
    test('round-trips colors (both brightnesses) and font sizes', () {
      const original = CustomStyleOverrides(
        colorOverridesLight: {'primary': 0xFF2F6EA8},
        colorOverridesDark: {'primary': 0xFF0EA5E9, 'ink': 0xFFF8FAFC},
        fontSizeOverrides: {'bodyMedium': 13.0, 'monoBodySize': 14.5},
      );

      final decoded = CustomStyleOverrides.fromJson(original.toJson());

      expect(decoded.colorOverridesLight, original.colorOverridesLight);
      expect(decoded.colorOverridesDark, original.colorOverridesDark);
      expect(decoded.fontSizeOverrides, original.fontSizeOverrides);
    });

    test('round-trips an empty instance', () {
      const original = CustomStyleOverrides();

      final decoded = CustomStyleOverrides.fromJson(original.toJson());

      expect(decoded.colorOverridesLight, isEmpty);
      expect(decoded.colorOverridesDark, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });

    test('fromJson(null) returns an empty instance', () {
      final decoded = CustomStyleOverrides.fromJson(null);

      expect(decoded.colorOverridesLight, isEmpty);
      expect(decoded.colorOverridesDark, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });

    test('v2 with only colors_light leaves colors_dark empty', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_light': {'bg': 0xFFF4F6F8},
      });

      expect(decoded.colorOverridesLight, {'bg': 0xFFF4F6F8});
      expect(decoded.colorOverridesDark, isEmpty);
    });

    test('v2 with only colors_dark leaves colors_light empty', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_dark': {'bg': 0xFF0B1220},
      });

      expect(decoded.colorOverridesDark, {'bg': 0xFF0B1220});
      expect(decoded.colorOverridesLight, isEmpty);
    });

    test('skips malformed color entries instead of throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_dark': {'primary': 'not-an-int', 'ink': 0xFFF8FAFC},
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverridesDark, {'ink': 0xFFF8FAFC});
    });

    test('skips malformed font size entries instead of throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_dark': <String, dynamic>{},
        'font_sizes': {'bodyMedium': 'not-a-number', 'bodySmall': 11},
      });

      expect(decoded.fontSizeOverrides, {'bodySmall': 11.0});
    });

    test('ignores unrelated top-level types without throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_dark': 'not-a-map',
        'font_sizes': 42,
      });

      expect(decoded.colorOverridesDark, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });
  });

  group('CustomStyleOverrides legacy (v1) migration to dark', () {
    test('a legacy single "colors" map becomes colorOverridesDark', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': {'bg': 0xFF112233},
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverridesDark, {'bg': 0xFF112233});
      expect(decoded.colorOverridesLight, isEmpty);
    });

    test('migrates old blue/magenta keys to primary/secondary on load', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': {
          'blue': 0xFF0EA5E9,
          'magenta': 0xFFDE7FDB,
          'ink': 0xFFF8FAFC,
        },
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverridesDark, {
        'primary': 0xFF0EA5E9,
        'secondary': 0xFFDE7FDB,
        'ink': 0xFFF8FAFC,
      });
    });

    test(
      'prefers an already-present primary/secondary key over legacy ones',
      () {
        final decoded = CustomStyleOverrides.fromJson({
          'colors': {'blue': 0xFF0EA5E9, 'primary': 0xFF112233},
          'font_sizes': <String, dynamic>{},
        });

        expect(decoded.colorOverridesDark, {'primary': 0xFF112233});
      },
    );
  });

  group('CustomStyleOverrides.colorOverridesFor', () {
    test('returns the light map for Brightness.light', () {
      const overrides = CustomStyleOverrides(
        colorOverridesLight: {'bg': 1},
        colorOverridesDark: {'bg': 2},
      );

      expect(overrides.colorOverridesFor(Brightness.light), {'bg': 1});
    });

    test('returns the dark map for Brightness.dark', () {
      const overrides = CustomStyleOverrides(
        colorOverridesLight: {'bg': 1},
        colorOverridesDark: {'bg': 2},
      );

      expect(overrides.colorOverridesFor(Brightness.dark), {'bg': 2});
    });
  });

  group('CustomStyleOverrides.copyWith', () {
    test('replaces only the provided map, leaving the other brightness '
        'untouched', () {
      const original = CustomStyleOverrides(
        colorOverridesLight: {'primary': 10},
        colorOverridesDark: {'primary': 1},
        fontSizeOverrides: {'bodyMedium': 12.0},
      );

      final updated = original.copyWith(colorOverridesDark: {'primary': 2});

      expect(updated.colorOverridesDark, {'primary': 2});
      expect(updated.colorOverridesLight, {'primary': 10});
      expect(updated.fontSizeOverrides, {'bodyMedium': 12.0});
    });
  });
}
