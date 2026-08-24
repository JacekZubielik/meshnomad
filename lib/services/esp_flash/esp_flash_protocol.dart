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

  /// Attaches the SPI flash chip with auto-detected pin configuration
  /// (esptool sends a 4-byte "0" spi_config to mean "use efuse/strapping
  /// defaults", which is correct for every board this app targets).
  Future<void> attachSpiFlash() async {
    final payload = Uint8List(8); // spi_config(4) + zero(4), both 0
    await _sendAndExpect(EspFlashCommand(espOpcodeSpiAttach, payload));
  }

  /// Writes [image] to flash starting at [offset], in [blockSize]-byte
  /// chunks, yielding fractional progress as each block is acknowledged.
  Stream<double> flashImage({
    required Uint8List image,
    required int offset,
    int blockSize = 0x1000,
  }) async* {
    final blockCount = (image.length / blockSize).ceil().clamp(1, 1 << 32);
    final beginPayload = _flashBeginPayload(
      imageSize: image.length,
      blockSize: blockSize,
      blockCount: blockCount,
      offset: offset,
    );
    // FLASH_BEGIN triggers a synchronous flash-sector erase on the device
    // before it replies — for a multi-hundred-KB image (typical MeshCore
    // companion firmware) this can legitimately take several seconds, far
    // longer than the 3s default used for every other command. Added after
    // external review: the original draft used the 3s default here too,
    // which would misclassify a normal erase-in-progress device as
    // unresponsive and throw EspFlashException before the real answer
    // arrived.
    await _sendAndExpect(
      EspFlashCommand(espOpcodeFlashBegin, beginPayload),
      timeout: const Duration(seconds: 20),
    );

    for (var seq = 0; seq < blockCount; seq++) {
      final start = seq * blockSize;
      final end = (start + blockSize).clamp(0, image.length);
      var block = image.sublist(start, end);
      if (block.length < blockSize) {
        // Pad the final block with 0xFF (erased-flash value) to blockSize.
        final padded = Uint8List(blockSize)..fillRange(0, blockSize, 0xFF);
        padded.setRange(0, block.length, block);
        block = padded;
      }
      final dataPayload = _flashDataPayload(block: block, seq: seq);
      await _sendAndExpect(
        EspFlashCommand(
          espOpcodeFlashData,
          dataPayload,
          checksum: espDataChecksum(block),
        ),
      );
      yield (seq + 1) / blockCount;
    }

    // FLASH_END payload: 4-byte flag, 0 = "run the app after flashing"
    // (matches esptool's default no-reboot-into-bootloader behaviour).
    final endPayload = Uint8List(4);
    await _sendAndExpect(EspFlashCommand(espOpcodeFlashEnd, endPayload));
  }

  Uint8List _flashBeginPayload({
    required int imageSize,
    required int blockSize,
    required int blockCount,
    required int offset,
  }) {
    final out = BytesBuilder();
    _addUint32Le(out, imageSize);
    _addUint32Le(out, blockCount);
    _addUint32Le(out, blockSize);
    _addUint32Le(out, offset);
    return out.toBytes();
  }

  Uint8List _flashDataPayload({required Uint8List block, required int seq}) {
    final out = BytesBuilder();
    _addUint32Le(out, block.length);
    _addUint32Le(out, seq);
    _addUint32Le(out, 0);
    _addUint32Le(out, 0);
    out.add(block);
    return out.toBytes();
  }

  void _addUint32Le(BytesBuilder out, int value) {
    out.addByte(value & 0xFF);
    out.addByte((value >> 8) & 0xFF);
    out.addByte((value >> 16) & 0xFF);
    out.addByte((value >> 24) & 0xFF);
  }

  Future<EspFlashResponse> _sendAndExpect(
    EspFlashCommand command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final responseFuture = port.incoming.first.timeout(timeout);
    await port.write(command.encode());
    final frame = await responseFuture;
    final response = EspFlashResponse.decode(frame);
    if (!response.success) {
      throw EspFlashException(
        'esptool command 0x${command.opcode.toRadixString(16)} failed '
        '(status=${response.status}, error=${response.error})',
      );
    }
    return response;
  }
}
