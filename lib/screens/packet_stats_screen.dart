import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:meshnomad/l10n/l10n.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/packet_observation_service.dart';
import 'package:meshnomad/services/packet_stats_snapshot.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
import 'package:meshnomad/widgets/settings_value_stepper.dart';
import 'package:provider/provider.dart';

// One entry per payloadTypeLabels entry (10) — previously only 5 colors for
// 10 labels, so `% length` silently repeated each color across two distinct
// payload types (e.g. Advert and Response both rendered sky blue). Operator-
// flagged 2026-08-17: colors in the timeline chart and the Packet types
// ranked card must be distinguishable, not reused.
// Pastel (Tailwind 300-tier) hue ramp, evenly stepped cyan → rose so every
// entry is clearly distinct from its neighbors (operator feedback
// 2026-08-17: colors "too similar", pastel is fine but must stay
// distinguishable). Deliberately skips amber/gold (~40°, matches
// scheme.primary/the pill border) and green (~90-150°, matches the Custom
// Style card background) so no payload color reads as UI chrome or
// disappears into the card.
const List<Color> _payloadTypeColors = [
  Color(0xFF67E8F9), // Advert — cyan-300
  Color(0xFF7DD3FC), // GroupText — sky-300
  Color(0xFF93C5FD), // TextMessage — blue-300
  Color(0xFFA5B4FC), // Ack — indigo-300
  Color(0xFFC4B5FD), // Request — violet-300
  Color(0xFFD8B4FE), // Response — purple-300
  Color(0xFFF0ABFC), // Trace — fuchsia-300
  Color(0xFFF9A8D4), // Path — pink-300
  Color(0xFFFDA4AF), // Control — rose-300
  Color(0xFFCBD5E1), // Unknown — slate-300 (neutral, not part of the ramp)
];

Color _colorForPayloadType(String label) {
  final index = payloadTypeLabels.indexOf(label);
  if (index < 0) return _payloadTypeColors.last;
  return _payloadTypeColors[index % _payloadTypeColors.length];
}

// Raw model labels (payloadTypeLabels, routeLabels, and the hop-width/RSSI
// bucket keys in packet_stats_snapshot.dart) are fixed English strings used
// as sort/color keys and asserted on by tests — translating the strings
// themselves would break both. These map a raw key to its display string
// instead, mirroring [_windowLabel] below.
String _payloadDisplayLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  switch (label) {
    case 'Advert':
      return l10n.packetStats_payloadAdvert;
    case 'GroupText':
      return l10n.packetStats_payloadGroupText;
    case 'TextMessage':
      return l10n.packetStats_payloadTextMessage;
    case 'Ack':
      return l10n.packetStats_payloadAck;
    case 'Request':
      return l10n.packetStats_payloadRequest;
    case 'Response':
      return l10n.packetStats_payloadResponse;
    case 'Trace':
      return l10n.packetStats_payloadTrace;
    case 'Path':
      return l10n.packetStats_payloadPath;
    case 'Control':
      return l10n.packetStats_payloadControl;
    case 'Unknown':
      return l10n.packetStats_payloadUnknown;
    default:
      return label;
  }
}

String _routeDisplayLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  switch (label) {
    case 'TransportFlood':
      return l10n.packetStats_routeTransportFlood;
    case 'Flood':
      return l10n.channelPath_floodPath;
    case 'Direct':
      return l10n.channelPath_directPath;
    case 'TransportDirect':
      return l10n.packetStats_routeTransportDirect;
    case 'Unknown':
      return l10n.packetStats_routeUnknown;
    default:
      return label;
  }
}

String _signalDisplayLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  switch (label) {
    case 'Strong':
      return l10n.packetStats_signalStrong;
    case 'Okay':
      return l10n.packetStats_signalOkay;
    case 'Weak':
      return l10n.packetStats_signalWeak;
    default:
      return label;
  }
}

String _hopWidthDisplayLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  switch (label) {
    case '1 byte / hop':
      return l10n.packetStats_hopWidthOneByte;
    case '2 bytes / hop':
      return l10n.packetStats_hopWidthTwoBytes;
    case '3 bytes / hop':
      return l10n.packetStats_hopWidthThreeBytes;
    case '4 bytes / hop':
      return l10n.packetStats_hopWidthFourBytes;
    case 'No path':
      return l10n.packetStats_hopWidthNoPath;
    case 'Unknown width':
      return l10n.packetStats_hopWidthUnknown;
    default:
      return label;
  }
}

