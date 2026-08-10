import 'dart:ui' show Brightness;

/// User-editable overrides for the "custom" [MeshStyle]. Every key is
/// optional — an absent key means "inherit from [defaultStyle]". Keys are
/// field names on [MeshTokens] (colors) or [TextTheme] roles / MeshTokens
/// mono-size fields (fonts), NOT arbitrary strings — the editor UI
/// (03-custom-style-editor-ui.md) exposes only a closed set of keys.
///
/// Colors are split per brightness (pkt 17) — [colorOverridesLight] and
/// [colorOverridesDark] are edited independently in the style editor via its
/// Jasny|Ciemny switch. Font sizes are NOT brightness-dependent (verified
/// 2026-08-07 against `MeshTheme._build()`, which uses the same literals for
/// both `light()`/`dark()`), so [fontSizeOverrides] stays a single map.
class CustomStyleOverrides {
  const CustomStyleOverrides({
    this.colorOverridesLight = const {},
    this.colorOverridesDark = const {},
    this.fontSizeOverrides = const {},
    this.spacingOverrides = const {},
    this.radiusOverrides = const {},
    this.cardElevated,
  });

  /// The closed set of `MeshTokens` color fields the editor UI exposes.
  /// The first 10 are the base/most-visible colors; `*Dim`/`*Bg`/`*Line`
  /// variants and background/text/divider layers are NOT here — they're
  /// computed automatically from these bases (02-variant-automat.md).
  /// The 32 `map*`/`los*` entries are semantically independent (each node
  /// type / LOS state is its own color) and are applied 1:1, no automat
  /// (A6, 04-editor-ui.md).
  static const List<String> editableColorKeys = [
    'bg',
    'ink',
    'line',
    'primary',
    'secondary',
    'signal',
    'warn',
    'alert',
    'me',
    'meInk',
    'mapOnline',
    'mapOffline',
    'mapStale',
    'mapRepeater',
    'mapRouter',
    'mapBatteryLow',
    'mapCluster',
    'mapSelected',
    'mapSensor',
    'mapShared',
    'mapPanelLight',
    'mapPanelDark',
    'mapTextPrimary',
    'mapTextSecondary',
    'mapTextMuted',
    'mapBorder',
    'mapMarkerOutline',
    'mapMarkerShadow',
    'losTerrain',
    'losBeam',
    'losHorizon',
    'losBlocked',
    'losMarginal',
    'losClear',
    'losSelected',
    'losChartBackground',
    'losPanelDark',
    'losPanelLight',
    'losText',
    'losTextMuted',
    'losBorder',
    'losShadow',
  ];

  /// The closed set of `textTheme` roles / `MeshTokens` mono-size fields the
  /// editor UI exposes — the roles that came out of the font-role migration
  /// (01-font-role-infra.md) as most frequently used.
  static const List<String> editableFontSizeKeys = [
    'bodyMedium',
    'bodySmall',
    'titleSmall',
    'labelSmall',
    'labelMedium',
    'monoCaptionSize',
    'monoBodySize',
  ];

  /// The closed set of `MeshTokens` spacing fields the editor UI exposes —
  /// keys mirror the Dart field names 1:1.
  static const List<String> editableSpacingKeys = [
    'spacingXxs',
    'spacingXs',
    'spacingSm',
    'spacingMd',
    'spacingLg',
    'spacingXlg',
    'spacingXxlg',
  ];

  /// Editable `MeshTokens` corner-radius fields. `pill` (999) is deliberately
  /// NOT editable — a slider to 999 is unusable; pill means "fully round".
  static const List<String> editableRadiusKeys = ['xs', 'sm', 'md', 'lg', 'xl'];

  final Map<String, int> colorOverridesLight; // key -> Color.value (ARGB int)
  final Map<String, int> colorOverridesDark; // key -> Color.value (ARGB int)
  final Map<String, double> fontSizeOverrides;
  final Map<String, double> spacingOverrides;
  final Map<String, double> radiusOverrides;

  /// Whether MeshCard draws its floating shadow. `null` means "inherit the
  /// default" (`true`) — use [withCardElevated] to change or clear this,
  /// never `copyWith` (its `??` pattern can't express "back to null").
  final bool? cardElevated;

  /// Returns the color-override map for [brightness] — the single read path
  /// callers (editor rows, `buildCustomStyle`) should use instead of picking
  /// a field directly, so the branch lives in one place.
  Map<String, int> colorOverridesFor(Brightness brightness) =>
      brightness == Brightness.light ? colorOverridesLight : colorOverridesDark;

