import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/settings_value_stepper.dart';
import 'packet_stats_screen.dart';
import 'companion_radio_stats_screen.dart';
import 'node_name_screen.dart';
import 'radio_settings_screen.dart';
import 'region_management_screen.dart';

Future<void> pushNodeSettingsScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => const NodeSettingsScreen()),
  );
}

/// Node identity, radio, region and diagnostics settings — its own screen,
/// matching the App Settings navigation pattern (2026-08-22 unification;
/// used to be a multi-row card embedded directly in the main Settings list,
/// with some rows opening dialogs and others pushing separate screens).
class NodeSettingsScreen extends StatelessWidget {
  const NodeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<MeshCoreConnector>(
      builder: (context, connector, _) {
        return Scaffold(
          appBar: AppBar(
            // Circular/accent app-bar family (2026-08-29) — see
            // docs/superpowers/meshnomad-vault/templates/ui-patterns/app-bar-schema.md.
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(l10n.settings_nodeSettings),
            centerTitle: true,
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: MeshTokens.of(context).spacingXs,
              ),
              children: [
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: _buildNodeCardContent(context, connector),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        SettingsTappableTile(
          icon: Icons.person_outline,
          title: l10n.settings_nodeName,
          subtitle: connector.selfName ?? l10n.settings_nodeNameNotSet,
          // Card screen instead of the former popup (2026-08-23).
          onTap: () => pushNodeNameScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.radio,
          title: l10n.settings_radioSettings,
          subtitle: l10n.settings_radioSettingsSubtitle,
          // Full screen with a card layout like Regions (user spec
          // 2026-08-23) — was an AlertDialog popup.
          onTap: () => pushRadioSettingsScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.landscape,
          title: l10n.settings_regionSettings,
          subtitle: l10n.settings_regionSettingsSubtitle,
          onTap: () => pushRegionManagementScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.sensors_outlined,
          title: l10n.radioStats_settingsTile,
          subtitle: l10n.radioStats_settingsSubtitle,
          // Full screen like Packet stats below (user spec 2026-08-23) —
          // NOT the MeshInfoDialog popup the RF indicator cluster uses.
          onTap: connector.isConnected && connector.supportsCompanionRadioStats
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CompanionRadioStatsScreen(),
                  ),
                )
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
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
        // Inline value stepper instead of the former dialog (user spec
        // 2026-08-23: same control as Appearance -> Button border). Applies
        // to the device immediately, like the other steppers do.
        _buildPathHashModeRow(context, connector),
        const MeshDashedDivider(indent: 16),
        // Battery type — relocated here from its own App Settings card
        // (user spec 2026-08-23): it is a per-device setting, so it
        // belongs with the rest of the node rows.
        _buildBatteryTypeRow(context, connector),
      ],
    );
  }

  Widget _buildBatteryTypeRow(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final deviceId = connector.batteryDeviceKey;
    final isConnected = connector.isConnected && deviceId != null;
    final settingsService = context.watch<AppSettingsService>();
    final selection = isConnected
        ? settingsService.batteryChemistryForDevice(deviceId)
        : 'nmc';
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingMd,
        vertical: t.spacingSm,
      ),
      child: Row(
        children: [
          Icon(Icons.battery_full, size: 20, color: t.primary),
          SizedBox(width: t.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.appSettings_batteryChemistry,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? context.l10n.appSettings_batteryChemistryPerDevice(
                          connector.deviceDisplayName,
                        )
                      : context.l10n.appSettings_batteryChemistryConnectFirst,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacingSm),
          SettingsValueStepper<String>(
            key: const ValueKey('batteryChemistryStepper'),
            values: const ['lipo', 'nmc', 'lifepo4'],
            value: selection,
            labelOf: (ctx, v) => switch (v) {
              'lifepo4' => ctx.l10n.appSettings_batteryLifepo4,
              'lipo' => ctx.l10n.appSettings_batteryLipo,
              _ => ctx.l10n.appSettings_batteryNmc,
            },
            buttonBorder: settingsService.activeProfileOverrides.buttonBorder,
            enabled: isConnected,
            onChanged: (v) {
              if (deviceId != null) {
                settingsService.setBatteryChemistryForDevice(deviceId, v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPathHashModeRow(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    final settingsService = context.watch<AppSettingsService>();
    final mode = (connector.pathHashByteWidth - 1).clamp(0, 2).toInt();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingMd,
        vertical: t.spacingSm,
      ),
      child: Row(
        children: [
          Icon(Icons.route_outlined, size: 20, color: t.primary),
          SizedBox(width: t.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.repeater_pathHashMode,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.repeater_pathHashMode_subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacingSm),
          // Modes 0-2 ONLY (1/2/3-byte path hashes). This is a hard
          // FIRMWARE limit, not an app choice: companion_radio/MyMesh.cpp
          // (upstream meshcore-dev/MeshCore) answers ERR_CODE_ILLEGAL_ARG
          // to CMD_SET_PATH_HASH_MODE with mode >= 3, so a fourth "4
          // bytes" value can never take effect — the device keeps the old
          // mode and the cycle appears to jam (verified 2026-08-23 against
          // firmware source and the reference meshcore_py client).
          SettingsValueStepper<int>(
            key: const ValueKey('pathHashModeStepper'),
            values: const [0, 1, 2],
            value: mode,
            labelOf: (ctx, v) => switch (v) {
              0 => ctx.l10n.repeater_pathHashModeOption0,
              1 => ctx.l10n.repeater_pathHashModeOption1,
              _ => ctx.l10n.repeater_pathHashModeOption2,
            },
            buttonBorder: settingsService.activeProfileOverrides.buttonBorder,
            enabled: connector.isConnected,
            onChanged: (v) => _applyPathHashMode(context, connector, v),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPathHashMode(
    BuildContext context,
    MeshCoreConnector connector,
    int mode,
  ) async {
    final l10n = context.l10n;
    try {
      await connector.setPathHashMode(mode);
      // Give the firmware a moment to commit before reading back — an
      // immediate device-info query can race the set command and answer
      // with the OLD mode, snapping the stepper back to the previous value
      // (seen on-device 2026-08-23 as the cycle "jamming").
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await connector.refreshDeviceInfo();
    } catch (e) {
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(l10n.settings_error(e.toString())),
      );
    }
  }
}
