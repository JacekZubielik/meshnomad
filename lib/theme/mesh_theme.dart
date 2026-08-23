import 'package:flutter/material.dart';

/// MeshCore palette — high-contrast slate surfaces with sky-primary accents.
class MeshPalette {
  MeshPalette._();

  // Surfaces shared with the map overlays and navigation.
  static const bg = Color(0xFF0B1220);
  static const bg1 = Color(0xFF0F172A);
  static const bg2 = Color(0xFF162033);
  static const bg3 = Color(0xFF1E293B);
  static const bg4 = Color(0xFF334155);

  // Lines — lifted for clearer element separation on the near-black surface
  static const line = Color(0xFF2A3850);
  static const line2 = Color(0xFF3B4A61);
  static const line3 = Color(0xFF546376);

  // Ink — muted tones brightened for readable secondary/tertiary text in dark
  static const ink = Color(0xFFF8FAFC);
  static const ink2 = Color(0xFFD5DEE9);
  static const ink3 = Color(0xFFAAB6C6);
  static const ink4 = Color(0xFF828FA3);

  // Signal-quality green (used only for SNR coloring, not UI chrome)
  static const signal = Color(0xFF22C55E);
  static const signalDim = Color(0xFF16A34A);

  // Warn
  static const warn = Color(0xFFF59E0B);
  static const warnDim = Color(0xFFD97706);
  static const warnBg = Color(0x1FF59E0B);
  static const warnLine = Color(0x66F59E0B);

  // Alert
  static const alert = Color(0xFFEF4444);
  static const alertBg = Color(0x1FEF4444);
  static const alertLine = Color(0x66EF4444);

  // Blue — primary map/app accent
  static const primary = Color(0xFF0EA5E9);
  static const primaryDim = Color(0xFF0284C7);
  static const primaryBg = Color(0x290EA5E9);
  static const primaryLine = Color(0x800EA5E9);

  // Olive green (2026-08-18 operator pick, ~25% HSL lightness)
  static const secondary = Color(0xFF4A730C);
  static const secondaryBg = Color(0x1C4A730C);
  static const secondaryLine = Color(0x474A730C);

  // Fixed (non-user-customizable) accents for the Contacts list — same
  // architectural treatment as mapSensor/mapOnline below: technically routed
  // through custom_style.dart's baseColorFor() for consistency, but no style
  // profile sets an override key for these today, so they render identically
  // regardless of the user's chosen Custom Style. Distinct from `secondary`
  // (used by the Repeater/Room/Sensor/Chat type system before this token
  // existed) and from `signal` (telemetry family) — 2026-08-19 design
  // session, resolving a live color collision between the Room type-pill and
  // the Route status-badge, both of which used to share `secondary`. Border
  // and text render at full opacity; the 20%-alpha background fill is
  // computed at the call site via .withValues(alpha: 0.2), not stored here.
  static const roomActive = Color(0xFF10B981);
  static const routeActive = Color(0xFF84CC16);

  // Me bubble (dusk primary)
  static const me = Color(0xFF0C4A6E);
  static const meBorder = Color(0xFF0369A1);
  static const meInk = Color(0xFFF0F9FF);

  // ── Light variant (used when user explicitly picks light theme)
  static const lightBg = Color(0xFFF4F6F8);
  static const lightBg1 = Color(0xFFEAEEF2);
  static const lightBg2 = Color(0xFFDFE5EA);
  static const lightLine = Color(0xFFC3CCD4);
  static const lightInk = Color(0xFF10161B);
  static const lightInk2 = Color(0xFF3C4853);
  static const lightInk3 = Color(0xFF69767F);
  static const lightBlue = Color(0xFF2F6EA8);

  // Pełna jasna baza pod defaultTokensLight (pkt 17). Wartości bg3/ink4/line3
  // ekstrapolowane z istniejących ramp; secondary/warn/alert przeniesione
  // z ColorScheme.light() (mesh_theme.dart); signal = dotychczasowy signalDim.
  // To TYMCZASOWY punkt startowy pod przyszłe zestawy pastelowe — nie kanon.
  static const lightLine1 = Color(0xFFD8DEE5);
  static const lightLine2 = Color(0xFFC3CCD4);
  static const lightLine3 = Color(0xFFB1BCC4);
  static const lightBg3 = Color(0xFFD2DAE1);
  static const lightBg4 = Color(0xFFC6CFD8);
  static const lightInk4 = Color(0xFFB8BDC0);
  static const lightSecondary = Color(0xFF4A730C);
  static const lightWarn = Color(0xFF9A5B16);
  static const lightAlert = Color(0xFFB53D2F);
  static const lightSignal = Color(0xFF16A34A);
}

