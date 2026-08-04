import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/theme/styles/custom_style.dart';
import 'package:meshcore_open/theme/styles/default_style.dart';

void main() {
  group('buildCustomStyle', () {
    test('id/displayName are fixed to "custom"', () {
      final style = buildCustomStyle(const CustomStyleOverrides());

      expect(style.id, 'custom');
      expect(style.displayName, 'Custom');
    });

    test('an empty overrides set falls back to defaultStyle values', () {
      final style = buildCustomStyle(const CustomStyleOverrides());
      final defaultTokens = MeshTokens.defaultTokens;

      final tokens = style.light.extension<MeshTokens>()!;
      expect(tokens.primary, defaultTokens.primary);
      expect(tokens.bg, defaultTokens.bg);
      expect(tokens.monoCaptionSize, defaultTokens.monoCaptionSize);
      expect(tokens.monoBodySize, defaultTokens.monoBodySize);
      expect(
        style.light.textTheme.bodyMedium?.fontSize,
        defaultStyle.light.textTheme.bodyMedium?.fontSize,
      );
    });

    test('a present color override wins over the default', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'primary': 0xFF112233}),
      );

      final tokens = style.light.extension<MeshTokens>()!;
      expect(tokens.primary, const Color(0xFF112233));
      // Unrelated fields stay at their default value.
      expect(tokens.ink, MeshTokens.defaultTokens.ink);
    });

    test('a present font size override wins over the default', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(fontSizeOverrides: {'bodyMedium': 20.0}),
      );

      expect(style.light.textTheme.bodyMedium?.fontSize, 20.0);
      // Unrelated roles stay at their default value.
      expect(
        style.light.textTheme.bodySmall?.fontSize,
        defaultStyle.light.textTheme.bodySmall?.fontSize,
      );
    });

    test('mono size overrides apply to both monoCaptionSize/monoBodySize', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          fontSizeOverrides: {'monoCaptionSize': 9.0, 'monoBodySize': 16.0},
        ),
      );

      final tokens = style.light.extension<MeshTokens>()!;
      expect(tokens.monoCaptionSize, 9.0);
      expect(tokens.monoBodySize, 16.0);
    });

    test('an unknown key is silently ignored, never throws', () {
      expect(
        () => buildCustomStyle(
          const CustomStyleOverrides(
            colorOverrides: {'notARealField': 0xFF000000},
            fontSizeOverrides: {'notARealRole': 99.0},
          ),
        ),
        returnsNormally,
      );
    });

    test('light and dark share the same token overrides', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'primary': 0xFF445566}),
      );

      expect(
        style.dark.extension<MeshTokens>()!.primary,
        style.light.extension<MeshTokens>()!.primary,
      );
    });
  });
}
