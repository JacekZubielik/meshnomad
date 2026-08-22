import 'package:flutter/material.dart';
import 'package:meshnomad/utils/gpx_export.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';

Future<void> pushGpxExportScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => const GpxExportScreen()),
  );
}

/// GPX export options (repeaters/room server, companions, everything) — its
/// own screen, one level below Location settings (2026-08-22).
class GpxExportScreen extends StatelessWidget {
  const GpxExportScreen({super.key});

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
            title: Text(l10n.settings_gpxExport),
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
                  child: _buildExportCardContent(context, connector),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportCardContent(
    BuildContext context,
    MeshCoreConnector connector,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        SettingsTappableTile(
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportRepeaters,
          subtitle: l10n.settings_gpxExportRepeatersSubtitle,
          onTap: () {
            final exporter = GpxExport(connector);
            exporter.addRepeaters();
            _gpxExport(
              context,
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
        SettingsTappableTile(
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportContacts,
          subtitle: l10n.settings_gpxExportContactsSubtitle,
          onTap: () {
            final exporter = GpxExport(connector);
            exporter.addContacts();
            _gpxExport(
              context,
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
        SettingsTappableTile(
          icon: Icons.download_outlined,
          title: l10n.settings_gpxExportAll,
          subtitle: l10n.settings_gpxExportAllSubtitle,
          onTap: () {
            final exporter = GpxExport(connector);
            exporter.addAll();
            _gpxExport(
              context,
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

  Future<void> _gpxExport(
    BuildContext context,
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
    if (!context.mounted) return;
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
      case gpxExportNotAvailable:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportNotAvailable),
        );
      case gpxExportFailed:
        showDismissibleSnackBar(
          context,
          content: Text(l10n.settings_gpxExportError),
        );
    }
  }
}
