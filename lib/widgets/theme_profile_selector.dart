import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';
import '../theme/styles/theme_definition.dart';

/// Chip row for picking a [ThemeDefinition]. Themes with `built: false`
/// still render a fully interactive, selectable chip (hover/press/selected
/// states) but selecting one does NOT change [activeThemeId] upstream in a
/// way that renders — callers decide (see AppSettingsScreen Step 3 /
/// QuickStylePicker) whether to actually apply an inert-theme selection.
class ThemeChipRow extends StatelessWidget {
  const ThemeChipRow({
    super.key,
    required this.themes,
    required this.activeThemeId,
    required this.onThemeSelected,
  });

  final List<ThemeDefinition> themes;
  final String activeThemeId;
  final ValueChanged<String> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Wrap(
      spacing: t.spacingXs,
      runSpacing: t.spacingXs,
      children: [
        for (final theme in themes)
          ChoiceChip(
            label: Text(theme.displayName),
            selected: activeThemeId == theme.id,
            onSelected: (_) => onThemeSelected(theme.id),
          ),
      ],
    );
  }
}

/// Chip row for picking a [ColorProfileSeed] within [activeTheme].
class ProfileChipRow extends StatelessWidget {
  const ProfileChipRow({
    super.key,
    required this.activeTheme,
    required this.activeProfileId,
    required this.onProfileSelected,
  });

  final ThemeDefinition activeTheme;
  final String activeProfileId;
  final ValueChanged<String> onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Wrap(
      spacing: t.spacingXs,
      runSpacing: t.spacingXs,
      children: [
        for (final profile in activeTheme.profiles)
          ChoiceChip(
            label: Text(profile.displayName),
            selected: activeProfileId == profile.id,
            onSelected: (_) => onProfileSelected(profile.id),
          ),
      ],
    );
  }
}
