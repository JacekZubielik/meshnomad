import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../l10n/contact_localization.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/mesh_ui.dart';
import 'repeater_direct_console_screen.dart';
import 'repeater_status_screen.dart';
import 'repeater_cli_screen.dart';
import 'repeater_settings_screen.dart';
import 'telemetry_screen.dart';
import 'neighbors_screen.dart';

class RepeaterHubScreen extends StatelessWidget {
  final Contact repeater;
  final String password;
  final bool isAdmin;

  const RepeaterHubScreen({
    super.key,
    required this.repeater,
    required this.password,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final settingsService = context.watch<AppSettingsService>();
    final connector = context.watch<MeshCoreConnector>();
    final chemistry = settingsService.batteryChemistryForRepeater(
      repeater.publicKeyHex,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          repeater.type == advTypeRepeater
              ? (isAdmin ? l10n.repeater_management : l10n.repeater_guest)
              : (isAdmin ? l10n.room_management : l10n.room_guest),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: MeshTokens.of(context).spacingLg),
          children: [
            // ── Identity card ─────────────────────────────────────────────
            Padding(
              // vertical 20 has no exact token — spacingLg (24) is nearest.
              padding: EdgeInsets.fromLTRB(
                MeshTokens.of(context).spacingMd,
                MeshTokens.of(context).spacingLg,
                MeshTokens.of(context).spacingMd,
                MeshTokens.of(context).spacingXxs,
              ),
              child: MeshCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    AvatarCircle(
                      name: repeater.name,
                      size: 52,
                      color: MeshTokens.of(context).warn,
                      icon: Icons.cell_tower,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repeater.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repeater.shortPubKeyHex,
                            style: MeshTokens.of(
                              context,
                            ).monoCaption(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            repeater.pathLabel(
                              l10n,
                              pathHashByteWidth: connector.pathHashByteWidth,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (repeater.hasLocation) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${repeater.latitude?.toStringAsFixed(4)}, '
                                    '${repeater.longitude?.toStringAsFixed(4)}',
                                    style: MeshTokens.of(context).monoCaption(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusChip(
                      label: isAdmin ? 'ADMIN' : 'GUEST',
                      color: isAdmin
                          ? MeshTokens.of(context).primary
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            // ── Battery chemistry (admin only) ─────────────────────────────
            if (isAdmin) ...[
              SectionHeader(l10n.appSettings_batteryChemistry),
              MeshCard(
                margin: EdgeInsets.symmetric(
                  horizontal: MeshTokens.of(context).spacingMd,
                  vertical: MeshTokens.of(context).spacingXxs,
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: DropdownButtonFormField<String>(
                  initialValue: chemistry,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.battery_full, size: 18),
                    labelText: l10n.appSettings_batteryChemistry,
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    settingsService.setBatteryChemistryForRepeater(
                      repeater.publicKeyHex,
                      value,
                    );
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'nmc',
                      child: Text(l10n.appSettings_batteryNmc),
                    ),
                    DropdownMenuItem(
                      value: 'lifepo4',
                      child: Text(l10n.appSettings_batteryLifepo4),
                    ),
                    DropdownMenuItem(
                      value: 'lipo',
                      child: Text(l10n.appSettings_batteryLipo),
                    ),
                  ],
                ),
              ),
            ],

            // ── Tools ──────────────────────────────────────────────────────
            SectionHeader(
              isAdmin
                  ? l10n.repeater_managementTools
                  : l10n.repeater_guestTools,
            ),

            _HubActionTile(
              index: 0,
              icon: Icons.analytics,
              title: l10n.repeater_status,
              subtitle: l10n.repeater_statusSubtitle,
              accentColor: MeshTokens.of(context).primary,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RepeaterStatusScreen(
                      repeater: repeater,
                      password: password,
                    ),
                  ),
                );
              },
            ),

            _HubActionTile(
              index: 1,
              icon: Icons.bar_chart_sharp,
              title: l10n.repeater_telemetry,
              subtitle: l10n.repeater_telemetrySubtitle,
              accentColor: MeshTokens.of(context).secondary,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TelemetryScreen(contact: repeater),
                  ),
                );
              },
            ),

            _HubActionTile(
              index: 2,
              icon: Icons.group,
              title: l10n.repeater_neighbors,
              subtitle: l10n.repeater_neighborsSubtitle,
              accentColor: MeshTokens.of(context).signal,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NeighborsScreen(repeater: repeater, password: password),
                  ),
                );
              },
            ),

            if (isAdmin) ...[
              _HubActionTile(
                index: 3,
                icon: Icons.terminal,
                title: l10n.repeater_cli,
                subtitle: l10n.repeater_cliSubtitle,
                accentColor: MeshTokens.of(context).warn,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepeaterCliScreen(
                        repeater: repeater,
                        password: password,
                      ),
                    ),
                  );
                },
              ),
              _HubActionTile(
                index: 4,
                icon: Icons.settings,
                title: l10n.repeater_settings,
                subtitle: l10n.repeater_settingsSubtitle,
                accentColor: MeshTokens.of(context).alert,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepeaterSettingsScreen(
                        repeater: repeater,
                        password: password,
                      ),
                    ),
                  );
                },
              ),
              _HubActionTile(
                index: 5,
                icon: Icons.dvr,
                title: l10n.repeaterHub_directConsole,
                subtitle: l10n.repeaterHub_directConsoleSubtitle,
                accentColor: MeshTokens.of(context).secondary,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RepeaterDirectConsoleScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubActionTile extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _HubActionTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListEntrance(
      index: index,
      child: MeshCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(MeshTokens.of(context).md),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
