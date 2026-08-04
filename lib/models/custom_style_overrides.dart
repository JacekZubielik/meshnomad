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

  /// The closed set of `MeshTokens` color fields the editor UI exposes —
  /// the most visible colors, not the full map/LOS palette.
  static const List<String> editableColorKeys = [
    'bg',
    'ink',
    'line',
    'blue',
    'magenta',
    'signal',
    'warn',
    'alert',
    'me',
    'meInk',
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
      colorOverrides: _parseIntMap(json['colors']),
      fontSizeOverrides: _parseDoubleMap(json['font_sizes']),
    );
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
