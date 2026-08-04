import 'package:flutter/material.dart';

import '../../models/custom_style_overrides.dart';
import '../mesh_derived.dart';
import '../mesh_tokens.dart';
import '../style.dart';
import 'default_style.dart';

/// Builds the "custom" [MeshStyle] by layering [overrides] on top of
/// [defaultStyle]'s exact values. Absent keys, or keys with no known
/// matching field, silently fall back to the default value — never throws.
MeshStyle buildCustomStyle(CustomStyleOverrides overrides) {
  MeshTokens applyColorOverrides(MeshTokens base) {
    int? colorFor(String key) => overrides.colorOverrides[key];
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

    final bgLayers = deriveBgLayers(bg);
    final inkLayers = deriveInkLayers(ink);
    final lineLayers = deriveLineLayers(line);
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
    );
  }

  TextTheme applyFontSizeOverrides(TextTheme base) {
    double? sizeFor(String key) => overrides.fontSizeOverrides[key];

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

  // Widget-themes that mesh_theme.dart bakes directly from the brightness's
  // surface color at ThemeData-construction time — `ThemeData.copyWith`
  // alone wouldn't refresh these, since they aren't looked up from
  // `colorScheme` lazily (checked 2026-08-04 against `mesh_theme.dart`).
  ThemeData applyColorSchemeAndChrome(ThemeData base, MeshTokens tokens) {
    final scheme = buildColorScheme(base.colorScheme, tokens);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
    );
  }

  // MeshTokens.defaultTokens is shared between light/dark (see comment on
  // that field) — still true after 01-font-role-infra.md, so one override
  // pass covers both brightness variants.
  final tokens = applyColorOverrides(MeshTokens.defaultTokens).copyWith(
    monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokens),
    monoBodySize: monoBodySizeFor(MeshTokens.defaultTokens),
  );

  return MeshStyle(
    id: 'custom',
    displayName: 'Custom',
    light: applyColorSchemeAndChrome(
      defaultStyle.light.copyWith(
        extensions: [tokens],
        textTheme: applyFontSizeOverrides(defaultStyle.light.textTheme),
      ),
      tokens,
    ),
    dark: applyColorSchemeAndChrome(
      defaultStyle.dark.copyWith(
        extensions: [tokens],
        textTheme: applyFontSizeOverrides(defaultStyle.dark.textTheme),
      ),
      tokens,
    ),
  );
}
