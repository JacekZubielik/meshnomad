/// User-editable overrides for a color profile (see `StyleRegistry`,
/// `ColorProfileSeed`). Every key is optional — an absent key means
/// "inherit from the profile's seed". Keys are field names on `MeshTokens`
/// (colors) or `TextTheme` roles / MeshTokens mono-size fields (fonts), NOT
/// arbitrary strings — the editor UI exposes only a closed set of keys.
///
/// Brightness is a property of the profile, derived from `colorOverrides['bg']`
/// (see `buildCustomStyle`) — there is no separate light/dark toggle, and no
/// brightness split in this type (design spec 2026-08-12).
class CustomStyleOverrides {
  const CustomStyleOverrides({
    this.colorOverrides = const {},
    this.fontSizeOverrides = const {},
    this.spacingOverrides = const {},
    this.radiusOverrides = const {},
    this.cardElevated,
    this.buttonBorder,
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
    // LOS chrome/status colors are intentionally NOT here — they derive from
    // the base palette (bg/ink/line/alert/signal/warn/primary) so editing
    // them separately would duplicate the main Colors section (decision
    // 2026-08-10). Only the three genuine chart data hues stay editable.
    'losTerrain',
    'losBeam',
    'losHorizon',
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

  /// Editable `MeshTokens` corner-radius fields. `pill` is exposed on the
  /// same 0-40 scale as the others (not 0-999) — for the button/FAB/chip
  /// heights this app uses, 40 already renders fully round, so the slider
  /// stays usable while its unedited default still clamps to "fully round"
  /// (see `_radiusFields`/`_TokenFieldRow` in custom_style_editor_screen.dart).
  static const List<String> editableRadiusKeys = [
    'xs',
    'sm',
    'md',
    'lg',
    'xl',
    'pill',
    'buttonRadius',
  ];

  final Map<String, int> colorOverrides; // key -> Color.value (ARGB int)
  final Map<String, double> fontSizeOverrides;
  final Map<String, double> spacingOverrides;
  final Map<String, double> radiusOverrides;

  /// Whether MeshCard draws its floating shadow. `null` means "inherit the
  /// default" (`true`) — use [withCardElevated] to change or clear this,
  /// never `copyWith` (its `??` pattern can't express "back to null").
  final bool? cardElevated;

  /// Button border mode: 'solid' | 'dotted'; `null` means no border (the
  /// default) — use [withButtonBorder] to change or clear.
  final String? buttonBorder;

  CustomStyleOverrides copyWith({
    Map<String, int>? colorOverrides,
    Map<String, double>? fontSizeOverrides,
    Map<String, double>? spacingOverrides,
    Map<String, double>? radiusOverrides,
  }) {
    return CustomStyleOverrides(
      colorOverrides: colorOverrides ?? this.colorOverrides,
      fontSizeOverrides: fontSizeOverrides ?? this.fontSizeOverrides,
      spacingOverrides: spacingOverrides ?? this.spacingOverrides,
      radiusOverrides: radiusOverrides ?? this.radiusOverrides,
      cardElevated: cardElevated,
      buttonBorder: buttonBorder,
    );
  }

  /// Returns a copy with [cardElevated] replaced — including back to `null`
  /// ("inherit"), which copyWith's `??` pattern cannot express.
  CustomStyleOverrides withCardElevated(bool? value) {
    return CustomStyleOverrides(
      colorOverrides: colorOverrides,
      fontSizeOverrides: fontSizeOverrides,
      spacingOverrides: spacingOverrides,
      radiusOverrides: radiusOverrides,
      cardElevated: value,
      buttonBorder: buttonBorder,
    );
  }

  /// Returns a copy with [buttonBorder] replaced — including back to `null`
  /// ("no border"), which copyWith's `??` pattern cannot express.
  CustomStyleOverrides withButtonBorder(String? value) {
    return CustomStyleOverrides(
      colorOverrides: colorOverrides,
      fontSizeOverrides: fontSizeOverrides,
      spacingOverrides: spacingOverrides,
      radiusOverrides: radiusOverrides,
      cardElevated: cardElevated,
      buttonBorder: value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'colors': colorOverrides,
      'font_sizes': fontSizeOverrides,
      'spacing': spacingOverrides,
      'radius': radiusOverrides,
      'card_elevated': cardElevated,
      'button_border': buttonBorder,
    };
  }

  /// Parses persisted settings JSON. Handles three shapes:
  /// - v3 (`colors` present, this shape): read directly, mapped through
  ///   [_migrateColorKeys] in case an old backup still has legacy
  ///   `blue`/`magenta` keys.
  /// - v2 legacy (`colors_light`/`colors_dark` present, pre-single-palette):
  ///   use `colors_dark` as the single map — the editor always visually
  ///   applied dark before this change per the original v1→v2 migration
  ///   note. `colors_light` is dropped (a user's light-brightness edits from
  ///   the removed toggle are not preserved — accepted per the design spec).
  /// - neither present: empty map.
  factory CustomStyleOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomStyleOverrides();
    final hasV2Split =
        json.containsKey('colors_light') || json.containsKey('colors_dark');
    final rawColors = hasV2Split ? json['colors_dark'] : json['colors'];
    return CustomStyleOverrides(
      colorOverrides: _migrateColorKeys(_parseIntMap(rawColors)),
      fontSizeOverrides: _parseDoubleMap(json['font_sizes']),
      spacingOverrides: _parseDoubleMap(json['spacing']),
      radiusOverrides: _parseDoubleMap(json['radius']),
      cardElevated: json['card_elevated'] is bool
          ? json['card_elevated'] as bool
          : null,
      buttonBorder: json['button_border'] is String
          ? json['button_border'] as String
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
