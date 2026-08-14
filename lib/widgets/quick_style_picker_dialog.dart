import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../screens/custom_style_editor_screen.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../theme/styles/style_registry.dart';
import 'mesh_info_dialog.dart';
import 'theme_profile_selector.dart';

/// Quick swap: two chip rows (theme, then color profile of the active
/// theme), plus a tune icon into the full [CustomStyleEditorScreen].
/// Selecting a `built` theme/profile re-themes the app live; selecting an
/// inert (`built: false`) theme only shows selection state locally.
Future<void> showQuickStylePickerDialog(BuildContext context) {
  return showMeshInfoDialog(
    context,
    title: context.l10n.appSettings_quickStyleDialogTitle,
    builder: (context) => const _QuickStylePickerBody(),
  );
}

class _QuickStylePickerBody extends StatefulWidget {
  const _QuickStylePickerBody();

  @override
  State<_QuickStylePickerBody> createState() => _QuickStylePickerBodyState();
}

class _QuickStylePickerBodyState extends State<_QuickStylePickerBody> {
  String? _previewThemeId;

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<AppSettingsService>();
    final settings = settingsService.settings;
    final t = MeshTokens.of(context);
    final displayedThemeId = _previewThemeId ?? settings.activeThemeId;
    final displayedTheme = StyleRegistry.themeById(displayedThemeId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.appSettings_theme,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SizedBox(height: t.spacingSm),
        ThemeChipRow(
          themes: StyleRegistry.themes,
          activeThemeId: displayedThemeId,
          onThemeSelected: (themeId) {
            final theme = StyleRegistry.themeById(themeId);
            if (theme.built) {
              setState(() => _previewThemeId = null);
              settingsService.setActiveTheme(
                themeId,
                profileId: theme.profiles.first.id,
              );
            } else {
              setState(() => _previewThemeId = themeId);
            }
          },
        ),
        SizedBox(height: t.spacingMd),
        Text(
          context.l10n.appSettings_colorStyle,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SizedBox(height: t.spacingSm),
        ProfileChipRow(
          activeTheme: displayedTheme,
          activeProfileId: _previewThemeId == null
              ? settings.activeProfileId
              : '',
          onProfileSelected: _previewThemeId == null
              ? settingsService.setActiveProfile
              : (_) {},
        ),
        SizedBox(height: t.spacingSm),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.tune, size: 18),
            tooltip: context.l10n.appSettings_editCustomStyleTooltip,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomStyleEditorScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
