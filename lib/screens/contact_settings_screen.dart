import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/elements_ui.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';

Future<void> pushContactSettingsScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const ContactSettingsScreen(),
    ),
  );
}

/// Auto-add contact settings — its own card screen (redesign 2026-08-23;
/// used to be an AlertDialog popup opened from Location settings). Save is
/// the single borderless action button; Cancel is gone — the system back
/// discards.
class ContactSettingsScreen extends StatefulWidget {
  const ContactSettingsScreen({super.key});

  @override
  State<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends State<ContactSettingsScreen> {
  bool _autoAddChat = false;
  bool _autoAddRepeater = false;
  bool _autoAddRoomServer = false;
  bool _autoAddSensor = false;
  bool _overwriteOldest = false;

  @override
  void initState() {
    super.initState();
    final connector = context.read<MeshCoreConnector>();
    _autoAddChat = connector.autoAddUsers ?? false;
    _autoAddRepeater = connector.autoAddRepeaters ?? false;
    _autoAddRoomServer = connector.autoAddRoomServers ?? false;
    _autoAddSensor = connector.autoAddSensors ?? false;
    _overwriteOldest = connector.autoAddOverwriteOldest ?? false;
  }

  Future<void> _save() async {
    final connector = context.read<MeshCoreConnector>();
    final frame = buildSetAutoAddConfigFrame(
      autoAddChat: _autoAddChat,
      autoAddRepeater: _autoAddRepeater,
      autoAddRoomServer: _autoAddRoomServer,
      autoAddSensor: _autoAddSensor,
      overwriteOldest: _overwriteOldest,
    );
    await connector.sendFrame(frame);
    await connector.sendFrame(buildGetAutoAddFlagsFrame());
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.contactsSettings_autoAddTitle),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: t.spacingXs),
            children: [
              MeshCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeatureToggleRow(
                      title: l10n.contactsSettings_autoAddUsersTitle,
                      subtitle: l10n.contactsSettings_autoAddUsersSubtitle,
                      value: _autoAddChat,
                      onChanged: (value) =>
                          setState(() => _autoAddChat = value),
                    ),
                    SizedBox(height: t.spacingXs),
                    FeatureToggleRow(
                      title: l10n.contactsSettings_autoAddRepeatersTitle,
                      subtitle: l10n.contactsSettings_autoAddRepeatersSubtitle,
                      value: _autoAddRepeater,
                      onChanged: (value) =>
                          setState(() => _autoAddRepeater = value),
                    ),
                    SizedBox(height: t.spacingXs),
                    FeatureToggleRow(
                      title: l10n.contactsSettings_autoAddRoomServersTitle,
                      subtitle:
                          l10n.contactsSettings_autoAddRoomServersSubtitle,
                      value: _autoAddRoomServer,
                      onChanged: (value) =>
                          setState(() => _autoAddRoomServer = value),
                    ),
                    SizedBox(height: t.spacingXs),
                    FeatureToggleRow(
                      title: l10n.contactsSettings_autoAddSensorsTitle,
                      subtitle: l10n.contactsSettings_autoAddSensorsSubtitle,
                      value: _autoAddSensor,
                      onChanged: (value) =>
                          setState(() => _autoAddSensor = value),
                    ),
                    const MeshDashedDivider(),
                    FeatureToggleRow(
                      title: l10n.contactsSettings_overwriteOldestTitle,
                      subtitle: l10n.contactsSettings_overwriteOldestSubtitle,
                      value: _overwriteOldest,
                      onChanged: (value) =>
                          setState(() => _overwriteOldest = value),
                    ),
                    SizedBox(height: t.spacingMd),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        // Plain action button, not a switch-style control —
                        // never renders the app-wide buttonBorder style.
                        style: const ButtonStyle(
                          side: WidgetStatePropertyAll(BorderSide.none),
                        ),
                        onPressed: _save,
                        child: Text(l10n.common_save),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
