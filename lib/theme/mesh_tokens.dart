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
    required this.alertInk,
    required this.primary,
    required this.primaryDim,
    required this.primaryBg,
    required this.primaryLine,
    required this.secondary,
    required this.secondaryBg,
    required this.secondaryLine,
    required this.secondaryInk,
    required this.roomActive,
    required this.routeActive,
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
    required this.mapMarkerInk,
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
    required this.pill,
    required this.spacingXxs,
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXlg,
    required this.spacingXxlg,
    required this.spacingHairline,
    required this.monoCaptionSize,
    required this.monoBodySize,
    required this.microLabelSize,
    required this.labelSize,
    required this.bodySize,
    required this.titleSize,
    required this.cardElevated,
    required this.cardShadow,
    required this.bordersVisible,
    required this.buttonRadius,
    required this.avatarTint5,
    required this.avatarTint6,
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

  /// Text/icon color drawn on top of an [alert]-colored background (badges,
  /// pills) — mirrors [meInk]'s role for the "me" bubble.
  final Color alertInk;
  final Color primary;
  final Color primaryDim;
  final Color primaryBg;
  final Color primaryLine;
  final Color secondary;
  final Color secondaryBg;
  final Color secondaryLine;

  /// Text/icon color drawn on top of a [secondary]-colored background —
  /// mirrors [meInk]'s role for the "me" bubble.
  final Color secondaryInk;

  /// Fixed accent for the Contacts list Room type-pill — see [MeshPalette]
  /// (`mesh_theme.dart`) doc comment for why this is a separate, non-user-
  /// customizable token instead of [secondary]. Border + text render at full
  /// opacity; the badge's background fill is this color at 20% alpha,
  /// computed at the call site (no separate stored Bg/Ink token — 2026-08-19).
  final Color roomActive;

  /// Fixed accent for the Contacts list Route status-badge (active state) —
  /// see [MeshPalette] doc comment; distinct hue from [roomActive] so the
  /// two never collide again. Same border/text-full-opacity, 20%-alpha-fill
  /// treatment as [roomActive].
  final Color routeActive;
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

  /// Glyph/text color drawn on top of a colored map marker (cluster count,
  /// selection ring icon, hop/self/shared badges) — mirrors [meInk].
  final Color mapMarkerInk;

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
  final double pill;

  /// Spacing scale (gap/padding tokens) — names carry the `spacing` prefix
  /// to stay unambiguous next to the radius fields above (`xs/sm/...`),
  /// which use the same short suffixes for an unrelated scale.
  final double spacingXxs;
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXlg;
  final double spacingXxlg;

  /// Sub-[spacingXxs] gap (~1-2dp) used for hairline visual separation
  /// (map/LOS legend rows, status-dot alignment) — raising these to
  /// [spacingXxs] would visibly change tightly-packed rows, so they get
  /// their own bottom-of-scale token instead of snapping up.
  final double spacingHairline;

  /// Dominant `.mono(fontSize: ...)` size for secondary/muted mono text
  /// (metadata, badges) — see docs/superpowers/prompts/2026-08-02-custom-
  /// style-editor/01-font-role-infra.md.
  final double monoCaptionSize;

  /// Dominant `.mono(fontSize: ...)` size for primary-colored mono content.
  final double monoBodySize;

  /// Sans-serif micro-label size (chip/badge accent labels) — smallest step
  /// of the general (non-mono) type scale.
  final double microLabelSize;

  /// Sans-serif small-label/subtitle size — general (non-mono) type scale.
  final double labelSize;

  /// Sans-serif body-text size — general (non-mono) type scale.
  final double bodySize;

  /// Sans-serif title size (AppBar/dialog titles) — general (non-mono) type
  /// scale.
  final double titleSize;

  /// Whether MeshCard draws its floating shadow by default (issue #23).
  final bool cardElevated;

  /// Base shadow color for MeshCard's elevated `boxShadow` layers — call
  /// sites derive their own alpha per layer (see MeshCard).
  final Color cardShadow;

  /// Whether outline/border chrome shows across the whole app (Divider,
  /// TextField, Card, Chip, SnackBar, AppBar bottom line, Tooltip, button
  /// family) — derived in `buildCustomStyle` from
  /// `CustomStyleOverrides.borderOverride ?? !cardElevated`, computed once
  /// here so every consumer reads a single resolved value.
  final bool bordersVisible;

  /// Corner radius for the app-wide tinted buttons (Filled/Elevated/
  /// Outlined) — user-editable independently of [pill] via the Custom Style
  /// editor's Buttons section (2026-08-21).
  final double buttonRadius;

  /// Shared drop shadow for label chips (_ContactBadge, ContactTypeBadge,
  /// RouteChip, …) — THE single place that defines it. Follows the
  /// style-wide shadow switch ([cardElevated], the Custom Style "Card
  /// shadow" toggle): null when shadows are off. Calibrated for ~16dp-tall
  /// chips (the map markers' blur 8 would read as smear at this size).
  List<BoxShadow>? get labelShadow => cardElevated
      ? [
          BoxShadow(
            color: cardShadow.withValues(alpha: 0.22),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ]
      : null;

  /// 5th/6th hues in the deterministic avatar-tint palette (see
  /// `avatarTintPalette` in mesh_ui.dart) — the first four reuse
  /// [primary]/[secondary]/[signal]/[warn].
  final Color avatarTint5;
  final Color avatarTint6;

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
    alertInk: Color(0xFFFFFFFF),
    primary: MeshPalette.primary,
    primaryDim: MeshPalette.primaryDim,
    primaryBg: MeshPalette.primaryBg,
    primaryLine: MeshPalette.primaryLine,
    secondary: MeshPalette.secondary,
    secondaryBg: MeshPalette.secondaryBg,
    secondaryLine: MeshPalette.secondaryLine,
    secondaryInk: Color(0xFFFFFFFF),
    roomActive: MeshPalette.roomActive,
    routeActive: MeshPalette.routeActive,
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
    mapMarkerInk: Color(0xFFFFFFFF),
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
    pill: MeshRadii.pill,
    spacingXxs: 6,
    spacingXs: 16,
    spacingSm: 13,
    spacingMd: 14,
    spacingLg: 24,
    spacingXlg: 32,
    spacingXxlg: 48,
    spacingHairline: 2,
    monoCaptionSize: 11,
    monoBodySize: 11,
    microLabelSize: 9,
    labelSize: 12,
    bodySize: 14,
    titleSize: 16,
    cardElevated: true,
    cardShadow: Color(0xFF000000),
    bordersVisible: false,
    buttonRadius: MeshRadii.pill,
    avatarTint5: Color(0xFF8FA8F0),
    avatarTint6: Color(0xFF6FD9CE),
  );

  /// Light-variant base tokens for the custom style (pkt 17). Values borrowed
  /// from today's light `ColorScheme`/`MeshPalette.light*` as a starting
  /// point — the Default style itself is slated for removal, this is NOT a
  /// compatibility contract. Radii, mono sizes and all map*/los* colors are
  /// shared with [defaultTokens] (call sites branch on brightness themselves).
  static const MeshTokens defaultTokensLight = MeshTokens(
    bg: MeshPalette.lightBg,
    bg1: MeshPalette.lightBg1,
    bg2: MeshPalette.lightBg2,
    bg3: MeshPalette.lightBg3,
    bg4: MeshPalette.lightBg4,
    line: MeshPalette.lightLine1,
    line2: MeshPalette.lightLine2,
    line3: MeshPalette.lightLine3,
    ink: MeshPalette.lightInk,
    ink2: MeshPalette.lightInk2,
    ink3: MeshPalette.lightInk3,
    ink4: MeshPalette.lightInk4,
    signal: MeshPalette.lightSignal,
    signalDim: Color(0xFF0D873A), // = deriveSignalDim(lightSignal)
    warn: MeshPalette.lightWarn,
    warnDim: Color(0xFF884412), // = deriveWarnVariants(lightWarn).warnDim
    warnBg: Color(0x1F9A5B16),
    warnLine: Color(0x669A5B16),
    alert: MeshPalette.lightAlert,
    alertBg: Color(0x1FB53D2F),
    alertLine: Color(0x66B53D2F),
    alertInk: Color(0xFFFFFFFF),
    primary: MeshPalette.lightBlue,
    primaryDim: Color(
      0xFF21578E,
    ), // = derivePrimaryVariants(lightBlue).primaryDim
    primaryBg: Color(0x292F6EA8),
    primaryLine: Color(0x802F6EA8),
    secondary: MeshPalette.lightSecondary,
    secondaryBg: Color(0x1C4A730C),
    secondaryLine: Color(0x474A730C),
    secondaryInk: Color(0xFFFFFFFF),
    roomActive: MeshPalette.roomActive,
    routeActive: MeshPalette.routeActive,
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
    mapMarkerInk: Color(0xFFFFFFFF),
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
    pill: MeshRadii.pill,
    spacingXxs: 6,
    spacingXs: 16,
    spacingSm: 13,
    spacingMd: 14,
    spacingLg: 24,
    spacingXlg: 32,
    spacingXxlg: 48,
    spacingHairline: 2,
    monoCaptionSize: 11,
    monoBodySize: 11,
    microLabelSize: 9,
    labelSize: 12,
    bodySize: 14,
    titleSize: 16,
    cardElevated: true,
    cardShadow: Color(0xFF000000),
    bordersVisible: false,
    buttonRadius: MeshRadii.pill,
    avatarTint5: Color(0xFF8FA8F0),
    avatarTint6: Color(0xFF6FD9CE),
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
    Color? alertInk,
    Color? primary,
    Color? primaryDim,
    Color? primaryBg,
    Color? primaryLine,
    Color? secondary,
    Color? secondaryBg,
    Color? secondaryLine,
    Color? secondaryInk,
    Color? roomActive,
    Color? routeActive,
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
    Color? mapMarkerInk,
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
    double? pill,
    double? spacingXxs,
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXlg,
    double? spacingXxlg,
    double? spacingHairline,
    double? monoCaptionSize,
    double? monoBodySize,
    double? microLabelSize,
    double? labelSize,
    double? bodySize,
    double? titleSize,
    bool? cardElevated,
    Color? cardShadow,
    bool? bordersVisible,
    double? buttonRadius,
    Color? avatarTint5,
    Color? avatarTint6,
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
      alertInk: alertInk ?? this.alertInk,
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      primaryBg: primaryBg ?? this.primaryBg,
      primaryLine: primaryLine ?? this.primaryLine,
      secondary: secondary ?? this.secondary,
      secondaryBg: secondaryBg ?? this.secondaryBg,
      secondaryLine: secondaryLine ?? this.secondaryLine,
      secondaryInk: secondaryInk ?? this.secondaryInk,
      roomActive: roomActive ?? this.roomActive,
      routeActive: routeActive ?? this.routeActive,
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
      mapMarkerInk: mapMarkerInk ?? this.mapMarkerInk,
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
      pill: pill ?? this.pill,
      spacingXxs: spacingXxs ?? this.spacingXxs,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXlg: spacingXlg ?? this.spacingXlg,
      spacingXxlg: spacingXxlg ?? this.spacingXxlg,
      spacingHairline: spacingHairline ?? this.spacingHairline,
      monoCaptionSize: monoCaptionSize ?? this.monoCaptionSize,
      monoBodySize: monoBodySize ?? this.monoBodySize,
      microLabelSize: microLabelSize ?? this.microLabelSize,
      labelSize: labelSize ?? this.labelSize,
      bodySize: bodySize ?? this.bodySize,
      titleSize: titleSize ?? this.titleSize,
      cardElevated: cardElevated ?? this.cardElevated,
      cardShadow: cardShadow ?? this.cardShadow,
      bordersVisible: bordersVisible ?? this.bordersVisible,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      avatarTint5: avatarTint5 ?? this.avatarTint5,
      avatarTint6: avatarTint6 ?? this.avatarTint6,
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