/// High-contrast semantic colors for UI rendered over variable map tiles.
class MapPalette {
  MapPalette._();

  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF6B7280);
  static const stale = Color(0xFFF59E0B);
  static const repeater = Color(0xFF2563EB);
  static const router = Color(0xFF7C3AED);
  static const batteryLow = Color(0xFFEF4444);
  static const cluster = Color(0xFFF97316);
  static const selected = Color(0xFF0EA5E9);
  static const sensor = Color(0xFF0F766E);
  static const shared = Color(0xFF0369A1);

  static const panelLight = Color(0xF0FFFFFF);
  static const panelDark = Color(0xF50B1220);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFCBD5E1);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0x5264758B);
  static const markerOutline = Colors.white;
  static const markerShadow = Color(0xB3000000);
}

/// High-contrast colors for line-of-sight maps and elevation profiles.
class LosPalette {
  LosPalette._();

  static const terrain = Color(0xFFA3E635);
  static const beam = Color(0xFF38BDF8);
  static const horizon = Color(0xFFFBBF24);
  static const blocked = Color(0xFFEF4444);
  static const marginal = Color(0xFFF59E0B);
  static const clear = Color(0xFF22C55E);
  static const selected = Color(0xFF0EA5E9);
  static const chartBackground = Color(0xFF0B1220);
  static const panelDark = Color(0xF00F172A);
  static const panelLight = Color(0xF5FFFFFF);
  static const text = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFFCBD5E1);
  static const border = Color(0x5264758B);
  static const shadow = Color(0x99000000);
}

/// Named font stacks — Flutter falls back to system fonts when the named
/// family isn't installed, keeping things working without bundled assets.
class MeshFonts {
  MeshFonts._();

  static const sans = 'Inter';
  static const mono = 'JetBrains Mono';
  static const display = 'Instrument Serif';
  static const emoji = 'Noto Color Emoji';

  static const List<String> sansFallback = [
    'system-ui',
    '-apple-system',
    'Roboto',
    'Noto Sans',
    'sans-serif',
  ];
  static const List<String> monoFallback = [
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];
  static const List<String> displayFallback = [
    'Cormorant Garamond',
    'Georgia',
    'Times New Roman',
    'serif',
  ];
  static const List<String> emojiFallback = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Emoji',
  ];
}

/// Fixed pt increments deriving "chrome" text sizes from the editable
/// `TextTheme` roles (`bodyMedium`, `bodySmall`, `titleSmall`), so overriding
/// a role in the custom style editor also resizes the widgets that read
/// these increments (B3/B4/C2, 2026-08-04) — matched to today's literal
/// `fontSize:` values in [MeshTheme._build] at the roles' defaults
/// (bodyMedium=13, bodySmall=11, titleSmall=10), see `03-roles-chrome.md`.
class MeshTypeScale {
  MeshTypeScale._();

  /// `titleMedium` = `titleSmall` + this (default 13+3=16, matches stock M3).
  static const double titleMediumIncrement = 3;

  /// `titleLarge` = `titleSmall` + this (default 13+9=22, matches stock M3).
  static const double titleLargeIncrement = 9;

  /// `headlineSmall` = `titleSmall` + this (default 13+11=24, stock M3).
  static const double headlineSmallIncrement = 11;

  /// AppBar title = `titleSmall` + this (default 13+7=20).
  static const double appBarTitleIncrement = 7;

  /// Elevated/filled button label = `bodyMedium` + this (default 12+2=14).
  static const double buttonLabelIncrement = 2;

  /// Chip label = `bodySmall` + this (default 11+1.5=12.5).
  static const double chipLabelIncrement = 1.5;

  /// NavigationBar label = `bodySmall` + this (default 11+0.5=11.5).
  static const double navigationLabelIncrement = 0.5;

  /// TabBar label (selected + unselected) = `bodyMedium` + this
  /// (default 12+1.5=13.5).
  static const double tabLabelIncrement = 1.5;

  /// Tooltip text = `bodySmall` + this (default 11+1=12).
  static const double tooltipIncrement = 1;

  /// Slider value-indicator text = `bodySmall` + this (default 11+1=12).
  static const double sliderIndicatorIncrement = 1;
}

/// Radii used consistently across the app.
class MeshRadii {
  MeshRadii._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const pill = 999.0;
}

