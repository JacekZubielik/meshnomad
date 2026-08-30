import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/esp_flash_protocol.dart';

/// Each write pops one BATCH of response frames — the real ROM answers a
/// single SYNC command with a burst of identical responses, so a
/// one-frame-per-write fake would hide the exact desync bug this suite
/// regression-tests.
class _FakePort implements EspFlashPort {
  _FakePort(this.responseBatches);

  final List<List<Uint8List>> responseBatches;
  final List<Uint8List> written = [];
  final _controller = StreamController<Uint8List>.broadcast();
  bool dtr = false;
  bool rts = false;

  @override
  Future<void> write(Uint8List bytes) async {
    written.add(bytes);
    if (responseBatches.isNotEmpty) {
      final batch = responseBatches.removeAt(0);
      // Simulate the device replying asynchronously, next microtask.
      scheduleMicrotask(() {
        for (final response in batch) {
          _controller.add(response);
        }
      });
    }
  }

  @override
  Stream<Uint8List> get incoming => _controller.stream;

  @override
  Future<void> setDtr(bool value) async => dtr = value;

  @override
  Future<void> setRts(bool value) async => rts = value;
}

/// ROM-style response: 4-byte status trailer [status, error, 0, 0], the
/// format every ESP32-family ROM loader actually sends.
Uint8List _romResponse(int opcode, {int status = 0, int error = 0}) {
  final body = Uint8List.fromList(<int>[
    0x01,
    opcode,
    0x04,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    status,
    error,
    0x00,
    0x00,
  ]);
  final out = BytesBuilder();
  out.addByte(0xC0);
  out.add(body);
  out.addByte(0xC0);
  return out.toBytes();
}

/// The real ROM answers one SYNC with a burst of identical responses.
List<Uint8List> _syncBurst({int count = 8}) =>
    List.generate(count, (_) => _romResponse(espOpcodeSync));

