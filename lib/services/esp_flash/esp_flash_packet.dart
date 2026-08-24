import 'dart:typed_data';

import 'slip_codec.dart';

/// esptool ROM-loader checksum seed (`ESP_CHECKSUM_MAGIC` in esptool).
const int espChecksumMagic = 0xEF;

/// XOR checksum of [data], seeded with [espChecksumMagic] — used only by
/// FLASH_DATA/MEM_DATA packets; every other command sends checksum 0.
int espDataChecksum(Uint8List data) {
  var checksum = espChecksumMagic;
  for (final byte in data) {
    checksum ^= byte;
  }
  return checksum;
}

/// A single esptool ROM-loader request packet.
///
/// Wire format (before SLIP framing): direction(1B, always 0x00 for a
/// request) + opcode(1B) + size(2B LE) + checksum(4B LE) + data.
class EspFlashCommand {
  EspFlashCommand(this.opcode, this.data, {this.checksum = 0});

  final int opcode;
  final Uint8List data;
  final int checksum;

  Uint8List encode() {
    final header = BytesBuilder();
    header.addByte(0x00); // direction: request
    header.addByte(opcode);
    header.addByte(data.length & 0xFF);
    header.addByte((data.length >> 8) & 0xFF);
    header.addByte(checksum & 0xFF);
    header.addByte((checksum >> 8) & 0xFF);
    header.addByte((checksum >> 16) & 0xFF);
    header.addByte((checksum >> 24) & 0xFF);
    header.add(data);
    return slipEncode(header.toBytes());
  }
}

/// A parsed esptool ROM-loader response packet. The ROM bootloader (as
/// opposed to an uploaded stub) always trails the response `value` with a
/// 2-byte status: `[status, error]`, `status == 0` meaning success.
class EspFlashResponse {
  EspFlashResponse({
    required this.opcode,
    required this.value,
    required this.status,
    required this.error,
  });

  final int opcode;
  final Uint8List value;
  final int status;
  final int error;

  bool get success => status == 0;

  static EspFlashResponse decode(Uint8List slipFrame) {
    final body = slipDecode(slipFrame);
    if (body.length < 10) {
      throw FormatException('esptool response too short: ${body.length} bytes');
    }
    final opcode = body[1];
    final size = body[2] | (body[3] << 8);
    final dataStart = 8;
    final dataEnd = dataStart + size;
    if (dataEnd > body.length) {
      throw FormatException(
        'esptool response declares size $size but only '
        '${body.length - dataStart} bytes available',
      );
    }
    final data = body.sublist(dataStart, dataEnd);
    if (data.length < 2) {
      throw const FormatException(
        'esptool response data missing 2-byte status trailer',
      );
    }
    final status = data[data.length - 2];
    final error = data[data.length - 1];
    final value = data.sublist(0, data.length - 2);
    return EspFlashResponse(
      opcode: opcode,
      value: value,
      status: status,
      error: error,
    );
  }
}
