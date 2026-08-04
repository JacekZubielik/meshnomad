import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';

void main() {
  group('CustomStyleOverrides JSON round-trip', () {
    test('round-trips colors and font sizes', () {
      const original = CustomStyleOverrides(
        colorOverrides: {'blue': 0xFF0EA5E9, 'ink': 0xFFF8FAFC},
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
        'colors': {'blue': 'not-an-int', 'ink': 0xFFF8FAFC},
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

  group('CustomStyleOverrides.copyWith', () {
    test('replaces only the provided map', () {
      const original = CustomStyleOverrides(
        colorOverrides: {'blue': 1},
        fontSizeOverrides: {'bodyMedium': 12.0},
      );

      final updated = original.copyWith(colorOverrides: {'blue': 2});

      expect(updated.colorOverrides, {'blue': 2});
      expect(updated.fontSizeOverrides, {'bodyMedium': 12.0});
    });
  });
}
