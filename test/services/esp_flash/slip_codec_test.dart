import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/slip_codec.dart';

void main() {
  test('slipEncode wraps payload in END bytes with no special bytes', () {
    final encoded = slipEncode(Uint8List.fromList(<int>[0x01, 0x02, 0x03]));

    expect(encoded, orderedEquals(<int>[slipEnd, 0x01, 0x02, 0x03, slipEnd]));
  });

  test('slipEncode escapes END and ESC bytes inside the payload', () {
    final encoded = slipEncode(
      Uint8List.fromList(<int>[slipEnd, slipEsc, 0x05]),
    );

    expect(
      encoded,
      orderedEquals(<int>[
        slipEnd,
        slipEsc,
        slipEscEnd,
        slipEsc,
        slipEscEsc,
        0x05,
        slipEnd,
      ]),
    );
  });

  test('slipDecode reverses slipEncode for arbitrary payloads', () {
    final payload = Uint8List.fromList(<int>[
      0x00,
      slipEnd,
      slipEsc,
      0xFF,
      0x7E,
      slipEnd,
    ]);

    expect(slipDecode(slipEncode(payload)), orderedEquals(payload));
  });

  test('slipDecode rejects a frame missing the trailing END byte', () {
    expect(
      () => slipDecode(Uint8List.fromList(<int>[slipEnd, 0x01, 0x02])),
      throwsFormatException,
    );
  });

  test('slipDecode rejects an unknown escape sequence', () {
    expect(
      () => slipDecode(
        Uint8List.fromList(<int>[slipEnd, slipEsc, 0x99, slipEnd]),
      ),
      throwsFormatException,
    );
  });
}
