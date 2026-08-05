/// User-editable overrides for the "custom" [MeshStyle]. Every key is
/// optional — an absent key means "inherit from [defaultStyle]". Keys are
/// field names on [MeshTokens] (colors) or [TextTheme] roles / MeshTokens
/// mono-size fields (fonts), NOT arbitrary strings — the editor UI
/// (03-custom-style-editor-ui.md) exposes only a closed set of keys.
class CustomStyleOverrides {
  const CustomStyleOverrides({
    this.colorOverrides = const {},
    this.fontSizeOverrides = const {},
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

  final Map<String, int> colorOverrides; // key -> Color.value (ARGB int)
  final Map<String, double> fontSizeOverrides;

  CustomStyleOverrides copyWith({
    Map<String, int>? colorOverrides,
    Map<String, double>? fontSizeOverrides,
  }) {
    return CustomStyleOverrides(
      colorOverrides: colorOverrides ?? this.colorOverrides,
      fontSizeOverrides: fontSizeOverrides ?? this.fontSizeOverrides,
    );
  }

  Map<String, dynamic> toJson() {
    return {'colors': colorOverrides, 'font_sizes': fontSizeOverrides};
  }

  factory CustomStyleOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomStyleOverrides();
    return CustomStyleOverrides(
      colorOverrides: _migrateColorKeys(_parseIntMap(json['colors'])),
      fontSizeOverrides: _parseDoubleMap(json['font_sizes']),
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
