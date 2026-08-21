import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meshnomad/utils/gpx_export.dart';
import 'package:meshnomad/widgets/elements_ui.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../models/radio_settings.dart';
import '../services/app_settings_service.dart';
import '../services/app_debug_log_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/app_bar.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import 'app_settings_screen.dart';
import 'app_debug_log_screen.dart';
import 'ble_debug_log_screen.dart';
import 'packet_stats_screen.dart';
import '../widgets/radio_stats_entry.dart';
import '../widgets/sync_progress_overlay.dart';
import 'region_management_screen.dart';

/// Convert device coding-rate value (1-4 on some firmware, 5-8 on others)
/// to the UI enum range (always 5-8).
int _toUiCodingRate(int deviceCr) {
  return deviceCr <= 4 ? deviceCr + 4 : deviceCr;
}

/// Convert UI coding-rate value (5-8) back to firmware encoding.
/// Uses the current device CR to detect which encoding the firmware expects.
int _toDeviceCodingRate(int uiCr, int? deviceCr) {
  if (deviceCr != null && deviceCr <= 4) {
    return uiCr - 4;
  }
  return uiCr;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showBatteryVoltage = false;
  bool _deviceInfoExpanded = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true. This screen is
    // the likely source of the "open source"/version text fragment
    // reported in known-issues pkt 2 (settings_aboutDescription/About row).
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          l10n.settings_title,
          indicators: false,
          subtitle: false,
        ),
        centerTitle: true,
        bottom: const SyncProgressAppBarBottom(),
      ),
      body: SafeArea(
        top: false,
        child: Consumer<MeshCoreConnector>(
          builder: (context, connector, child) {
            final t = MeshTokens.of(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(0, t.spacingXs, 0, t.spacingLg),
              children: [
                // IDENTITY section
                SectionHeader(l10n.settings_deviceInfo),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildIdentityCardContent(context, connector),
                ),

                // NODE section
                SectionHeader(l10n.settings_nodeSettings),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildNodeCardContent(context, connector),
                ),

                // LOCATION section
                SectionHeader(l10n.settings_location),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildLocationCardContent(context, connector),
                ),

                // APP SETTINGS
                SectionHeader(l10n.settings_appSettings),
                MeshCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppSettingsScreen(),
                    ),
                  ),
                  child: _buildNavTileContent(
                    context,
                    icon: Icons.settings_outlined,
                    title: l10n.settings_appSettings,
                    subtitle: l10n.settings_appSettingsSubtitle,
                  ),
                ),

                // ACTIONS section
                SectionHeader(l10n.settings_actions),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildActionsCardContent(context, connector),
                ),

                // EXPORT section
                SectionHeader(l10n.settings_gpxExportRepeaters),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildExportCardContent(context, connector),
                ),

                // DEBUG section
                SectionHeader(l10n.settings_debug),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildDebugCardContent(context),
                ),

                // ABOUT
                SectionHeader(l10n.settings_about),
                MeshCard(
                  onTap: () => _showAbout(context),
                  child: _buildNavTileContent(
                    context,
                    icon: Icons.info_outline,
                    title: l10n.settings_about,
                    subtitle: l10n.settings_aboutVersion(
                      _appVersion.isEmpty ? l10n.common_loading : _appVersion,
                    ),
                    showChevron: false,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavTileContent(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool showChevron = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: t.primary),
        SizedBox(width: t.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showChevron)
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 16),
      ],
    );
  }

  Widget _buildIdentityCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: device name + status chip + expand toggle
        InkWell(
          onTap: () {
            setState(() {
              _deviceInfoExpanded = !_deviceInfoExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(t.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connector.deviceDisplayName,
                        style: MeshTokens.of(context).mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      SizedBox(height: t.spacingXxs),
                      StatusChip(
                        label: connector.isConnected
                            ? l10n.common_connected
                            : l10n.common_disconnected,
                        color: connector.isConnected
                            ? MeshTokens.of(context).primary
                            : scheme.onSurfaceVariant,
                        pulse: connector.isConnected,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _deviceInfoExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: MeshTokens.of(context).primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expandable detail rows
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _deviceInfoExpanded
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spacingMd,
                    0,
                    t.spacingMd,
                    t.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MeshDashedDivider(),
                      SizedBox(height: t.spacingSm),
                      _infoRow(
                        context,
                        label: l10n.settings_infoId,
                        value: connector.deviceIdLabel,
                      ),
                      _buildBatteryInfoRow(context, connector),
                      if (connector.selfName != null)
                        _infoRow(
                          context,
                          label: l10n.settings_nodeName,
                          value: connector.selfName!,
                        ),
                      if (connector.selfPublicKey != null)
                        _infoRow(
                          context,
                          label: l10n.settings_infoPublicKey,
                          value:
                              '${pubKeyToHex(connector.selfPublicKey!).substring(0, 16)}...',
                          mono: true,
                        ),
                      _infoRow(
                        context,
                        label: l10n.settings_infoContactsCount,
                        value: '${connector.contacts.length}',
                      ),
                      _infoRow(
                        context,
                        label: l10n.settings_infoChannelCount,
                        value: '${connector.channels.length}',
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    bool mono = false,
    Widget? leading,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);

    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: t.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading, SizedBox(width: t.spacingXs)],
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          mono
              ? Text(
                  value,
                  style: MeshTokens.of(context).monoBody(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? scheme.onSurface,
                  ),
                )
              : Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(MeshTokens.of(context).xs),
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Widget _buildBatteryInfoRow(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    final percent = connector.batteryPercent;
    final millivolts = connector.batteryMillivolts;

    final String displayValue;
    if (millivolts == null) {
      displayValue = l10n.common_notAvailable;
    } else if (_showBatteryVoltage) {
      displayValue = l10n.common_voltageValue(
        (millivolts / 1000.0).toStringAsFixed(2),
      );
    } else {
      displayValue = percent != null
          ? l10n.common_percentValue(percent)
          : l10n.common_notAvailable;
    }

    final IconData icon;
    final Color? iconColor;
    final Color? valueColor;

    if (percent == null) {
      icon = Icons.battery_unknown;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
      valueColor = null;
    } else if (percent <= 15) {
      icon = Icons.battery_alert;
      iconColor = Theme.of(context).colorScheme.tertiary;
      valueColor = Theme.of(context).colorScheme.tertiary;
    } else {
      icon = Icons.battery_full;
      iconColor = MeshTokens.of(context).primary;
      valueColor = null;
    }

    return _infoRow(
      context,
      label: l10n.settings_infoBattery,
      value: displayValue,
      leading: Icon(icon, size: 14, color: iconColor),
      valueColor: valueColor,
      onTap: millivolts != null
          ? () {
              setState(() {
                _showBatteryVoltage = !_showBatteryVoltage;
              });
            }
          : null,
    );
  }

  Widget _buildNodeCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        _tappableTile(
          context,
          icon: Icons.person_outline,
          title: l10n.settings_nodeName,
          subtitle: connector.selfName ?? l10n.settings_nodeNameNotSet,
          onTap: () => _editNodeName(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.radio,
          title: l10n.settings_radioSettings,
          subtitle: l10n.settings_radioSettingsSubtitle,
          onTap: () => _showRadioSettings(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.landscape,
          title: l10n.settings_regionSettings,
          subtitle: l10n.settings_regionSettingsSubtitle,
          onTap: () => pushRegionManagementScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.sensors_outlined,
          title: l10n.radioStats_settingsTile,
          subtitle: l10n.radioStats_settingsSubtitle,
          onTap: connector.isConnected && connector.supportsCompanionRadioStats
              ? () => pushCompanionRadioStatsScreen(context)
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.bar_chart,
          title: l10n.packetStats_settingsTile,
          subtitle: l10n.packetStats_settingsSubtitle,
          onTap: connector.isConnected
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PacketStatsScreen()),
                )
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.route_outlined,
          title: l10n.repeater_pathHashMode,
          subtitle: _pathHashModeSubtitle(context, connector.pathHashByteWidth),
          onTap: connector.isConnected
              ? () => _editPathHashMode(context, connector)
              : null,
        ),
      ],
    );
  }

  String _pathHashModeSubtitle(BuildContext context, int pathHashByteWidth) {
    final l10n = context.l10n;
    return switch (pathHashByteWidth.clamp(1, 4).toInt()) {
      1 => l10n.repeater_pathHashModeOption0,
      2 => l10n.repeater_pathHashModeOption1,
      3 => l10n.repeater_pathHashModeOption2,
      _ => l10n.repeater_pathHashModeOption3,
    };
  }

  Widget _buildLocationCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        _tappableTile(
          context,
          icon: Icons.location_on_outlined,
          title: l10n.settings_location,
          subtitle: l10n.settings_locationSubtitle,
          onTap: () => _editLocation(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.group_add_outlined,
          title: l10n.settings_contactSettings,
          subtitle: l10n.settings_contactSettingsSubtitle,
          onTap: () => _editAutoAddConfig(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.visibility_off_outlined,
          title: l10n.settings_privacy,
          subtitle: l10n.settings_privacySubtitle,
          onTap: () => _privacySettings(context, connector),
        ),
      ],
    );
  }

  Widget _buildActionsCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        _tappableTile(
          context,
          icon: Icons.sync,
          title: l10n.settings_syncTime,
          subtitle: l10n.settings_syncTimeSubtitle,
          onTap: () => _syncTime(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.refresh,
          title: l10n.settings_refreshContacts,
          subtitle: l10n.settings_refreshContactsSubtitle,
          onTap: () => connector.getContacts(),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.restart_alt,
          title: l10n.settings_rebootDevice,
          subtitle: l10n.settings_rebootDeviceSubtitle,
          titleColor: MeshTokens.of(context).warn,
          iconColor: MeshTokens.of(context).warn,
          onTap: () => _confirmReboot(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.delete_outline,
          title: l10n.settings_deleteAllPaths,
          subtitle: l10n.settings_deleteAllPathsSubtitle,
          titleColor: MeshTokens.of(context).alert,
          iconColor: MeshTokens.of(context).alert,
          onTap: () => _confirmDeleteAllPaths(context, connector),
        ),
      ],
    );
  }

  Widget _buildExportCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        _tappableTile(
          context,
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportRepeaters,
          subtitle: l10n.settings_gpxExportRepeatersSubtitle,
          onTap: () async {
            final exporter = GpxExport(connector);
            exporter.addRepeaters();
            _gpxExport(
              exporter,
              l10n.map_repeater,
              l10n.settings_gpxExportRepeatersRoom,
              'meshcore_repeaters_',
              l10n.settings_gpxExportShareText,
              l10n.settings_gpxExportShareSubject,
            );
          },
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportContacts,
          subtitle: l10n.settings_gpxExportContactsSubtitle,
          onTap: () async {
            final exporter = GpxExport(connector);
            exporter.addContacts();
            _gpxExport(
              exporter,
              l10n.map_repeater,
              l10n.settings_gpxExportChat,
              'meshcore_contacts_',
              l10n.settings_gpxExportShareText,
              l10n.settings_gpxExportShareSubject,
            );
          },
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportAll,
          subtitle: l10n.settings_gpxExportAllSubtitle,
          onTap: () async {
            final exporter = GpxExport(connector);
            exporter.addAll();
            _gpxExport(
              exporter,
              l10n.map_repeater,
              l10n.settings_gpxExportAllContacts,
              'meshcore_all_',
              l10n.settings_gpxExportShareText,
              l10n.settings_gpxExportShareSubject,
            );
          },
        ),
      ],
    );
  }

  Widget _buildDebugCardContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _tappableTile(
          context,
          icon: Icons.bluetooth_outlined,
          title: l10n.settings_companionDebugLog,
          subtitle: l10n.settings_companionDebugLogSubtitle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BleDebugLogScreen(),
              ),
            );
          },
        ),
        const MeshDashedDivider(indent: 16),
        _tappableTile(
          context,
          icon: Icons.code_outlined,
          title: l10n.settings_appDebugLog,
          subtitle: l10n.settings_appDebugLogSubtitle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AppDebugLogScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _tappableTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    // Accent by default (2026-08-21 refinement); warn/alert tiles still
    // pass their own semantic color explicitly.
    final effectiveIconColor = iconColor ?? t.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingSm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveIconColor),
            SizedBox(width: t.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: titleColor != null
                          ? titleColor.withValues(alpha: 0.7)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }

  void _editNodeName(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    final controller = TextEditingController(text: connector.selfName ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_nodeName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.settings_nodeNameHint,
            border: const OutlineInputBorder(),
          ),
          maxLength: 31,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final name = controller.text.trim();
              return TextButton(
                onPressed: name.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await connector.setNodeName(name);
                        await connector.refreshDeviceInfo();
                        if (!context.mounted) return;
                        showDismissibleSnackBar(
                          context,
                          content: Text(l10n.settings_nodeNameUpdated),
                        );
                      },
                child: Text(l10n.common_save),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRadioSettings(BuildContext context, MeshCoreConnector connector) {
    showDialog(
      context: context,
      builder: (context) => _RadioSettingsDialog(connector: connector),
    );
  }

  void _editPathHashMode(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    var selectedMode = (connector.pathHashByteWidth - 1).clamp(0, 3).toInt();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.repeater_pathHashMode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedMode,
                decoration: InputDecoration(
                  labelText: l10n.repeater_pathHashMode,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(l10n.repeater_pathHashModeOption0),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(l10n.repeater_pathHashModeOption1),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(l10n.repeater_pathHashModeOption2),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text(l10n.repeater_pathHashModeOption3),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedMode = value);
                },
              ),
              SizedBox(height: MeshTokens.of(context).spacingSm),
              Text(
                l10n.repeater_pathHashModeHelper,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await connector.setPathHashMode(selectedMode);
                  await connector.refreshDeviceInfo();
                  if (!context.mounted) return;
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.repeater_settingsSaved),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.settings_error(e.toString())),
                  );
                }
              },
              child: Text(l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _editLocation(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    final settingsService = context.read<AppSettingsService>();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final intervalController = TextEditingController();
    latController.text = connector.selfLatitude?.toStringAsFixed(6) ?? '';
    lonController.text = connector.selfLongitude?.toStringAsFixed(6) ?? '';

    // Safe access to custom vars - may be null before device responds
    final customVars = connector.currentCustomVars ?? {};
    final bool hasGPS = customVars.containsKey("gps");
    bool isGPSEnabled = customVars["gps"] == "1";

    final currentInterval = settingsService.resolvedGpsIntervalSeconds(
      customVars,
    );
    intervalController.text = currentInterval.toString();

    String? intervalError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.settings_location),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: InputDecoration(
                  labelText: l10n.settings_latitude,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              TextField(
                controller: lonController,
                decoration: InputDecoration(
                  labelText: l10n.settings_longitude,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              if (hasGPS) ...[
                SizedBox(height: MeshTokens.of(context).spacingMd),
                TextField(
                  controller: intervalController,
                  onChanged: (_) {
                    if (intervalError != null) {
                      setDialogState(() => intervalError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.settings_locationIntervalSec,
                    border: const OutlineInputBorder(),
                    errorText: intervalError,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                ),
                SizedBox(height: MeshTokens.of(context).spacingMd),
                FeatureToggleRow(
                  title: l10n.settings_locationGPSEnable,
                  subtitle: l10n.settings_locationGPSEnableSubtitle,
                  value: isGPSEnabled,
                  onChanged: (value) async {
                    setDialogState(() => isGPSEnabled = value);
                    if (value) {
                      await connector.setCustomVar("gps:1");
                    } else {
                      await connector.setCustomVar("gps:0");
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.common_cancel),
            ),
            TextButton(
              onPressed: () async {
                int? interval;
                if (hasGPS) {
                  final intervalText = intervalController.text.trim();
                  if (intervalText.isNotEmpty) {
                    interval = int.tryParse(intervalText);
                    if (interval == null ||
                        interval < 60 ||
                        interval >= 86400) {
                      setDialogState(() {
                        intervalError = l10n.settings_locationIntervalInvalid;
                      });
                      return;
                    }
                  }
                }

                Navigator.pop(context);

                if (interval != null) {
                  await settingsService.setGpsIntervalSeconds(
                    interval,
                    writeToDevice: (value) =>
                        connector.setCustomVar("gps_interval:$value"),
                  );
                  await connector.refreshDeviceInfo();
                  if (!context.mounted) return;
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.settings_locationUpdated),
                  );
                }

                final latText = latController.text.trim();
                final lonText = lonController.text.trim();
                if (latText.isEmpty && lonText.isEmpty) {
                  return;
                }

                final currentLat = connector.selfLatitude;
                final currentLon = connector.selfLongitude;
                final lat = latText.isNotEmpty
                    ? double.tryParse(latText)
                    : currentLat;
                final lon = lonText.isNotEmpty
                    ? double.tryParse(lonText)
                    : currentLon;
                if (lat == null || lon == null) {
                  if (!context.mounted) return;
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.settings_locationBothRequired),
                  );
                  return;
                }
                if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                  if (!context.mounted) return;
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.settings_locationInvalid),
                  );
                  return;
                }

                await connector.setNodeLocation(lat: lat, lon: lon);
                await connector.refreshDeviceInfo();
                if (!context.mounted) return;
                showDismissibleSnackBar(
                  context,
                  content: Text(l10n.settings_locationUpdated),
                );
              },
              child: Text(l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _syncTime(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    connector.syncTime();
    showDismissibleSnackBar(
      context,
      content: Text(l10n.settings_timeSynchronized),
    );
  }

  void _confirmDeleteAllPaths(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_deleteAllPaths),
        content: Text(l10n.settings_deleteAllPathsSubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              connector.deleteAllPaths();
            },
            child: Text(
              l10n.common_deleteAll,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReboot(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_rebootDevice),
        content: Text(l10n.settings_rebootDeviceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              connector.rebootDevice();
            },
            child: Text(
              l10n.common_reboot,
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final l10n = context.l10n;
    showAboutDialog(
      context: context,
      applicationName: l10n.appTitle,
      applicationVersion: _appVersion.isEmpty
          ? l10n.common_loading
          : _appVersion,
      applicationLegalese: l10n.settings_aboutLegalese,
      children: [
        SizedBox(height: MeshTokens.of(context).spacingMd),
        Text(l10n.settings_aboutDescription),
      ],
    );
  }

  Future<void> _gpxExport(
    GpxExport exporter,
    String name,
    String description,
    String filename,
    String shareText,
    String subject,
  ) async {
    final l10n = context.l10n;
    final result = await exporter.exportGPX(
      name,
      description,
      filename,
      shareText,
      subject,
    );
    if (!mounted) return;
    switch (result) {
      case gpxExportSuccess:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportSuccess),
        );
      case gpxExportNoContacts:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportNoContacts),
        );
        break;
      case gpxExportNotAvailable:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportNotAvailable),
        );
        break;
      case gpxExportFailed:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportError),
        );
        break;
    }
  }

  void _editAutoAddConfig(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;
    bool autoAddChat = false;
    bool autoAddRepeater = false;
    bool autoAddRoomServer = false;
    bool autoAddSensor = false;
    bool overwriteOldest = false;

    final connector = context.read<MeshCoreConnector>();
    autoAddChat = connector.autoAddUsers ?? false;
    autoAddRepeater = connector.autoAddRepeaters ?? false;
    autoAddRoomServer = connector.autoAddRoomServers ?? false;
    autoAddSensor = connector.autoAddSensors ?? false;
    overwriteOldest = connector.autoAddOverwriteOldest ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.contactsSettings_autoAddTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FeatureToggleRow(
                  title: l10n.contactsSettings_autoAddUsersTitle,
                  subtitle: l10n.contactsSettings_autoAddUsersSubtitle,
                  value: autoAddChat,
                  onChanged: (value) {
                    setDialogState(() => autoAddChat = value);
                  },
                ),
                SizedBox(height: MeshTokens.of(context).spacingXs),
                FeatureToggleRow(
                  title: l10n.contactsSettings_autoAddRepeatersTitle,
                  subtitle: l10n.contactsSettings_autoAddRepeatersSubtitle,
                  value: autoAddRepeater,
                  onChanged: (value) {
                    setDialogState(() => autoAddRepeater = value);
                  },
                ),
                SizedBox(height: MeshTokens.of(context).spacingXs),
                FeatureToggleRow(
                  title: l10n.contactsSettings_autoAddRoomServersTitle,
                  subtitle: l10n.contactsSettings_autoAddRoomServersSubtitle,
                  value: autoAddRoomServer,
                  onChanged: (value) {
                    setDialogState(() => autoAddRoomServer = value);
                  },
                ),
                SizedBox(height: MeshTokens.of(context).spacingXs),
                FeatureToggleRow(
                  title: l10n.contactsSettings_autoAddSensorsTitle,
                  subtitle: l10n.contactsSettings_autoAddSensorsSubtitle,
                  value: autoAddSensor,
                  onChanged: (value) {
                    setDialogState(() => autoAddSensor = value);
                  },
                ),
                const MeshDashedDivider(),
                FeatureToggleRow(
                  title: l10n.contactsSettings_overwriteOldestTitle,
                  subtitle: l10n.contactsSettings_overwriteOldestSubtitle,
                  value: overwriteOldest,
                  onChanged: (value) {
                    setDialogState(() => overwriteOldest = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.common_cancel),
            ),
            TextButton(
              onPressed: () {
                _sendSettings(
                  connector,
                  autoAddChat,
                  autoAddRepeater,
                  autoAddRoomServer,
                  autoAddSensor,
                  overwriteOldest,
                );
                Navigator.pop(context);
              },
              child: Text(l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _sendSettings(
    MeshCoreConnector connector,
    bool autoAddChat,
    bool autoAddRepeater,
    bool autoAddRoomServer,
    bool autoAddSensor,
    bool overwriteOldest,
  ) async {
    final frame = buildSetAutoAddConfigFrame(
      autoAddChat: autoAddChat,
      autoAddRepeater: autoAddRepeater,
      autoAddRoomServer: autoAddRoomServer,
      autoAddSensor: autoAddSensor,
      overwriteOldest: overwriteOldest,
    );
    await connector.sendFrame(frame);
    await connector.sendFrame(buildGetAutoAddFlagsFrame());
  }
}

void _privacySettings(BuildContext context, MeshCoreConnector connector) {
  final l10n = context.l10n;
  final settingsService = context.read<AppSettingsService>();

  int telemetryMode = connector.telemetryModeBase;
  int telemetryLocMode = connector.telemetryModeLoc;
  int telemetryEnvMode = connector.telemetryModeEnv;
  bool advertLocPolicy = connector.advertLocationPolicy == 0 ? false : true;
  int multiAcks = connector.multiAcks;
  bool autoZeroHopAdvertOnGpsUpdate =
      settingsService.settings.autoSendZeroHopAdvertOnGpsUpdate;

  final telemModeBase = [
    DropdownMenuItem(value: teleModeDeny, child: Text(l10n.settings_denyAll)),
    DropdownMenuItem(
      value: teleModeAllowFlags,
      child: Text(l10n.settings_allowByContact),
    ),
    DropdownMenuItem(
      value: teleModeAllowAll,
      child: Text(l10n.settings_allowAll),
    ),
  ];

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.settings_privacy),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settings_privacySettingsDescription),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              FeatureToggleRow(
                title: l10n.settings_advertLocation,
                subtitle: l10n.settings_advertLocationSubtitle,
                value: advertLocPolicy,
                onChanged: (value) {
                  setDialogState(() => advertLocPolicy = value);
                },
              ),
              SizedBox(height: MeshTokens.of(context).spacingXs),
              FeatureToggleRow(
                title: l10n.settings_autoZeroHopAdvertOnGpsUpdate,
                subtitle: l10n.settings_autoZeroHopAdvertOnGpsUpdateSubtitle,
                value: autoZeroHopAdvertOnGpsUpdate,
                enabled: advertLocPolicy,
                onChanged: advertLocPolicy
                    ? (value) {
                        setDialogState(
                          () => autoZeroHopAdvertOnGpsUpdate = value,
                        );
                      }
                    : null,
              ),
              SizedBox(height: MeshTokens.of(context).spacingXs),
              SwitchListTile(
                title: Text(l10n.settings_multiAck),
                value: multiAcks == 1,
                onChanged: (value) {
                  setDialogState(() => multiAcks = value ? 1 : 0);
                },
                contentPadding: EdgeInsets.zero,
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              DropdownButtonFormField<int>(
                initialValue: telemetryMode,
                decoration: InputDecoration(
                  labelText: l10n.settings_telemetryBaseMode,
                  border: const OutlineInputBorder(),
                ),
                items: telemModeBase,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => telemetryMode = value);
                  }
                },
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              DropdownButtonFormField<int>(
                initialValue: telemetryLocMode,
                decoration: InputDecoration(
                  labelText: l10n.settings_telemetryLocationMode,
                  border: const OutlineInputBorder(),
                ),
                items: telemModeBase,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => telemetryLocMode = value);
                  }
                },
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              DropdownButtonFormField<int>(
                initialValue: telemetryEnvMode,
                decoration: InputDecoration(
                  labelText: l10n.settings_telemetryEnvironmentMode,
                  border: const OutlineInputBorder(),
                ),
                items: telemModeBase,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => telemetryEnvMode = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await connector.setTelemetryModeBase(
                telemetryMode,
                telemetryLocMode,
                telemetryEnvMode,
                advertLocPolicy ? 1 : 0,
                multiAcks,
              );
              await settingsService.setAutoSendZeroHopAdvertOnGpsUpdate(
                autoZeroHopAdvertOnGpsUpdate,
              );
              await connector.refreshDeviceInfo();
              if (!context.mounted) return;
              showDismissibleSnackBar(
                context,
                content: Text(l10n.settings_telemetryModeUpdated),
              );
            },
            child: Text(l10n.common_save),
          ),
        ],
      ),
    ),
  );
}

