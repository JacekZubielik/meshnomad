import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/custom_style_overrides.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../theme/styles/default_style.dart';
import '../widgets/mesh_ui.dart';

class _ColorFieldSpec {
  const _ColorFieldSpec(
    this.key,
    this.defaultColorDark,
    this.defaultColorLight,
  );
  final String key;
  final Color defaultColorDark;
  final Color defaultColorLight;

  Color defaultColorFor(Brightness brightness) =>
      brightness == Brightness.light ? defaultColorLight : defaultColorDark;
}

class _FontFieldSpec {
  const _FontFieldSpec(this.key, this.defaultSize);
  final String key;
  final double defaultSize;
}

final List<_ColorFieldSpec> _baseColorFields = [
  _ColorFieldSpec(
    'bg',
    MeshTokens.defaultTokens.bg,
    MeshTokens.defaultTokensLight.bg,
  ),
  _ColorFieldSpec(
    'ink',
    MeshTokens.defaultTokens.ink,
    MeshTokens.defaultTokensLight.ink,
  ),
  _ColorFieldSpec(
    'line',
    MeshTokens.defaultTokens.line,
    MeshTokens.defaultTokensLight.line,
  ),
  _ColorFieldSpec(
    'primary',
    MeshTokens.defaultTokens.primary,
    MeshTokens.defaultTokensLight.primary,
  ),
  _ColorFieldSpec(
    'secondary',
    MeshTokens.defaultTokens.secondary,
    MeshTokens.defaultTokensLight.secondary,
  ),
  _ColorFieldSpec(
    'signal',
    MeshTokens.defaultTokens.signal,
    MeshTokens.defaultTokensLight.signal,
  ),
  _ColorFieldSpec(
    'warn',
    MeshTokens.defaultTokens.warn,
    MeshTokens.defaultTokensLight.warn,
  ),
  _ColorFieldSpec(
    'alert',
    MeshTokens.defaultTokens.alert,
    MeshTokens.defaultTokensLight.alert,
  ),
  _ColorFieldSpec(
    'me',
    MeshTokens.defaultTokens.me,
    MeshTokens.defaultTokensLight.me,
  ),
  _ColorFieldSpec(
    'meInk',
    MeshTokens.defaultTokens.meInk,
    MeshTokens.defaultTokensLight.meInk,
  ),
];

// A6/04-editor-ui.md: map/LOS palettes are semantically independent per
// marker/state colors — every field is its own row, no automat. They're
// shared between brightnesses (defaultTokensLight mirrors defaultTokens for
// every map*/los* field, pkt 17 prompt 01), so dark/light defaults are equal.
final List<_ColorFieldSpec> _mapColorFields = [
  _ColorFieldSpec(
    'mapOnline',
    MeshTokens.defaultTokens.mapOnline,
    MeshTokens.defaultTokensLight.mapOnline,
  ),
  _ColorFieldSpec(
    'mapOffline',
    MeshTokens.defaultTokens.mapOffline,
    MeshTokens.defaultTokensLight.mapOffline,
  ),
  _ColorFieldSpec(
    'mapStale',
    MeshTokens.defaultTokens.mapStale,
    MeshTokens.defaultTokensLight.mapStale,
  ),
  _ColorFieldSpec(
    'mapRepeater',
    MeshTokens.defaultTokens.mapRepeater,
    MeshTokens.defaultTokensLight.mapRepeater,
  ),
  _ColorFieldSpec(
    'mapRouter',
    MeshTokens.defaultTokens.mapRouter,
    MeshTokens.defaultTokensLight.mapRouter,
  ),
  _ColorFieldSpec(
    'mapBatteryLow',
    MeshTokens.defaultTokens.mapBatteryLow,
    MeshTokens.defaultTokensLight.mapBatteryLow,
  ),
  _ColorFieldSpec(
    'mapCluster',
    MeshTokens.defaultTokens.mapCluster,
    MeshTokens.defaultTokensLight.mapCluster,
  ),
  _ColorFieldSpec(
    'mapSelected',
    MeshTokens.defaultTokens.mapSelected,
    MeshTokens.defaultTokensLight.mapSelected,
  ),
  _ColorFieldSpec(
    'mapSensor',
    MeshTokens.defaultTokens.mapSensor,
    MeshTokens.defaultTokensLight.mapSensor,
  ),
  _ColorFieldSpec(
    'mapShared',
    MeshTokens.defaultTokens.mapShared,
    MeshTokens.defaultTokensLight.mapShared,
  ),
  _ColorFieldSpec(
    'mapPanelLight',
    MeshTokens.defaultTokens.mapPanelLight,
    MeshTokens.defaultTokensLight.mapPanelLight,
  ),
  _ColorFieldSpec(
    'mapPanelDark',
    MeshTokens.defaultTokens.mapPanelDark,
    MeshTokens.defaultTokensLight.mapPanelDark,
  ),
  _ColorFieldSpec(
    'mapTextPrimary',
    MeshTokens.defaultTokens.mapTextPrimary,
    MeshTokens.defaultTokensLight.mapTextPrimary,
  ),
  _ColorFieldSpec(
    'mapTextSecondary',
    MeshTokens.defaultTokens.mapTextSecondary,
    MeshTokens.defaultTokensLight.mapTextSecondary,
  ),
  _ColorFieldSpec(
    'mapTextMuted',
    MeshTokens.defaultTokens.mapTextMuted,
    MeshTokens.defaultTokensLight.mapTextMuted,
  ),
  _ColorFieldSpec(
    'mapBorder',
    MeshTokens.defaultTokens.mapBorder,
    MeshTokens.defaultTokensLight.mapBorder,
  ),
  _ColorFieldSpec(
    'mapMarkerOutline',
    MeshTokens.defaultTokens.mapMarkerOutline,
    MeshTokens.defaultTokensLight.mapMarkerOutline,
  ),
  _ColorFieldSpec(
    'mapMarkerShadow',
    MeshTokens.defaultTokens.mapMarkerShadow,
    MeshTokens.defaultTokensLight.mapMarkerShadow,
  ),
];

