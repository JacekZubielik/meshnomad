import 'package:flutter/material.dart';

import 'mesh_theme.dart';

/// Style-specific design tokens not covered by [ColorScheme]: semantic
/// accent colors, the map/LOS palettes, corner radii, and font-derived text
/// helpers. Attached to [ThemeData.extensions] by each [MeshStyle]. Look up
/// with [MeshTokens.of].
class MeshTokens extends ThemeExtension<MeshTokens> {
  const MeshTokens({
    required this.bg,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.line,
    required this.line2,
    required this.line3,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.signal,
    required this.signalDim,
    required this.warn,
    required this.warnDim,
    required this.warnBg,
    required this.warnLine,
    required this.alert,
    required this.alertBg,
    required this.alertLine,
    required this.blue,
    required this.blueDim,
    required this.blueBg,
    required this.blueLine,
    required this.magenta,
    required this.magentaBg,
    required this.magentaLine,
    required this.me,
    required this.meBorder,
    required this.meInk,
    required this.mapOnline,
    required this.mapOffline,
    required this.mapStale,
    required this.mapRepeater,
    required this.mapRouter,
    required this.mapBatteryLow,
    required this.mapCluster,
    required this.mapSelected,
    required this.mapSensor,
    required this.mapShared,
    required this.mapPanelLight,
    required this.mapPanelDark,
    required this.mapTextPrimary,
    required this.mapTextSecondary,
    required this.mapTextMuted,
    required this.mapBorder,
    required this.mapMarkerOutline,
    required this.mapMarkerShadow,
    required this.losTerrain,
    required this.losBeam,
    required this.losHorizon,
    required this.losBlocked,
    required this.losMarginal,
    required this.losClear,
    required this.losSelected,
    required this.losChartBackground,
    required this.losPanelDark,
    required this.losPanelLight,
    required this.losText,
    required this.losTextMuted,
    required this.losBorder,
    required this.losShadow,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
    required this.monoCaptionSize,
    required this.monoBodySize,
  });

  final Color bg;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color bg4;
  final Color line;
  final Color line2;
  final Color line3;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color signal;
  final Color signalDim;
  final Color warn;
  final Color warnDim;
  final Color warnBg;
  final Color warnLine;
  final Color alert;
  final Color alertBg;
  final Color alertLine;
  final Color blue;
  final Color blueDim;
  final Color blueBg;
  final Color blueLine;
  final Color magenta;
  final Color magentaBg;
  final Color magentaLine;
  final Color me;
  final Color meBorder;
  final Color meInk;

  final Color mapOnline;
  final Color mapOffline;
  final Color mapStale;
  final Color mapRepeater;
  final Color mapRouter;
  final Color mapBatteryLow;
  final Color mapCluster;
  final Color mapSelected;
  final Color mapSensor;
  final Color mapShared;
  final Color mapPanelLight;
  final Color mapPanelDark;
  final Color mapTextPrimary;
  final Color mapTextSecondary;
  final Color mapTextMuted;
  final Color mapBorder;
  final Color mapMarkerOutline;
  final Color mapMarkerShadow;

  final Color losTerrain;
  final Color losBeam;
  final Color losHorizon;
  final Color losBlocked;
  final Color losMarginal;
  final Color losClear;
  final Color losSelected;
  final Color losChartBackground;
  final Color losPanelDark;
  final Color losPanelLight;
  final Color losText;
  final Color losTextMuted;
  final Color losBorder;
  final Color losShadow;

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  /// Dominant `.mono(fontSize: ...)` size for secondary/muted mono text
  /// (metadata, badges) — see docs/superpowers/prompts/2026-08-02-custom-
  /// style-editor/01-font-role-infra.md.
  final double monoCaptionSize;

  /// Dominant `.mono(fontSize: ...)` size for primary-colored mono content.
  final double monoBodySize;

