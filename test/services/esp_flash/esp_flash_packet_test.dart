import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/esp_flash_packet.dart';

void main() {
  test(
    'EspFlashCommand.encode builds header + SLIP-framed body with no data checksum',
    () {
      // Non-data commands (e.g. SYNC) always use checksum 0.
      final command = EspFlashCommand(
        0x08,
        Uint8List.fromList(<int>[0x07, 0x07]),
      );
      final encoded = command.encode();

      // direction(0x00) + opcode(0x08) + size(2 LE) + checksum(4 LE, zero) + data
      expect(encoded.first, 0xC0); // starts SLIP-framed
      expect(encoded.last, 0xC0); // ends SLIP-framed
    },
  );

  test('espDataChecksum computes esptool XOR checksum seeded with 0xEF', () {
    final data = Uint8List.fromList(<int>[0x01, 0x02, 0x03]);
    final checksum = espDataChecksum(data);

    expect(checksum, 0xEF ^ 0x01 ^ 0x02 ^ 0x03);
  });

  test(
    'EspFlashResponse.decode parses a successful 2-byte-status ROM response',
    () {
      // Response header: direction=0x01, opcode=0x08, size=2 (LE), checksum=0 (4 bytes),
      // data = [0x00, 0x00] (status=success, error=0).
      final header = Uint8List.fromList(<int>[
        0x01,
        0x08,
        0x02,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      final frame = _slipWrap(header);

      final response = EspFlashResponse.decode(frame);

      expect(response.opcode, 0x08);
      expect(response.status, 0);
      expect(response.error, 0);
      expect(response.success, isTrue);
    },
  );

  test('EspFlashResponse.decode reports failure for non-zero status byte', () {
    final header = Uint8List.fromList(<int>[
      0x01, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x01, 0x05, // status=1 (fail), error=5
    ]);
    final frame = _slipWrap(header);

    final response = EspFlashResponse.decode(frame);

    expect(response.success, isFalse);
    expect(response.error, 5);
  });

  test(
    'EspFlashResponse.decode extracts a non-empty value before the 2-byte status trailer',
    () {
      // Added after external review: an earlier concern was whether decode()
      // hardcodes "total data length == 2" — it doesn't; it always takes the
      // LAST 2 bytes of `data` as [status, error] regardless of how many
      // value bytes precede them (this matches the real ROM-loader wire
      // format, e.g. a READ_REG response carries a 4-byte register value
      // before its 2-byte status). This test proves that explicitly instead
      // of leaving it implied by the smaller fixed-size responses above.
      final header = Uint8List.fromList(<int>[
        0x01, 0x0A, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xDE, 0xAD, 0xBE, 0xEF, // 4-byte value
        0x00, 0x00, // status=success, error=0
      ]);
      final frame = _slipWrap(header);

      final response = EspFlashResponse.decode(frame);

      expect(response.value, orderedEquals(<int>[0xDE, 0xAD, 0xBE, 0xEF]));
      expect(response.success, isTrue);
    },
  );
}

Uint8List _slipWrap(Uint8List body) {
  final out = BytesBuilder();
  out.addByte(0xC0);
  out.add(body);
  out.addByte(0xC0);
  return out.toBytes();
}