final List<_ColorFieldSpec> _losColorFields = [
  _ColorFieldSpec(
    'losTerrain',
    MeshTokens.defaultTokens.losTerrain,
    MeshTokens.defaultTokensLight.losTerrain,
  ),
  _ColorFieldSpec(
    'losBeam',
    MeshTokens.defaultTokens.losBeam,
    MeshTokens.defaultTokensLight.losBeam,
  ),
  _ColorFieldSpec(
    'losHorizon',
    MeshTokens.defaultTokens.losHorizon,
    MeshTokens.defaultTokensLight.losHorizon,
  ),
  _ColorFieldSpec(
    'losBlocked',
    MeshTokens.defaultTokens.losBlocked,
    MeshTokens.defaultTokensLight.losBlocked,
  ),
  _ColorFieldSpec(
    'losMarginal',
    MeshTokens.defaultTokens.losMarginal,
    MeshTokens.defaultTokensLight.losMarginal,
  ),
  _ColorFieldSpec(
    'losClear',
    MeshTokens.defaultTokens.losClear,
    MeshTokens.defaultTokensLight.losClear,
  ),
  _ColorFieldSpec(
    'losSelected',
    MeshTokens.defaultTokens.losSelected,
    MeshTokens.defaultTokensLight.losSelected,
  ),
  _ColorFieldSpec(
    'losChartBackground',
    MeshTokens.defaultTokens.losChartBackground,
    MeshTokens.defaultTokensLight.losChartBackground,
  ),
  _ColorFieldSpec(
    'losPanelDark',
    MeshTokens.defaultTokens.losPanelDark,
    MeshTokens.defaultTokensLight.losPanelDark,
  ),
  _ColorFieldSpec(
    'losPanelLight',
    MeshTokens.defaultTokens.losPanelLight,
    MeshTokens.defaultTokensLight.losPanelLight,
  ),
  _ColorFieldSpec(
    'losText',
    MeshTokens.defaultTokens.losText,
    MeshTokens.defaultTokensLight.losText,
  ),
  _ColorFieldSpec(
    'losTextMuted',
    MeshTokens.defaultTokens.losTextMuted,
    MeshTokens.defaultTokensLight.losTextMuted,
  ),
  _ColorFieldSpec(
    'losBorder',
    MeshTokens.defaultTokens.losBorder,
    MeshTokens.defaultTokensLight.losBorder,
  ),
  _ColorFieldSpec(
    'losShadow',
    MeshTokens.defaultTokens.losShadow,
    MeshTokens.defaultTokensLight.losShadow,
  ),
];

