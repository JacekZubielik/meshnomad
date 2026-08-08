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

    test('an empty overrides set falls back to the dark default tokens '
        '(dark variant)', () {
      final style = buildCustomStyle(const CustomStyleOverrides());
      final defaultTokens = MeshTokens.defaultTokens;

      final tokens = style.dark.extension<MeshTokens>()!;
      expect(tokens.primary, defaultTokens.primary);
      expect(tokens.bg, defaultTokens.bg);
      expect(tokens.monoCaptionSize, defaultTokens.monoCaptionSize);
      expect(tokens.monoBodySize, defaultTokens.monoBodySize);
      expect(
        style.dark.textTheme.bodyMedium?.fontSize,
        defaultStyle.dark.textTheme.bodyMedium?.fontSize,
      );
    });

    // Guard test for pkt 17: before the two-pass build, buildCustomStyle
    // rendered `light` from the DARK default tokens — a Custom+Light user
    // saw a dark app. This must read the light default tokens instead.
    test('an empty overrides set falls back to the light default tokens '
        '(light variant — pkt 17 guard)', () {
      final style = buildCustomStyle(const CustomStyleOverrides());
      final defaultTokensLight = MeshTokens.defaultTokensLight;

      final tokens = style.light.extension<MeshTokens>()!;
      expect(tokens.primary, defaultTokensLight.primary);
      expect(tokens.bg, defaultTokensLight.bg);
      expect(tokens.ink, defaultTokensLight.ink);
      expect(tokens.line, defaultTokensLight.line);
      expect(style.light.colorScheme.surface, defaultTokensLight.bg);
      expect(style.light.colorScheme.onSurface, defaultTokensLight.ink);
      expect(style.light.scaffoldBackgroundColor, defaultTokensLight.bg);
      expect(
        style.light.textTheme.bodyMedium?.fontSize,
        defaultStyle.light.textTheme.bodyMedium?.fontSize,
      );
    });

    test('a dark color override wins over the default in the dark variant', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesDark: {'primary': 0xFF112233}),
      );

      final tokens = style.dark.extension<MeshTokens>()!;
      expect(tokens.primary, const Color(0xFF112233));
      // Unrelated fields stay at their default value.
      expect(tokens.ink, MeshTokens.defaultTokens.ink);
    });

    test('a present font size override wins over the default', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(fontSizeOverrides: {'bodyMedium': 20.0}),
      );

      expect(style.light.textTheme.bodyMedium?.fontSize, 20.0);
      expect(style.dark.textTheme.bodyMedium?.fontSize, 20.0);
      // Unrelated roles stay at their default value.
      expect(
        style.light.textTheme.bodySmall?.fontSize,
        defaultStyle.light.textTheme.bodySmall?.fontSize,
      );
    });

    test('mono size overrides apply to both monoCaptionSize/monoBodySize '
        'in both brightness variants', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          fontSizeOverrides: {'monoCaptionSize': 9.0, 'monoBodySize': 16.0},
        ),
      );

      final darkTokens = style.dark.extension<MeshTokens>()!;
      expect(darkTokens.monoCaptionSize, 9.0);
      expect(darkTokens.monoBodySize, 16.0);
      final lightTokens = style.light.extension<MeshTokens>()!;
      expect(lightTokens.monoCaptionSize, 9.0);
      expect(lightTokens.monoBodySize, 16.0);
    });

    test('an unknown key is silently ignored, never throws', () {
      expect(
        () => buildCustomStyle(
          const CustomStyleOverrides(
            colorOverridesDark: {'notARealField': 0xFF000000},
            fontSizeOverrides: {'notARealRole': 99.0},
          ),
        ),
        returnsNormally,
      );
    });

    test('a dark-only override does not leak into the light variant '
        '(pkt 17 isolation)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesDark: {'bg': 0xFF445566}),
      );

      expect(
        style.light.extension<MeshTokens>()!.bg,
        MeshTokens.defaultTokensLight.bg,
      );
      expect(style.light.colorScheme.surface, MeshTokens.defaultTokensLight.bg);
    });

    test('a light-only override does not leak into the dark variant '
        '(pkt 17 isolation)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesLight: {'bg': 0xFFAABBCC}),
      );

      expect(
        style.dark.extension<MeshTokens>()!.bg,
        MeshTokens.defaultTokens.bg,
      );
      expect(style.dark.colorScheme.surface, MeshTokens.defaultTokens.bg);
      expect(style.light.extension<MeshTokens>()!.bg, const Color(0xFFAABBCC));
    });

    test('an empty overrides set reproduces defaultStyle.dark.colorScheme '
        'bit-for-bit (variant-automat parity)', () {
      final style = buildCustomStyle(const CustomStyleOverrides());

      expect(style.dark.colorScheme, defaultStyle.dark.colorScheme);
    });

    test('overriding dark primary reshapes MeshTokens.primaryBg and '
        'ColorScheme.primary alike (C3), light stays untouched', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesDark: {'primary': 0xFF00FF00}),
      );

      final tokens = style.dark.extension<MeshTokens>()!;
      final primaryBgHsl = HSLColor.fromColor(tokens.primaryBg);
      expect(primaryBgHsl.hue, closeTo(120.0, 1.0)); // green hue

      expect(style.dark.colorScheme.primary, const Color(0xFF00FF00));
      expect(
        style.light.colorScheme.primary,
        MeshTokens.defaultTokensLight.primary,
      );
    });

    test('overriding a light bg reshapes the light surface layers — they '
        'get DARKER on a light base, not white (pkt 17 automat direction)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesLight: {'bg': 0xFFF0EDE8}),
      );

      final tokens = style.light.extension<MeshTokens>()!;
      expect(style.light.colorScheme.surface, tokens.bg);
      expect(style.light.colorScheme.surfaceContainerLow, tokens.bg1);
      expect(style.light.colorScheme.surfaceContainerHighest, tokens.bg3);
      expect(style.light.scaffoldBackgroundColor, tokens.bg);
      expect(style.light.appBarTheme.backgroundColor, tokens.bg);

      final bgLightness = HSLColor.fromColor(tokens.bg).lightness;
      final bg1Lightness = HSLColor.fromColor(tokens.bg1).lightness;
      final bg4Lightness = HSLColor.fromColor(tokens.bg4).lightness;
      expect(bg1Lightness, lessThan(bgLightness));
      expect(bg4Lightness, lessThan(bg1Lightness));
    });

    test('overriding a dark bg also reshapes the dark surface layers used '
        'by ColorScheme.surfaceContainer*', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverridesDark: {'bg': 0xFF1A0033}),
      );

      final tokens = style.dark.extension<MeshTokens>()!;
      expect(style.dark.colorScheme.surface, tokens.bg);
      expect(style.dark.colorScheme.surfaceContainerLow, tokens.bg1);
      expect(style.dark.colorScheme.surfaceContainerHighest, tokens.bg3);
      expect(style.dark.scaffoldBackgroundColor, tokens.bg);
      expect(style.dark.appBarTheme.backgroundColor, tokens.bg);
    });

    test('overriding a map/LOS color applies it 1:1 with no automat '
        '(04-editor-ui.md)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverridesDark: {'mapOnline': 0xFF00FF00, 'losBeam': 0xFF123456},
        ),
      );

      final tokens = style.dark.extension<MeshTokens>()!;
      expect(tokens.mapOnline, const Color(0xFF00FF00));
      expect(tokens.losBeam, const Color(0xFF123456));
      // Unrelated map/LOS fields stay at their default value.
      expect(tokens.mapOffline, MeshTokens.defaultTokens.mapOffline);
      expect(tokens.losTerrain, MeshTokens.defaultTokens.losTerrain);
    });
  });
}
