import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/models/companion_core_stats.dart';

void main() {
  test('CompanionCoreStats.tryParse golden 11-byte core frame', () {
    // battery 4150 mV (0x1036 LE), uptime 90000 s (0x00015F90 LE),
    // err_flags 0b011 = CAD timeout + queue full (0x0003 LE), queue_len 2
    final frame = Uint8List.fromList([
      respCodeStats,
      statsTypeCore,
      0x36, 0x10, // battery_mv LE
      0x90, 0x5F, 0x01, 0x00, // uptime_secs LE
      0x03, 0x00, // err_flags LE
      0x02, // queue_len
    ]);
    final s = CompanionCoreStats.tryParse(frame);
    expect(s, isNotNull);
    expect(s!.batteryMillivolts, 4150);
    expect(s.uptimeSecs, 90000);
    expect(s.errFlags, 0x0003);
    expect(s.queueLen, 2);
    expect(s.queueWasFull, isTrue);
    expect(s.cadTimeoutOccurred, isTrue);
    expect(s.startRxTimeoutOccurred, isFalse);
  });

  test('CompanionCoreStats.tryParse rejects short frame', () {
    expect(CompanionCoreStats.tryParse(Uint8List(5)), isNull);
  });

  test('CompanionCoreStats.tryParse rejects wrong stats_type byte', () {
    final frame = Uint8List(11);
    frame[0] = respCodeStats;
    frame[1] = statsTypeRadio; // wrong subtype
    expect(CompanionCoreStats.tryParse(frame), isNull);
  });
}
