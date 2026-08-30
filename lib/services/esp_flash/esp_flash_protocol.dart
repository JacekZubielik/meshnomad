import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'esp_flash_packet.dart';

/// esptool ROM-loader opcode constants used by this protocol layer.
const int espOpcodeFlashBegin = 0x02;
const int espOpcodeFlashData = 0x03;
const int espOpcodeFlashEnd = 0x04;
const int espOpcodeSync = 0x08;
const int espOpcodeSpiAttach = 0x0D;

/// ROM-loader error code for "received message is invalid" — what an
/// original-ESP32 ROM returns when FLASH_BEGIN carries the newer 20-byte
/// payload (and vice versa scenarios). Used to drive the payload fallback.
const int espErrorInvalidMessage = 0x05;

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

/// A single persistent subscription over the port's incoming frames with a
/// timeout-safe `next()`. Two properties matter here, both learned the hard
/// way on real hardware (2026-08-25):
///
/// 1. One subscription for the protocol's whole lifetime. The previous
///    `port.incoming.first`-per-command approach created and cancelled a
///    fresh subscription for every exchange, which raced with in-flight
///    frame delivery and consumed responses out of order.
/// 2. A timed-out wait must NOT consume the next frame. `StreamQueue.next`
///    keeps its request pending after the caller's `.timeout()` fires, so
///    the abandoned request silently swallows the next arriving frame —
///    this buffer just leaves the frame queued for the next `next()` call.
class _FrameBuffer {
  _FrameBuffer(Stream<Uint8List> source) {
    _subscription = source.listen(
      (frame) {
        _frames.add(frame);
        _signal?.complete();
        _signal = null;
      },
      onError: (Object error) {
        _error = error;
        _signal?.complete();
        _signal = null;
      },
    );
  }

  final Queue<Uint8List> _frames = Queue<Uint8List>();
  Completer<void>? _signal;
  Object? _error;
  late final StreamSubscription<Uint8List> _subscription;

  Future<Uint8List> next(Duration timeout) async {
    if (_frames.isNotEmpty) return _frames.removeFirst();
    if (_error != null) throw StateError('USB stream error: $_error');
    final signal = Completer<void>();
    _signal = signal;
    try {
      await signal.future.timeout(timeout);
    } on TimeoutException {
      if (identical(_signal, signal)) _signal = null;
      // A frame may have landed between the timer firing and this handler
      // running — prefer delivering it over throwing.
      if (_frames.isNotEmpty) return _frames.removeFirst();
      rethrow;
    }
    if (_frames.isNotEmpty) return _frames.removeFirst();
    if (_error != null) throw StateError('USB stream error: $_error');
    throw TimeoutException('No frame available');
  }

  Future<void> dispose() => _subscription.cancel();
}

/// esptool ROM-loader wire protocol: SYNC handshake, SPI flash attach, and
/// flash begin/data/end (implemented in Task 4). Talks directly to the ROM
/// bootloader — no stub-loader upload (see plan Global Constraints).
class EspFlashProtocol {
  // Subscribes to `port.incoming` immediately in the constructor — the
  // buffer must exist before the first write so no response can slip past.
  EspFlashProtocol(this.port) : _incoming = _FrameBuffer(port.incoming);

  final EspFlashPort port;
  final _FrameBuffer _incoming;