final List<_FontFieldSpec> _fontFields = [
  _FontFieldSpec(
    'bodyMedium',
    defaultStyle.light.textTheme.bodyMedium?.fontSize ?? 12,
  ),
  _FontFieldSpec(
    'bodySmall',
    defaultStyle.light.textTheme.bodySmall?.fontSize ?? 11,
  ),
  _FontFieldSpec(
    'titleSmall',
    defaultStyle.light.textTheme.titleSmall?.fontSize ?? 13,
  ),
  _FontFieldSpec(
    'labelSmall',
    defaultStyle.light.textTheme.labelSmall?.fontSize ?? 10,
  ),
  _FontFieldSpec(
    'labelMedium',
    defaultStyle.light.textTheme.labelMedium?.fontSize ?? 15,
  ),
  _FontFieldSpec('monoCaptionSize', MeshTokens.defaultTokens.monoCaptionSize),
  _FontFieldSpec('monoBodySize', MeshTokens.defaultTokens.monoBodySize),
];

/// Maps a color field key to its localized (label, subtitle) pair. One
/// switch covering the base + map + LOS sections (04-editor-ui.md).
(String, String) _colorFieldText(AppLocalizations l10n, String key) {
  switch (key) {
    case 'bg':
      return (l10n.styleEditor_bg_label, l10n.styleEditor_bg_subtitle);
    case 'ink':
      return (l10n.styleEditor_ink_label, l10n.styleEditor_ink_subtitle);
    case 'line':
      return (l10n.styleEditor_line_label, l10n.styleEditor_line_subtitle);
    case 'primary':
      return (
        l10n.styleEditor_primary_label,
        l10n.styleEditor_primary_subtitle,
      );
    case 'secondary':
      return (
        l10n.styleEditor_secondary_label,
        l10n.styleEditor_secondary_subtitle,
      );
    case 'signal':
      return (l10n.styleEditor_signal_label, l10n.styleEditor_signal_subtitle);
    case 'warn':
      return (l10n.styleEditor_warn_label, l10n.styleEditor_warn_subtitle);
    case 'alert':
      return (l10n.styleEditor_alert_label, l10n.styleEditor_alert_subtitle);
    case 'me':
      return (l10n.styleEditor_me_label, l10n.styleEditor_me_subtitle);
    case 'meInk':
      return (l10n.styleEditor_meInk_label, l10n.styleEditor_meInk_subtitle);
    case 'mapOnline':
      return (
        l10n.styleEditor_mapOnline_label,
        l10n.styleEditor_mapOnline_subtitle,
      );
    case 'mapOffline':
      return (
        l10n.styleEditor_mapOffline_label,
        l10n.styleEditor_mapOffline_subtitle,
      );
    case 'mapStale':
      return (
        l10n.styleEditor_mapStale_label,
        l10n.styleEditor_mapStale_subtitle,
      );
    case 'mapRepeater':
      return (
        l10n.styleEditor_mapRepeater_label,
        l10n.styleEditor_mapRepeater_subtitle,
      );
    case 'mapRouter':
      return (
        l10n.styleEditor_mapRouter_label,
        l10n.styleEditor_mapRouter_subtitle,
      );
    case 'mapBatteryLow':
      return (
        l10n.styleEditor_mapBatteryLow_label,
        l10n.styleEditor_mapBatteryLow_subtitle,
      );
    case 'mapCluster':
      return (
        l10n.styleEditor_mapCluster_label,
        l10n.styleEditor_mapCluster_subtitle,
      );
    case 'mapSelected':
      return (
        l10n.styleEditor_mapSelected_label,
        l10n.styleEditor_mapSelected_subtitle,
      );
    case 'mapSensor':
      return (
        l10n.styleEditor_mapSensor_label,
        l10n.styleEditor_mapSensor_subtitle,
      );
    case 'mapShared':
      return (
        l10n.styleEditor_mapShared_label,
        l10n.styleEditor_mapShared_subtitle,
      );
    case 'mapPanelLight':
      return (
        l10n.styleEditor_mapPanelLight_label,
        l10n.styleEditor_mapPanelLight_subtitle,
      );
    case 'mapPanelDark':
      return (
        l10n.styleEditor_mapPanelDark_label,
        l10n.styleEditor_mapPanelDark_subtitle,
      );
    case 'mapTextPrimary':
      return (
        l10n.styleEditor_mapTextPrimary_label,
        l10n.styleEditor_mapTextPrimary_subtitle,
      );
    case 'mapTextSecondary':
      return (
        l10n.styleEditor_mapTextSecondary_label,
        l10n.styleEditor_mapTextSecondary_subtitle,
      );
    case 'mapTextMuted':
      return (
        l10n.styleEditor_mapTextMuted_label,
        l10n.styleEditor_mapTextMuted_subtitle,
      );
    case 'mapBorder':
      return (
        l10n.styleEditor_mapBorder_label,
        l10n.styleEditor_mapBorder_subtitle,
      );
    case 'mapMarkerOutline':
      return (
        l10n.styleEditor_mapMarkerOutline_label,
        l10n.styleEditor_mapMarkerOutline_subtitle,
      );
    case 'mapMarkerShadow':
      return (
        l10n.styleEditor_mapMarkerShadow_label,
        l10n.styleEditor_mapMarkerShadow_subtitle,
      );
    case 'losTerrain':
      return (
        l10n.styleEditor_losTerrain_label,
        l10n.styleEditor_losTerrain_subtitle,
      );
    case 'losBeam':
      return (
        l10n.styleEditor_losBeam_label,
        l10n.styleEditor_losBeam_subtitle,
      );
    case 'losHorizon':
      return (
        l10n.styleEditor_losHorizon_label,
        l10n.styleEditor_losHorizon_subtitle,
      );
    case 'losBlocked':
      return (
        l10n.styleEditor_losBlocked_label,
        l10n.styleEditor_losBlocked_subtitle,
      );
    case 'losMarginal':
      return (
        l10n.styleEditor_losMarginal_label,
        l10n.styleEditor_losMarginal_subtitle,
      );
    case 'losClear':
      return (
        l10n.styleEditor_losClear_label,
        l10n.styleEditor_losClear_subtitle,
      );
    case 'losSelected':
      return (
        l10n.styleEditor_losSelected_label,
        l10n.styleEditor_losSelected_subtitle,
      );
    case 'losChartBackground':
      return (
        l10n.styleEditor_losChartBackground_label,
        l10n.styleEditor_losChartBackground_subtitle,
      );
    case 'losPanelDark':
      return (
        l10n.styleEditor_losPanelDark_label,
        l10n.styleEditor_losPanelDark_subtitle,
      );
    case 'losPanelLight':
      return (
        l10n.styleEditor_losPanelLight_label,
        l10n.styleEditor_losPanelLight_subtitle,
      );
    case 'losText':
      return (
        l10n.styleEditor_losText_label,
        l10n.styleEditor_losText_subtitle,
      );
    case 'losTextMuted':
      return (
        l10n.styleEditor_losTextMuted_label,
        l10n.styleEditor_losTextMuted_subtitle,
      );
    case 'losBorder':
      return (
        l10n.styleEditor_losBorder_label,
        l10n.styleEditor_losBorder_subtitle,
      );
    case 'losShadow':
      return (
        l10n.styleEditor_losShadow_label,
        l10n.styleEditor_losShadow_subtitle,
      );
    default:
      throw ArgumentError('Unknown color field key: $key');
  }
}

