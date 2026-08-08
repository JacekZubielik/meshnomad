import 'package:flutter/material.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/models/companion_radio_stats.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/l10n/l10n.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/widgets/mesh_ui.dart';
import 'package:meshcore_open/widgets/radio_stats_band_chart.dart';
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
  final List<double> _rssiHistory = [];
  final List<double> _snrHistory = [];
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
      _rssiHistory.add(s.lastRssiDbm.toDouble());
      _snrHistory.add(s.lastSnrDb);
      while (_noiseHistory.length > _maxSamples) {
        _noiseHistory.removeAt(0);
        _rssiHistory.removeAt(0);
        _snrHistory.removeAt(0);
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

  /// Airtime card: TX budget in the rolling 1 h window with the duty-cycle
  /// limit as a dotted-off caption, then the RX total as before.
  Widget _airtimeCard(
    AppLocalizations l10n,
    CompanionRadioStats stats,
    MeshCoreConnector connector,
    int dutyCyclePercent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = MeshTokens.of(context);
    final txUsed = connector.txAirUsedLastHourSecs;
    final txLimit = 3600 * dutyCyclePercent ~/ 100;
    final txPct = txLimit > 0 ? (txUsed * 100 / txLimit).round() : 0;
    return MeshCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.upload, size: 16, color: tokens.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.radioStats_txWindow(txUsed, txLimit),
                    style: tokens.monoBody(color: scheme.onSurface),
                  ),
                ),
                Text(
                  l10n.radioStats_txWindowPercent(txPct),
                  style: tokens.monoBody(color: tokens.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 1,
              child: CustomPaint(
                painter: _DottedLinePainter(color: scheme.outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text(
              l10n.radioStats_txLimitCaption(dutyCyclePercent, stats.txAirSecs),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          _tile(
            l10n.radioStats_rxAir(stats.rxAirSecs),
            Icons.download,
            tokens.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dutyCyclePercent = context
        .watch<AppSettingsService>()
        .settings
        .txDutyCyclePercent;
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
                  _airtimeCard(l10n, stats, connector, dutyCyclePercent),
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
                  l10n.radioStats_bandChartCaption,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RadioStatsBandChart(
                    rssi: _rssiHistory,
                    noise: _noiseHistory,
                    snr: _snrHistory,
                    noiseLabel: l10n.radioStats_seriesNoise,
                  ),
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

/// Delicate dotted rule between the TX budget row and its limit caption.
class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 4.5) {
      canvas.drawLine(Offset(x, y), Offset(x + 1.5, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter old) => old.color != color;
}
