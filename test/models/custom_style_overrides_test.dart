import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';

void main() {
  group('CustomStyleOverrides JSON round-trip (v3, single palette)', () {
    test('round-trips colors and font sizes', () {
      const original = CustomStyleOverrides(
        colorOverrides: {'primary': 0xFF0EA5E9, 'ink': 0xFFF8FAFC},
        fontSizeOverrides: {'bodyMedium': 13.0, 'monoBodySize': 14.5},
      );

      final decoded = CustomStyleOverrides.fromJson(original.toJson());

      expect(decoded.colorOverrides, original.colorOverrides);
      expect(decoded.fontSizeOverrides, original.fontSizeOverrides);
    });

    test('round-trips an empty instance', () {
      const original = CustomStyleOverrides();

      final decoded = CustomStyleOverrides.fromJson(original.toJson());

      expect(decoded.colorOverrides, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });

    test('fromJson(null) returns an empty instance', () {
      final decoded = CustomStyleOverrides.fromJson(null);

      expect(decoded.colorOverrides, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });

    test('skips malformed color entries instead of throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': {'primary': 'not-an-int', 'ink': 0xFFF8FAFC},
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverrides, {'ink': 0xFFF8FAFC});
    });

    test('skips malformed font size entries instead of throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': <String, dynamic>{},
        'font_sizes': {'bodyMedium': 'not-a-number', 'bodySmall': 11},
      });

      expect(decoded.fontSizeOverrides, {'bodySmall': 11.0});
    });

    test('ignores unrelated top-level types without throwing', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': 'not-a-map',
        'font_sizes': 42,
      });

      expect(decoded.colorOverrides, isEmpty);
      expect(decoded.fontSizeOverrides, isEmpty);
    });
  });

  group('CustomStyleOverrides legacy (v2, per-brightness) migration', () {
    test('uses colors_dark as the single palette, colors_light is dropped', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_light': {'bg': 0xFFF4F6F8},
        'colors_dark': {'bg': 0xFF0B1220, 'primary': 0xFF0EA5E9},
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverrides, {'bg': 0xFF0B1220, 'primary': 0xFF0EA5E9});
    });

    test('v2 with only colors_light yields an empty palette', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors_light': {'bg': 0xFFF4F6F8},
      });

      expect(decoded.colorOverrides, isEmpty);
    });
  });

  group('CustomStyleOverrides legacy (v1) migration', () {
    test('a legacy single "colors" map becomes colorOverrides', () {
      final decoded = CustomStyleOverrides.fromJson({
        'colors': {'bg': 0xFF112233},
        'font_sizes': <String, dynamic>{},
      });

      expect(decoded.colorOverrides, {'bg': 0xFF112233});
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

      expect(decoded.colorOverrides, {
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

        expect(decoded.colorOverrides, {'primary': 0xFF112233});
      },
    );
  });

  group('CustomStyleOverrides.copyWith', () {
    test('replaces only the provided map', () {
      const original = CustomStyleOverrides(
        colorOverrides: {'primary': 1},
        fontSizeOverrides: {'bodyMedium': 12.0},
      );

      final updated = original.copyWith(colorOverrides: {'primary': 2});

      expect(updated.colorOverrides, {'primary': 2});
      expect(updated.fontSizeOverrides, {'bodyMedium': 12.0});
    });
  });
}