/// Applies the duty-cycle limit chosen in the radio settings dialog:
/// persists it app-side (drives the radio stats airtime budget) and forwards
/// it to the connected node over the self-CLI (`set dutycycle`, 1–100),
/// which companion firmware accepts (see docs/BLE_PROTOCOL.md, CLI Commands).
Future<void> applyDutyCycleToNode({
  required int percent,
  required AppSettingsService settings,
  required MeshCoreConnector connector,
}) async {
  await settings.setTxDutyCyclePercent(percent);
  await connector.sendCliCommand('set dutycycle $percent');
}

class _RadioSettingsDialog extends StatefulWidget {
  final MeshCoreConnector connector;

  const _RadioSettingsDialog({required this.connector});

  @override
  State<_RadioSettingsDialog> createState() => _RadioSettingsDialogState();
}

class _RadioSettingsDialogState extends State<_RadioSettingsDialog> {
  final _frequencyController = TextEditingController();
  LoRaBandwidth _bandwidth = LoRaBandwidth.bw125;
  LoRaSpreadingFactor _spreadingFactor = LoRaSpreadingFactor.sf7;
  LoRaCodingRate _codingRate = LoRaCodingRate.cr4_5;
  final _txPowerController = TextEditingController(text: '20');
  bool _clientRepeat = false;
  int? _selectedPresetIndex;
  _RadioSettingsSnapshot? _lastNonRepeatSnapshot;
  String? _frequencyError;
  String? _txPowerError;
  int _dutyCycle = 10;

