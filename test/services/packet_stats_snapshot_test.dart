import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/models/packet_observation.dart';
import 'package:meshnomad/services/packet_stats_snapshot.dart';

PacketObservation _obs({
  required DateTime at,
  int payloadType = 0x04,
  int routeType = 0x01,
  double snr = 8.0,
  int rssi = -72,
  int hopCount = 0,
  int hopHashWidth = 1,
  List<int> pathBytes = const [],
}) {
  return PacketObservation(
    observedAt: at,
    payloadType: payloadType,
    routeType: routeType,
    snr: snr,
    rssi: rssi,
    hopCount: hopCount,
    hopHashWidth: hopHashWidth,
    pathBytes: Uint8List.fromList(pathBytes),
    payloadLength: 12,
  );
}

void main() {
  final sessionStart = DateTime(2026, 1, 1, 12, 0, 0);

  group('window filtering', () {
    test(
      'includes a packet exactly at windowStart, excludes one before it',
      () {
        final now = sessionStart.add(const Duration(minutes: 15));
        final windowStart = now.subtract(const Duration(minutes: 15));
        final observations = [
          _obs(at: windowStart.subtract(const Duration(seconds: 1))),
          _obs(at: windowStart),
        ];

        final snapshot = PacketStatsSnapshot.build(
          observations: observations,
          now: now,
          sessionStartedAt: sessionStart,
          window: StatsWindow.fifteenMinutes,
          trimmedCount: 0,
          totalObserved: observations.length,
        );

        expect(snapshot.packetCount, 1);
      },
    );
  });

  group('packetsPerMinute', () {
    test('computes for a known count over a known window', () {
      final now = sessionStart.add(const Duration(minutes: 20));
      final observations = List.generate(
        30,
        (i) => _obs(at: now.subtract(Duration(seconds: i * 2))),
      );

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.fifteenMinutes,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      // 30 packets over the 15-minute window = 2 packets/min.
      expect(snapshot.packetCount, 30);
      expect(snapshot.packetsPerMinute, closeTo(2.0, 0.001));
    });
  });

  group('medianRssi', () {
    test('odd sample count', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [
        _obs(at: now, rssi: -90),
        _obs(at: now, rssi: -70),
        _obs(at: now, rssi: -80),
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      expect(snapshot.medianRssi, -80.0);
    });

    test('even sample count averages the two middle values', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [
        _obs(at: now, rssi: -90),
        _obs(at: now, rssi: -70),
        _obs(at: now, rssi: -80),
        _obs(at: now, rssi: -60),
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      // sorted: -90, -80, -70, -60 -> mid two: -80, -70 -> avg -75
      expect(snapshot.medianRssi, -75.0);
    });
  });

  group('timeline', () {
    test('always yields exactly 10 bins', () {
      final now = sessionStart.add(const Duration(seconds: 5));
      final snapshot = PacketStatsSnapshot.build(
        observations: const [],
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.fifteenMinutes,
        trimmedCount: 0,
        totalObserved: 0,
      );

      expect(snapshot.timeline, hasLength(10));
    });

    test('a packet at the far edge of the window lands in bin 9', () {
      final now = sessionStart.add(const Duration(minutes: 15));
      final windowStart = now.subtract(const Duration(minutes: 15));
      // binWidth = 900/10 = 90s. Last bin covers [810, 900). Put the packet
      // at the very last representable instant before `now`.
      final observations = [
        _obs(at: windowStart.add(const Duration(seconds: 899))),
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.fifteenMinutes,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      expect(snapshot.timeline, hasLength(10));
      expect(snapshot.timeline[9].total, 1);
      final sumOfOthers = snapshot.timeline
          .take(9)
          .fold<int>(0, (sum, bin) => sum + bin.total);
      expect(sumOfOthers, 0);
    });
  });

  group('hopProfile', () {
    test('preserves bucket order and does not sort by count', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [
        // Heavily weight the last bucket so a count-sort would reorder it
        // to the front; the fixed-order contract says it must stay last.
        for (var i = 0; i < 5; i++) _obs(at: now, hopCount: 40),
        _obs(at: now, hopCount: 0),
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      expect(snapshot.hopProfile.map((s) => s.label), [
        '0',
        '1',
        '2-5',
        '6-10',
        '11-15',
        '16-20',
        '21-31',
        '32+',
      ]);
      expect(snapshot.hopProfile.last.count, 5);
      expect(snapshot.hopProfile.first.count, 1);
    });
  });

  group('payloadBreakdown', () {
    test('shows every type alphabetically, including zero-count ones '
        '(operator decision 2026-08-17: full parameter set visible '
        'immediately, not growing in as traffic arrives)', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [
        _obs(at: now, payloadType: 0x00), // Request
        _obs(at: now, payloadType: 0x01), // Response
        _obs(at: now, payloadType: 0x01), // Response
        _obs(at: now, payloadType: 0x04), // Advert
        _obs(at: now, payloadType: 0x04), // Advert
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      // All 10 fixed labels present, alphabetical, regardless of count.
      expect(snapshot.payloadBreakdown.map((s) => s.label), [
        'Ack',
        'Advert',
        'Control',
        'GroupText',
        'Path',
        'Request',
        'Response',
        'TextMessage',
        'Trace',
        'Unknown',
      ]);
      final byLabel = {
        for (final s in snapshot.payloadBreakdown) s.label: s.count,
      };
      expect(byLabel['Advert'], 2);
      expect(byLabel['Response'], 2);
      expect(byLabel['Request'], 1);
      expect(byLabel['Ack'], 0);
    });
  });

  group('hopByteWidth', () {
    test('fixed order (operator decision): 1..4 bytes/hop, then No path, '
        'then Unknown width — not sorted by count', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [
        _obs(at: now, hopCount: 0), // No path
        for (var i = 0; i < 3; i++)
          _obs(at: now, hopCount: 2, hopHashWidth: 1), // 1 byte / hop
      ];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: observations.length,
      );

      expect(snapshot.hopByteWidth.map((s) => s.label), [
        '1 byte / hop',
        '2 bytes / hop',
        '3 bytes / hop',
        '4 bytes / hop',
        'No path',
        'Unknown width',
      ]);
      // "1 byte / hop" has 3 observations but must stay first (fixed
      // order) even though it outranks "No path" under a count rule too.
      expect(snapshot.hopByteWidth.first.count, 3);
      expect(snapshot.hopByteWidth[4].label, 'No path');
      expect(snapshot.hopByteWidth[4].count, 1);
    });
  });

  group('rssiBuckets', () {
    test(
      'boundaries: -70 is Okay, -85 is Okay, -69 is Strong, -86 is Weak',
      () {
        final now = sessionStart.add(const Duration(seconds: 10));
        final observations = [
          _obs(at: now, rssi: -69),
          _obs(at: now, rssi: -70),
          _obs(at: now, rssi: -85),
          _obs(at: now, rssi: -86),
        ];

        final snapshot = PacketStatsSnapshot.build(
          observations: observations,
          now: now,
          sessionStartedAt: sessionStart,
          window: StatsWindow.twoWeeks,
          trimmedCount: 0,
          totalObserved: observations.length,
        );

        final byLabel = {
          for (final s in snapshot.rssiBuckets) s.label: s.count,
        };
        expect(byLabel['Strong'], 1); // -69
        expect(byLabel['Okay'], 2); // -70, -85
        expect(byLabel['Weak'], 1); // -86
      },
    );
  });

  group('windowFullyCovered', () {
    test('is false when the oldest retained observation is younger than '
        'the window (session-only log cannot cover it)', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final observations = [_obs(at: now)];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 5,
        totalObserved: 25,
      );

      expect(snapshot.windowFullyCovered, isFalse);
    });

    test('is true when the oldest retained observation predates the '
        'window start', () {
      final now = sessionStart.add(const Duration(days: 15));
      final observations = [_obs(at: sessionStart), _obs(at: now)];

      final snapshot = PacketStatsSnapshot.build(
        observations: observations,
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.twoWeeks,
        trimmedCount: 0,
        totalObserved: 2,
      );

      expect(snapshot.windowFullyCovered, isTrue);
    });

    test('session window: false when trimmedCount > 0', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final snapshot = PacketStatsSnapshot.build(
        observations: [_obs(at: now)],
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.session,
        trimmedCount: 5,
        totalObserved: 25,
      );

      expect(snapshot.windowFullyCovered, isFalse);
    });

    test('session window: true when trimmedCount is 0', () {
      final now = sessionStart.add(const Duration(seconds: 10));
      final snapshot = PacketStatsSnapshot.build(
        observations: [_obs(at: now)],
        now: now,
        sessionStartedAt: sessionStart,
        window: StatsWindow.session,
        trimmedCount: 0,
        totalObserved: 1,
      );

      expect(snapshot.windowFullyCovered, isTrue);
    });
  });
}
