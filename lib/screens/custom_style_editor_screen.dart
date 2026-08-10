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

// Only the LOS colors with NO equivalent in the main palette stay editable
// here — the chrome/status LOS tokens (panels, text, border, blocked/clear/
// marginal/selected, chart bg) now derive from the main Colors tab
// (bg/ink/line/alert/signal/warn/primary), so editing them separately was
// redundant (user decision 2026-08-10). These three are genuine chart data
// hues; their default swatch is read LIVE (they derive from the accents),
// so the picker shows the actually-applied color for the edited brightness.
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
];

/// The live (currently-applied) value of an editable LOS data token — used as
/// the picker's default swatch so it matches the derived-from-accent color.
Color _liveLosColor(MeshTokens tokens, String key) => switch (key) {
  'losTerrain' => tokens.losTerrain,
  'losBeam' => tokens.losBeam,
  'losHorizon' => tokens.losHorizon,
  _ => throw ArgumentError('Not a live-default LOS key: $key'),
};

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

class _SpacingFieldSpec {
  const _SpacingFieldSpec(this.key, this.defaultValue, this.min, this.max);
  final String key;
  final double defaultValue;
  final double min;
  final double max;
}

final List<_SpacingFieldSpec> _spacingFields = [
  _SpacingFieldSpec('spacingXxs', MeshTokens.defaultTokens.spacingXxs, 2, 12),
  _SpacingFieldSpec('spacingXs', MeshTokens.defaultTokens.spacingXs, 4, 16),
  _SpacingFieldSpec('spacingSm', MeshTokens.defaultTokens.spacingSm, 6, 20),
  _SpacingFieldSpec('spacingMd', MeshTokens.defaultTokens.spacingMd, 8, 28),
  _SpacingFieldSpec('spacingLg', MeshTokens.defaultTokens.spacingLg, 16, 40),
  _SpacingFieldSpec('spacingXlg', MeshTokens.defaultTokens.spacingXlg, 20, 52),
  _SpacingFieldSpec(
    'spacingXxlg',
    MeshTokens.defaultTokens.spacingXxlg,
    32,
    72,
  ),
];