  AppDebugLogService get _appLog =>
      Provider.of<AppDebugLogService>(context, listen: false);

  @override
  void initState() {
    super.initState();

    // Populate with current settings if available
    if (widget.connector.currentFreqHz != null) {
      _frequencyController.text = (widget.connector.currentFreqHz! / 1000.0)
          .toStringAsFixed(3);
    } else {
      _frequencyController.text = '915.0';
    }

    if (widget.connector.currentBwHz != null) {
      // Find matching bandwidth enum
      final bwValue = widget.connector.currentBwHz!;
      for (var bw in LoRaBandwidth.values) {
        if (bw.hz == bwValue) {
          _bandwidth = bw;
          break;
        }
      }
    }

    if (widget.connector.currentSf != null) {
      // Find matching spreading factor enum
      final sfValue = widget.connector.currentSf!;
      for (var sf in LoRaSpreadingFactor.values) {
        if (sf.value == sfValue) {
          _spreadingFactor = sf;
          break;
        }
      }
    }

    if (widget.connector.currentCr != null) {
      // Find matching coding rate enum
      final crValue = _toUiCodingRate(widget.connector.currentCr!);
      for (var cr in LoRaCodingRate.values) {
        if (cr.value == crValue) {
          _codingRate = cr;
          break;
        }
      }
    }

    if (widget.connector.currentTxPower != null) {
      _txPowerController.text = widget.connector.currentTxPower.toString();
    }

    _clientRepeat = widget.connector.clientRepeat ?? false;
    _dutyCycle = context.read<AppSettingsService>().settings.txDutyCyclePercent;
    _selectedPresetIndex = _findMatchingPresetIndex();
    if (_clientRepeat) {
      _lastNonRepeatSnapshot =
          _sessionRememberedNonRepeatSnapshot() ??
          _inferNonRepeatSnapshotForRepeatEnabled();
      _selectedPresetIndex = _findMatchingPresetIndexForSnapshot(
        _lastNonRepeatSnapshot!,
      );
    } else {
      _lastNonRepeatSnapshot = _nonRepeatSnapshotForCurrentSelection();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logRadioSettingsState('Dialog initialized');
    });
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _txPowerController.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    setState(() {
      _applyPresetState(index);
    });
    _logRadioSettingsState(
      'Applied preset ${RadioSettings.presets[index].$1} (#$index)',
    );
  }

  int? _findMatchingPresetIndex() {
    return _findMatchingPresetIndexForSnapshot(_currentSnapshot());
  }

  int? _findMatchingPresetIndexForSnapshot(_RadioSettingsSnapshot snapshot) {
    for (final i in _visiblePresetIndexes()) {
      final preset = RadioSettings.presets[i].$2;
      if (preset.frequencyHz == snapshot.frequencyHz &&
          preset.bandwidth == snapshot.bandwidth &&
          preset.spreadingFactor == snapshot.spreadingFactor &&
          preset.codingRate == snapshot.codingRate &&
          preset.txPowerDbm == snapshot.txPowerDbm) {
        return i;
      }
    }
    return null;
  }

  Iterable<int> _visiblePresetIndexes() sync* {
    for (var i = 0; i < RadioSettings.presets.length; i++) {
      if (_isOffGridPresetIndex(i)) {
        continue;
      }
      yield i;
    }
  }

  _RadioSettingsSnapshot _currentSnapshot() {
    final frequencyMHz = double.tryParse(_frequencyController.text) ?? 915.0;
    final txPowerDbm = int.tryParse(_txPowerController.text) ?? 20;
    return _RadioSettingsSnapshot(
      frequencyMHz: frequencyMHz,
      bandwidth: _bandwidth,
      spreadingFactor: _spreadingFactor,
      codingRate: _codingRate,
      txPowerDbm: txPowerDbm,
    );
  }

  bool _isOffGridPresetIndex(int? index) {
    if (index == null) return false;
    return RadioSettings.presets[index].$1.startsWith('Off-Grid ');
  }

  double _offGridFrequencyForBaseFrequency(double baseFrequencyMHz) {
    if (baseFrequencyMHz < 500) return 433.0;
    if (baseFrequencyMHz < 900) return 869.0;
    return 918.0;
  }

  double _normalFrequencyForBand(double frequencyMHz) {
    if (frequencyMHz < 500) return 433.650;
    if (frequencyMHz < 900) return 869.432;
    return 915.8;
  }

  _RadioSettingsSnapshot _fallbackNonRepeatSnapshot(
    double currentFrequencyMHz,
  ) {
    return _RadioSettingsSnapshot(
      frequencyMHz: _normalFrequencyForBand(currentFrequencyMHz),
      bandwidth: _bandwidth,
      spreadingFactor: _spreadingFactor,
      codingRate: _codingRate,
      txPowerDbm: int.tryParse(_txPowerController.text) ?? 20,
    );
  }

  _RadioSettingsSnapshot _nonRepeatSnapshotForCurrentSelection() {
    final current = _currentSnapshot();
    if (!_isOffGridPresetIndex(_selectedPresetIndex)) {
      return current;
    }
    return _fallbackNonRepeatSnapshot(current.frequencyMHz);
  }

  _RadioSettingsSnapshot? _sessionRememberedNonRepeatSnapshot() {
    final snapshot = widget.connector.rememberedNonRepeatRadioState;
    if (snapshot == null) return null;
    return _RadioSettingsSnapshot.fromMeshCoreSnapshot(snapshot);
  }

  _RadioSettingsSnapshot _inferNonRepeatSnapshotForRepeatEnabled() {
    final current = _currentSnapshot();
    for (final i in _visiblePresetIndexes()) {
      final preset = RadioSettings.presets[i].$2;
      final offGridFreqHz =
          (_offGridFrequencyForBaseFrequency(preset.frequencyMHz) * 1000)
              .round();
      if (offGridFreqHz == current.frequencyHz &&
          preset.bandwidth == current.bandwidth &&
          preset.spreadingFactor == current.spreadingFactor &&
          preset.codingRate == current.codingRate &&
          preset.txPowerDbm == current.txPowerDbm) {
        return _RadioSettingsSnapshot(
          frequencyMHz: preset.frequencyMHz,
          bandwidth: preset.bandwidth,
          spreadingFactor: preset.spreadingFactor,
          codingRate: preset.codingRate,
          txPowerDbm: preset.txPowerDbm,
        );
      }
    }
    return _fallbackNonRepeatSnapshot(current.frequencyMHz);
  }

  void _applySnapshot(_RadioSettingsSnapshot snapshot) {
    _frequencyController.text = snapshot.frequencyMHz.toStringAsFixed(3);
    _bandwidth = snapshot.bandwidth;
    _spreadingFactor = snapshot.spreadingFactor;
    _codingRate = snapshot.codingRate;
    _txPowerController.text = snapshot.txPowerDbm.toString();
  }

  void _applyPresetState(int index) {
    final preset = RadioSettings.presets[index].$2;
    final baseSnapshot = _RadioSettingsSnapshot(
      frequencyMHz: preset.frequencyMHz,
      bandwidth: preset.bandwidth,
      spreadingFactor: preset.spreadingFactor,
      codingRate: preset.codingRate,
      txPowerDbm: preset.txPowerDbm,
    );
    final frequencyMHz = _clientRepeat
        ? _offGridFrequencyForBaseFrequency(baseSnapshot.frequencyMHz)
        : baseSnapshot.frequencyMHz;
    _frequencyController.text = frequencyMHz.toString();
    _bandwidth = preset.bandwidth;
    _spreadingFactor = preset.spreadingFactor;
    _codingRate = preset.codingRate;
    _txPowerController.text = preset.txPowerDbm.toString();
    _selectedPresetIndex = index;
    _lastNonRepeatSnapshot = baseSnapshot;
  }

  void _syncPresetSelection() {
    final previousPresetIndex = _selectedPresetIndex;
    final previousLastNonRepeat = _lastNonRepeatSnapshot;
    if (_clientRepeat) {
      final baseSnapshot =
          previousLastNonRepeat ?? _inferNonRepeatSnapshotForRepeatEnabled();
      if (_bandwidth != baseSnapshot.bandwidth ||
          _spreadingFactor != baseSnapshot.spreadingFactor ||
          _codingRate != baseSnapshot.codingRate ||
          (int.tryParse(_txPowerController.text) ?? 20) !=
              baseSnapshot.txPowerDbm) {
        _lastNonRepeatSnapshot = _RadioSettingsSnapshot(
          frequencyMHz: baseSnapshot.frequencyMHz,
          bandwidth: _bandwidth,
          spreadingFactor: _spreadingFactor,
          codingRate: _codingRate,
          txPowerDbm: int.tryParse(_txPowerController.text) ?? 20,
        );
      }
      _selectedPresetIndex = _findMatchingPresetIndexForSnapshot(
        _lastNonRepeatSnapshot ?? baseSnapshot,
      );
      if (previousPresetIndex != _selectedPresetIndex ||
          previousLastNonRepeat != _lastNonRepeatSnapshot) {
        _logRadioSettingsState(
          'Preset match updated while repeat enabled: ${_presetLabel(previousPresetIndex)} -> ${_presetLabel(_selectedPresetIndex)}',
        );
      }
      return;
    }
    _lastNonRepeatSnapshot = _nonRepeatSnapshotForCurrentSelection();
    _selectedPresetIndex = _findMatchingPresetIndexForSnapshot(
      _lastNonRepeatSnapshot!,
    );
    if (previousPresetIndex != _selectedPresetIndex ||
        previousLastNonRepeat != _lastNonRepeatSnapshot) {
      _logRadioSettingsState(
        'Preset sync updated state from ${_presetLabel(previousPresetIndex)} to ${_presetLabel(_selectedPresetIndex)}',
      );
    }
  }

  void _handleManualSettingsChanged(String source) {
    _logRadioSettingsState('Manual settings edit: $source');
    setState(() {
      _validateFields();
      _syncPresetSelection();
    });
  }

  void _validateFields() {
    final l10n = context.l10n;
    final freqMHz = double.tryParse(_frequencyController.text);
    _frequencyError = (freqMHz == null || freqMHz < 300 || freqMHz > 2500)
        ? l10n.settings_frequencyInvalid
        : null;

    final maxTxPower = widget.connector.maxTxPower ?? 22;
    final txPower = int.tryParse(_txPowerController.text);
    _txPowerError = (txPower == null || txPower < 0 || txPower > maxTxPower)
        ? '${l10n.settings_txPowerInvalid} (0-$maxTxPower dBm)'
        : null;
  }

  void _handleClientRepeatChanged(bool enabled) {
    _logRadioSettingsState(
      'Off-grid repeat toggle requested: $_clientRepeat -> $enabled',
    );
    setState(() {
      final currentSnapshot = _currentSnapshot();
      if (enabled) {
        if (!_clientRepeat) {
          _syncPresetSelection();
        }
        final baseSnapshot = _lastNonRepeatSnapshot ?? currentSnapshot;
        _clientRepeat = true;
        _frequencyController.text = _offGridFrequencyForBaseFrequency(
          baseSnapshot.frequencyMHz,
        ).toStringAsFixed(3);
        return;
      }

      _clientRepeat = false;
      _applySnapshot(
        _lastNonRepeatSnapshot ??
            _fallbackNonRepeatSnapshot(currentSnapshot.frequencyMHz),
      );
      _syncPresetSelection();
    });
    _logRadioSettingsState('Off-grid repeat toggle applied');
  }

  Future<void> _saveSettings() async {
    final l10n = context.l10n;
    final appSettings = context.read<AppSettingsService>();
    final freqMHz = double.tryParse(_frequencyController.text);
    final txPower = int.tryParse(_txPowerController.text);

    if (freqMHz == null || freqMHz < 300 || freqMHz > 2500) {
      showDismissibleSnackBar(
        context,
        content: Text(l10n.settings_frequencyInvalid),
      );
      return;
    }

    final maxTxPower = widget.connector.maxTxPower ?? 22;
    if (txPower == null || txPower < 0 || txPower > maxTxPower) {
      showDismissibleSnackBar(
        context,
        content: Text('${l10n.settings_txPowerInvalid} (0-$maxTxPower dBm)'),
      );
      return;
    }

    final freqHz = (freqMHz * 1000).round();
    final bwHz = _bandwidth.hz;
    final sf = _spreadingFactor.value;
    final cr = _toDeviceCodingRate(
      _codingRate.value,
      widget.connector.currentCr,
    );

    // if the client repeat isnt null then we know its supported
    //otherwise we leave it out of the frame to avoid accidentally enabling
    final knownRepeat = widget.connector.clientRepeat != null;

    if (knownRepeat) {
      const validRepeatFreqsKHz = {433000, 869000, 918000};
      if (_clientRepeat && !validRepeatFreqsKHz.contains(freqHz)) {
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_clientRepeatFreqWarning),
        );
        return;
      }
    }

    try {
      _logRadioSettingsState('Saving radio settings');
      await widget.connector.sendFrame(
        buildSetRadioParamsFrame(
          freqHz,
          bwHz,
          sf,
          cr,
          clientRepeat: knownRepeat ? _clientRepeat : null,
        ),
      );
      await widget.connector.sendFrame(buildSetRadioTxPowerFrame(txPower));
      await applyDutyCycleToNode(
        percent: _dutyCycle,
        settings: appSettings,
        connector: widget.connector,
      );
      await widget.connector.refreshDeviceInfo();
      final rememberedSnapshot = _clientRepeat
          ? _lastNonRepeatSnapshot
          : _currentSnapshot();
      if (rememberedSnapshot != null) {
        widget.connector.rememberNonRepeatRadioState(
          rememberedSnapshot.toMeshCoreSnapshot(widget.connector.currentCr),
        );
      }

      if (!mounted) return;
      _logRadioSettingsState('Radio settings saved successfully');
      showDismissibleSnackBar(
        context,
        content: Text(l10n.settings_radioSettingsUpdated),
      );
    } catch (e) {
      _appLog.warn('Radio settings save failed: $e', tag: 'RadioSettings');
      if (!mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(l10n.settings_error(e.toString())),
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _presetLabel(int? index) {
    if (index == null) {
      return 'custom';
    }
    return '${RadioSettings.presets[index].$1} (#$index)';
  }

  String _formatSnapshot(_RadioSettingsSnapshot? snapshot) {
    if (snapshot == null) {
      return 'null';
    }
    return '${snapshot.frequencyMHz.toStringAsFixed(3)}MHz/'
        '${snapshot.bandwidth.label}/'
        '${snapshot.spreadingFactor.label}/'
        '${snapshot.codingRate.label}/'
        '${snapshot.txPowerDbm}dBm';
  }

  void _logRadioSettingsState(String message) {
    if (!kDebugMode) return;
    _appLog.info(
      '$message | '
      'freq=${_frequencyController.text}MHz '
      'bw=${_bandwidth.label} '
      'sf=${_spreadingFactor.label} '
      'cr=${_codingRate.label} '
      'tx=${_txPowerController.text}dBm '
      'repeat=$_clientRepeat '
      'preset=${_presetLabel(_selectedPresetIndex)} '
      'lastNonRepeat=${_formatSnapshot(_lastNonRepeatSnapshot)}',
      tag: 'RadioSettings',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return AlertDialog(
      title: Text(l10n.settings_radioSettings),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey<int?>(_selectedPresetIndex),
              initialValue: _selectedPresetIndex,
              decoration: InputDecoration(
                labelText: l10n.settings_presets,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final i in _visiblePresetIndexes())
                  DropdownMenuItem(
                    value: i,
                    child: Text(RadioSettings.presets[i].$1),
                  ),
              ],
              onChanged: (index) {
                if (index != null) {
                  _applyPreset(index);
                }
              },
            ),
            SizedBox(height: t.spacingMd),
            TextField(
              controller: _frequencyController,
              onChanged: (_) => _handleManualSettingsChanged('frequency'),
              decoration: InputDecoration(
                labelText: l10n.settings_frequency,
                border: const OutlineInputBorder(),
                helperText: l10n.settings_frequencyHelper,
                errorText: _frequencyError,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            SizedBox(height: t.spacingMd),
            DropdownButtonFormField<LoRaBandwidth>(
              initialValue: _bandwidth,
              decoration: InputDecoration(
                labelText: l10n.settings_bandwidth,
                border: const OutlineInputBorder(),
              ),
              items: LoRaBandwidth.values
                  .map(
                    (bw) => DropdownMenuItem(value: bw, child: Text(bw.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _bandwidth = value;
                    _syncPresetSelection();
                  });
                  _logRadioSettingsState('Manual settings edit: bandwidth');
                }
              },
            ),
            SizedBox(height: t.spacingMd),
            DropdownButtonFormField<LoRaSpreadingFactor>(
              initialValue: _spreadingFactor,
              decoration: InputDecoration(
                labelText: l10n.settings_spreadingFactor,
                border: const OutlineInputBorder(),
              ),
              items: LoRaSpreadingFactor.values
                  .map(
                    (sf) => DropdownMenuItem(value: sf, child: Text(sf.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _spreadingFactor = value;
                    _syncPresetSelection();
                  });
                  _logRadioSettingsState(
                    'Manual settings edit: spreading factor',
                  );
                }
              },
            ),
            SizedBox(height: t.spacingMd),
            DropdownButtonFormField<LoRaCodingRate>(
              initialValue: _codingRate,
              decoration: InputDecoration(
                labelText: l10n.settings_codingRate,
                border: const OutlineInputBorder(),
              ),
              items: LoRaCodingRate.values
                  .map(
                    (cr) => DropdownMenuItem(value: cr, child: Text(cr.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _codingRate = value;
                    _syncPresetSelection();
                  });
                  _logRadioSettingsState('Manual settings edit: coding rate');
                }
              },
            ),
            SizedBox(height: t.spacingMd),
            TextField(
              controller: _txPowerController,
              onChanged: (_) => _handleManualSettingsChanged('tx power'),
              decoration: InputDecoration(
                labelText: l10n.settings_txPower,
                border: const OutlineInputBorder(),
                helperText: widget.connector.maxTxPower != null
                    ? '${l10n.settings_txPowerHelper} (max: ${widget.connector.maxTxPower} dBm)'
                    : l10n.settings_txPowerHelper,
                errorText: _txPowerError,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: t.spacingMd),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.repeater_dutyCycle),
              subtitle: Text(l10n.repeater_dutyCycleHelper),
              trailing: Text(
                l10n.repeater_dutyCyclePercent(_dutyCycle),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Slider(
              value: _dutyCycle.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: l10n.repeater_dutyCyclePercent(_dutyCycle),
              onChanged: (value) => setState(() => _dutyCycle = value.toInt()),
            ),
            if (widget.connector.clientRepeat != null) ...[
              SizedBox(height: t.spacingMd),
              SwitchListTile(
                title: Text(l10n.settings_clientRepeat),
                subtitle: Text(l10n.settings_clientRepeatSubtitle),
                value: _clientRepeat,
                onChanged: _handleClientRepeatChanged,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: (_frequencyError != null || _txPowerError != null)
              ? null
              : _saveSettings,
          child: Text(l10n.common_save),
        ),
      ],
    );
  }
}