  CustomStyleOverrides copyWith({
    Map<String, int>? colorOverridesLight,
    Map<String, int>? colorOverridesDark,
    Map<String, double>? fontSizeOverrides,
    Map<String, double>? spacingOverrides,
    Map<String, double>? radiusOverrides,
  }) {
    return CustomStyleOverrides(
      colorOverridesLight: colorOverridesLight ?? this.colorOverridesLight,
      colorOverridesDark: colorOverridesDark ?? this.colorOverridesDark,
      fontSizeOverrides: fontSizeOverrides ?? this.fontSizeOverrides,
      spacingOverrides: spacingOverrides ?? this.spacingOverrides,
      radiusOverrides: radiusOverrides ?? this.radiusOverrides,
      cardElevated: cardElevated,
    );
  }

  /// Returns a copy with [cardElevated] replaced — including back to `null`
  /// ("inherit"), which copyWith's `??` pattern cannot express.
  CustomStyleOverrides withCardElevated(bool? value) {
    return CustomStyleOverrides(
      colorOverridesLight: colorOverridesLight,
      colorOverridesDark: colorOverridesDark,
      fontSizeOverrides: fontSizeOverrides,
      spacingOverrides: spacingOverrides,
      radiusOverrides: radiusOverrides,
      cardElevated: value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'colors_light': colorOverridesLight,
      'colors_dark': colorOverridesDark,
      'font_sizes': fontSizeOverrides,
      'spacing': spacingOverrides,
      'radius': radiusOverrides,
      'card_elevated': cardElevated,
    };
  }

  /// Parses persisted settings JSON. Handles three shapes:
  /// - v2 (`colors_light`/`colors_dark` present): read directly, each mapped
  ///   through [_migrateColorKeys] in case an old backup still has legacy
  ///   `blue`/`magenta` keys.
  /// - legacy v1 (`colors` only): the whole map becomes [colorOverridesDark]
  ///   — the editor only ever edited the dark palette before pkt 17, so a
  ///   user's saved overrides visually applied to dark.
  /// - neither present: both maps empty.
  factory CustomStyleOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomStyleOverrides();
    final hasV2 =
        json.containsKey('colors_light') || json.containsKey('colors_dark');
    if (hasV2) {
      return CustomStyleOverrides(
        colorOverridesLight: _migrateColorKeys(
          _parseIntMap(json['colors_light']),
        ),
        colorOverridesDark: _migrateColorKeys(
          _parseIntMap(json['colors_dark']),
        ),
        fontSizeOverrides: _parseDoubleMap(json['font_sizes']),
        spacingOverrides: _parseDoubleMap(json['spacing']),
        radiusOverrides: _parseDoubleMap(json['radius']),
        cardElevated: json['card_elevated'] is bool
            ? json['card_elevated'] as bool
            : null,
      );
    }
    return CustomStyleOverrides(
      colorOverridesDark: _migrateColorKeys(_parseIntMap(json['colors'])),
      fontSizeOverrides: _parseDoubleMap(json['font_sizes']),
      spacingOverrides: _parseDoubleMap(json['spacing']),
      radiusOverrides: _parseDoubleMap(json['radius']),
      cardElevated: json['card_elevated'] is bool
          ? json['card_elevated'] as bool
          : null,
    );
  }

  /// Renames legacy `blue`/`magenta` persisted keys to `primary`/`secondary`
  /// (token rename, 01-token-rename.md) so overrides saved before the
  /// rename keep applying to the same field after an app update.
  static Map<String, int> _migrateColorKeys(Map<String, int> colors) {
    if (!colors.containsKey('blue') && !colors.containsKey('magenta')) {
      return colors;
    }
    final migrated = Map<String, int>.from(colors);
    if (migrated.containsKey('blue') && !migrated.containsKey('primary')) {
      migrated['primary'] = migrated.remove('blue')!;
    } else {
      migrated.remove('blue');
    }
    if (migrated.containsKey('magenta') && !migrated.containsKey('secondary')) {
      migrated['secondary'] = migrated.remove('magenta')!;
    } else {
      migrated.remove('magenta');
    }
    return migrated;
  }

  static Map<String, int> _parseIntMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      try {
        result[entry.key.toString()] = entry.value as int;
      } catch (_) {
        // Skip malformed entries rather than failing the whole parse.
      }
    }
    return result;
  }

  static Map<String, double> _parseDoubleMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, double>{};
    for (final entry in raw.entries) {
      try {
        result[entry.key.toString()] = (entry.value as num).toDouble();
      } catch (_) {
        // Skip malformed entries rather than failing the whole parse.
      }
    }
    return result;
  }
}
