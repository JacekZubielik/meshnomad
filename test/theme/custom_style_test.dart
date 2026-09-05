import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/models/custom_style_overrides.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/theme/styles/custom_style.dart';

void main() {
  group('buildCustomStyle', () {
    test('id/displayName are fixed to "custom"', () {
      final style = buildCustomStyle(const CustomStyleOverrides());

      expect(style.id, 'custom');
      expect(style.displayName, 'Custom');
    });

    test('an empty overrides set falls back to the dark default tokens '
        '(single-pass default resolution)', () {
      final style = buildCustomStyle(const CustomStyleOverrides());
      final defaultTokens = MeshTokens.defaultTokens;

      final tokens = style.theme.extension<MeshTokens>()!;
      expect(tokens.primary, defaultTokens.primary);
      expect(tokens.bg, defaultTokens.bg);
      expect(tokens.monoCaptionSize, defaultTokens.monoCaptionSize);
      expect(tokens.monoBodySize, defaultTokens.monoBodySize);
      expect(
        style.theme.textTheme.bodyMedium?.fontSize,
        MeshTheme.dark().textTheme.bodyMedium?.fontSize,
      );
    });

    test('a color override wins over the default', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'primary': 0xFF112233}),
      );

      final tokens = style.theme.extension<MeshTokens>()!;
      expect(tokens.primary, const Color(0xFF112233));
      // Unrelated fields stay at their default value.
      expect(tokens.ink, MeshTokens.defaultTokens.ink);
    });

    test('a present font size override wins over the default, in both '
        'brightness resolutions', () {
      final darkResolved = buildCustomStyle(
        const CustomStyleOverrides(fontSizeOverrides: {'bodyMedium': 20.0}),
      );
      expect(darkResolved.theme.textTheme.bodyMedium?.fontSize, 20.0);
      // Unrelated roles stay at their default value.
      expect(
        darkResolved.theme.textTheme.bodySmall?.fontSize,
        MeshTheme.dark().textTheme.bodySmall?.fontSize,
      );

      final lightResolved = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'bg': 0xFFF0EDE8},
          fontSizeOverrides: {'bodyMedium': 20.0},
        ),
      );
      expect(lightResolved.theme.textTheme.bodyMedium?.fontSize, 20.0);
    });

    test('mono size overrides apply to both monoCaptionSize/monoBodySize, '
        'in both brightness resolutions', () {
      final darkResolved = buildCustomStyle(
        const CustomStyleOverrides(
          fontSizeOverrides: {'monoCaptionSize': 9.0, 'monoBodySize': 16.0},
        ),
      );
      final darkTokens = darkResolved.theme.extension<MeshTokens>()!;
      expect(darkTokens.monoCaptionSize, 9.0);
      expect(darkTokens.monoBodySize, 16.0);

      final lightResolved = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'bg': 0xFFF0EDE8},
          fontSizeOverrides: {'monoCaptionSize': 9.0, 'monoBodySize': 16.0},
        ),
      );
      final lightTokens = lightResolved.theme.extension<MeshTokens>()!;
      expect(lightTokens.monoCaptionSize, 9.0);
      expect(lightTokens.monoBodySize, 16.0);
    });

    test('chat text / micro label size overrides apply to the tokens, '
        'in both brightness resolutions', () {
      for (final colors in [
        const <String, int>{},
        const {'bg': 0xFFF0EDE8},
      ]) {
        final resolved = buildCustomStyle(
          CustomStyleOverrides(
            colorOverrides: colors,
            fontSizeOverrides: const {'bodySize': 17.0, 'microLabelSize': 7.5},
          ),
        );
        final tokens = resolved.theme.extension<MeshTokens>()!;
        expect(tokens.bodySize, 17.0);
        expect(tokens.microLabelSize, 7.5);
      }
    });

    test('every editable font key changes something in the resolved style', () {
      // A key listed as editable must land somewhere the app reads from —
      // an unhandled key here throws, so the switch stays in sync with
      // CustomStyleOverrides.editableFontSizeKeys.
      double sizeOf(ThemeData theme, String key) {
        final text = theme.textTheme;
        final tokens = theme.extension<MeshTokens>()!;
        return switch (key) {
          'bodyMedium' => text.bodyMedium!.fontSize!,
          'bodySmall' => text.bodySmall!.fontSize!,
          'titleSmall' => text.titleSmall!.fontSize!,
          'labelSmall' => text.labelSmall!.fontSize!,
          'labelMedium' => text.labelMedium!.fontSize!,
          'monoCaptionSize' => tokens.monoCaptionSize,
          'monoBodySize' => tokens.monoBodySize,
          'bodySize' => tokens.bodySize,
          'microLabelSize' => tokens.microLabelSize,
          _ => throw StateError('no reader for editable font key $key'),
        };
      }

      for (final key in CustomStyleOverrides.editableFontSizeKeys) {
        final resolved = buildCustomStyle(
          CustomStyleOverrides(fontSizeOverrides: {key: 23.0}),
        );
        expect(sizeOf(resolved.theme, key), 23.0, reason: key);
      }
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

    test('an empty overrides set reproduces MeshTheme.dark().colorScheme '
        'bit-for-bit, except outline/outlineVariant (variant-automat '
        'parity)', () {
      final style = buildCustomStyle(const CustomStyleOverrides());

      // outline/outlineVariant intentionally diverge from mesh_theme.dart's
      // own mapping (line2/line) — buildCustomStyle always drives them from
      // `secondary` instead, so every Divider/OutlinedButton border etc.
      // app-wide reads the same accent as the Custom Style editor's own
      // dividers (user decision 2026-08-15). Every other field must still
      // match bit-for-bit.
      final dark = MeshTheme.dark().colorScheme;
      expect(
        style.theme.colorScheme,
        dark.copyWith(
          outline: MeshTokens.defaultTokens.secondary,
          outlineVariant: MeshTokens.defaultTokens.secondary,
        ),
      );
    });

    test('AppBar bottom border tracks the overridden outlineVariant, not '
        'the frozen base theme value (2026-09-01 fix)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'secondary': 0xFF00FFAA},
          borderOverride: true,
        ),
      );
      final shape = style.theme.appBarTheme.shape;
      expect(shape, isA<Border>());
      final border = shape! as Border;
      expect(border.bottom.color, style.theme.colorScheme.outlineVariant);
      expect(border.bottom.color, const Color(0xFF00FFAA));
    });

    test(
      'AppBar bottom border is transparent/hidden when bordersVisible is false',
      () {
        final style = buildCustomStyle(
          const CustomStyleOverrides(
            colorOverrides: {'secondary': 0xFF00FFAA},
            borderOverride: false,
          ),
        );
        final shape = style.theme.appBarTheme.shape;
        expect(shape, isA<Border>());
        final border = shape! as Border;
        // Border should be transparent/zero-width when bordersVisible is false
        expect(border.bottom.color, Colors.transparent);
        expect(border.bottom.width, 0);
      },
    );

    test('overriding primary reshapes MeshTokens.primaryBg and '
        'ColorScheme.primary alike (C3)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'primary': 0xFF00FF00}),
      );

      final tokens = style.theme.extension<MeshTokens>()!;
      final primaryBgHsl = HSLColor.fromColor(tokens.primaryBg);
      expect(primaryBgHsl.hue, closeTo(120.0, 1.0)); // green hue

      expect(style.theme.colorScheme.primary, const Color(0xFF00FF00));
    });

    test('overriding a light bg reshapes the surface layers — they get '
        'DARKER on a light base, not white (automat direction)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'bg': 0xFFF0EDE8}),
      );

      final tokens = style.theme.extension<MeshTokens>()!;
      expect(style.theme.colorScheme.surface, tokens.bg);
      expect(style.theme.colorScheme.surfaceContainerLow, tokens.bg1);
      expect(style.theme.colorScheme.surfaceContainerHighest, tokens.bg3);
      // scaffoldBackgroundColor is one step up the surfaceContainer ladder
      // from appBarTheme's own tokens.bg (2026-09-02: list content vs. app
      // bar/bottom bar contrast) — the two are deliberately different now.
      expect(style.theme.scaffoldBackgroundColor, tokens.bg1);
      expect(style.theme.appBarTheme.backgroundColor, tokens.bg);

      final bgLightness = HSLColor.fromColor(tokens.bg).lightness;
      final bg1Lightness = HSLColor.fromColor(tokens.bg1).lightness;
      final bg4Lightness = HSLColor.fromColor(tokens.bg4).lightness;
      expect(bg1Lightness, lessThan(bgLightness));
      expect(bg4Lightness, lessThan(bg1Lightness));
    });

    test('overriding a dark bg also reshapes the surface layers used '
        'by ColorScheme.surfaceContainer*', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'bg': 0xFF1A0033}),
      );

      final tokens = style.theme.extension<MeshTokens>()!;
      expect(style.theme.colorScheme.surface, tokens.bg);
      expect(style.theme.colorScheme.surfaceContainerLow, tokens.bg1);
      expect(style.theme.colorScheme.surfaceContainerHighest, tokens.bg3);
      // scaffoldBackgroundColor is one step up the surfaceContainer ladder
      // from appBarTheme's own tokens.bg (2026-09-02: list content vs. app
      // bar/bottom bar contrast) — the two are deliberately different now.
      expect(style.theme.scaffoldBackgroundColor, tokens.bg1);
      expect(style.theme.appBarTheme.backgroundColor, tokens.bg);
    });

    test('overriding a map/LOS color applies it 1:1 with no automat '
        '(04-editor-ui.md)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'mapOnline': 0xFF00FF00, 'losBeam': 0xFF123456},
        ),
      );

      final tokens = style.theme.extension<MeshTokens>()!;
      expect(tokens.mapOnline, const Color(0xFF00FF00));
      expect(tokens.losBeam, const Color(0xFF123456));
      // Map fields stay independent (fixed defaults, no theme derivation).
      expect(tokens.mapOffline, MeshTokens.defaultTokens.mapOffline);
    });

    test('un-overridden LOS tokens now follow the active scheme '
        '(chrome from surfaces/ink, status from accents)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'bg': 0xFF102010, 'primary': 0xFFFF8800},
        ),
      );
      final tokens = style.theme.extension<MeshTokens>()!;
      // Chrome derives: chart bg == bg, text == ink.
      expect(tokens.losChartBackground, tokens.bg);
      expect(tokens.losText, tokens.ink);
      // Status derives from accents (bit-identical to the old fixed palette
      // when accents are unchanged; here primary was overridden).
      expect(tokens.losBlocked, tokens.alert);
      expect(tokens.losClear, tokens.signal);
      expect(tokens.losSelected, tokens.primary);
      // An explicit LOS override still wins over the derived default.
      final pinned = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'losSelected': 0xFF123456}),
      );
      expect(
        pinned.theme.extension<MeshTokens>()!.losSelected,
        const Color(0xFF123456),
      );
    });

    test(
      'default spacing scale is 6/16/13/14/24/32 in both brightnesses '
      '(2026-08-21 operator-set defaults; spacingXxlg removed 2026-08-24)',
      () {
        for (final tokens in [
          MeshTokens.defaultTokens,
          MeshTokens.defaultTokensLight,
        ]) {
          expect(tokens.spacingXxs, 6);
          expect(tokens.spacingXs, 16);
          expect(tokens.spacingSm, 13);
          expect(tokens.spacingMd, 14);
          expect(tokens.spacingLg, 24);
          expect(tokens.spacingXlg, 32);
        }
      },
    );

    test('a present spacing override wins over the default '
        '(brightness-independent)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(spacingOverrides: {'spacingMd': 24.0}),
      );
      expect(style.theme.extension<MeshTokens>()!.spacingMd, 24.0);
      expect(
        style.theme.extension<MeshTokens>()!.spacingXs,
        MeshTokens.defaultTokens.spacingXs,
      );
    });

    test('an unknown spacing key silently falls back to defaults', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(spacingOverrides: {'notARealStep': 99.0}),
      );
      expect(
        style.theme.extension<MeshTokens>()!.spacingMd,
        MeshTokens.defaultTokens.spacingMd,
      );
    });

    test('chat bubble corner overrides apply to their own tokens '
        '(2026-09-05: two sliders, independent of lg/xs)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          radiusOverrides: {'bubbleRadius': 21.0, 'bubbleTailRadius': 3.0},
        ),
      );
      final tokens = style.theme.extension<MeshTokens>()!;
      expect(tokens.bubbleRadius, 21.0);
      expect(tokens.bubbleTailRadius, 3.0);
      // The general ladder is untouched by them.
      expect(tokens.lg, MeshTokens.defaultTokens.lg);
      expect(tokens.xs, MeshTokens.defaultTokens.xs);
    });

    test('a radius override wins over the default and reshapes chrome', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(radiusOverrides: {'md': 2.0}),
      );
      expect(style.theme.extension<MeshTokens>()!.md, 2.0);
      final border = style.theme.inputDecorationTheme.border;
      expect(border, isA<OutlineInputBorder>());
      expect((border! as OutlineInputBorder).borderRadius.topLeft.x, 2.0);
    });

    test(
      'a pill radius override wins over the default and reshapes the FAB',
      () {
        final style = buildCustomStyle(
          const CustomStyleOverrides(radiusOverrides: {'pill': 4.0}),
        );
        expect(style.theme.extension<MeshTokens>()!.pill, 4.0);
        final shape = style.theme.floatingActionButtonTheme.shape;
        expect(shape, isA<RoundedRectangleBorder>());
        final radius =
            (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
        expect(radius.topLeft.x, 4.0);
      },
    );

    test('buttons follow their own self-contained radius/border control, '
        'independent of the app-wide bordersVisible toggle (2026-08-21 '
        'Buttons section, reverted to independent 2026-08-23)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          radiusOverrides: {'buttonRadius': 6.0},
          buttonBorder: 'solid',
        ),
      );
      final shape = style.theme.filledButtonTheme.style?.shape?.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      final rrb = shape! as RoundedRectangleBorder;
      expect((rrb.borderRadius as BorderRadius).topLeft.x, 6.0);
      expect(rrb.side.style, BorderStyle.solid);
      expect(rrb.side.color, style.theme.colorScheme.primary);

      // buttonBorder: 'solid' shows a border even when the app-wide switch
      // would hide borders everywhere else (borderOverride: false here).
      final solidDespiteGlobalOff = buildCustomStyle(
        const CustomStyleOverrides(
          buttonBorder: 'solid',
          borderOverride: false,
        ),
      );
      final solidShape =
          solidDespiteGlobalOff.theme.filledButtonTheme.style?.shape?.resolve(
                {},
              )!
              as RoundedRectangleBorder;
      expect(solidShape.side, isNot(BorderSide.none));

      // buttonBorder: 'none' hides the border even when the app-wide switch
      // would show borders everywhere else (borderOverride: true here).
      final noneDespiteGlobalOn = buildCustomStyle(
        const CustomStyleOverrides(buttonBorder: 'none', borderOverride: true),
      );
      final noneDespiteGlobalOnShape =
          noneDespiteGlobalOn.theme.filledButtonTheme.style?.shape?.resolve({})!
              as RoundedRectangleBorder;
      expect(noneDespiteGlobalOnShape.side, BorderSide.none);

      final none = buildCustomStyle(const CustomStyleOverrides());
      final noneShape =
          none.theme.filledButtonTheme.style?.shape?.resolve({})!
              as RoundedRectangleBorder;
      expect(noneShape.side, BorderSide.none);
    });

    test('pill defaults to fully round (999) when not overridden', () {
      final style = buildCustomStyle(const CustomStyleOverrides());
      expect(style.theme.extension<MeshTokens>()!.pill, 999.0);
    });

    test('cardElevated override flows into tokens; null inherits default', () {
      final off = buildCustomStyle(
        const CustomStyleOverrides(cardElevated: false),
      );
      expect(off.theme.extension<MeshTokens>()!.cardElevated, false);
      final inherit = buildCustomStyle(const CustomStyleOverrides());
      expect(inherit.theme.extension<MeshTokens>()!.cardElevated, true);
    });

    test('bordersVisible follows !cardElevated by default, and '
        'borderOverride wins independently either direction '
        '(2026-08-23 border/shadow unification)', () {
      bool visible(CustomStyleOverrides o) =>
          buildCustomStyle(o).theme.extension<MeshTokens>()!.bordersVisible;

      // Shadow on (default) -> borders hidden; shadow off -> borders shown.
      expect(visible(const CustomStyleOverrides()), false);
      expect(visible(const CustomStyleOverrides(cardElevated: false)), true);

      // Explicit override wins over the shadow-derived default either way.
      expect(visible(const CustomStyleOverrides(borderOverride: true)), true);
      expect(
        visible(
          const CustomStyleOverrides(
            cardElevated: false,
            borderOverride: false,
          ),
        ),
        false,
      );

      // Spot-check a couple of the widget sites actually gated by it.
      final shown = buildCustomStyle(
        const CustomStyleOverrides(borderOverride: true),
      ).theme;
      final hidden = buildCustomStyle(const CustomStyleOverrides()).theme;
      expect(
        (shown.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderSide,
        isNot(BorderSide.none),
      );
      expect(
        (hidden.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderSide,
        BorderSide.none,
      );
      expect(shown.dividerTheme.color, isNot(Colors.transparent));
      expect(hidden.dividerTheme.color, Colors.transparent);
    });

    test('a bg override re-derives popup chrome backgrounds '
        '(dialog/sheet/snackbar/menu follow the custom surface)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'bg': 0xFF808080}),
      );
      final theme = style.theme;
      final scheme = theme.colorScheme;
      expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerLow);
      expect(
        theme.bottomSheetTheme.backgroundColor,
        scheme.surfaceContainerLow,
      );
      expect(
        theme.bottomSheetTheme.modalBackgroundColor,
        scheme.surfaceContainerLow,
      );
      expect(theme.snackBarTheme.backgroundColor, scheme.surfaceContainerHigh);
      expect(theme.popupMenuTheme.color, scheme.surfaceContainerHigh);
      expect(theme.navigationBarTheme.backgroundColor, scheme.surface);
      expect(theme.chipTheme.backgroundColor, scheme.surfaceContainerLow);
    });

    test('overrides re-derive baked input fill and switch chrome '
        '(a light-resolved profile follows its own light palette)', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(
          colorOverrides: {'bg': 0xFFEEEEEE, 'primary': 0xFF112233},
        ),
      );
      final theme = style.theme;
      final scheme = theme.colorScheme;
      expect(theme.inputDecorationTheme.fillColor, scheme.surfaceContainerHigh);
      expect(
        theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
        scheme.primary.withValues(alpha: 0.2),
      );
      expect(theme.switchTheme.thumbColor!.resolve({}), scheme.secondary);
    });

    test('a primary override re-derives button/FAB/progress accents '
        'and container colors', () {
      final style = buildCustomStyle(
        const CustomStyleOverrides(colorOverrides: {'primary': 0xFFFF8800}),
      );
      final theme = style.theme;
      final scheme = theme.colorScheme;
      expect(scheme.primary, const Color(0xFFFF8800));
      // FAB now follows the tinted-primary button language too (2026-08-23).
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        scheme.primary.withValues(alpha: 0.2),
      );
      expect(theme.floatingActionButtonTheme.foregroundColor, scheme.primary);
      // Buttons render the tinted-primary language (2026-08-21): 20% tint
      // fill with the accent itself as ink.
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        scheme.primary.withValues(alpha: 0.2),
      );
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        scheme.primary,
      );
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve({}),
        scheme.primary,
      );
      expect(theme.progressIndicatorTheme.color, scheme.primary);
      expect(
        theme.sliderTheme.activeTrackColor,
        scheme.primary.withValues(alpha: 0.2),
      );
      expect(theme.sliderTheme.thumbColor, scheme.primary);
      expect(theme.cardTheme.color, scheme.surfaceContainerLow);
      // Containers (used e.g. by the path editor sheet) must follow the
      // overridden accent instead of inheriting the default style's blue.
      expect(
        scheme.primaryContainer,
        isNot(MeshTheme.dark().colorScheme.primaryContainer),
      );
      expect(scheme.onPrimaryContainer, scheme.onSurface);
    });
  });
}