String _windowLabel(BuildContext context, StatsWindow window) {
  switch (window) {
    case StatsWindow.fifteenMinutes:
      return context.l10n.packetStats_windowFifteenMinutes;
    case StatsWindow.thirtyMinutes:
      return context.l10n.packetStats_windowThirtyMinutes;
    case StatsWindow.sixtyMinutes:
      return context.l10n.packetStats_windowSixtyMinutes;
    case StatsWindow.oneDay:
      return context.l10n.packetStats_windowOneDay;
    case StatsWindow.sevenDays:
      return context.l10n.packetStats_windowSevenDays;
    case StatsWindow.twoWeeks:
      return context.l10n.packetStats_windowTwoWeeks;
    case StatsWindow.session:
      return context.l10n.packetStats_windowSession;
  }
}

String _formatDuration(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

class PacketStatsScreen extends StatefulWidget {
  const PacketStatsScreen({super.key});

  @override
  State<PacketStatsScreen> createState() => _PacketStatsScreenState();
}

class _PacketStatsScreenState extends State<PacketStatsScreen> {
  StatsWindow _window = StatsWindow.session;

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final service = context.watch<PacketObservationService>();
    final tokens = MeshTokens.of(context);
    final snapshot = PacketStatsSnapshot.build(
      observations: service.observations,
      now: DateTime.now(),
      sessionStartedAt: service.sessionStartedAt,
      window: _window,
      trimmedCount: service.trimmedCount,
      totalObserved: service.totalObserved,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.packetStats_screenTitle),
        centerTitle: true,
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => service.clear(),
                child: Text(context.l10n.packetStats_clearLog),
              ),
              const PopupMenuDivider(),
              ...quickAccessMenuItems(context),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Window stepper floats over the top-right of the BODY (user
            // corrections 2026-08-23: not in the coverage card, not in a
            // FAB slot that straddles the app bar) — visually resting on
            // the coverage card corner, where the old picker chip lived.
            _buildStatsList(context, service, snapshot, tokens),
            Positioned(
              top: tokens.spacingMd + tokens.spacingXxs,
              right: tokens.spacingMd + tokens.spacingSm,
              child: _WindowPill(
                window: _window,
                onChanged: (w) => setState(() => _window = w),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsList(
    BuildContext context,
    PacketObservationService service,
    PacketStatsSnapshot snapshot,
    MeshTokens tokens,
  ) {
    return ListView(
      padding: EdgeInsets.all(tokens.spacingMd),
      children: [
        _CoverageCard(service: service, snapshot: snapshot, window: _window),
        SizedBox(height: tokens.spacingSm),
        _StatsSummaryCard(
          snapshot: snapshot,
          maxObservations: service.maxObservations,
        ),
        SizedBox(height: tokens.spacingSm),
        _TrafficTimelineCard(snapshot: snapshot),
        SizedBox(height: tokens.spacingSm),
        _RankedCard(
          title: context.l10n.packetStats_sectionPacketTypes,
          stats: snapshot.payloadBreakdown,
          colorFor: _colorForPayloadType,
          labelFor: _payloadDisplayLabel,
        ),
        SizedBox(height: tokens.spacingSm),
        _RankedCard(
          title: context.l10n.packetStats_sectionRouteMix,
          stats: snapshot.routeBreakdown,
          labelFor: _routeDisplayLabel,
        ),
        SizedBox(height: tokens.spacingSm),
        _RankedCard(
          title: context.l10n.packetStats_sectionHopProfile,
          stats: snapshot.hopProfile,
        ),
        SizedBox(height: tokens.spacingSm),
        _RankedCard(
          title: context.l10n.packetStats_sectionHopByteWidth,
          stats: snapshot.hopByteWidth,
          labelFor: _hopWidthDisplayLabel,
        ),
        SizedBox(height: tokens.spacingSm),
        _RankedCard(
          title: context.l10n.packetStats_sectionSignalDistribution,
          stats: snapshot.rssiBuckets,
          labelFor: _signalDisplayLabel,
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.service,
    required this.snapshot,
    required this.window,
  });

  final PacketObservationService service;
  final PacketStatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final showWarning =
        (service.trimmedCount > 0 && window == StatsWindow.session) ||
        !snapshot.windowFullyCovered;

    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final messageColor = showWarning
        ? MeshPalette.warn
        : scheme.onSurfaceVariant;

    // Trimmed/partial are single warning sentences; the normal tone splits
    // into a "Tracking:" label line + a count line (operator layout request
    // 2026-08-17), matching the two always-present "N packets in window." /
    // "N observed this session." lines below.
    final List<Widget> messageLines;
    if (service.trimmedCount > 0 && window == StatsWindow.session) {
      messageLines = [
        Text(
          context.l10n.packetStats_coverageTrimmed(service.totalObserved),
          style: bodyStyle?.copyWith(color: messageColor),
        ),
      ];
    } else if (!snapshot.windowFullyCovered) {
      messageLines = [
        Text(
          context.l10n.packetStats_coveragePartial(
            _formatDuration(Duration(seconds: snapshot.coverageSeconds)),
          ),
          style: bodyStyle?.copyWith(color: messageColor),
        ),
      ];
    } else {
      messageLines = [
        Text(
          context.l10n.packetStats_coverageTrackingLabel,
          style: bodyStyle?.copyWith(color: messageColor),
        ),
        Text(
          context.l10n.packetStats_coverageNormal(service.observations.length),
          style: bodyStyle?.copyWith(color: messageColor),
        ),
      ];
    }

    return MeshCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(tokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacingXxs),
            child: Text(
              context.l10n.packetStats_coverageLabel,
              style: tokens.accentLabel(color: scheme.onSurfaceVariant),
            ),
          ),
          SizedBox(height: tokens.spacingXs),
          ...messageLines,
          Text(
            context.l10n.packetStats_coveragePacketsInWindow(
              snapshot.packetCount,
              _windowLabel(context, window),
            ),
            style: tokens.monoCaption(color: scheme.onSurfaceVariant),
          ),
          Text(
            context.l10n.packetStats_coverageObservedTotal(
              service.totalObserved,
            ),
            style: tokens.monoCaption(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Bordered pill window-selector — mirrors the mockup's `.window-dd` chip
/// (border, rounded pill, compact padding). Built on [PopupMenuButton] with
/// a fully custom [child] rather than [DropdownButton]: DropdownButton bakes
/// in a 24px default icon and Material's minimum dense-button chrome, which
/// bloated the pill past the mockup's compact proportions even after
/// shrinking the icon/text — the widget itself was the wrong building block,
/// not just its parameters (operator-flagged padding bug, second pass).
class _WindowPill extends StatelessWidget {
  const _WindowPill({required this.window, required this.onChanged});

  final StatsWindow window;
  final ValueChanged<StatsWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    // The shared -/+ value stepper (user spec 2026-08-23) — replaces the
    // former "Session ▾" popup-menu chip.
    final buttonBorder = context
        .watch<AppSettingsService>()
        .activeProfileOverrides
        .buttonBorder;
    return SettingsValueStepper<StatsWindow>(
      key: const ValueKey('packetStatsWindowStepper'),
      values: StatsWindow.values,
      value: window,
      labelOf: (ctx, w) => _windowLabel(ctx, w),
      buttonBorder: buttonBorder,
      onChanged: onChanged,
    );
  }
}

/// The six headline metrics live in ONE card (2026-08-17 operator feedback:
/// six separate tiles read as visually noisy — combine into a single
/// summary panel).
class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({
    required this.snapshot,
    required this.maxObservations,
  });

  final PacketStatsSnapshot snapshot;
  final int maxObservations;

  @override
  Widget build(BuildContext context) {
    final ppm = snapshot.packetsPerMinute;
    final ppmText = ppm >= 100
        ? ppm.toStringAsFixed(0)
        : ppm >= 10
        ? ppm.toStringAsFixed(1)
        : ppm.toStringAsFixed(2);
    final pathPercent = (snapshot.pathBearingRate * 100).round();
    final rssiDetail = snapshot.averageRssi == null
        ? context.l10n.packetStats_tileMedianRssiDetailNone
        : context.l10n.packetStats_tileMedianRssiDetail(
            snapshot.averageRssi!.toStringAsFixed(0),
          );
    final snrDetail = snapshot.averageSnr == null
        ? context.l10n.packetStats_tileMedianSnrDetailNone
        : context.l10n.packetStats_tileMedianSnrDetail(
            snapshot.averageSnr!.toStringAsFixed(1),
          );

    return StatSectionCard(
      title: context.l10n.packetStats_summaryTitle,
      minTileWidth: 180,
      maxColumns: 3,
      children: [
        StatEntry(
          icon: Icons.speed_outlined,
          label: context.l10n.packetStats_tilePacketsPerMinute,
          value: ppmText,
          detail: context.l10n.packetStats_tilePacketsPerMinuteDetail(
            snapshot.packetCount,
          ),
        ),
        StatEntry(
          icon: Icons.hub_outlined,
          label: context.l10n.packetStats_tileUniqueSources,
          value: '${snapshot.uniqueSources}',
          detail: context.l10n.packetStats_tileUniqueSourcesDetail,
        ),
        StatEntry(
          icon: Icons.alt_route_outlined,
          label: context.l10n.packetStats_tilePathDiversity,
          value: '${snapshot.distinctPaths}',
          detail: context.l10n.packetStats_tilePathDiversityDetail(pathPercent),
        ),
        StatEntry(
          icon: Icons.podcasts_outlined,
          label: context.l10n.packetStats_tileMedianRssi,
          value: snapshot.medianRssi == null
              ? '—'
              : snapshot.medianRssi!.toStringAsFixed(0),
          unit: snapshot.medianRssi == null ? null : 'dBm',
          detail: rssiDetail,
        ),
        StatEntry(
          icon: Icons.graphic_eq_outlined,
          label: context.l10n.packetStats_tileMedianSnr,
          value: snapshot.medianSnr == null
              ? '—'
              : snapshot.medianSnr!.toStringAsFixed(1),
          unit: snapshot.medianSnr == null ? null : 'dB',
          detail: snrDetail,
        ),
        StatEntry(
          icon: Icons.storage_outlined,
          label: context.l10n.packetStats_tileObservations,
          value: '${snapshot.packetCount}',
          detail: context.l10n.packetStats_tileObservationsDetail(
            maxObservations,
          ),
        ),
      ],
    );
  }
}

class _TrafficTimelineCard extends StatelessWidget {
  const _TrafficTimelineCard({required this.snapshot});

  final PacketStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxTotal = snapshot.timeline
        .map((b) => b.total)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return MeshCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(tokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.packetStats_timelineTitle.toUpperCase(),
            style: tokens.accentLabel(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: tokens.spacingSm),
          // Always render the chart structure — even with zero traffic —
          // rather than swapping in an empty-state message. 2026-08-17
          // operator feedback: parameters/sections must be visible
          // immediately, not appear only once data arrives.
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxTotal == 0 ? 1 : maxTotal.toDouble(),
                alignment: BarChartAlignment.spaceEvenly,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= snapshot.timeline.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            snapshot.timeline[index].label,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bin = snapshot.timeline[group.x];
                      final entries = bin.countsByLabel.entries
                          .map(
                            (e) =>
                                '${_payloadDisplayLabel(context, e.key)}: '
                                '${e.value}',
                          )
                          .join('\n');
                      return BarTooltipItem(
                        entries.isEmpty ? '0' : entries,
                        const TextStyle(),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < snapshot.timeline.length; i++)
                    _stackedGroup(i, snapshot.timeline[i]),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spacingSm),
          // Full legend always shown, not filtered to labels seen so far —
          // same "show everything up front" rule as the ranked cards below.
          Wrap(
            spacing: tokens.spacingSm,
            runSpacing: tokens.spacingXxs,
            children: [
              for (final label in payloadTypeLabels)
                _LegendItem(
                  color: _colorForPayloadType(label),
                  label: _payloadDisplayLabel(context, label),
                ),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _stackedGroup(int index, TimelineBin bin) {
    var cumulative = 0.0;
    final stackItems = <BarChartRodStackItem>[];
    for (final label in payloadTypeLabels) {
      final count = bin.countsByLabel[label] ?? 0;
      if (count == 0) continue;
      final from = cumulative;
      final to = cumulative + count;
      stackItems.add(
        BarChartRodStackItem(from, to, _colorForPayloadType(label)),
      );
      cumulative = to;
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          // 0-width when there's no data yet, so the bar is invisible but
          // the group slot (and its X-axis label) still renders.
          toY: bin.total == 0 ? 0 : bin.total.toDouble(),
          rodStackItems: stackItems,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  const _RankedCard({
    required this.title,
    required this.stats,
    this.colorFor,
    this.labelFor,
  });

  final String title;
  final List<RankedStat> stats;
  final Color Function(String label)? colorFor;
  // Raw stat.label values are fixed English model keys (see the comment
  // above _payloadDisplayLabel) — this translates them for display. Left
  // null for hopProfile, whose numeric bucket labels ("0", "2-5", …) don't
  // need translation.
  final String Function(BuildContext context, String label)? labelFor;

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(tokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tokens.accentLabel(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: tokens.spacingSm),
          // Every category always shown (even at 0) — 2026-08-17 operator
          // feedback: parameters must be visible immediately, not appear
          // in the list only once traffic for them arrives.
          for (final stat in stats)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacingXs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(labelFor?.call(context, stat.label) ?? stat.label),
                      Text(
                        '${stat.count} · ${(stat.share * 100).round()}%',
                        style: tokens.monoCaption(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacingXxs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stat.share.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        colorFor?.call(stat.label) ?? scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
