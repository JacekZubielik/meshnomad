import 'package:flutter/material.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'indicator_caption.dart';
import 'mesh_info_dialog.dart';
import 'stats_line_chart.dart';

class BatteryUi {
  final IconData icon;
  final Color? color;
  const BatteryUi(this.icon, this.color);
}

BatteryUi batteryUiForPercent(BuildContext context, int? percent) {
  if (percent == null) {
    return const BatteryUi(Icons.battery_unknown, null);
  }

  final p = percent.clamp(0, 100);

  return switch (p) {
    <= 5 => BatteryUi(Icons.battery_alert, MeshTokens.of(context).alert),
    <= 15 => BatteryUi(Icons.battery_0_bar, MeshTokens.of(context).alert),
    <= 30 => BatteryUi(Icons.battery_1_bar, MeshTokens.of(context).warn),
    <= 45 => BatteryUi(Icons.battery_2_bar, MeshTokens.of(context).warn),
    <= 60 => const BatteryUi(Icons.battery_3_bar, null),
    <= 80 => const BatteryUi(Icons.battery_5_bar, null),
    _ => BatteryUi(Icons.battery_full, MeshTokens.of(context).signal),
  };
}

class BatteryIndicator extends StatefulWidget {
  final MeshCoreConnector connector;

  const BatteryIndicator({super.key, required this.connector});

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  void _showBatteryPopup(BuildContext context) {
    showMeshInfoDialog<void>(
      context,
      title: context.l10n.indicator_batteryTitle,
      builder: (_) => _BatteryPopupBody(connector: widget.connector),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.connector.batteryPercent;
    final millivolts = widget.connector.batteryMillivolts;

    if (millivolts == null) {
      return const SizedBox.shrink();
    }

    // The caption always shows the percentage — details (voltage, and the
    // upcoming history chart) live in the shared info popup.
    final displayText = percent != null ? '$percent%' : '—';

    final batteryUi = batteryUiForPercent(context, percent);

    return InkWell(
      onTap: () => _showBatteryPopup(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(batteryUi.icon, size: 18, color: batteryUi.color),
                const SizedBox(height: 2),
                IndicatorCaption(displayText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Battery popup body: live charge/voltage rows plus the session charge
/// chart with a mandatory range selector (5 min / 30 min / whole session).
class _BatteryPopupBody extends StatefulWidget {
  final MeshCoreConnector connector;

  const _BatteryPopupBody({required this.connector});

  @override
  State<_BatteryPopupBody> createState() => _BatteryPopupBodyState();
}

class _BatteryPopupBodyState extends State<_BatteryPopupBody> {
  Duration? _window = const Duration(minutes: 30);

  List<double> _samplesInWindow() {
    final history = widget.connector.batteryHistory;
    final window = _window;
    if (window == null) {
      return [for (final (_, percent) in history) percent];
    }
    final cutoff = DateTime.now().subtract(window);
    return [
      for (final (time, percent) in history)
        if (time.isAfter(cutoff)) percent,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: widget.connector,
      builder: (context, _) {
        final percent = widget.connector.batteryPercent;
        final millivolts = widget.connector.batteryMillivolts;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeshInfoRow(
              l10n.indicator_chargeLabel,
              percent != null ? '$percent%' : '—',
            ),
            MeshInfoRow(
              l10n.indicator_voltageLabel,
              millivolts != null
                  ? '${(millivolts / 1000.0).toStringAsFixed(2)} V'
                  : '—',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, window) in [
                  ('5 min', const Duration(minutes: 5)),
                  ('30 min', const Duration(minutes: 30)),
                  (l10n.indicator_rangeSession, null),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _window == window,
                    onSelected: (_) => setState(() => _window = window),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            StatsLineChart(samples: _samplesInWindow(), height: 160),
          ],
        );
      },
    );
  }
}