class _RadioSettingsSnapshot {
  final double frequencyMHz;
  final LoRaBandwidth bandwidth;
  final LoRaSpreadingFactor spreadingFactor;
  final LoRaCodingRate codingRate;
  final int txPowerDbm;

  const _RadioSettingsSnapshot({
    required this.frequencyMHz,
    required this.bandwidth,
    required this.spreadingFactor,
    required this.codingRate,
    required this.txPowerDbm,
  });

  /// Frequency in integer Hz — avoids floating-point comparison issues.
  int get frequencyHz => (frequencyMHz * 1000).round();

  /// Convert from the connector's raw-int snapshot to UI-enum snapshot.
  static _RadioSettingsSnapshot? fromMeshCoreSnapshot(
    MeshCoreRadioStateSnapshot snapshot,
  ) {
    final bw = LoRaBandwidth.values
        .where((b) => b.hz == snapshot.bwHz)
        .firstOrNull;
    final sf = LoRaSpreadingFactor.values
        .where((s) => s.value == snapshot.sf)
        .firstOrNull;
    final cr = LoRaCodingRate.values
        .where((c) => c.value == _toUiCodingRate(snapshot.cr))
        .firstOrNull;
    if (bw == null || sf == null || cr == null) return null;
    return _RadioSettingsSnapshot(
      frequencyMHz: snapshot.freqHz / 1000.0,
      bandwidth: bw,
      spreadingFactor: sf,
      codingRate: cr,
      txPowerDbm: snapshot.txPowerDbm,
    );
  }

  /// Convert back to the connector's raw-int snapshot.
  MeshCoreRadioStateSnapshot toMeshCoreSnapshot(int? deviceCr) {
    return MeshCoreRadioStateSnapshot(
      freqHz: frequencyHz,
      bwHz: bandwidth.hz,
      sf: spreadingFactor.value,
      cr: _toDeviceCodingRate(codingRate.value, deviceCr),
      txPowerDbm: txPowerDbm,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _RadioSettingsSnapshot &&
        frequencyHz == other.frequencyHz &&
        bandwidth == other.bandwidth &&
        spreadingFactor == other.spreadingFactor &&
        codingRate == other.codingRate &&
        txPowerDbm == other.txPowerDbm;
  }

  @override
  int get hashCode => Object.hash(
    frequencyHz,
    bandwidth,
    spreadingFactor,
    codingRate,
    txPowerDbm,
  );
}
