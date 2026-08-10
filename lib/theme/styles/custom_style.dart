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
      // LOS palette (14 tokens) — every one stays user-editable in the LOS
      // editor section, but its DEFAULT now derives from the active scheme
      // instead of a fixed dark palette, so the Line-of-sight screen follows
      // the custom theme out of the box (user decision 2026-08-10).
      //   chrome  → surface/ink/line layers (panels, text, borders, chart bg)
      //   status  → accent tokens (blocked=alert, clear=signal, marginal=warn,
      //             selected=primary) — semantically correct AND bit-for-bit
      //             identical to the old fixed defaults.
      //   terrain/beam/horizon → distinct data hues with no theme equivalent;
      //             derived off warn/primary but still overridable per taste.
      losTerrain: baseColorFor('losTerrain', signal),
      losBeam: baseColorFor('losBeam', primary),
      losHorizon: baseColorFor('losHorizon', warn),
      losBlocked: baseColorFor('losBlocked', alert),
      losMarginal: baseColorFor('losMarginal', warn),
      losClear: baseColorFor('losClear', signal),
      losSelected: baseColorFor('losSelected', primary),
      losChartBackground: baseColorFor('losChartBackground', bg),
      losPanelDark: baseColorFor(
        'losPanelDark',
        bgLayers.bg1.withValues(alpha: 0xF0 / 0xFF),
      ),
      losPanelLight: baseColorFor('losPanelLight', base.losPanelLight),
      losText: baseColorFor('losText', ink),
      losTextMuted: baseColorFor('losTextMuted', inkLayers.ink2),
      losBorder: baseColorFor(
        'losBorder',
        lineLayers.line2.withValues(alpha: 0x52 / 0xFF),
      ),
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

  double spacingFor(String key, double base) =>
      overrides.spacingOverrides[key] ?? base;

  double radiusFor(String key, double base) =>
      overrides.radiusOverrides[key] ?? base;

  // Accent that steps aside for the disabled state, so M3's own
  // disabled styling (onSurface @ 12%/38%) keeps applying.
  WidgetStateProperty<Color?> accentUnlessDisabled(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : color,
      );

  // Container tint derived from an overridden accent over the custom
  // surface; keeps the hand-picked default container when neither the
  // accent nor the surface changed (bit-for-bit parity with defaultStyle).
  bool containerUntouched(
    Color accent,
    Color baseAccent,
    MeshTokens tokens,
    ColorScheme base,
  ) => accent == baseAccent && tokens.bg1 == base.surfaceContainerLow;

  Color containerFor(
    Color accent,
    Color baseAccent,
    Color baseContainer,
    MeshTokens tokens,
    ColorScheme base,
  ) => containerUntouched(accent, baseAccent, tokens, base)
      ? baseContainer
      : Color.alphaBlend(accent.withValues(alpha: 0.30), tokens.bg1);

  Color onContainerFor(
    Color accent,
    Color baseAccent,
    Color baseOnContainer,
    MeshTokens tokens,
    ColorScheme base,
  ) => containerUntouched(accent, baseAccent, tokens, base)
      ? baseOnContainer
      : tokens.ink;

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
      // Containers were originally left inherited (C3) — but sheets/dialogs
      // (e.g. the path editor) paint primary/secondaryContainer surfaces, so
      // an inherited default-blue container ignores the user's accents
      // (reported live 2026-08-10). Derive them as an accent tint over the
      // custom surface — but ONLY once the accent (or surface) actually
      // changed, so an empty overrides set stays bit-for-bit identical to
      // the default scheme (variant-automat parity test).
      primaryContainer: containerFor(
        tokens.primary,
        base.primary,
        base.primaryContainer,
        tokens,
        base,
      ),
      onPrimaryContainer: onContainerFor(
        tokens.primary,
        base.primary,
        base.onPrimaryContainer,
        tokens,
        base,
      ),
      secondaryContainer: containerFor(
        tokens.secondary,
        base.secondary,
        base.secondaryContainer,
        tokens,
        base,
      ),
      onSecondaryContainer: onContainerFor(
        tokens.secondary,
        base.secondary,
        base.onSecondaryContainer,
        tokens,
        base,
      ),
      tertiaryContainer: containerFor(
        tokens.warn,
        base.tertiary,
        base.tertiaryContainer,
        tokens,
        base,
      ),
      onTertiaryContainer: onContainerFor(
        tokens.warn,
        base.tertiary,
        base.onTertiaryContainer,
        tokens,
        base,
      ),
      errorContainer: containerFor(
        tokens.alert,
        base.error,
        base.errorContainer,
        tokens,
        base,
      ),
      onErrorContainer: onContainerFor(
        tokens.alert,
        base.error,
        base.onErrorContainer,
        tokens,
        base,
      ),
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

  // Chrome sub-themes bake their corner radii from MeshRadii at
  // ThemeData-construction time (mesh_theme.dart) — a radius override must
  // re-derive these too, mirroring applyChromeFontSizes 1:1.
  ThemeData applyChromeRadii(ThemeData base, MeshTokens t) {
    RoundedRectangleBorder rrb(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    OutlineInputBorder? oib(InputBorder? b, double r) => b is OutlineInputBorder
        ? b.copyWith(borderRadius: BorderRadius.circular(r))
        : null;
    final input = base.inputDecorationTheme;
    return base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        shape: base.cardTheme.shape is RoundedRectangleBorder
            ? (base.cardTheme.shape! as RoundedRectangleBorder).copyWith(
                borderRadius: BorderRadius.circular(t.md),
              )
            : rrb(t.md),
      ),
      inputDecorationTheme: input.copyWith(
        border: oib(input.border, t.md),
        enabledBorder: oib(input.enabledBorder, t.md),
        focusedBorder: oib(input.focusedBorder, t.md),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorShape: rrb(t.md),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(shape: rrb(t.md)),
      popupMenuTheme: base.popupMenuTheme.copyWith(shape: rrb(t.md)),
      dialogTheme: base.dialogTheme.copyWith(shape: rrb(t.lg)),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.lg)),
        ),
      ),
      // pill-based shapes (FAB, buttons, chips) intentionally untouched —
      // pill is not editable, so their baked MeshRadii.pill stays correct.
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
      // Popup/overlay chrome bakes its backgrounds from the scheme at
      // ThemeData-construction time (mesh_theme.dart) — without re-deriving
      // them here, dialogs/sheets/snackbars/menus keep the DEFAULT style's
      // surfaces while their content follows the overridden scheme (reported
      // live 2026-08-10: navy popups with a gray chart on a custom gray bg).
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: base.snackBarTheme.contentTextStyle?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: scheme.surfaceContainerHigh,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: base.chipTheme.labelStyle?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: base.iconTheme.copyWith(color: scheme.onSurfaceVariant),
      // Input/select chrome bakes its colors the same way (fill, hint,
      // switch thumb/track, segmented selection) — reported live 2026-08-10:
      // fields kept the DEFAULT dark palette after switching Custom to light.
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      // Button-family accents bake scheme.primary at ThemeData construction
      // (FAB, filled/elevated/text buttons, progress) — third instance of the
      // baked-chrome class (after popups and inputs), reported live
      // 2026-08-10: default-blue buttons on a custom orange accent.
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surfaceContainerLow,
        shape: base.cardTheme.shape is RoundedRectangleBorder
            ? (base.cardTheme.shape! as RoundedRectangleBorder).copyWith(
                side: BorderSide(color: scheme.outlineVariant),
              )
            : base.cardTheme.shape,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.surfaceContainerHighest,
        valueIndicatorTextStyle: base.sliderTheme.valueIndicatorTextStyle
            ?.copyWith(color: scheme.onSurface),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: scheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: accentUnlessDisabled(scheme.primary),
          foregroundColor: accentUnlessDisabled(scheme.onPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: accentUnlessDisabled(scheme.primary),
          foregroundColor: accentUnlessDisabled(scheme.onPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: accentUnlessDisabled(scheme.primary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: accentUnlessDisabled(scheme.onSurface),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: (base.segmentedButtonTheme.style ?? const ButtonStyle())
            .copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? scheme.primary.withValues(alpha: 0.16)
                    : null,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.onSurface,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: scheme.outlineVariant),
              ),
            ),
      ),
    );
    return applyChromeRadii(applyChromeFontSizes(withScheme), tokens);
  }

  final darkTokens =
      applyColorOverrides(MeshTokens.defaultTokens, Brightness.dark).copyWith(
        monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokens),
        monoBodySize: monoBodySizeFor(MeshTokens.defaultTokens),
        spacingXxs: spacingFor(
          'spacingXxs',
          MeshTokens.defaultTokens.spacingXxs,
        ),
        spacingXs: spacingFor('spacingXs', MeshTokens.defaultTokens.spacingXs),
        spacingSm: spacingFor('spacingSm', MeshTokens.defaultTokens.spacingSm),
        spacingMd: spacingFor('spacingMd', MeshTokens.defaultTokens.spacingMd),
        spacingLg: spacingFor('spacingLg', MeshTokens.defaultTokens.spacingLg),
        spacingXlg: spacingFor(
          'spacingXlg',
          MeshTokens.defaultTokens.spacingXlg,
        ),
        spacingXxlg: spacingFor(
          'spacingXxlg',
          MeshTokens.defaultTokens.spacingXxlg,
        ),
        xs: radiusFor('xs', MeshTokens.defaultTokens.xs),
        sm: radiusFor('sm', MeshTokens.defaultTokens.sm),
        md: radiusFor('md', MeshTokens.defaultTokens.md),
        lg: radiusFor('lg', MeshTokens.defaultTokens.lg),
        xl: radiusFor('xl', MeshTokens.defaultTokens.xl),
        cardElevated: overrides.cardElevated ?? true,
      );
  final lightTokens =
      applyColorOverrides(
        MeshTokens.defaultTokensLight,
        Brightness.light,
      ).copyWith(
        monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokensLight),
        monoBodySize: monoBodySizeFor(MeshTokens.defaultTokensLight),
        spacingXxs: spacingFor(
          'spacingXxs',
          MeshTokens.defaultTokensLight.spacingXxs,
        ),
        spacingXs: spacingFor(
          'spacingXs',
          MeshTokens.defaultTokensLight.spacingXs,
        ),
        spacingSm: spacingFor(
          'spacingSm',
          MeshTokens.defaultTokensLight.spacingSm,
        ),
        spacingMd: spacingFor(
          'spacingMd',
          MeshTokens.defaultTokensLight.spacingMd,
        ),
        spacingLg: spacingFor(
          'spacingLg',
          MeshTokens.defaultTokensLight.spacingLg,
        ),
        spacingXlg: spacingFor(
          'spacingXlg',
          MeshTokens.defaultTokensLight.spacingXlg,
        ),
        spacingXxlg: spacingFor(
          'spacingXxlg',
          MeshTokens.defaultTokensLight.spacingXxlg,
        ),
        xs: radiusFor('xs', MeshTokens.defaultTokensLight.xs),
        sm: radiusFor('sm', MeshTokens.defaultTokensLight.sm),
        md: radiusFor('md', MeshTokens.defaultTokensLight.md),
        lg: radiusFor('lg', MeshTokens.defaultTokensLight.lg),
        xl: radiusFor('xl', MeshTokens.defaultTokensLight.xl),
        cardElevated: overrides.cardElevated ?? true,
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