  /// Cancels the underlying frame subscription. Call when the flash
  /// session is over (success or failure).
  Future<void> dispose() => _incoming.dispose();

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
      await port.write(encoded);
      try {
        final frame = await _incoming.next(attemptTimeout);
        final response = EspFlashResponse.decode(frame);
        if (response.opcode == espOpcodeSync && response.success) {
          // The ROM answers ONE sync command with a whole burst of
          // identical response packets (esptool reads and discards seven
          // extras after the first). Anything left queued here would be
          // mistaken for the NEXT command's reply — observed live
          // 2026-08-25 as SPI_ATTACH "succeeding" against a leftover SYNC
          // response. Drain until the line goes quiet.
          await _drainQueuedFrames();
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

  Future<void> _drainQueuedFrames({
    Duration quietTime = const Duration(milliseconds: 100),
  }) async {
    while (true) {
      try {
        await _incoming.next(quietTime);
      } on TimeoutException {
        return;
      }
    }
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
  ///
  /// [blockSize] defaults to 0x400 — esptool's FLASH_WRITE_SIZE when
  /// talking to the ROM loader (the 0x4000 figure seen elsewhere is
  /// stub-loader only).
  Stream<double> flashImage({
    required Uint8List image,
    required int offset,
    int blockSize = 0x400,
  }) async* {
    final blockCount = (image.length / blockSize).ceil().clamp(1, 1 << 32);
    // FLASH_BEGIN triggers a synchronous flash-sector erase on the device
    // before it replies — for a multi-hundred-KB image (typical MeshCore
    // companion firmware) this can legitimately take several seconds, far
    // longer than the 3s default used for every other command.
    const beginTimeout = Duration(seconds: 20);
    // ESP32-S2/S3/C3-generation ROM loaders REQUIRE a fifth 32-bit word in
    // FLASH_BEGIN (flash-encryption flag, 0 = plaintext) and reject the
    // classic 16-byte payload with error 0x05 "invalid message" — the
    // failure that, combined with the status-trailer decode bug, produced
    // a fully fake "successful" flash on a Heltec V4 (ESP32-S3). The
    // original ESP32 ROM conversely rejects the 20-byte form, so try
    // modern first and fall back once.
    final begin = await _sendAndExpect(
      EspFlashCommand(
        espOpcodeFlashBegin,
        _flashBeginPayload(
          imageSize: image.length,
          blockSize: blockSize,
          blockCount: blockCount,
          offset: offset,
          includeEncryptionFlag: true,
        ),
      ),
      timeout: beginTimeout,
      throwOnFailureStatus: false,
    );
    if (!begin.success) {
      if (begin.error != espErrorInvalidMessage) {
        throw EspFlashException(
          'esptool FLASH_BEGIN failed '
          '(status=${begin.status}, error=${begin.error})',
        );
      }
      await _sendAndExpect(
        EspFlashCommand(
          espOpcodeFlashBegin,
          _flashBeginPayload(
            imageSize: image.length,
            blockSize: blockSize,
            blockCount: blockCount,
            offset: offset,
            includeEncryptionFlag: false,
          ),
        ),
        timeout: beginTimeout,
      );
    }

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

    // FLASH_END flag 0 asks the ROM itself to reboot the chip. The flag-1
    // ("run user code") variant is rejected by the ROM with error 0x06
    // (observed live on a Heltec V4 after every block was already
    // written), and esptool skips flash_finish for ROM loaders entirely,
    // relying on an RTS pulse instead — but native USB-Serial/JTAG boards
    // can ignore that pulse, so ask the ROM to reboot AND let the caller
    // pulse the lines; whichever works, wins. Best-effort by design: a
    // chip that reboots on receipt never sends the response.
    try {
      await _sendAndExpect(
        EspFlashCommand(espOpcodeFlashEnd, Uint8List(4)), // flag 0 = reboot
        timeout: const Duration(milliseconds: 500),
        throwOnFailureStatus: false,
      );
    } on TimeoutException {
      // No response — the chip is most likely already rebooting.
    } on EspFlashException {
      // Desync guard tripped by a reboot-banner fragment — irrelevant now.
    } on FormatException {
      // Non-SLIP boot banner bytes instead of a response — same story.
    }
  }

  Uint8List _flashBeginPayload({
    required int imageSize,
    required int blockSize,
    required int blockCount,
    required int offset,
    required bool includeEncryptionFlag,
  }) {
    final out = BytesBuilder();
    _addUint32Le(out, imageSize);
    _addUint32Le(out, blockCount);
    _addUint32Le(out, blockSize);
    _addUint32Le(out, offset);
    if (includeEncryptionFlag) {
      _addUint32Le(out, 0); // 0 = do not encrypt while writing
    }
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
    bool throwOnFailureStatus = true,
  }) async {
    await port.write(command.encode());
    final frame = await _incoming.next(timeout);
    final response = EspFlashResponse.decode(frame);
    // A response to the wrong command must never be treated as success —
    // this is the check that turns any future stream desync into a loud,
    // honest failure instead of a silent fake "flash complete".
    if (response.opcode != command.opcode) {
      throw EspFlashException(
        'esptool response opcode mismatch: sent 0x${command.opcode.toRadixString(16)}, '
        'got 0x${response.opcode.toRadixString(16)} — device and host are out of sync',
      );
    }
    if (throwOnFailureStatus && !response.success) {
      throw EspFlashException(
        'esptool command 0x${command.opcode.toRadixString(16)} failed '
        '(status=${response.status}, error=${response.error})',
      );
    }
    return response;
  }
}
