import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/models/companion_packet_stats.dart';

Uint8List _u32le(int v) {
  final b = Uint8List(4);
  b.buffer.asByteData().setUint32(0, v, Endian.little);
  return b;
}

void main() {
  test('CompanionPacketStats.tryParse golden 30-byte packets frame', () {
    final frame = Uint8List.fromList([
      respCodeStats,
      statsTypePackets,
      ..._u32le(1000), // recv
      ..._u32le(900), // sent
      ..._u32le(300), // sent flood
      ..._u32le(600), // sent direct
      ..._u32le(400), // recv flood
      ..._u32le(600), // recv direct
      ..._u32le(12), // recv errors
    ]);
    final s = CompanionPacketStats.tryParse(frame);
    expect(s, isNotNull);
    expect(s!.recv, 1000);
    expect(s.sent, 900);
    expect(s.sentFlood, 300);
    expect(s.sentDirect, 600);
    expect(s.recvFlood, 400);
    expect(s.recvDirect, 600);
    expect(s.recvErrors, 12);
  });

  test('CompanionPacketStats.tryParse rejects short frame', () {
    expect(CompanionPacketStats.tryParse(Uint8List(10)), isNull);
  });

  test('CompanionPacketStats.tryParse rejects wrong stats_type byte', () {
    final frame = Uint8List(30);
    frame[0] = respCodeStats;
    frame[1] = statsTypeCore; // wrong subtype
    expect(CompanionPacketStats.tryParse(frame), isNull);
  });
}
