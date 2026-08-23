import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/elements_ui.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import 'contact_settings_screen.dart';
import 'gpx_export_screen.dart';
import 'privacy_settings_screen.dart';

Future<void> pushLocationSettingsScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const LocationSettingsScreen(),
    ),
  );
}

/// Location, contact auto-add and privacy settings — its own screen,
/// matching the App Settings navigation pattern (2026-08-22 unification;
/// used to be a multi-row card embedded directly in the main Settings list
/// with every row opening a dialog).
class LocationSettingsScreen extends StatelessWidget {
  const LocationSettingsScreen({super.key});

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
            title: Text(l10n.settings_location),
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
                  child: _buildLocationCardContent(context, connector),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        SettingsTappableTile(
          icon: Icons.location_on_outlined,
          title: l10n.settings_location,
          subtitle: l10n.settings_locationSubtitle,
          onTap: () => _editLocation(context, connector),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExport,
          subtitle: l10n.settings_gpxExportSubtitle,
          onTap: () => pushGpxExportScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.group_add_outlined,
          title: l10n.settings_contactSettings,
          subtitle: l10n.settings_contactSettingsSubtitle,
          // Card screen instead of the former popup (2026-08-23).
          onTap: () => pushContactSettingsScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SettingsTappableTile(
          icon: Icons.visibility_off_outlined,
          title: l10n.settings_privacy,
          subtitle: l10n.settings_privacySubtitle,
          // Card screen instead of the former popup (2026-08-23).
          onTap: () => pushPrivacySettingsScreen(context),
        ),
      ],
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
}
