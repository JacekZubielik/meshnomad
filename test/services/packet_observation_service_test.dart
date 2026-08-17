import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/packet_observation.dart';
import 'package:meshcore_open/services/packet_observation_service.dart';

PacketObservation _observation({
  required DateTime at,
  int payloadType = 0x05,
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
  group('PacketObservation', () {
    test('splits path bytes into hop tokens by hash width', () {
      final observation = _observation(
        at: DateTime(2026, 1, 1),
        hopCount: 3,
        hopHashWidth: 2,
        pathBytes: [0x0a, 0x1b, 0x2c, 0x3d, 0x4e, 0x5f],
      );

      expect(observation.hopTokens, ['0A1B', '2C3D', '4E5F']);
      expect(observation.pathSignature, '0A1B>2C3D>4E5F');
    });

    test('reports no path when there are no hops', () {
      final observation = _observation(at: DateTime(2026, 1, 1));

      expect(observation.hopTokens, isEmpty);
      expect(observation.pathSignature, isNull);
    });
  });

  group('PacketObservationService', () {
    test('records observations and counts them', () {
      final service = PacketObservationService();

      service.record(_observation(at: DateTime(2026, 1, 1, 12)));
      service.record(_observation(at: DateTime(2026, 1, 1, 12, 1)));

      expect(service.observations, hasLength(2));
      expect(service.totalObserved, 2);
      expect(service.trimmedCount, 0);
      expect(service.coversWholeSession, isTrue);
    });

    test('drops oldest observations past the cap and reports trimming', () {
      final service = PacketObservationService(maxObservations: 2);

      service.record(_observation(at: DateTime(2026, 1, 1, 12), rssi: -60));
      service.record(_observation(at: DateTime(2026, 1, 1, 12, 1), rssi: -70));
      service.record(_observation(at: DateTime(2026, 1, 1, 12, 2), rssi: -80));

      expect(service.observations, hasLength(2));
      expect(service.observations.first.rssi, -70);
      expect(service.totalObserved, 3);
      expect(service.trimmedCount, 1);
      expect(service.coversWholeSession, isFalse);
    });

    test('filters observations by window start inclusively', () {
      final service = PacketObservationService();
      final cutoff = DateTime(2026, 1, 1, 12, 30);

      service.record(_observation(at: DateTime(2026, 1, 1, 12)));
      service.record(_observation(at: cutoff));
      service.record(_observation(at: DateTime(2026, 1, 1, 13)));

      expect(service.since(cutoff), hasLength(2));
    });

    test('clear resets counters', () {
      final service = PacketObservationService(maxObservations: 1);

      service.record(_observation(at: DateTime(2026, 1, 1, 12)));
      service.record(_observation(at: DateTime(2026, 1, 1, 13)));
      service.clear();

      expect(service.observations, isEmpty);
      expect(service.totalObserved, 0);
      expect(service.trimmedCount, 0);
    });

    test('notifies listeners on record', () {
      final service = PacketObservationService();
      var notifications = 0;
      service.addListener(() => notifications++);

      service.record(_observation(at: DateTime(2026, 1, 1, 12)));

      expect(notifications, 1);
    });
  });
}
