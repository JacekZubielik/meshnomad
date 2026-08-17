import 'dart:math' as math;

import '../models/packet_observation.dart';

/// Time window a [PacketStatsSnapshot] is computed over.
enum StatsWindow {
  oneMinute,
  fiveMinutes,
  tenMinutes,
  thirtyMinutes,
  session;

  /// The window's fixed duration, or `null` for [session] (unbounded, spans
  /// the whole app session).
  Duration? get span {
    switch (this) {
      case StatsWindow.oneMinute:
        return const Duration(seconds: 60);
      case StatsWindow.fiveMinutes:
        return const Duration(seconds: 300);
      case StatsWindow.tenMinutes:
        return const Duration(seconds: 600);
      case StatsWindow.thirtyMinutes:
        return const Duration(seconds: 1800);
      case StatsWindow.session:
        return null;
    }
  }
}

/// Fixed, ordered payload-type labels used for both grouping and colour
/// assignment. Order matters: colours are assigned by list index, not by
/// count, so a type keeps its colour when the window changes.
const List<String> payloadTypeLabels = [
  'Advert',
  'GroupText',
  'TextMessage',
  'Ack',
  'Request',
  'Response',
  'Trace',
  'Path',
  'Control',
  'Unknown',
];

/// Fixed, ordered route labels used for grouping.
const List<String> routeLabels = [
  'TransportFlood',
  'Flood',
  'Direct',
  'TransportDirect',
  'Unknown',
];

String _payloadTypeLabel(int payloadType) {
  switch (payloadType) {
    case 0x00:
      return 'Request';
    case 0x01:
      return 'Response';
    case 0x02:
      return 'TextMessage';
    case 0x03:
      return 'Ack';
    case 0x04:
      return 'Advert';
    case 0x05:
      return 'GroupText';
    case 0x08:
      return 'Path';
    case 0x09:
      return 'Trace';
    case 0x0B:
      return 'Control';
    default:
      return 'Unknown';
  }
}

String _routeLabel(int routeType) {
  switch (routeType) {
    case 0x00:
      return 'TransportFlood';
    case 0x01:
      return 'Flood';
    case 0x02:
      return 'Direct';
    case 0x03:
      return 'TransportDirect';
    default:
      return 'Unknown';
  }
}

/// One labelled, ranked entry in a breakdown (e.g. "Advert — 42 — 18%").
class RankedStat {
  const RankedStat({
    required this.label,
    required this.count,
    required this.share,
  });

  final String label;
  final int count;

  /// `count / denominator`, in `[0, 1]`. `0` when the denominator is `0`.
  final double share;
}

/// One bin of the traffic timeline: a time slice with a total and a
/// per-payload-type breakdown for stacking.
class TimelineBin {
  const TimelineBin({
    required this.label,
    required this.total,
    required this.countsByLabel,
  });

  /// `HH:mm` of the bin's start.
  final String label;
  final int total;
  final Map<String, int> countsByLabel;
}

/// A fully-computed set of packet statistics for one [StatsWindow], derived
/// from a [PacketObservationService]'s buffer at one point in time.
class PacketStatsSnapshot {
  const PacketStatsSnapshot({
    required this.packetCount,
    required this.windowFullyCovered,
    required this.coverageSeconds,
    required this.packetsPerMinute,
    required this.uniqueSources,
    required this.pathBearing,
    required this.distinctPaths,
    required this.pathBearingRate,
    required this.medianRssi,
    required this.averageRssi,
    required this.medianSnr,
    required this.averageSnr,
    required this.timeline,
    required this.payloadBreakdown,
    required this.routeBreakdown,
    required this.hopByteWidth,
    required this.rssiBuckets,
    required this.hopProfile,
  });

  final int packetCount;
  final bool windowFullyCovered;
  final int coverageSeconds;
  final double packetsPerMinute;
  final int uniqueSources;
  final int pathBearing;
  final int distinctPaths;
  final double pathBearingRate;
  final double? medianRssi;
  final double? averageRssi;
  final double? medianSnr;
  final double? averageSnr;
  final List<TimelineBin> timeline;

  /// Ranked, sorted by count desc then label asc; zero-count entries
  /// omitted.
  final List<RankedStat> payloadBreakdown;

  /// Ranked, sorted by count desc then label asc; zero-count entries
  /// omitted.
  final List<RankedStat> routeBreakdown;

  /// Ranked, sorted by count desc then label asc; zero-count entries
  /// omitted.
  final List<RankedStat> hopByteWidth;

  /// Fixed order strongest-to-weakest (Strong, Okay, Weak) — NOT sorted by
  /// count or label. Always has all 3 buckets, including zero-count ones.
  final List<RankedStat> rssiBuckets;