String _fontFieldLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'bodyMedium':
      return l10n.styleEditor_bodyMedium_label;
    case 'bodySmall':
      return l10n.styleEditor_bodySmall_label;
    case 'titleSmall':
      return l10n.styleEditor_titleSmall_label;
    case 'labelSmall':
      return l10n.styleEditor_labelSmall_label;
    case 'labelMedium':
      return l10n.styleEditor_labelMedium_label;
    case 'monoCaptionSize':
      return l10n.styleEditor_monoCaptionSize_label;
    case 'monoBodySize':
      return l10n.styleEditor_monoBodySize_label;
    default:
      throw ArgumentError('Unknown font field key: $key');
  }
}

String _fontFieldSubtitle(AppLocalizations l10n, String key) {
  switch (key) {
    case 'bodyMedium':
      return l10n.styleEditor_bodyMedium_subtitle;
    case 'bodySmall':
      return l10n.styleEditor_bodySmall_subtitle;
    case 'titleSmall':
      return l10n.styleEditor_titleSmall_subtitle;
    case 'labelSmall':
      return l10n.styleEditor_labelSmall_subtitle;
    case 'labelMedium':
      return l10n.styleEditor_labelMedium_subtitle;
    case 'monoCaptionSize':
      return l10n.styleEditor_monoCaptionSize_subtitle;
    case 'monoBodySize':
      return l10n.styleEditor_monoBodySize_subtitle;
    default:
      throw ArgumentError('Unknown font field key: $key');
  }
}

