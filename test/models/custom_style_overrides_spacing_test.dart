import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';

void main() {
  test('toJson/fromJson roundtrips spacing overrides', () {
    const overrides = CustomStyleOverrides(
      spacingOverrides: {'spacingMd': 20.0, 'spacingXs': 6.0},
    );
    final decoded = CustomStyleOverrides.fromJson(overrides.toJson());
    expect(decoded.spacingOverrides, {'spacingMd': 20.0, 'spacingXs': 6.0});
  });

  test('fromJson without a spacing key yields an empty map (old saves)', () {
    final decoded = CustomStyleOverrides.fromJson({
      'colors_dark': {'primary': 0xFF112233},
      'font_sizes': {'bodyMedium': 14.0},
    });
    expect(decoded.spacingOverrides, isEmpty);
    expect(decoded.colorOverridesDark, {'primary': 0xFF112233});
  });

  test('copyWith replaces only spacingOverrides', () {
    const base = CustomStyleOverrides(fontSizeOverrides: {'bodyMedium': 13.0});
    final next = base.copyWith(spacingOverrides: {'spacingLg': 30.0});
    expect(next.spacingOverrides, {'spacingLg': 30.0});
    expect(next.fontSizeOverrides, {'bodyMedium': 13.0});
  });

  test('editableSpacingKeys lists all 7 steps in scale order', () {
    expect(CustomStyleOverrides.editableSpacingKeys, [
      'spacingXxs',
      'spacingXs',
      'spacingSm',
      'spacingMd',
      'spacingLg',
      'spacingXlg',
      'spacingXxlg',
    ]);
  });

  test('toJson/fromJson roundtrips radius overrides', () {
    const overrides = CustomStyleOverrides(radiusOverrides: {'md': 20.0});
    final decoded = CustomStyleOverrides.fromJson(overrides.toJson());
    expect(decoded.radiusOverrides, {'md': 20.0});
  });

  test('editableRadiusKeys lists 5 editable steps (pill excluded)', () {
    expect(CustomStyleOverrides.editableRadiusKeys, [
      'xs',
      'sm',
      'md',
      'lg',
      'xl',
    ]);
  });
}
