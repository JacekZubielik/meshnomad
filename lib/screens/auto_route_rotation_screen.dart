import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/settings_value_stepper.dart';

Future<void> pushAutoRouteRotationScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const AutoRouteRotationScreen(),
    ),
  );
}

/// Auto-route-rotation settings — its own screen, opened from the Messaging
/// card (redesign 2026-08-23: the card row is now a chevron navigation tile;
/// the enable switch and its tuning rows live here, separated by dashed
/// dividers like regular card rows).
class AutoRouteRotationScreen extends StatelessWidget {
  const AutoRouteRotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<AppSettingsService>(
      builder: (context, settingsService, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appSettings_autoRouteRotation),
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
                  child: _buildCardContent(context, settingsService),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final autoRouteEnabled = settingsService.settings.autoRouteRotationEnabled;
    final t = MeshTokens.of(context);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.alt_route,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_autoRouteRotation),
          subtitle: Text(context.l10n.appSettings_autoRouteRotationSubtitle),
          value: autoRouteEnabled,
          onChanged: (value) {
            settingsService.setAutoRouteRotationEnabled(value);
            showDismissibleSnackBar(
              context,
              content: Text(
                value
                    ? context.l10n.appSettings_autoRouteRotationEnabled
                    : context.l10n.appSettings_autoRouteRotationDisabled,
              ),
              duration: const Duration(seconds: 2),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: autoRouteEnabled
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MeshDashedDivider(indent: 16),
                    _stepperRow<double>(
                      context,
                      settingsService,
                      stepperKey: const ValueKey('maxRouteWeightStepper'),
                      title: context.l10n.appSettings_maxRouteWeight,
                      subtitle: context.l10n.appSettings_maxRouteWeightSubtitle,
                      values: [for (var i = 1; i <= 10; i++) i.toDouble()],
                      value: settingsService.settings.maxRouteWeight,
                      labelOf: (v) => v.round().toString(),
                      onChanged: settingsService.setMaxRouteWeight,
                    ),
                    const MeshDashedDivider(indent: 16),
                    _stepperRow<double>(
                      context,
                      settingsService,
                      stepperKey: const ValueKey('initialRouteWeightStepper'),
                      title: context.l10n.appSettings_initialRouteWeight,
                      subtitle:
                          context.l10n.appSettings_initialRouteWeightSubtitle,
                      values: [for (var i = 1; i <= 10; i++) i * 0.5],
                      value: settingsService.settings.initialRouteWeight,
                      labelOf: (v) => v.toStringAsFixed(1),
                      onChanged: settingsService.setInitialRouteWeight,
                    ),
                    const MeshDashedDivider(indent: 16),
                    _stepperRow<double>(
                      context,
                      settingsService,
                      stepperKey: const ValueKey(
                        'routeWeightSuccessIncrementStepper',
                      ),
                      title:
                          context.l10n.appSettings_routeWeightSuccessIncrement,
                      subtitle: context
                          .l10n
                          .appSettings_routeWeightSuccessIncrementSubtitle,
                      values: [for (var i = 1; i <= 20; i++) i * 0.1],
                      value:
                          settingsService.settings.routeWeightSuccessIncrement,
                      labelOf: (v) => v.toStringAsFixed(1),
                      onChanged: settingsService.setRouteWeightSuccessIncrement,
                    ),
                    const MeshDashedDivider(indent: 16),
                    _stepperRow<double>(
                      context,
                      settingsService,
                      stepperKey: const ValueKey(
                        'routeWeightFailureDecrementStepper',
                      ),
                      title:
                          context.l10n.appSettings_routeWeightFailureDecrement,
                      subtitle: context
                          .l10n
                          .appSettings_routeWeightFailureDecrementSubtitle,
                      values: [for (var i = 1; i <= 20; i++) i * 0.1],
                      value:
                          settingsService.settings.routeWeightFailureDecrement,
                      labelOf: (v) => v.toStringAsFixed(1),
                      onChanged: settingsService.setRouteWeightFailureDecrement,
                    ),
                    const MeshDashedDivider(indent: 16),
                    _stepperRow<int>(
                      context,
                      settingsService,
                      stepperKey: const ValueKey('maxMessageRetriesStepper'),
                      title: context.l10n.appSettings_maxMessageRetries,
                      subtitle:
                          context.l10n.appSettings_maxMessageRetriesSubtitle,
                      values: [for (var i = 2; i <= 10; i++) i],
                      value: settingsService.settings.maxMessageRetries,
                      labelOf: (v) => v.toString(),
                      onChanged: settingsService.setMaxMessageRetries,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// One tuning row: title + subtitle on the left, the shared value stepper
  /// on the right. Double values coming from the old Slider UI may carry
  /// floating-point noise (e.g. 0.7000000004), so they are snapped to the
  /// nearest cycle entry before display.
  Widget _stepperRow<T extends num>(
    BuildContext context,
    AppSettingsService settingsService, {
    required Key stepperKey,
    required String title,
    required String subtitle,
    required List<T> values,
    required T value,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    final t = MeshTokens.of(context);
    final theme = Theme.of(context);
    final snapped = values.reduce(
      (a, b) => (value - a).abs() <= (value - b).abs() ? a : b,
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingMd,
        vertical: t.spacingXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.listTileTheme.titleTextStyle),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.listTileTheme.subtitleTextStyle),
              ],
            ),
          ),
          SizedBox(width: t.spacingSm),
          SettingsValueStepper<T>(
            key: stepperKey,
            values: values,
            value: snapped,
            labelOf: (_, v) => labelOf(v),
            buttonBorder: settingsService.activeProfileOverrides.buttonBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