// A compact preset palette for the color picker sheet — common hues at a
// couple of lightness steps, not tied to any single brand.
const List<Color> _presetSwatches = [
  Color(0xFF000000),
  Color(0xFF1A1A1A),
  Color(0xFF334155),
  Color(0xFF64748B),
  Color(0xFF94A3B8),
  Color(0xFFCBD5E1),
  Color(0xFFF1F5F9),
  Color(0xFFFFFFFF),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF10B981),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFA855F7),
  Color(0xFFD946EF),
  Color(0xFFEC4899),
];

/// Editor for the "custom" [MeshStyle]: base colors, collapsible Map/LOS
/// palettes (32 fields, A6), and font-size roles, layered on top of
/// [defaultStyle] via [CustomStyleOverrides]. Every row supports per-field
/// reset; "Reset all" at the bottom clears every override after
/// confirmation (D1, 04-editor-ui.md).
class CustomStyleEditorScreen extends StatefulWidget {
  const CustomStyleEditorScreen({super.key});

  @override
  State<CustomStyleEditorScreen> createState() =>
      _CustomStyleEditorScreenState();
}

class _CustomStyleEditorScreenState extends State<CustomStyleEditorScreen> {
  Brightness? _editedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the switch from the app's current theme on first build only —
    // afterwards the user's own tap on the segment is the source of truth,
    // independent of whatever brightness the app happens to be rendering.
    _editedBrightness ??= Theme.of(context).brightness;
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) — this fixes known-issues pkt 6 too (Font sizes
    // tab had no working selection since the global SelectionArea sat
    // above the Navigator and its Overlay-hosting workaround interfered).
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final brightness = _editedBrightness!;
    return Consumer<AppSettingsService>(
      builder: (context, settingsService, child) {
        final l10n = context.l10n;
        final scheme = Theme.of(context).colorScheme;
        final overrides = settingsService.settings.customStyleOverrides;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.styleEditor_title),
            centerTitle: true,
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Center(
                    child: SegmentedButton<Brightness>(
                      key: const ValueKey('brightnessSwitch'),
                      segments: [
                        ButtonSegment(
                          value: Brightness.light,
                          label: Text(l10n.styleEditor_brightnessLight),
                        ),
                        ButtonSegment(
                          value: Brightness.dark,
                          label: Text(l10n.styleEditor_brightnessDark),
                        ),
                      ],
                      selected: {brightness},
                      onSelectionChanged: (selection) =>
                          setState(() => _editedBrightness = selection.first),
                    ),
                  ),
                ),
                SectionHeader(l10n.styleEditor_colorsSection),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _baseColorFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _ColorFieldRow(
                          key: ValueKey('colorRow_${_baseColorFields[i].key}'),
                          spec: _baseColorFields[i],
                          overrides: overrides,
                          settingsService: settingsService,
                          brightness: brightness,
                        ),
                      ],
                    ],
                  ),
                ),
                _ColorSectionExpansionTile(
                  key: const ValueKey('mapSection'),
                  title: l10n.styleEditor_mapSection,
                  fields: _mapColorFields,
                  overrides: overrides,
                  settingsService: settingsService,
                  brightness: brightness,
                ),
                _ColorSectionExpansionTile(
                  key: const ValueKey('losSection'),
                  title: l10n.styleEditor_losSection,
                  fields: _losColorFields,
                  overrides: overrides,
                  settingsService: settingsService,
                  brightness: brightness,
                ),
                SectionHeader(l10n.styleEditor_fontSizesSection),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.styleEditor_fontSizesIntro,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _fontFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _FontFieldRow(
                          key: ValueKey('fontRow_${_fontFields[i].key}'),
                          spec: _fontFields[i],
                          overrides: overrides,
                          settingsService: settingsService,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('resetAllButton'),
                      onPressed: () =>
                          _confirmResetAll(context, settingsService),
                      child: Text(l10n.styleEditor_resetAll),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmResetAll(
    BuildContext context,
    AppSettingsService settingsService,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.styleEditor_resetAll),
        content: Text(l10n.styleEditor_resetAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            key: const ValueKey('confirmResetAllButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.styleEditor_resetAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settingsService.resetAllCustomOverrides();
    }
  }
}

/// A collapsed-by-default section of color rows (Map/LOS palettes, A6).
class _ColorSectionExpansionTile extends StatelessWidget {
  const _ColorSectionExpansionTile({
    super.key,
    required this.title,
    required this.fields,
    required this.overrides,
    required this.settingsService,
    required this.brightness,
  });

