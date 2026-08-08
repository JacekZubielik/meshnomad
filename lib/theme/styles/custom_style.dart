import 'package:flutter/material.dart';

import '../../models/custom_style_overrides.dart';
import '../mesh_derived.dart';
import '../mesh_theme.dart' show MeshTypeScale;
import '../mesh_tokens.dart';
import '../style.dart';
import 'default_style.dart';

/// Builds the "custom" [MeshStyle] by layering [overrides] on top of
/// [defaultStyle]'s exact values. Absent keys, or keys with no known
/// matching field, silently fall back to the default value — never throws.
MeshStyle buildCustomStyle(CustomStyleOverrides overrides) {
  // Two-pass build (pkt 17): dark reads defaultTokens + the dark HSL automat
  // (layers lighten off a dark base), light reads defaultTokensLight + the
  // light automat (layers darken off a light base, see mesh_derived.dart).
  // Accent derivers (primary/secondary/warn/alert/signal) stay shared — "dim"
  // darkens either way and works on light accents too.
  MeshTokens applyColorOverrides(MeshTokens base, Brightness brightness) {
    final colors = overrides.colorOverridesFor(brightness);
    final isLight = brightness == Brightness.light;
    int? colorFor(String key) => colors[key];
    Color baseColorFor(String key, Color fallback) {
      final value = colorFor(key);
      return value != null ? Color(value) : fallback;
    }

    // Overridden (or default) base colors — every derived/variant token
    // below is computed FROM THESE, not from the untouched defaults, so a
    // user-picked accent also reshapes its dim/bg/line variants (A5/A6).
    final bg = baseColorFor('bg', base.bg);
    final ink = baseColorFor('ink', base.ink);
    final line = baseColorFor('line', base.line);
    final primary = baseColorFor('primary', base.primary);
    final secondary = baseColorFor('secondary', base.secondary);
    final signal = baseColorFor('signal', base.signal);
    final warn = baseColorFor('warn', base.warn);
    final alert = baseColorFor('alert', base.alert);
    final me = baseColorFor('me', base.me);
    final meInk = baseColorFor('meInk', base.meInk);

    final bgLayers = isLight ? deriveBgLayersLight(bg) : deriveBgLayers(bg);
    final inkLayers = isLight
        ? deriveInkLayersLight(ink)
        : deriveInkLayers(ink);
    final lineLayers = isLight
        ? deriveLineLayersLight(line)
        : deriveLineLayers(line);
    final primaryVariants = derivePrimaryVariants(primary);
    final secondaryVariants = deriveSecondaryVariants(secondary);
    final warnVariants = deriveWarnVariants(warn);
    final alertVariants = deriveAlertVariants(alert);

    return base.copyWith(
      bg: bg,
      bg1: bgLayers.bg1,
      bg2: bgLayers.bg2,
      bg3: bgLayers.bg3,
      bg4: bgLayers.bg4,
      ink: ink,
      ink2: inkLayers.ink2,
      ink3: inkLayers.ink3,
      ink4: inkLayers.ink4,
      line: line,
      line2: lineLayers.line2,
      line3: lineLayers.line3,
      primary: primary,
      primaryDim: primaryVariants.primaryDim,
      primaryBg: primaryVariants.primaryBg,
      primaryLine: primaryVariants.primaryLine,
      secondary: secondary,
      secondaryBg: secondaryVariants.secondaryBg,
      secondaryLine: secondaryVariants.secondaryLine,
      signal: signal,
      signalDim: deriveSignalDim(signal),
      warn: warn,
      warnDim: warnVariants.warnDim,
      warnBg: warnVariants.warnBg,
      warnLine: warnVariants.warnLine,
      alert: alert,
      alertBg: alertVariants.alertBg,
      alertLine: alertVariants.alertLine,
      me: me,
      meInk: meInk,
      // Map/LOS palettes (A6/04-editor-ui.md) — semantically independent
      // per-marker/per-state colors, applied 1:1, no automat.
      mapOnline: baseColorFor('mapOnline', base.mapOnline),
      mapOffline: baseColorFor('mapOffline', base.mapOffline),
      mapStale: baseColorFor('mapStale', base.mapStale),
      mapRepeater: baseColorFor('mapRepeater', base.mapRepeater),
      mapRouter: baseColorFor('mapRouter', base.mapRouter),
      mapBatteryLow: baseColorFor('mapBatteryLow', base.mapBatteryLow),
      mapCluster: baseColorFor('mapCluster', base.mapCluster),
      mapSelected: baseColorFor('mapSelected', base.mapSelected),
      mapSensor: baseColorFor('mapSensor', base.mapSensor),
      mapShared: baseColorFor('mapShared', base.mapShared),
      mapPanelLight: baseColorFor('mapPanelLight', base.mapPanelLight),
      mapPanelDark: baseColorFor('mapPanelDark', base.mapPanelDark),
      mapTextPrimary: baseColorFor('mapTextPrimary', base.mapTextPrimary),
      mapTextSecondary: baseColorFor('mapTextSecondary', base.mapTextSecondary),
      mapTextMuted: baseColorFor('mapTextMuted', base.mapTextMuted),
      mapBorder: baseColorFor('mapBorder', base.mapBorder),
      mapMarkerOutline: baseColorFor('mapMarkerOutline', base.mapMarkerOutline),
      mapMarkerShadow: baseColorFor('mapMarkerShadow', base.mapMarkerShadow),
      losTerrain: baseColorFor('losTerrain', base.losTerrain),
      losBeam: baseColorFor('losBeam', base.losBeam),
      losHorizon: baseColorFor('losHorizon', base.losHorizon),
      losBlocked: baseColorFor('losBlocked', base.losBlocked),
      losMarginal: baseColorFor('losMarginal', base.losMarginal),
      losClear: baseColorFor('losClear', base.losClear),
      losSelected: baseColorFor('losSelected', base.losSelected),
      losChartBackground: baseColorFor(
        'losChartBackground',
        base.losChartBackground,
      ),
      losPanelDark: baseColorFor('losPanelDark', base.losPanelDark),
      losPanelLight: baseColorFor('losPanelLight', base.losPanelLight),
      losText: baseColorFor('losText', base.losText),
      losTextMuted: baseColorFor('losTextMuted', base.losTextMuted),
      losBorder: baseColorFor('losBorder', base.losBorder),
      losShadow: baseColorFor('losShadow', base.losShadow),
    );
  }

  TextTheme applyFontSizeOverrides(TextTheme base) {
    double? sizeFor(String key) => overrides.fontSizeOverrides[key];
    // B3: titleMedium/titleLarge/headlineSmall aren't editable directly —
    // they're always derived from the (possibly overridden) titleSmall, so
    // dragging the "Title" slider also resizes large titles consistently.
    final titleSmallSize = sizeFor('titleSmall') ?? base.titleSmall!.fontSize!;

    return base.copyWith(
      bodyMedium: sizeFor('bodyMedium') != null
          ? base.bodyMedium?.copyWith(fontSize: sizeFor('bodyMedium'))
          : null,
      bodySmall: sizeFor('bodySmall') != null
          ? base.bodySmall?.copyWith(fontSize: sizeFor('bodySmall'))
          : null,
      titleSmall: sizeFor('titleSmall') != null
          ? base.titleSmall?.copyWith(fontSize: sizeFor('titleSmall'))
          : null,
      titleMedium: base.titleMedium?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.titleMediumIncrement,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.titleLargeIncrement,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.headlineSmallIncrement,
      ),
      labelSmall: sizeFor('labelSmall') != null
          ? base.labelSmall?.copyWith(fontSize: sizeFor('labelSmall'))
          : null,
      labelMedium: sizeFor('labelMedium') != null
          ? base.labelMedium?.copyWith(fontSize: sizeFor('labelMedium'))
          : null,
    );
  }

  double monoCaptionSizeFor(MeshTokens base) =>
      overrides.fontSizeOverrides['monoCaptionSize'] ?? base.monoCaptionSize;
  double monoBodySizeFor(MeshTokens base) =>
      overrides.fontSizeOverrides['monoBodySize'] ?? base.monoBodySize;

  // C3: Material widgets reading `Theme.of(context).colorScheme.*` (not
  // `MeshTokens.of(context)`) must also see the overridden accent — rebuild
  // both brightness variants' [ColorScheme] from the same tokens, mirroring
  // the field mapping in `mesh_theme.dart`'s `ColorScheme(...)` constructors
  // (verified 2026-08-04, decision C3). Fields absent from [MeshTokens]
  // (containers, `onX` contrast colors, shadow/scrim, …) are left untouched,
  // inherited from [defaultStyle].
  ColorScheme buildColorScheme(ColorScheme base, MeshTokens tokens) {
    return base.copyWith(
      primary: tokens.primary,
      secondary: tokens.secondary,
      tertiary: tokens.warn,
      error: tokens.alert,
      surface: tokens.bg,
      onSurface: tokens.ink,
      surfaceContainerLowest: tokens.bg,
      surfaceContainerLow: tokens.bg1,
      surfaceContainer: tokens.bg1,
      surfaceContainerHigh: tokens.bg2,
      surfaceContainerHighest: tokens.bg3,
      onSurfaceVariant: tokens.ink2,
      outline: tokens.line2,
      outlineVariant: tokens.line,
      inverseSurface: tokens.ink,
      onInverseSurface: tokens.bg,
      inversePrimary: tokens.primaryDim,
    );
  }

  // B4/C2: chrome sub-themes bake their `fontSize` from the role sizes at
  // ThemeData-construction time (mesh_theme.dart), so a role override (e.g.
  // dragging "Body") must re-derive these too, mirroring MeshTypeScale's
  // increments 1:1 — otherwise chrome would silently keep the default sizes.
  TextStyle? withFontSize(TextStyle? style, double fontSize) =>
      style?.copyWith(fontSize: fontSize);

  ThemeData applyChromeFontSizes(ThemeData base) {
    final text = base.textTheme;
    final bodyMediumSize = text.bodyMedium!.fontSize!;
    final bodySmallSize = text.bodySmall!.fontSize!;
    final titleSmallSize = text.titleSmall!.fontSize!;
    final buttonTextSize = bodyMediumSize + MeshTypeScale.buttonLabelIncrement;

    return base.copyWith(
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: withFontSize(
          base.listTileTheme.titleTextStyle,
          bodyMediumSize,
        ),
        subtitleTextStyle: withFontSize(
          base.listTileTheme.subtitleTextStyle,
          bodySmallSize,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: withFontSize(
          base.appBarTheme.titleTextStyle,
          titleSmallSize + MeshTypeScale.appBarTitleIncrement,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style?.copyWith(
          textStyle: WidgetStateProperty.resolveWith(
            (states) => withFontSize(
              base.elevatedButtonTheme.style?.textStyle?.resolve(states),
              buttonTextSize,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          textStyle: WidgetStateProperty.resolveWith(
            (states) => withFontSize(
              base.filledButtonTheme.style?.textStyle?.resolve(states),
              buttonTextSize,
            ),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: withFontSize(
          base.chipTheme.labelStyle,
          bodySmallSize + MeshTypeScale.chipLabelIncrement,
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => withFontSize(
            base.navigationBarTheme.labelTextStyle?.resolve(states),
            bodySmallSize + MeshTypeScale.navigationLabelIncrement,
          ),
        ),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: withFontSize(
          base.tabBarTheme.labelStyle,
          bodyMediumSize + MeshTypeScale.tabLabelIncrement,
        ),
        unselectedLabelStyle: withFontSize(
          base.tabBarTheme.unselectedLabelStyle,
          bodyMediumSize + MeshTypeScale.tabLabelIncrement,
        ),
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        textStyle: withFontSize(
          base.tooltipTheme.textStyle,
          bodySmallSize + MeshTypeScale.tooltipIncrement,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        valueIndicatorTextStyle: withFontSize(
          base.sliderTheme.valueIndicatorTextStyle,
          bodySmallSize + MeshTypeScale.sliderIndicatorIncrement,
        ),
      ),
    );
  }

  // Widget-themes that mesh_theme.dart bakes directly from the brightness's
  // surface color at ThemeData-construction time — `ThemeData.copyWith`
  // alone wouldn't refresh these, since they aren't looked up from
  // `colorScheme` lazily (checked 2026-08-04 against `mesh_theme.dart`).
  ThemeData applyColorSchemeAndChrome(ThemeData base, MeshTokens tokens) {
    final scheme = buildColorScheme(base.colorScheme, tokens);
    final withScheme = base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: base.listTileTheme.titleTextStyle?.copyWith(
          color: scheme.onSurface,
        ),
        subtitleTextStyle: base.listTileTheme.subtitleTextStyle?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    return applyChromeFontSizes(withScheme);
  }

  final darkTokens =
      applyColorOverrides(MeshTokens.defaultTokens, Brightness.dark).copyWith(
        monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokens),
        monoBodySize: monoBodySizeFor(MeshTokens.defaultTokens),
      );
  final lightTokens =
      applyColorOverrides(
        MeshTokens.defaultTokensLight,
        Brightness.light,
      ).copyWith(
        monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokensLight),
        monoBodySize: monoBodySizeFor(MeshTokens.defaultTokensLight),
      );

  return MeshStyle(
    id: 'custom',
    displayName: 'Custom',
    light: applyColorSchemeAndChrome(
      defaultStyle.light.copyWith(
        extensions: [lightTokens],
        textTheme: applyFontSizeOverrides(defaultStyle.light.textTheme),
      ),
      lightTokens,
    ),
    dark: applyColorSchemeAndChrome(
      defaultStyle.dark.copyWith(
        extensions: [darkTokens],
        textTheme: applyFontSizeOverrides(defaultStyle.dark.textTheme),
      ),
      darkTokens,
    ),
  );
}