final List<_SpacingFieldSpec> _radiusFields = [
  _SpacingFieldSpec('xs', MeshTokens.defaultTokens.xs, 0, 16),
  _SpacingFieldSpec('sm', MeshTokens.defaultTokens.sm, 4, 20),
  _SpacingFieldSpec('md', MeshTokens.defaultTokens.md, 6, 24),
  _SpacingFieldSpec('lg', MeshTokens.defaultTokens.lg, 10, 32),
  _SpacingFieldSpec('xl', MeshTokens.defaultTokens.xl, 14, 40),
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

(String, String) _spacingFieldText(AppLocalizations l10n, String key) {
  switch (key) {
    case 'spacingXxs':
      return (
        l10n.styleEditor_spacingXxs_label,
        l10n.styleEditor_spacingXxs_subtitle,
      );
    case 'spacingXs':
      return (
        l10n.styleEditor_spacingXs_label,
        l10n.styleEditor_spacingXs_subtitle,
      );
    case 'spacingSm':
      return (
        l10n.styleEditor_spacingSm_label,
        l10n.styleEditor_spacingSm_subtitle,
      );
    case 'spacingMd':
      return (
        l10n.styleEditor_spacingMd_label,
        l10n.styleEditor_spacingMd_subtitle,
      );
    case 'spacingLg':
      return (
        l10n.styleEditor_spacingLg_label,
        l10n.styleEditor_spacingLg_subtitle,
      );
    case 'spacingXlg':
      return (
        l10n.styleEditor_spacingXlg_label,
        l10n.styleEditor_spacingXlg_subtitle,
      );
    case 'spacingXxlg':
      return (
        l10n.styleEditor_spacingXxlg_label,
        l10n.styleEditor_spacingXxlg_subtitle,
      );
    default:
      throw ArgumentError('Unknown spacing field key: $key');
  }
}

(String, String) _radiusFieldText(AppLocalizations l10n, String key) {
  switch (key) {
    case 'xs':
      return (
        l10n.styleEditor_radiusXs_label,
        l10n.styleEditor_radiusXs_subtitle,
      );
    case 'sm':
      return (
        l10n.styleEditor_radiusSm_label,
        l10n.styleEditor_radiusSm_subtitle,
      );
    case 'md':
      return (
        l10n.styleEditor_radiusMd_label,
        l10n.styleEditor_radiusMd_subtitle,
      );
    case 'lg':
      return (
        l10n.styleEditor_radiusLg_label,
        l10n.styleEditor_radiusLg_subtitle,
      );
    case 'xl':
      return (
        l10n.styleEditor_radiusXl_label,
        l10n.styleEditor_radiusXl_subtitle,
      );
    default:
      throw ArgumentError('Unknown radius field key: $key');
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
                      // Switching the edited palette also switches the APP
                      // theme to that brightness (user decision 2026-08-10)
                      // — otherwise you edit light values while looking at
                      // the dark UI and never see what you're changing.
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        setState(() => _editedBrightness = next);
                        settingsService.setThemeMode(
                          next == Brightness.light ? 'light' : 'dark',
                        );
                      },
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
                  liveLosDefaults: true,
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
                SectionHeader(l10n.styleEditor_spacingSection),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _spacingFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        Builder(
                          builder: (context) {
                            final spec = _spacingFields[i];
                            final (label, subtitle) = _spacingFieldText(
                              l10n,
                              spec.key,
                            );
                            final override =
                                overrides.spacingOverrides[spec.key];
                            return _TokenFieldRow(
                              key: ValueKey('spacingRow_${spec.key}'),
                              spec: spec,
                              kind: _TokenPreviewKind.spacing,
                              currentValue: override ?? spec.defaultValue,
                              hasOverride: override != null,
                              label: label,
                              subtitle: subtitle,
                              onChanged: (v) => settingsService
                                  .setCustomSpacingOverride(spec.key, v),
                              onReset: () => settingsService
                                  .resetCustomSpacingOverride(spec.key),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SectionHeader(l10n.styleEditor_radiusSection),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _radiusFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        Builder(
                          builder: (context) {
                            final spec = _radiusFields[i];
                            final (label, subtitle) = _radiusFieldText(
                              l10n,
                              spec.key,
                            );
                            final override =
                                overrides.radiusOverrides[spec.key];
                            return _TokenFieldRow(
                              key: ValueKey('radiusRow_${spec.key}'),
                              spec: spec,
                              kind: _TokenPreviewKind.radius,
                              currentValue: override ?? spec.defaultValue,
                              hasOverride: override != null,
                              label: label,
                              subtitle: subtitle,
                              onChanged: (v) => settingsService
                                  .setCustomRadiusOverride(spec.key, v),
                              onReset: () => settingsService
                                  .resetCustomRadiusOverride(spec.key),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SectionHeader(l10n.styleEditor_cardSection),
                MeshCard(
                  padding: EdgeInsets.zero,
                  // Live preview ON THIS CARD (Wariant C): the switch drives
                  // the shadow of its own section card, regardless of which
                  // style is currently active in the app.
                  elevated: overrides.cardElevated ?? true,
                  child: SwitchListTile(
                    key: const ValueKey('cardShadowSwitch'),
                    title: Text(l10n.styleEditor_cardShadow_label),
                    subtitle: Text(l10n.styleEditor_cardShadow_subtitle),
                    value: overrides.cardElevated ?? true,
                    onChanged: (v) => settingsService.setCustomCardElevated(v),
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
    this.liveLosDefaults = false,
  });

  final String title;
  final List<_ColorFieldSpec> fields;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;
  final Brightness brightness;

  /// When true, each row's default swatch reads the live applied token
  /// (via [_liveLosColor]) instead of the spec's fixed default — used for the
  /// LOS data colors, whose defaults derive from the theme accents.
  final bool liveLosDefaults;

  @override
  Widget build(BuildContext context) {
    final tokens = liveLosDefaults ? MeshTokens.of(context) : null;
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
              liveDefaultColor: tokens == null
                  ? null
                  : _liveLosColor(tokens, fields[i].key),
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
    this.liveDefaultColor,
  });

  final _ColorFieldSpec spec;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;
  final Brightness brightness;

  /// Overrides the swatch shown when there's no explicit override — used for
  /// LOS data colors whose default derives live from the theme accents.
  final Color? liveDefaultColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, subtitle) = _colorFieldText(l10n, spec.key);
    final override = overrides.colorOverridesFor(brightness)[spec.key];
    final currentColor = override != null
        ? Color(override)
        : (liveDefaultColor ?? spec.defaultColorFor(brightness));
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
      // pkt 2: the reset affordance stays visible on every row (disabled
      // when there's nothing to reset) instead of disappearing — a hidden
      // trailing widget reads as "no reset exists for this field".
      trailing: IconButton(
        key: ValueKey('resetIcon_${spec.key}'),
        icon: const Icon(Icons.settings_backup_restore, size: 20),
        tooltip: l10n.styleEditor_resetTooltip,
        onPressed: override == null
            ? null
            : () => settingsService.resetCustomColorOverride(
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
        onPreviewChanged: (color) => settingsService.setCustomColorOverride(
          spec.key,
          color,
          brightness: brightness,
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.currentColor,
    required this.onColorSelected,
    this.onPreviewChanged,
  });

  final String title;
  final Color currentColor;
  // One-shot pick (swatch tap, hex confirm, example chip) — applies AND
  // closes the sheet, per the caller's wiring in _openColorPicker.
  final ValueChanged<Color> onColorSelected;
  // Continuous adjustment (the tint slider) — applies live without
  // closing. Optional because only the slider needs it.
  final ValueChanged<Color>? onPreviewChanged;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

// A compact, functional reference — not the full preset grid above —
// distinct base hues with their hex spelled out so a user unfamiliar with
// the format can see what a value looks like. Tapping applies immediately,
// same as tapping a preset swatch (pkt 3c).
const List<Color> _exampleSwatches = [
  Color(0xFFFFFFFF),
  Color(0xFF000000),
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
];

// pkt 3b: tick marks stay a single color across the whole track (not
// active/inactive-shaded) and are only differentiated by size — larger
// every 25%, smaller every 5% in between. Flutter positions `center`
// using the real track/thumb geometry, so alignment is exact regardless
// of what this shape draws.
class _TintTickMarkShape extends SliderTickMarkShape {
  const _TintTickMarkShape();

  static const double _minorRadius = 2;
  static const double _majorRadius = 3;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) => const Size.fromRadius(_majorRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required bool isEnabled,
    required Offset thumbCenter,
  }) {
    // `center` is this tick's own position; there's no direct "which
    // division is this" parameter, so derive it from the track rect the
    // same way Slider itself lays ticks out.
    final trackRect = sliderTheme.trackShape!.getPreferredRect(
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      isDiscrete: true,
    );
    final fraction = trackRect.width == 0
        ? 0.0
        : ((center.dx - trackRect.left) / trackRect.width).clamp(0.0, 1.0);
    final isMajor = (fraction * 100).round() % 25 == 0;
    final paint = Paint()
      ..color = sliderTheme.activeTickMarkColor ?? Colors.transparent;
    context.canvas.drawCircle(
      center,
      isMajor ? _majorRadius : _minorRadius,
      paint,
    );
  }
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final TextEditingController _hexController;
  String? _hexError;

  // pkt 3b: hue/saturation are captured once and held fixed — the slider
  // only ever moves lightness, so it can't drift the color's hue on
  // repeated small adjustments (recomputing from the live preview color
  // each time would compound rounding through the RGB<->HSL round trip).
  late final double _hue;
  late final double _saturation;
  late double _lightness;
  late Color _previewColor;

  static final RegExp _hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');

  @override
  void initState() {
    super.initState();
    _previewColor = widget.currentColor;
    final hsl = HSLColor.fromColor(widget.currentColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.styleEditor_tintLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SliderTheme(
                  data: Theme.of(context).sliderTheme.copyWith(
                    showValueIndicator: ShowValueIndicator.alwaysVisible,
                    tickMarkShape: const _TintTickMarkShape(),
                    activeTickMarkColor: MeshTokens.of(
                      context,
                    ).ink.withValues(alpha: 0.55),
                    inactiveTickMarkColor: MeshTokens.of(
                      context,
                    ).ink.withValues(alpha: 0.55),
                  ),
                  child: Slider(
                    key: const ValueKey('tintSlider'),
                    value: _lightness,
                    divisions: 20,
                    // Leading/trailing spaces widen the measured label text
                    // beyond the digits themselves — the bubble shape sizes
                    // itself to that measurement, so this buys visual
                    // breathing room without fighting the shape's own
                    // (otherwise tight) internal padding.
                    label: ' ${(_lightness * 100).round()}% ',
                    // Live-applies on every step WITHOUT closing the sheet —
                    // unlike every other control here (swatches, hex), a
                    // slider is inherently a multi-step adjustment, not a
                    // single pick. Closing on each change (the original
                    // bug) made it unusable.
                    onChanged: (v) => setState(() {
                      _lightness = v;
                      _previewColor = HSLColor.fromAHSL(
                        1.0,
                        _hue,
                        _saturation,
                        v,
                      ).toColor();
                      _hexController.text =
                          '#${_previewColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                      _hexError = null;
                      widget.onPreviewChanged?.call(_previewColor);
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.styleEditor_hexExamplesCaption,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final example in _exampleSwatches)
                      GestureDetector(
                        key: ValueKey('example_${example.toARGB32()}'),
                        onTap: () => widget.onColorSelected(example),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: example,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '#${example.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                                style: MeshTokens.of(context).mono(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
      // pkt 2: reset stays visible (disabled when nothing to reset) — see
      // the matching comment on _ColorFieldRow.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${currentSize.toStringAsFixed(1)}pt'),
          IconButton(
            key: ValueKey('resetIcon_${spec.key}'),
            icon: const Icon(Icons.settings_backup_restore, size: 20),
            tooltip: l10n.styleEditor_resetTooltip,
            onPressed: override == null
                ? null
                : () => settingsService.resetCustomFontSizeOverride(spec.key),
          ),
        ],
      ),
    );
  }
}

/// Wariant C (mockup 2026-08-10): slider row with a LIVE mini-preview.
/// kind == spacing: two 16x16 blocks with a gap bar whose width == value.
/// kind == radius: a 34x26 outlined box whose top-left corner radius == value.
enum _TokenPreviewKind { spacing, radius }

class _TokenFieldRow extends StatelessWidget {
  const _TokenFieldRow({
    super.key,
    required this.spec,
    required this.kind,
    required this.currentValue,
    required this.hasOverride,
    required this.label,
    required this.subtitle,
    required this.onChanged,
    required this.onReset,
  });

  final _SpacingFieldSpec spec;
  final _TokenPreviewKind kind;
  final double currentValue;
  final bool hasOverride;
  final String label;
  final String subtitle;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  Widget _preview(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    switch (kind) {
      case _TokenPreviewKind.spacing:
        Widget block() => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            block(),
            Container(
              width: currentValue,
              height: 6,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            block(),
          ],
        );
      case _TokenPreviewKind.radius:
        return Container(
          width: 34,
          height: 26,
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 2),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(currentValue),
              topRight: const Radius.circular(4),
              bottomLeft: const Radius.circular(4),
              bottomRight: const Radius.circular(4),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final value = currentValue.clamp(spec.min, spec.max).toDouble();
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
      subtitle: Row(
        children: [
          _preview(context),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: value,
              min: spec.min,
              max: spec.max,
              divisions: (spec.max - spec.min).round(),
              label: value.toStringAsFixed(0),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${value.toStringAsFixed(0)}dp'),
          IconButton(
            key: ValueKey('resetIcon_${spec.key}'),
            icon: const Icon(Icons.settings_backup_restore, size: 20),
            tooltip: l10n.styleEditor_resetTooltip,
            onPressed: hasOverride ? onReset : null,
          ),
        ],
      ),
    );
  }
}
