import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/models/companion_radio_stats.dart';
import 'package:meshnomad/l10n/l10n.dart';
import 'package:meshnomad/screens/companion_radio_stats_screen.dart';
import 'package:provider/provider.dart';

import '../theme/mesh_tokens.dart';
import 'indicator_caption.dart';
import 'mesh_info_dialog.dart';
import 'mesh_ui.dart';

void pushCompanionRadioStatsScreen(BuildContext context) {
  // Radio stats open as the shared info popup (MeshInfoDialog pattern),
  // not as a full-screen route.
  showMeshInfoDialog<void>(
    context,
    title: context.l10n.radioStats_screenTitle,
    builder: (_) => const RadioStatsPanel(),
  );
}

class RadioStatsIconButton extends StatefulWidget {
  final bool compact;

  const RadioStatsIconButton({super.key, this.compact = false});

  @override
  State<RadioStatsIconButton> createState() => _RadioStatsIconButtonState();
}

class _RadioStatsIconButtonState extends State<RadioStatsIconButton> {
  MeshCoreConnector? _connector;

  @override
  void initState() {
    super.initState();
    final c = context.read<MeshCoreConnector>();
    _connector = c;
    c.acquireRadioStatsPolling();
  }

  @override
  void dispose() {
    _connector?.releaseRadioStatsPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MeshCoreConnector, ({bool connected, bool supported})>(
      selector: (_, c) =>
          (connected: c.isConnected, supported: c.supportsCompanionRadioStats),
      builder: (context, state, _) {
        if (!state.connected || !state.supported) {
          return const SizedBox.shrink();
        }
        final connector = context.read<MeshCoreConnector>();
        return ValueListenableBuilder<CompanionRadioStats?>(
          valueListenable: connector.radioStatsNotifier,
          builder: (context, stats, child) {
            final dot = AirActivityDot(
              active: connector.radioStatsAirActivityPulse,
            );
            if (widget.compact) {
              final caption = stats == null ? '—' : '${stats.noiseFloorDbm}dBm';
              return Semantics(
                label: context.l10n.radioStats_tooltip,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    MeshTokens.of(context).xs,
                  ),
                  onTap: () => pushCompanionRadioStatsScreen(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MeshTokens.of(context).spacingXxs,
                      vertical: MeshTokens.of(context).spacingXs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AirActivityDot(
                          active: connector.radioStatsAirActivityPulse,
                          icon: Icons.wifi_tethering,
                        ),
                        const SizedBox(height: 2),
                        IndicatorCaption(caption),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Tooltip(
              message: context.l10n.radioStats_tooltip,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => pushCompanionRadioStatsScreen(context),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: dot),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AirActivityDot extends StatefulWidget {
  final bool active;
  final IconData? icon;

  const AirActivityDot({super.key, required this.active, this.icon});

  @override
  State<AirActivityDot> createState() => AirActivityDotState();
}

class AirActivityDotState extends State<AirActivityDot> {
  Timer? _timer;
  bool _blink = true;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startTimer();
  }

  @override
  void didUpdateWidget(covariant AirActivityDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startTimer();
    } else if (!widget.active && oldWidget.active) {
      _stopTimer();
      _blink = true;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _blink = !_blink);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.active && _blink;
    final scheme = Theme.of(context).colorScheme;
    // Blink to the caption's white, not accent blue — the accent belongs to
    // the BT transport icon.
    final color = on ? scheme.onSurface : scheme.outline;
    final icon = widget.icon;
    if (icon != null) {
      return Icon(icon, size: 18, color: color);
    }
    return PulseDot(color: color, size: 11, animate: false);
  }
}
