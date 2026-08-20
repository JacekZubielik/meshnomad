import 'dart:typed_data';

import '../connector/meshcore_protocol.dart';
import '../utils/app_logger.dart';

/// Parsed `RESP_CODE_STATS` + `STATS_TYPE_CORE` (11 bytes total).
class CompanionCoreStats {
  final int batteryMillivolts;
  final int uptimeSecs;
  final int errFlags;
  final int queueLen;
  final DateTime receivedAt;

  const CompanionCoreStats({
    required this.batteryMillivolts,
    required this.uptimeSecs,
    required this.errFlags,
    required this.queueLen,
    required this.receivedAt,
  });

  /// `ERR_EVENT_FULL` (`src/Dispatcher.h:110`) — outbound queue was full.
  bool get queueWasFull => (errFlags & 0x1) != 0;

  /// `ERR_EVENT_CAD_TIMEOUT` (`src/Dispatcher.h:111`).
  bool get cadTimeoutOccurred => (errFlags & 0x2) != 0;

  /// `ERR_EVENT_STARTRX_TIMEOUT` (`src/Dispatcher.h:112`).
  bool get startRxTimeoutOccurred => (errFlags & 0x4) != 0;

  static CompanionCoreStats? tryParse(Uint8List frame) {
    if (frame.length < 11) return null;
    if (frame[0] != respCodeStats || frame[1] != statsTypeCore) return null;
    try {
      final reader = BufferReader(frame);
      reader.skipBytes(2);
      final batteryMv = reader.readUInt16LE();
      final uptime = reader.readUInt32LE();
      final flags = reader.readUInt16LE();
      final queueLen = reader.readUInt8();
      return CompanionCoreStats(
        batteryMillivolts: batteryMv,
        uptimeSecs: uptime,
        errFlags: flags,
        queueLen: queueLen,
        receivedAt: DateTime.now(),
      );
    } catch (e) {
      appLogger.warn('CompanionCoreStats parse error: $e');
      return null;
    }
  }
}