  /// The default style's tokens — identical values to today's
  /// [MeshPalette]/[MapPalette]/[LosPalette]/[MeshRadii]. The same instance
  /// is used for both light and dark [ThemeData] since none of these values
  /// are brightness-dependent today (call sites needing brightness-aware
  /// colors already branch on [Theme.of(context).brightness] themselves,
  /// e.g. choosing [mapPanelLight] vs [mapPanelDark] explicitly).
  static const MeshTokens defaultTokens = MeshTokens(
    bg: MeshPalette.bg,
    bg1: MeshPalette.bg1,
    bg2: MeshPalette.bg2,
    bg3: MeshPalette.bg3,
    bg4: MeshPalette.bg4,
    line: MeshPalette.line,
    line2: MeshPalette.line2,
    line3: MeshPalette.line3,
    ink: MeshPalette.ink,
    ink2: MeshPalette.ink2,
    ink3: MeshPalette.ink3,
    ink4: MeshPalette.ink4,
    signal: MeshPalette.signal,
    signalDim: MeshPalette.signalDim,
    warn: MeshPalette.warn,
    warnDim: MeshPalette.warnDim,
    warnBg: MeshPalette.warnBg,
    warnLine: MeshPalette.warnLine,
    alert: MeshPalette.alert,
    alertBg: MeshPalette.alertBg,
    alertLine: MeshPalette.alertLine,
    blue: MeshPalette.blue,
    blueDim: MeshPalette.blueDim,
    blueBg: MeshPalette.blueBg,
    blueLine: MeshPalette.blueLine,
    magenta: MeshPalette.magenta,
    magentaBg: MeshPalette.magentaBg,
    magentaLine: MeshPalette.magentaLine,
    me: MeshPalette.me,
    meBorder: MeshPalette.meBorder,
    meInk: MeshPalette.meInk,
    mapOnline: MapPalette.online,
    mapOffline: MapPalette.offline,
    mapStale: MapPalette.stale,
    mapRepeater: MapPalette.repeater,
    mapRouter: MapPalette.router,
    mapBatteryLow: MapPalette.batteryLow,
    mapCluster: MapPalette.cluster,
    mapSelected: MapPalette.selected,
    mapSensor: MapPalette.sensor,
    mapShared: MapPalette.shared,
    mapPanelLight: MapPalette.panelLight,
    mapPanelDark: MapPalette.panelDark,
    mapTextPrimary: MapPalette.textPrimary,
    mapTextSecondary: MapPalette.textSecondary,
    mapTextMuted: MapPalette.textMuted,
    mapBorder: MapPalette.border,
    mapMarkerOutline: MapPalette.markerOutline,
    mapMarkerShadow: MapPalette.markerShadow,
    losTerrain: LosPalette.terrain,
    losBeam: LosPalette.beam,
    losHorizon: LosPalette.horizon,
    losBlocked: LosPalette.blocked,
    losMarginal: LosPalette.marginal,
    losClear: LosPalette.clear,
    losSelected: LosPalette.selected,
    losChartBackground: LosPalette.chartBackground,
    losPanelDark: LosPalette.panelDark,
    losPanelLight: LosPalette.panelLight,
    losText: LosPalette.text,
    losTextMuted: LosPalette.textMuted,
    losBorder: LosPalette.border,
    losShadow: LosPalette.shadow,
    xs: MeshRadii.xs,
    sm: MeshRadii.sm,
    md: MeshRadii.md,
    lg: MeshRadii.lg,
    xl: MeshRadii.xl,
    pill: MeshRadii.pill,
    monoCaptionSize: 11,
    monoBodySize: 13,
  );

  static MeshTokens of(BuildContext context) {
    return Theme.of(context).extension<MeshTokens>()!;
  }

