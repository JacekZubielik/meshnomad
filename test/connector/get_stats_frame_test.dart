import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';

void main() {
  group('buildGetStatsFrame', () {
    test('CORE subtype is [cmd][0]', () {
      expect(
        buildGetStatsFrame(statsTypeCore),
        Uint8List.fromList([cmdGetStats, statsTypeCore]),
      );
    });

    test('PACKETS subtype is [cmd][2]', () {
      expect(
        buildGetStatsFrame(statsTypePackets),
        Uint8List.fromList([cmdGetStats, statsTypePackets]),
      );
    });
  });
}
