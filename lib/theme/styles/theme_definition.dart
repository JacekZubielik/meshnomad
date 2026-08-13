import '../../models/custom_style_overrides.dart';

/// One selectable color profile within a [ThemeDefinition] — a full,
/// editable override set (colors, spacing, radius, card style, fonts).
/// [id] is stable and persisted (prefixed by the theme id, see
/// StyleRegistry) — never rename or reuse an existing id.
class ColorProfileSeed {
  const ColorProfileSeed({
    required this.id,
    required this.displayName,
    required this.overrides,
  });

  final String id;
  final String displayName;
  final CustomStyleOverrides overrides;
}

/// One selectable layout theme (window/component structure). [built]
/// false means the theme has a finished selector entry (buttons render,
/// are tappable, show selection state) but selecting it does NOT change
/// the app's rendered layout — see docs/superpowers/specs/2026-08-12-
/// theme-color-profiles-design.md "Button set".
class ThemeDefinition {
  const ThemeDefinition({
    required this.id,
    required this.displayName,
    required this.built,
    required this.profiles,
  });

  final String id;
  final String displayName;
  final bool built;
  final List<ColorProfileSeed> profiles;
}
