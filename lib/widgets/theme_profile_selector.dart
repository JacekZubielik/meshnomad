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
          SelectableChipButton(
            key: ValueKey('themeChip_${theme.id}'),
            label: theme.displayName,
            selected: activeThemeId == theme.id,
            onTap: () => onThemeSelected(theme.id),
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
          SelectableChipButton(
            key: ValueKey('profileChip_${profile.id}'),
            label: profile.displayName,
            selected: activeProfileId == profile.id,
            onTap: () => onProfileSelected(profile.id),
          ),
      ],
    );
  }
}

/// A chip-sized selection toggle built from the app's real button widgets
/// (FilledButton when selected, OutlinedButton otherwise) instead of a
/// Material [ChoiceChip]. ChoiceChip reads its shape from the shared
/// `chipTheme` (pinned to the `pill` radius token, always a solid border),
/// which is also used by unrelated chips elsewhere in the app (map filter
/// chips, repeater CLI action chips). Routing these two pickers through
/// FilledButton/OutlinedButton instead means they pick up `buttonRadius`
/// and `buttonBorder` (none/solid/dotted) from the Custom Style Editor's
/// Buttons section, like every other button in the app, without touching
/// chipTheme or any chip used elsewhere. Public since 2026-08-24 — also
/// used by `FlasherScreen`'s source picker; keep this the single
/// implementation of this pattern rather than a per-screen copy.
class SelectableChipButton extends StatelessWidget {
  const SelectableChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    // outlinedButtonTheme never got the same explicit textStyle bump that
    // elevatedButtonTheme/filledButtonTheme carry (mesh_theme.dart), so an
    // OutlinedButton falls back to Flutter's default label size — taller
    // than a FilledButton with identical padding. Pin both variants to the
    // FilledButton's real textStyle so selected/unselected chips render at
    // the same height regardless of that gap.
    final buttonTextStyle = Theme.of(
      context,
    ).filledButtonTheme.style?.textStyle?.resolve(const {});
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: t.spacingMd, vertical: t.spacingXs),
      ),
      textStyle: WidgetStatePropertyAll(buttonTextStyle),
    );
    return selected
        ? FilledButton(onPressed: onTap, style: style, child: Text(label))
        : OutlinedButton(onPressed: onTap, style: style, child: Text(label));
  }
}
