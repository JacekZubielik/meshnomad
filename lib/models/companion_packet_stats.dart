import 'dart:typed_data';

import '../connector/meshcore_protocol.dart';
import '../utils/app_logger.dart';

/// Parsed `RESP_CODE_STATS` + `STATS_TYPE_PACKETS` (30 bytes total).
class CompanionPacketStats {
  final int recv;
  final int sent;
  final int sentFlood;
  final int sentDirect;
  final int recvFlood;
  final int recvDirect;
  final int recvErrors;
  final DateTime receivedAt;

  const CompanionPacketStats({
    required this.recv,
    required this.sent,
    required this.sentFlood,
    required this.sentDirect,
    required this.recvFlood,
    required this.recvDirect,
    required this.recvErrors,
    required this.receivedAt,
  });

  static CompanionPacketStats? tryParse(Uint8List frame) {
    if (frame.length < 30) return null;
    if (frame[0] != respCodeStats || frame[1] != statsTypePackets) return null;
    try {
      final reader = BufferReader(frame);
      reader.skipBytes(2);
      final recv = reader.readUInt32LE();
      final sent = reader.readUInt32LE();
      final sentFlood = reader.readUInt32LE();
      final sentDirect = reader.readUInt32LE();
      final recvFlood = reader.readUInt32LE();
      final recvDirect = reader.readUInt32LE();
      final recvErrors = reader.readUInt32LE();
      return CompanionPacketStats(
        recv: recv,
        sent: sent,
        sentFlood: sentFlood,
        sentDirect: sentDirect,
        recvFlood: recvFlood,
        recvDirect: recvDirect,
        recvErrors: recvErrors,
        receivedAt: DateTime.now(),
      );
    } catch (e) {
      appLogger.warn('CompanionPacketStats parse error: $e');
      return null;
    }
  }
}