void main() {
  test(
    'sync() succeeds on the first response and sends a SYNC command',
    () async {
      final port = _FakePort([_syncBurst()]);
      final protocol = EspFlashProtocol(port);

      await protocol.sync();

      expect(port.written, hasLength(1));
      expect(port.written.first.first, 0xC0); // SLIP-framed
    },
  );

  test(
    'sync() retries up to maxAttempts and throws if the device never answers',
    () async {
      final port = _FakePort(
        [],
      ); // no responses queued — every attempt times out
      final protocol = EspFlashProtocol(port);

      await expectLater(
        () => protocol.sync(
          maxAttempts: 2,
          attemptTimeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<EspFlashException>()),
      );
      expect(port.written, hasLength(2));
    },
  );

  test(
    'attachSpiFlash sends SPI_ATTACH and succeeds on an OK response',
    () async {
      final port = _FakePort([
        [_romResponse(espOpcodeSpiAttach)],
      ]);
      final protocol = EspFlashProtocol(port);

      await protocol.attachSpiFlash();

      expect(port.written, hasLength(1));
    },
  );

  test(
    'the SYNC response burst is drained: the command AFTER sync reads its '
    'own response, not a leftover SYNC frame '
    '(regression: leftover burst frames desynced every later exchange — '
    'the flash "succeeded" against stale responses on real hardware)',
    () async {
      final port = _FakePort([
        _syncBurst(),
        [_romResponse(espOpcodeSpiAttach)],
      ]);
      final protocol = EspFlashProtocol(port);

      await protocol.sync();
      // Must not throw an opcode mismatch — the burst must be gone.
      await protocol.attachSpiFlash();

      expect(port.written, hasLength(2));
    },
  );

  test(
    'a response opcode that does not match the command just sent throws '
    '(the guard that turns any future stream desync into a loud failure)',
    () async {
      final port = _FakePort([
        [_romResponse(espOpcodeSync)], // wrong opcode for SPI_ATTACH
      ]);
      final protocol = EspFlashProtocol(port);

      await expectLater(
        protocol.attachSpiFlash(),
        throwsA(
          isA<EspFlashException>().having(
            (e) => e.message,
            'message',
            contains('opcode mismatch'),
          ),
        ),
      );
    },
  );

  test(
    'a ROM failure status [1, error, 0, 0] throws instead of decoding as '
    'success (regression: the 2-byte-trailer decode read the reserved '
    'zeros as status/error, so a rejected FLASH_BEGIN looked successful)',
    () async {
      final port = _FakePort([
        [_romResponse(espOpcodeSpiAttach, status: 1, error: 0x08)],
      ]);
      final protocol = EspFlashProtocol(port);

      await expectLater(
        protocol.attachSpiFlash(),
        throwsA(
          isA<EspFlashException>().having(
            (e) => e.message,
            'message',
            contains('error=8'),
          ),
        ),
      );
    },
  );

  test('flashImage sends FLASH_BEGIN, one FLASH_DATA block, then a '
      'best-effort FLASH_END(reboot), reporting progress', () async {
    final port = _FakePort([
      [_romResponse(espOpcodeFlashBegin)],
      [_romResponse(espOpcodeFlashData)],
      [_romResponse(espOpcodeFlashEnd)],
    ]);
    final protocol = EspFlashProtocol(port);
    final image = Uint8List.fromList(List<int>.filled(100, 0xAB));

    final progress = await protocol
        .flashImage(image: image, offset: 0x10000, blockSize: 200)
        .toList();

    expect(
      port.written,
      hasLength(3),
    ); // BEGIN, one DATA block (100 < 200), END
    expect(progress.last, 1.0);
  });

  test(
    'a rejected or unanswered FLASH_END never fails the flash — the data '
    'is already written and the chip may reboot before replying '
    '(the ROM rejects flag 1 with error 0x06; flag 0 may kill the link)',
    () async {
      final rejectingPort = _FakePort([
        [_romResponse(espOpcodeFlashBegin)],
        [_romResponse(espOpcodeFlashData)],
        [_romResponse(espOpcodeFlashEnd, status: 1, error: 0x06)],
      ]);
      final progress = await EspFlashProtocol(rejectingPort)
          .flashImage(
            image: Uint8List.fromList(List<int>.filled(100, 0xAB)),
            offset: 0x10000,
            blockSize: 200,
          )
          .toList();
      expect(progress.last, 1.0);

      final silentPort = _FakePort([
        [_romResponse(espOpcodeFlashBegin)],
        [_romResponse(espOpcodeFlashData)],
        // no batch for FLASH_END — the write goes unanswered
      ]);
      final silentProgress = await EspFlashProtocol(silentPort)
          .flashImage(
            image: Uint8List.fromList(List<int>.filled(100, 0xAB)),
            offset: 0x10000,
            blockSize: 200,
          )
          .toList();
      expect(silentProgress.last, 1.0);
    },
  );

  test('FLASH_BEGIN rejected with error 0x05 (classic ESP32 ROM refusing the '
      '20-byte payload) is retried once with the 16-byte form', () async {
    final port = _FakePort([
      [
        _romResponse(
          espOpcodeFlashBegin,
          status: 1,
          error: espErrorInvalidMessage,
        ),
      ],
      [_romResponse(espOpcodeFlashBegin)],
      [_romResponse(espOpcodeFlashData)],
      [_romResponse(espOpcodeFlashEnd)],
    ]);
    final protocol = EspFlashProtocol(port);
    final image = Uint8List.fromList(List<int>.filled(100, 0xAB));

    final progress = await protocol
        .flashImage(image: image, offset: 0x10000, blockSize: 200)
        .toList();

    // BEGIN(modern), BEGIN(classic), DATA, END
    expect(port.written, hasLength(4));
    // The retried BEGIN is 4 bytes shorter (no encryption-flag word).
    expect(port.written[0].length, greaterThan(port.written[1].length));
    expect(progress.last, 1.0);
  });

  test(
    'flashImage throws EspFlashException if a FLASH_DATA block fails',
    () async {
      final port = _FakePort([
        [_romResponse(espOpcodeFlashBegin)],
        [_romResponse(espOpcodeFlashData, status: 1, error: 0x08)],
      ]);
      final protocol = EspFlashProtocol(port);

      await expectLater(
        protocol.flashImage(image: Uint8List(10), offset: 0x10000).toList(),
        throwsA(isA<EspFlashException>()),
      );
    },
  );

  test('sync, attachSpiFlash and flashImage chained on ONE protocol instance '
      'each consume their own matching response in order', () async {
    final port = _FakePort([
      _syncBurst(),
      [_romResponse(espOpcodeSpiAttach)],
      [_romResponse(espOpcodeFlashBegin)],
      [_romResponse(espOpcodeFlashData)],
      [_romResponse(espOpcodeFlashEnd)],
    ]);
    final protocol = EspFlashProtocol(port);

    await protocol.sync();
    await protocol.attachSpiFlash();
    final progress = await protocol
        .flashImage(
          image: Uint8List.fromList(List<int>.filled(10, 0xAB)),
          offset: 0x10000,
        )
        .toList();

    expect(port.written, hasLength(5)); // SYNC, ATTACH, BEGIN, DATA, END
    expect(progress.last, 1.0);
  });
}