  final String title;
  final List<_ColorFieldSpec> fields;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return MeshCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(title),
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            _ColorFieldRow(
              key: ValueKey('colorRow_${fields[i].key}'),
              spec: fields[i],
              overrides: overrides,
              settingsService: settingsService,
              brightness: brightness,
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorFieldRow extends StatelessWidget {
  const _ColorFieldRow({
    super.key,
    required this.spec,
    required this.overrides,
    required this.settingsService,
    required this.brightness,
  });

  final _ColorFieldSpec spec;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, subtitle) = _colorFieldText(l10n, spec.key);
    final override = overrides.colorOverridesFor(brightness)[spec.key];
    final currentColor = override != null
        ? Color(override)
        : spec.defaultColorFor(brightness);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(label),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      onTap: () => _openColorPicker(context, currentColor, label),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline),
        ),
      ),
      trailing: override == null
          ? null
          : IconButton(
              key: ValueKey('resetIcon_${spec.key}'),
              icon: const Icon(Icons.settings_backup_restore, size: 20),
              tooltip: l10n.styleEditor_resetTooltip,
              onPressed: () => settingsService.resetCustomColorOverride(
                spec.key,
                brightness,
              ),
            ),
    );
  }

  void _openColorPicker(
    BuildContext context,
    Color currentColor,
    String title,
  ) {
    showMeshSheet<void>(
      context,
      builder: (sheetContext) => _ColorPickerSheet(
        title: title,
        currentColor: currentColor,
        onColorSelected: (color) {
          settingsService.setCustomColorOverride(
            spec.key,
            color,
            brightness: brightness,
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.currentColor,
    required this.onColorSelected,
  });

  final String title;
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final TextEditingController _hexController;
  String? _hexError;

  static final RegExp _hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text:
          '#${widget.currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex() {
    final match = _hexPattern.firstMatch(_hexController.text.trim());
    if (match == null) {
      setState(() => _hexError = context.l10n.styleEditor_hexError);
      return;
    }
    final value = int.parse(match.group(1)!, radix: 16);
    widget.onColorSelected(Color(0xFF000000 | value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // showMeshSheet's useSafeArea only guards the top edge — the sheet body
    // must clear the system navigation bar itself.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(title: widget.title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in _presetSwatches)
                  GestureDetector(
                    key: ValueKey('swatch_${swatch.toARGB32()}'),
                    onTap: () => widget.onColorSelected(swatch),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: swatch,
                      child: swatch.toARGB32() == widget.currentColor.toARGB32()
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color:
                                  ThemeData.estimateBrightnessForColor(
                                        swatch,
                                      ) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _hexController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: l10n.styleEditor_hexLabel,
                hintText: l10n.styleEditor_hexHint,
                errorText: _hexError,
                suffixIcon: IconButton(
                  key: const ValueKey('applyHexButton'),
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    setState(() => _hexError = null);
                    _applyHex();
                  },
                ),
              ),
              onChanged: (_) => setState(() => _hexError = null),
              onSubmitted: (_) => _applyHex(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontFieldRow extends StatelessWidget {
  const _FontFieldRow({
    super.key,
    required this.spec,
    required this.overrides,
    required this.settingsService,
  });

  final _FontFieldSpec spec;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;

  static const double _minSize = 8;
  static const double _maxSize = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _fontFieldLabel(l10n, spec.key);
    final subtitle = _fontFieldSubtitle(l10n, spec.key);
    final override = overrides.fontSizeOverrides[spec.key];
    final currentSize = (override ?? spec.defaultSize).clamp(
      _minSize,
      _maxSize,
    );
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      subtitle: Slider(
        value: currentSize,
        min: _minSize,
        max: _maxSize,
        divisions: ((_maxSize - _minSize) * 2).round(),
        label: currentSize.toStringAsFixed(1),
        onChanged: (value) =>
            settingsService.setCustomFontSizeOverride(spec.key, value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${currentSize.toStringAsFixed(1)}pt'),
          if (override != null)
            IconButton(
              key: ValueKey('resetIcon_${spec.key}'),
              icon: const Icon(Icons.settings_backup_restore, size: 20),
              tooltip: l10n.styleEditor_resetTooltip,
              onPressed: () =>
                  settingsService.resetCustomFontSizeOverride(spec.key),
            ),
        ],
      ),
    );
  }
}
