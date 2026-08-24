import 'dart:async';
import 'dart:typed_data';

import 'esp_flash_packet.dart';

/// esptool ROM-loader opcode constants used by this protocol layer.
const int espOpcodeFlashBegin = 0x02;
const int espOpcodeFlashData = 0x03;
const int espOpcodeFlashEnd = 0x04;
const int espOpcodeSync = 0x08;
const int espOpcodeSpiAttach = 0x0D;

/// Transport contract [EspFlashProtocol] depends on. Implemented by
/// [EspSerialTransport] (Task 5) against the app's real USB stack, and by a
/// fake in tests — the protocol layer never touches platform channels or
/// `flutter_libserialport` directly.
abstract class EspFlashPort {
  Future<void> write(Uint8List bytes);
  Stream<Uint8List> get incoming;
  Future<void> setDtr(bool value);
  Future<void> setRts(bool value);
}

class EspFlashException implements Exception {
  EspFlashException(this.message);
  final String message;

  @override
  String toString() => 'EspFlashException: $message';
}

/// esptool ROM-loader wire protocol: SYNC handshake, SPI flash attach, and
/// flash begin/data/end (implemented in Task 4). Talks directly to the ROM
/// bootloader — no stub-loader upload (see plan Global Constraints).
class EspFlashProtocol {
  EspFlashProtocol(this.port);

  final EspFlashPort port;

  /// The esptool "sync" command: fixed 36-byte payload
  /// `0x07 0x07 0x12 0x20` followed by 32 repetitions of `0x55`.
  static Uint8List _syncPayload() {
    final out = BytesBuilder();
    out.add(<int>[0x07, 0x07, 0x12, 0x20]);
    for (var i = 0; i < 32; i++) {
      out.addByte(0x55);
    }
    return out.toBytes();
  }

  Future<void> sync({
    int maxAttempts = 5,
    Duration attemptTimeout = const Duration(milliseconds: 100),
  }) async {
    final command = EspFlashCommand(espOpcodeSync, _syncPayload());
    final encoded = command.encode();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final responseFuture = port.incoming.first.timeout(attemptTimeout);
      await port.write(encoded);
      try {
        final frame = await responseFuture;
        final response = EspFlashResponse.decode(frame);
        if (response.opcode == espOpcodeSync && response.success) {
          return;
        }
      } on TimeoutException {
        // fall through to next attempt
      } on FormatException {
        // malformed/partial frame (e.g. bootloader boot banner on this
        // line) — treat as a failed attempt, not a hard error.
      }
    }
    throw EspFlashException(
      'ESP32 did not respond to SYNC after $maxAttempts attempts — '
      'hold the BOOT button while connecting and try again.',
    );
  }
}