  /// Mono text style — mirrors the pre-migration `MeshTheme.mono`.
  TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: MeshFonts.mono,
      fontFamilyFallback: MeshFonts.monoFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Mono text style at [monoCaptionSize] — secondary/muted mono content.
  TextStyle monoCaption({Color? color, double? letterSpacing}) {
    return TextStyle(
      fontFamily: MeshFonts.mono,
      fontFamilyFallback: MeshFonts.monoFallback,
      fontSize: monoCaptionSize,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Mono text style at [monoBodySize] — primary-colored mono content.
  TextStyle monoBody({
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: MeshFonts.mono,
      fontFamilyFallback: MeshFonts.monoFallback,
      fontSize: monoBodySize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Serif display style — mirrors the pre-migration `MeshTheme.display`.
  TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: MeshFonts.display,
      fontFamilyFallback: MeshFonts.displayFallback,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      letterSpacing: letterSpacing ?? -0.2,
    );
  }

  /// Section-accent / chip label style — mirrors the pre-migration
  /// `MeshTheme.accentLabel`.
  TextStyle accentLabel({Color? color, double? fontSize}) {
    return TextStyle(
      fontFamily: MeshFonts.sans,
      fontFamilyFallback: MeshFonts.sansFallback,
      fontSize: fontSize ?? 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );
  }

  /// Color-emoji style — mirrors the pre-migration `MeshTheme.emoji`.
  TextStyle emoji({double fontSize = 28}) {
    return TextStyle(
      fontFamily: MeshFonts.emoji,
      fontFamilyFallback: MeshFonts.emojiFallback,
      fontSize: fontSize,
      height: 1,
    );
  }

  /// Color-codes an SNR value — mirrors the pre-migration
  /// `MeshTheme.snrColor`.
  Color snrColor(num? snr, {required bool blocked}) {
    if (blocked) return alert;
    if (snr == null) return ink3;
    if (snr > -5) return signal;
    if (snr > -12) return warn;
    return alert;
  }

  @override
  MeshTokens copyWith({
    Color? bg,
    Color? bg1,
    Color? bg2,
    Color? bg3,
    Color? bg4,
    Color? line,
    Color? line2,
    Color? line3,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? signal,
    Color? signalDim,
    Color? warn,
    Color? warnDim,
    Color? warnBg,
    Color? warnLine,
    Color? alert,
    Color? alertBg,
    Color? alertLine,
    Color? blue,
    Color? blueDim,
    Color? blueBg,
    Color? blueLine,
    Color? magenta,
    Color? magentaBg,
    Color? magentaLine,
    Color? me,
    Color? meBorder,
    Color? meInk,
    Color? mapOnline,
    Color? mapOffline,
    Color? mapStale,
    Color? mapRepeater,
    Color? mapRouter,
    Color? mapBatteryLow,
    Color? mapCluster,
    Color? mapSelected,
    Color? mapSensor,
    Color? mapShared,
    Color? mapPanelLight,
    Color? mapPanelDark,
    Color? mapTextPrimary,
    Color? mapTextSecondary,
    Color? mapTextMuted,
    Color? mapBorder,
    Color? mapMarkerOutline,
    Color? mapMarkerShadow,
    Color? losTerrain,
    Color? losBeam,
    Color? losHorizon,
    Color? losBlocked,
    Color? losMarginal,
    Color? losClear,
    Color? losSelected,
    Color? losChartBackground,
    Color? losPanelDark,
    Color? losPanelLight,
    Color? losText,
    Color? losTextMuted,
    Color? losBorder,
    Color? losShadow,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? pill,
    double? monoCaptionSize,
    double? monoBodySize,
  }) {
    return MeshTokens(
      bg: bg ?? this.bg,
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      bg4: bg4 ?? this.bg4,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      line3: line3 ?? this.line3,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      signal: signal ?? this.signal,
      signalDim: signalDim ?? this.signalDim,
      warn: warn ?? this.warn,
      warnDim: warnDim ?? this.warnDim,
      warnBg: warnBg ?? this.warnBg,
      warnLine: warnLine ?? this.warnLine,
      alert: alert ?? this.alert,
      alertBg: alertBg ?? this.alertBg,
      alertLine: alertLine ?? this.alertLine,
      blue: blue ?? this.blue,
      blueDim: blueDim ?? this.blueDim,
      blueBg: blueBg ?? this.blueBg,
      blueLine: blueLine ?? this.blueLine,
      magenta: magenta ?? this.magenta,
      magentaBg: magentaBg ?? this.magentaBg,
      magentaLine: magentaLine ?? this.magentaLine,
      me: me ?? this.me,
      meBorder: meBorder ?? this.meBorder,
      meInk: meInk ?? this.meInk,
      mapOnline: mapOnline ?? this.mapOnline,
      mapOffline: mapOffline ?? this.mapOffline,
      mapStale: mapStale ?? this.mapStale,
      mapRepeater: mapRepeater ?? this.mapRepeater,
      mapRouter: mapRouter ?? this.mapRouter,
      mapBatteryLow: mapBatteryLow ?? this.mapBatteryLow,
      mapCluster: mapCluster ?? this.mapCluster,
      mapSelected: mapSelected ?? this.mapSelected,
      mapSensor: mapSensor ?? this.mapSensor,
      mapShared: mapShared ?? this.mapShared,
      mapPanelLight: mapPanelLight ?? this.mapPanelLight,
      mapPanelDark: mapPanelDark ?? this.mapPanelDark,
      mapTextPrimary: mapTextPrimary ?? this.mapTextPrimary,
      mapTextSecondary: mapTextSecondary ?? this.mapTextSecondary,
      mapTextMuted: mapTextMuted ?? this.mapTextMuted,
      mapBorder: mapBorder ?? this.mapBorder,
      mapMarkerOutline: mapMarkerOutline ?? this.mapMarkerOutline,
      mapMarkerShadow: mapMarkerShadow ?? this.mapMarkerShadow,
      losTerrain: losTerrain ?? this.losTerrain,
      losBeam: losBeam ?? this.losBeam,
      losHorizon: losHorizon ?? this.losHorizon,
      losBlocked: losBlocked ?? this.losBlocked,
      losMarginal: losMarginal ?? this.losMarginal,
      losClear: losClear ?? this.losClear,
      losSelected: losSelected ?? this.losSelected,
      losChartBackground: losChartBackground ?? this.losChartBackground,
      losPanelDark: losPanelDark ?? this.losPanelDark,
      losPanelLight: losPanelLight ?? this.losPanelLight,
      losText: losText ?? this.losText,
      losTextMuted: losTextMuted ?? this.losTextMuted,
      losBorder: losBorder ?? this.losBorder,
      losShadow: losShadow ?? this.losShadow,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
      monoCaptionSize: monoCaptionSize ?? this.monoCaptionSize,
      monoBodySize: monoBodySize ?? this.monoBodySize,
    );
  }

  @override
  MeshTokens lerp(ThemeExtension<MeshTokens>? other, double t) {
    // Styles switch discretely (user picks one), never animate between two
    // token sets — a step function at the midpoint is correct here.
    if (other is! MeshTokens) return this;
    return t < 0.5 ? this : other;
  }
}