/// Shared helpers exposed via [MeshTheme.of].
class MeshTheme {
  MeshTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: MeshPalette.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF075985),
      onPrimaryContainer: Colors.white,
      secondary: MeshPalette.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF331A33),
      onSecondaryContainer: Colors.white,
      tertiary: MeshPalette.warn,
      onTertiary: Color(0xFF0B1220),
      tertiaryContainer: Color(0xFF78350F),
      onTertiaryContainer: Colors.white,
      error: MeshPalette.alert,
      onError: Colors.white,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Colors.white,
      surface: MeshPalette.bg,
      onSurface: MeshPalette.ink,
      surfaceContainerLowest: MeshPalette.bg,
      surfaceContainerLow: MeshPalette.bg1,
      surfaceContainer: MeshPalette.bg1,
      surfaceContainerHigh: MeshPalette.bg2,
      surfaceContainerHighest: MeshPalette.bg3,
      onSurfaceVariant: MeshPalette.ink2,
      outline: MeshPalette.line2,
      outlineVariant: MeshPalette.line,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: MeshPalette.ink,
      onInverseSurface: MeshPalette.bg,
      inversePrimary: MeshPalette.primaryDim,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: MeshPalette.lightBlue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD3E4F5),
      onPrimaryContainer: Color(0xFF12354F),
      secondary: Color(0xFF8C4A8A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFD6EE),
      onSecondaryContainer: Color(0xFF3D1A3C),
      tertiary: Color(0xFF9A5B16),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF8E3C9),
      onTertiaryContainer: Color(0xFF4A2A05),
      error: Color(0xFFB53D2F),
      onError: Colors.white,
      errorContainer: Color(0xFFF6D9D4),
      onErrorContainer: Color(0xFF5C1A12),
      surface: MeshPalette.lightBg,
      onSurface: MeshPalette.lightInk,
      surfaceContainerLowest: MeshPalette.lightBg,
      surfaceContainerLow: MeshPalette.lightBg1,
      surfaceContainer: MeshPalette.lightBg1,
      surfaceContainerHigh: MeshPalette.lightBg2,
      surfaceContainerHighest: Color(0xFFD2DAE1),
      onSurfaceVariant: MeshPalette.lightInk2,
      outline: MeshPalette.lightLine,
      outlineVariant: Color(0xFFD8DEE5),
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final materialText =
        Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: scheme,
        ).black.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
        );

    // Explicit sizes matching the app's dominant `fontSize:` literal clusters
    // (see docs/superpowers/specs/2026-08-02-custom-style-editor-design.md,
    // "role fontów") — the stock Material 2021 scale doesn't match them.
    const titleSmallSize = 10.0;
    final baseText = materialText.copyWith(
      bodyMedium: materialText.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: materialText.bodySmall?.copyWith(fontSize: 11),
      titleSmall: materialText.titleSmall?.copyWith(fontSize: titleSmallSize),
      // Large titles derived from titleSmall (B3) via fixed increments
      // (2026-08-21: base dropped to 10, so the whole title ladder shrinks).
      titleMedium: materialText.titleMedium?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.titleMediumIncrement,
      ),
      titleLarge: materialText.titleLarge?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.titleLargeIncrement,
      ),
      headlineSmall: materialText.headlineSmall?.copyWith(
        fontSize: titleSmallSize + MeshTypeScale.headlineSmallIncrement,
      ),
      labelSmall: materialText.labelSmall?.copyWith(fontSize: 10),
      labelMedium: materialText.labelMedium?.copyWith(fontSize: 15),
    );

    // Chrome sizes below are derived from these resolved roles (B4) rather
    // than hardcoded, so a custom-style role override reshapes chrome too —
    // see MeshTypeScale and buildCustomStyle's mirrored rebuild.
    final bodyMediumSize = baseText.bodyMedium!.fontSize!;
    final bodySmallSize = baseText.bodySmall!.fontSize!;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      fontFamily: MeshFonts.sans,
      fontFamilyFallback: MeshFonts.sansFallback,
      textTheme: baseText,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: titleSmallSize + MeshTypeScale.appBarTitleIncrement,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        tileColor: Colors.transparent,
        // C2: without an explicit titleTextStyle, ListTile/SwitchListTile
        // titles fall back to the SDK's M3 default (bodyLarge, not an
        // editable role) instead of scaling with the rest of the UI.
        titleTextStyle: baseText.bodyMedium?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: baseText.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.pill),
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      // App-wide button language (2026-08-21, modeled on the repeater CLI
      // param-popup steppers): primary tint bg (~20%), primary ink, no
      // border, soft shadow. Radius/border-mode are user-editable via the
      // Custom Style editor's Buttons section (buildCustomStyle re-derives).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.2),
          foregroundColor: scheme.primary,
          elevation: 1,
          shadowColor: const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
          textStyle: TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontWeight: FontWeight.w600,
            fontSize: bodyMediumSize + MeshTypeScale.buttonLabelIncrement,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.2),
          foregroundColor: scheme.primary,
          side: BorderSide.none,
          elevation: 1,
          shadowColor: const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: bodySmallSize + MeshTypeScale.chipLabelIncrement,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        // Explicit selected-state colors — Material 3's own default (derived
        // from secondaryContainer) gave near-invisible checkmark contrast
        // under some custom color profiles (found on-device 2026-08-13).
        // NOT primaryContainer: for a profile with untouched overrides
        // (e.g. Blue) that resolves to a hardcoded literal container color
        // that can blend into the surrounding surface — an alpha tint of
        // `primary` itself (same 0x29 alpha as MeshTokens.primaryBg,
        // mesh_derived.dart) always contrasts against the flat unselected
        // background, and the opaque `primary` checkmark always contrasts
        // against that tint.
        selectedColor: scheme.primary.withValues(alpha: 0x29 / 0xFF),
        checkmarkColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontSize: bodySmallSize + MeshTypeScale.navigationLabelIncrement,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MeshRadii.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        // A border (matching MeshCard's flat-mode idiom) keeps the bar
        // readable against whatever's behind it — surfaceContainerHigh
        // alone can read as "blends into the background" on some custom
        // color profiles (found on-device 2026-08-15).
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshRadii.md),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.16),
          selectedForegroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Switch language (2026-08-21): ON = primary tint track (20%) + solid
      // primary thumb; OFF = secondary tint track (20%) + solid secondary
      // thumb. No outline in either state — matches the app-wide tinted
      // button look this session introduced.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.secondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.secondary.withValues(alpha: 0.2),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      // Sliders: 20%-tint track, solid 100% thumb (2026-08-21) — same
      // tint/solid split as the switch above.
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary.withValues(alpha: 0.2),
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.surfaceContainerHighest,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: MeshFonts.mono,
          fontFamilyFallback: MeshFonts.monoFallback,
          color: scheme.onSurface,
          fontSize: bodySmallSize + MeshTypeScale.sliderIndicatorIncrement,
        ),
        trackHeight: 3,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: bodyMediumSize + MeshTypeScale.tabLabelIncrement,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: MeshFonts.sans,
          fontFamilyFallback: MeshFonts.sansFallback,
          fontSize: bodyMediumSize + MeshTypeScale.tabLabelIncrement,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(MeshRadii.sm),
          border: Border.all(color: scheme.outline),
        ),
        textStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: bodySmallSize + MeshTypeScale.tooltipIncrement,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.2),
          foregroundColor: scheme.primary,
          elevation: 1,
          shadowColor: const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeshRadii.pill),
          ),
          textStyle: TextStyle(
            fontFamily: MeshFonts.sans,
            fontFamilyFallback: MeshFonts.sansFallback,
            fontWeight: FontWeight.w600,
            fontSize: bodyMediumSize + MeshTypeScale.buttonLabelIncrement,
          ),
        ),
      ),
    );
  }

  /// Mono text style — sizes default to the body size Inter is using.
  static TextStyle mono({
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

  /// Serif display style.
  static TextStyle display({
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

  /// Section-accent / chip label — sans for legibility, with light tracking
  /// to keep the "label" feel that section headers rely on.
  static TextStyle accentLabel({Color? color, double? fontSize}) {
    return TextStyle(
      fontFamily: MeshFonts.sans,
      fontFamilyFallback: MeshFonts.sansFallback,
      fontSize: fontSize ?? 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );
  }

  /// Color-emoji style with platform fallbacks and stable vertical metrics.
  static TextStyle emoji({double fontSize = 28}) {
    return TextStyle(
      fontFamily: MeshFonts.emoji,
      fontFamilyFallback: MeshFonts.emojiFallback,
      fontSize: fontSize,
      height: 1,
    );
  }

  /// Color-code an SNR value for consistency across the app.
  static Color snrColor(num? snr, {required bool blocked}) {
    if (blocked) return MeshPalette.alert;
    if (snr == null) return MeshPalette.ink3;
    if (snr > -5) return MeshPalette.signal;
    if (snr > -12) return MeshPalette.warn;
    return MeshPalette.alert;
  }
}
