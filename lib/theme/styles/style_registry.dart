import '../../models/custom_style_overrides.dart';
import 'profiles/default_blue_profile.dart';
import 'profiles/default_green_profile.dart';
import 'theme_definition.dart';

/// Catalog of every layout theme and its color profiles. `built: false`
/// themes (terminal, omarchy) exist only so their selector buttons render
/// with real labels/ids — see docs/superpowers/specs/2026-08-12-theme-
/// color-profiles-design.md. Never reuse or repurpose an existing id.
class StyleRegistry {
  StyleRegistry._();

  static final List<ThemeDefinition> themes = [
    const ThemeDefinition(
      id: 'default',
      displayName: 'Default',
      built: true,
      profiles: [defaultGreenProfile, defaultBlueProfile],
    ),
    const ThemeDefinition(
      id: 'terminal',
      displayName: 'Terminal',
      built: false,
      profiles: [
        ColorProfileSeed(
          id: 'green',
          displayName: 'Green',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'amber',
          displayName: 'Amber',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'cyan',
          displayName: 'Cyan',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'ice',
          displayName: 'Ice',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'red',
          displayName: 'Red',
          overrides: CustomStyleOverrides(),
        ),
      ],
    ),
    const ThemeDefinition(
      id: 'omarchy',
      displayName: 'Omarchy',
      built: false,
      profiles: [
        ColorProfileSeed(
          id: 'tokyo',
          displayName: 'Tokyo',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'everforest',
          displayName: 'Everforest',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'gruvbox',
          displayName: 'Gruvbox',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'nord',
          displayName: 'Nord',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'rose',
          displayName: 'Rosé',
          overrides: CustomStyleOverrides(),
        ),
        ColorProfileSeed(
          id: 'matte',
          displayName: 'Matte',
          overrides: CustomStyleOverrides(),
        ),
      ],
    ),
  ];

  static ThemeDefinition themeById(String id) {
    for (final theme in themes) {
      if (theme.id == id) return theme;
    }
    return themes.first; // 'default'
  }

  static ColorProfileSeed profileSeed(String themeId, String profileId) {
    final theme = themeById(themeId);
    for (final profile in theme.profiles) {
      if (profile.id == profileId) return profile;
    }
    return theme.profiles.first;
  }
}
