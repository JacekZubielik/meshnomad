import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../helpers/snack_bar_builder.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/elements_ui.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/settings_value_stepper.dart';

Future<void> pushPrivacySettingsScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const PrivacySettingsScreen(),
    ),
  );
}

/// Privacy settings — its own card screen (redesign 2026-08-23; used to be
/// an AlertDialog popup opened from Location settings). Save is the single
/// borderless action button; Cancel is gone — the system back discards.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  int _telemetryMode = teleModeDeny;
  int _telemetryLocMode = teleModeDeny;
  int _telemetryEnvMode = teleModeDeny;
  bool _advertLocPolicy = false;
  int _multiAcks = 0;
  bool _autoZeroHopAdvertOnGpsUpdate = false;

  static const _telemModeValues = [
    teleModeDeny,
    teleModeAllowFlags,
    teleModeAllowAll,
  ];

  @override
  void initState() {
    super.initState();
    final connector = context.read<MeshCoreConnector>();
    final settingsService = context.read<AppSettingsService>();
    _telemetryMode = connector.telemetryModeBase;
    _telemetryLocMode = connector.telemetryModeLoc;
    _telemetryEnvMode = connector.telemetryModeEnv;
    _advertLocPolicy = connector.advertLocationPolicy != 0;
    _multiAcks = connector.multiAcks;
    _autoZeroHopAdvertOnGpsUpdate =
        settingsService.settings.autoSendZeroHopAdvertOnGpsUpdate;
  }

  String _telemModeLabel(BuildContext ctx, int v) => switch (v) {
    teleModeAllowFlags => ctx.l10n.settings_allowByContact,
    teleModeAllowAll => ctx.l10n.settings_allowAll,
    _ => ctx.l10n.settings_denyAll,
  };

  Widget _telemModeRow({
    required String label,
    required Key stepperKey,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final t = MeshTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).listTileTheme.titleTextStyle,
          ),
        ),
        SizedBox(width: t.spacingSm),
        SettingsValueStepper<int>(
          key: stepperKey,
          values: _telemModeValues,
          value: value,
          labelOf: _telemModeLabel,
          buttonBorder: context
              .watch<AppSettingsService>()
              .activeProfileOverrides
              .buttonBorder,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final connector = context.read<MeshCoreConnector>();
    final settingsService = context.read<AppSettingsService>();
    await connector.setTelemetryModeBase(
      _telemetryMode,
      _telemetryLocMode,
      _telemetryEnvMode,
      _advertLocPolicy ? 1 : 0,
      _multiAcks,
    );
    await settingsService.setAutoSendZeroHopAdvertOnGpsUpdate(
      _autoZeroHopAdvertOnGpsUpdate,
    );
    await connector.refreshDeviceInfo();
    if (!mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(l10n.settings_telemetryModeUpdated),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settings_privacy), centerTitle: true),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: t.spacingXs),
            children: [
              MeshCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settings_privacySettingsDescription),
                    SizedBox(height: t.spacingMd),
                    FeatureToggleRow(
                      title: l10n.settings_advertLocation,
                      subtitle: l10n.settings_advertLocationSubtitle,
                      value: _advertLocPolicy,
                      onChanged: (value) =>
                          setState(() => _advertLocPolicy = value),
                    ),
                    SizedBox(height: t.spacingXs),
                    FeatureToggleRow(
                      title: l10n.settings_autoZeroHopAdvertOnGpsUpdate,
                      subtitle:
                          l10n.settings_autoZeroHopAdvertOnGpsUpdateSubtitle,
                      value: _autoZeroHopAdvertOnGpsUpdate,
                      enabled: _advertLocPolicy,
                      onChanged: _advertLocPolicy
                          ? (value) => setState(
                              () => _autoZeroHopAdvertOnGpsUpdate = value,
                            )
                          : null,
                    ),
                    SizedBox(height: t.spacingXs),
                    SwitchListTile(
                      title: Text(l10n.settings_multiAck),
                      value: _multiAcks == 1,
                      onChanged: (value) =>
                          setState(() => _multiAcks = value ? 1 : 0),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SizedBox(height: t.spacingXs),
                    const MeshDashedDivider(),
                    SizedBox(height: t.spacingXs),
                    Text(
                      l10n.settings_telemetrySection,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: t.spacingMd),
                    _telemModeRow(
                      label: l10n.settings_telemetryBaseMode,
                      stepperKey: const ValueKey('telemetryBaseModeStepper'),
                      value: _telemetryMode,
                      onChanged: (value) =>
                          setState(() => _telemetryMode = value),
                    ),
                    SizedBox(height: t.spacingMd),
                    _telemModeRow(
                      label: l10n.settings_telemetryLocationMode,
                      stepperKey: const ValueKey(
                        'telemetryLocationModeStepper',
                      ),
                      value: _telemetryLocMode,
                      onChanged: (value) =>
                          setState(() => _telemetryLocMode = value),
                    ),
                    SizedBox(height: t.spacingMd),
                    _telemModeRow(
                      label: l10n.settings_telemetryEnvironmentMode,
                      stepperKey: const ValueKey('telemetryEnvModeStepper'),
                      value: _telemetryEnvMode,
                      onChanged: (value) =>
                          setState(() => _telemetryEnvMode = value),
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
