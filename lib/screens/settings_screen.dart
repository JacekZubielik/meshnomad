import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../helpers/snack_bar_builder.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/app_bar.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import 'about_screen.dart';
import 'app_settings_screen.dart';
import 'app_debug_log_screen.dart';
import 'ble_debug_log_screen.dart';
import 'location_settings_screen.dart';
import 'node_settings_screen.dart';
import '../widgets/sync_progress_overlay.dart';

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
    // offstage routes still mounted via maintainState:true. About used to be
    // a showAboutDialog popup nested inside this scope — now its own screen
    // (about_screen.dart) with its own SelectionArea, which also resolves
    // the "open source"/version text fragment reported in known-issues
    // pkt 2 (settings_aboutDescription/About row).
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

                // NODE section — own screen (2026-08-22 unification), same
                // nav-tile pattern as App Settings below.
                SectionHeader(l10n.settings_nodeSettings),
                MeshCard(
                  onTap: () => pushNodeSettingsScreen(context),
                  child: _buildNavTileContent(
                    context,
                    icon: Icons.tune,
                    title: l10n.settings_nodeSettings,
                    subtitle: l10n.settings_nodeSettingsSubtitle,
                  ),
                ),

                // LOCATION section — own screen (2026-08-22 unification).
                SectionHeader(l10n.settings_location),
                MeshCard(
                  onTap: () => pushLocationSettingsScreen(context),
                  child: _buildNavTileContent(
                    context,
                    icon: Icons.location_on_outlined,
                    title: l10n.settings_location,
                    subtitle: l10n.settings_locationSubtitle,
                  ),
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

                // DEBUG section
                SectionHeader(l10n.settings_debug),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildDebugCardContent(context),
                ),

                // ABOUT — own screen (2026-08-22 unification; used to be
                // Flutter's built-in showAboutDialog popup).
                SectionHeader(l10n.settings_about),
                MeshCard(
                  onTap: () => pushAboutScreen(context),
                  child: _buildNavTileContent(
                    context,
                    icon: Icons.info_outline,
                    title: l10n.settings_about,
                    subtitle: l10n.settings_aboutVersion(
                      _appVersion.isEmpty ? l10n.common_loading : _appVersion,
                    ),
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

  Widget _buildActionsCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        SettingsTappableTile(
          icon: Icons.sync,
          title: l10n.settings_syncTime,
          subtitle: l10n.settings_syncTimeSubtitle,
          onTap: () => _syncTime(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.refresh,
          title: l10n.settings_refreshContacts,
          subtitle: l10n.settings_refreshContactsSubtitle,
          onTap: () => connector.getContacts(),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.restart_alt,
          title: l10n.settings_rebootDevice,
          subtitle: l10n.settings_rebootDeviceSubtitle,
          titleColor: MeshTokens.of(context).warn,
          onTap: () => _confirmReboot(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.delete_outline,
          title: l10n.settings_deleteAllPaths,
          subtitle: l10n.settings_deleteAllPathsSubtitle,
          titleColor: MeshTokens.of(context).alert,
          onTap: () => _confirmDeleteAllPaths(context, connector),
        ),
      ],
    );
  }

  Widget _buildDebugCardContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SettingsTappableTile(
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
        SettingsTappableTile(
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
}
