import 'package:flutter/material.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/models/companion_radio_stats.dart';
import 'package:meshcore_open/l10n/l10n.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/widgets/mesh_ui.dart';
import 'package:meshcore_open/widgets/stats_line_chart.dart';
import 'package:provider/provider.dart';

class CompanionRadioStatsScreen extends StatelessWidget {
  const CompanionRadioStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.radioStats_screenTitle),
          centerTitle: true,
        ),
        body: const SingleChildScrollView(child: RadioStatsPanel()),
      ),
    );
  }
}

/// Live radio stats body — polling lifecycle, tiles and the noise chart.
/// Hosted by [CompanionRadioStatsScreen] and by the RF indicator's popup.
class RadioStatsPanel extends StatefulWidget {
  const RadioStatsPanel({super.key});

  @override
  State<RadioStatsPanel> createState() => _RadioStatsPanelState();
}

class _RadioStatsPanelState extends State<RadioStatsPanel> {
  final List<double> _noiseHistory = [];
  static const int _maxSamples = 120;
  MeshCoreConnector? _connector;
  DateTime? _lastChartSampleAt;

  @override
  void initState() {
    super.initState();
    final c = context.read<MeshCoreConnector>();
    _connector = c;
    c.acquireRadioStatsPolling();
    c.setPollingInterval(1);
    c.radioStatsNotifier.addListener(_onStatsUpdate);
  }

  void _onStatsUpdate() {
    final s = _connector?.radioStatsNotifier.value;
    if (s == null || !mounted) return;
    if (_lastChartSampleAt == s.receivedAt) return;
    _lastChartSampleAt = s.receivedAt;
    setState(() {
      _noiseHistory.add(s.noiseFloorDbm.toDouble());
      while (_noiseHistory.length > _maxSamples) {
        _noiseHistory.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _connector?.radioStatsNotifier.removeListener(_onStatsUpdate);
    _connector?.releaseRadioStatsPolling();
    _connector?.setPollingInterval(30);
    super.dispose();
  }

  Widget _tile(String text, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: MeshTokens.of(context).monoBody(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Selector<MeshCoreConnector, ({bool connected, bool supported})>(
      selector: (_, c) =>
          (connected: c.isConnected, supported: c.supportsCompanionRadioStats),
      builder: (context, state, _) {
        if (!state.connected) {
          return Center(child: Text(l10n.radioStats_notConnected));
        }
        if (!state.supported) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.radioStats_firmwareTooOld,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final connector = context.read<MeshCoreConnector>();
        final scheme = Theme.of(context).colorScheme;

        return ValueListenableBuilder<CompanionRadioStats?>(
          valueListenable: connector.radioStatsNotifier,
          builder: (context, stats, _) {
            // A plain column — the hosting screen or popup provides
            // the scrolling.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stats != null) ...[
                  const SectionHeader(
                    'Signal',
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  ),
                  MeshCard(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tile(
                          l10n.radioStats_noiseFloor(stats.noiseFloorDbm),
                          Icons.noise_aware,
                          scheme.onSurfaceVariant,
                        ),
                        const Divider(height: 1),
                        _tile(
                          l10n.radioStats_lastRssi(stats.lastRssiDbm),
                          Icons.wifi_tethering,
                          scheme.onSurfaceVariant,
                        ),
                        const Divider(height: 1),
                        _tile(
                          l10n.radioStats_lastSnr(
                            stats.lastSnrDb.toStringAsFixed(1),
                          ),
                          Icons.signal_cellular_alt,
                          MeshTokens.of(
                            context,
                          ).snrColor(stats.lastSnrDb, blocked: false),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader(
                    'Airtime',
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  ),
                  MeshCard(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tile(
                          l10n.radioStats_txAir(stats.txAirSecs),
                          Icons.upload,
                          MeshTokens.of(context).primary,
                        ),
                        const Divider(height: 1),
                        _tile(
                          l10n.radioStats_rxAir(stats.rxAirSecs),
                          Icons.download,
                          MeshTokens.of(context).primary,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 80),
                  Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      l10n.radioStats_waiting,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
                SectionHeader(
                  l10n.radioStats_chartCaption,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StatsLineChart(samples: _noiseHistory, height: 200),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}
