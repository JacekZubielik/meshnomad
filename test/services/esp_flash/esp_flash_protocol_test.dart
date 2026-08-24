import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/esp_flash_packet.dart';
import 'package:meshnomad/services/esp_flash/esp_flash_protocol.dart';

class _FakePort implements EspFlashPort {
  _FakePort(this.responses);

  final List<Uint8List> responses;
  final List<Uint8List> written = [];
  final _controller = StreamController<Uint8List>.broadcast();
  bool dtr = false;
  bool rts = false;

  @override
  Future<void> write(Uint8List bytes) async {
    written.add(bytes);
    if (responses.isNotEmpty) {
      final response = responses.removeAt(0);
      // Simulate the device replying asynchronously, next microtask.
      scheduleMicrotask(() => _controller.add(response));
    }
  }

  @override
  Stream<Uint8List> get incoming => _controller.stream;

  @override
  Future<void> setDtr(bool value) async => dtr = value;

  @override
  Future<void> setRts(bool value) async => rts = value;
}

Uint8List _syncSuccessResponse() {
  final body = Uint8List.fromList(<int>[
    0x01,
    espOpcodeSync,
    0x02,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
  final out = BytesBuilder();
  out.addByte(0xC0);
  out.add(body);
  out.addByte(0xC0);
  return out.toBytes();
}

Uint8List _genericSuccessResponse(int opcode) {
  final body = Uint8List.fromList(<int>[
    0x01,
    opcode,
    0x02,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
  final out = BytesBuilder();
  out.addByte(0xC0);
  out.add(body);
  out.addByte(0xC0);
  return out.toBytes();
}

void main() {
  test(
    'sync() succeeds on the first response and sends a SYNC command',
    () async {
      final port = _FakePort([_syncSuccessResponse()]);
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
      final port = _FakePort([_genericSuccessResponse(espOpcodeSpiAttach)]);
      final protocol = EspFlashProtocol(port);

      await protocol.attachSpiFlash();

      expect(port.written, hasLength(1));
    },
  );

  test(
    'flashImage sends FLASH_BEGIN then one FLASH_DATA block then FLASH_END, reporting progress',
    () async {
      final port = _FakePort([
        _genericSuccessResponse(espOpcodeFlashBegin),
        _genericSuccessResponse(espOpcodeFlashData),
        _genericSuccessResponse(espOpcodeFlashEnd),
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
    },
  );

  test(
    'flashImage throws EspFlashException if a FLASH_DATA block fails',
    () async {
      final port = _FakePort([
        _genericSuccessResponse(espOpcodeFlashBegin),
        // FLASH_DATA response with status=1 (failure):
        () {
          final body = Uint8List.fromList(<int>[
            0x01,
            espOpcodeFlashData,
            0x02,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x01,
            0x02,
          ]);
          final out = BytesBuilder();
          out.addByte(0xC0);
          out.add(body);
          out.addByte(0xC0);
          return out.toBytes();
        }(),
      ]);
      final protocol = EspFlashProtocol(port);

      await expectLater(
        protocol.flashImage(image: Uint8List(10), offset: 0x10000).toList(),
        throwsA(isA<EspFlashException>()),
      );
    },
  );
}