  /// Fixed bucket order by hop count — NOT sorted by count. Always has all
  /// 8 buckets, including zero-count ones.
  final List<RankedStat> hopProfile;

  static PacketStatsSnapshot build({
    required List<PacketObservation> observations,
    required DateTime now,
    required DateTime sessionStartedAt,
    required StatsWindow window,
    required int trimmedCount,
    required int totalObserved,
  }) {
    final span = window.span;
    final windowStart = span == null ? sessionStartedAt : now.subtract(span);
    final packets = observations
        .where((o) => !o.observedAt.isBefore(windowStart))
        .toList(growable: false);
    final packetCount = packets.length;

    // Coverage
    final oldestRetained = observations.isEmpty
        ? now
        : observations.first.observedAt;
    final windowFullyCovered = span == null
        ? trimmedCount == 0
        : !oldestRetained.isAfter(windowStart);
    final coverageSeconds = math.max(
      1,
      now.difference(oldestRetained).inSeconds,
    );

    // Rates
    final effectiveSeconds = span == null
        ? math.max(1, now.difference(sessionStartedAt).inSeconds)
        : span.inSeconds;
    final packetsPerMinute =
        packetCount / math.max(effectiveSeconds / 60, 1 / 60);

    // Simple aggregates
    final sourceKeys = <String>{};
    var pathBearing = 0;
    final pathSignatures = <String>{};
    for (final p in packets) {
      final tokens = p.hopTokens;
      if (tokens.isNotEmpty) {
        sourceKeys.add(tokens.first);
        pathBearing++;
      }
      final signature = p.pathSignature;
      if (signature != null) pathSignatures.add(signature);
    }
    final uniqueSources = sourceKeys.length;
    final distinctPaths = pathSignatures.length;
    final pathBearingRate = packetCount > 0 ? pathBearing / packetCount : 0.0;

    // RSSI / SNR
    final rssiValues = packets.map((p) => p.rssi.toDouble()).toList();
    final snrValues = packets.map((p) => p.snr).toList();
    final medianRssi = _median(rssiValues);
    final averageRssi = rssiValues.isEmpty
        ? null
        : rssiValues.reduce((a, b) => a + b) / rssiValues.length;
    final medianSnr = _median(snrValues);
    final averageSnr = snrValues.isEmpty
        ? null
        : snrValues.reduce((a, b) => a + b) / snrValues.length;

    // Timeline: exactly 10 bins
    final spanSeconds = math.max(
      (span ?? Duration(seconds: math.max(60, effectiveSeconds))).inSeconds,
      60,
    );
    final binWidth = math.max(1, spanSeconds ~/ 10);
    final binTotals = List<int>.filled(10, 0);
    final binCountsByLabel = List.generate(10, (_) => <String, int>{});
    for (final p in packets) {
      final offsetSeconds = p.observedAt.difference(windowStart).inSeconds;
      final index = (offsetSeconds / binWidth).floor().clamp(0, 9);
      binTotals[index]++;
      final label = _payloadTypeLabel(p.payloadType);
      binCountsByLabel[index][label] =
          (binCountsByLabel[index][label] ?? 0) + 1;
    }
    final timeline = List<TimelineBin>.generate(10, (i) {
      final binStart = windowStart.add(Duration(seconds: i * binWidth));
      final label =
          '${binStart.hour.toString().padLeft(2, '0')}:'
          '${binStart.minute.toString().padLeft(2, '0')}';
      return TimelineBin(
        label: label,
        total: binTotals[i],
        countsByLabel: binCountsByLabel[i],
      );
    });

    // Ranked breakdowns
    final payloadCounts = <String, int>{
      for (final l in payloadTypeLabels) l: 0,
    };
    final routeCounts = <String, int>{for (final l in routeLabels) l: 0};
    for (final p in packets) {
      payloadCounts[_payloadTypeLabel(p.payloadType)] =
          (payloadCounts[_payloadTypeLabel(p.payloadType)] ?? 0) + 1;
      routeCounts[_routeLabel(p.routeType)] =
          (routeCounts[_routeLabel(p.routeType)] ?? 0) + 1;
    }
    // Alphabetical, every category always present (even at 0) — the
    // operator wants the full parameter set visible immediately, not
    // growing in as traffic arrives (confuses first-time reading of the
    // screen), and sorted by label, not by count.
    final payloadBreakdown = _rankedAlphabetical(payloadCounts, packetCount);
    final routeBreakdown = _rankedAlphabetical(routeCounts, packetCount);

    // Hop byte width — fixed order (operator decision): narrowest hash
    // width first, "No path" and "Unknown width" last. NOT sorted by count.
    const hopByteWidthOrder = [
      '1 byte / hop',
      '2 bytes / hop',
      '3 bytes / hop',
      '4 bytes / hop',
      'No path',
      'Unknown width',
    ];
    final hopByteWidthCounts = <String, int>{
      for (final b in hopByteWidthOrder) b: 0,
    };
    for (final p in packets) {
      final String bucket;
      if (p.hopCount <= 0) {
        bucket = 'No path';
      } else {
        switch (p.hopHashWidth) {
          case 1:
            bucket = '1 byte / hop';
          case 2:
            bucket = '2 bytes / hop';
          case 3:
            bucket = '3 bytes / hop';
          case 4:
            bucket = '4 bytes / hop';
          default:
            bucket = 'Unknown width';
        }
      }
      hopByteWidthCounts[bucket] = (hopByteWidthCounts[bucket] ?? 0) + 1;
    }
    final hopByteWidth = [
      for (final b in hopByteWidthOrder)
        RankedStat(
          label: b,
          count: hopByteWidthCounts[b]!,
          share: packetCount > 0 ? hopByteWidthCounts[b]! / packetCount : 0.0,
        ),
    ];

    // RSSI buckets — denominator is number of packets (all have rssi).
    // Fixed order strongest-to-weakest (operator decision 2026-08-17), NOT
    // alphabetical ("Okay" would otherwise sort before "Strong").
    const rssiBucketOrder = ['Strong', 'Okay', 'Weak'];
    final rssiBucketCounts = <String, int>{
      for (final b in rssiBucketOrder) b: 0,
    };
    for (final p in packets) {
      final String bucket;
      if (p.rssi > -70) {
        bucket = 'Strong';
      } else if (p.rssi >= -85) {
        bucket = 'Okay';
      } else {
        bucket = 'Weak';
      }
      rssiBucketCounts[bucket] = (rssiBucketCounts[bucket] ?? 0) + 1;
    }
    final rssiBuckets = [
      for (final b in rssiBucketOrder)
        RankedStat(
          label: b,
          count: rssiBucketCounts[b]!,
          share: packetCount > 0 ? rssiBucketCounts[b]! / packetCount : 0.0,
        ),
    ];

    // Hop profile — fixed order, NOT sorted by count, all buckets present.
    const hopProfileOrder = [
      '0',
      '1',
      '2-5',
      '6-10',
      '11-15',
      '16-20',
      '21-31',
      '32+',
    ];
    final hopProfileCounts = <String, int>{
      for (final b in hopProfileOrder) b: 0,
    };
    for (final p in packets) {
      final String bucket;
      final h = p.hopCount;
      if (h == 0) {
        bucket = '0';
      } else if (h == 1) {
        bucket = '1';
      } else if (h <= 5) {
        bucket = '2-5';
      } else if (h <= 10) {
        bucket = '6-10';
      } else if (h <= 15) {
        bucket = '11-15';
      } else if (h <= 20) {
        bucket = '16-20';
      } else if (h <= 31) {
        bucket = '21-31';
      } else {
        bucket = '32+';
      }
      hopProfileCounts[bucket] = (hopProfileCounts[bucket] ?? 0) + 1;
    }
    final hopProfile = [
      for (final b in hopProfileOrder)
        RankedStat(
          label: b,
          count: hopProfileCounts[b]!,
          share: packetCount > 0 ? hopProfileCounts[b]! / packetCount : 0.0,
        ),
    ];

    return PacketStatsSnapshot(
      packetCount: packetCount,
      windowFullyCovered: windowFullyCovered,
      coverageSeconds: coverageSeconds,
      packetsPerMinute: packetsPerMinute,
      uniqueSources: uniqueSources,
      pathBearing: pathBearing,
      distinctPaths: distinctPaths,
      pathBearingRate: pathBearingRate,
      medianRssi: medianRssi,
      averageRssi: averageRssi,
      medianSnr: medianSnr,
      averageSnr: averageSnr,
      timeline: timeline,
      payloadBreakdown: payloadBreakdown,
      routeBreakdown: routeBreakdown,
      hopByteWidth: hopByteWidth,
      rssiBuckets: rssiBuckets,
      hopProfile: hopProfile,
    );
  }
}

double? _median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/// All categories always included (even at zero) and sorted by label, not
/// count — the operator wants the full parameter set visible immediately
/// rather than rows appearing as traffic arrives.
List<RankedStat> _rankedAlphabetical(Map<String, int> counts, int denominator) {
  final entries = counts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (final e in entries)
      RankedStat(
        label: e.key,
        count: e.value,
        share: denominator > 0 ? e.value / denominator : 0.0,
      ),
  ];
}
