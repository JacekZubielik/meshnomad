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

/// A parsed esptool ROM-loader response packet. ESP32-family ROM
/// bootloaders trail the response data with a 4-byte status
/// `[status, error, reserved, reserved]`; the ESP8266 ROM and the esptool
/// flasher stub use a 2-byte `[status, error]`. `status == 0` means
/// success. Reading the wrong trailer width is not cosmetic: an ESP32-S3
/// ROM failure `[1, 5, 0, 0]` decodes as status=0/error=0 (success!) under
/// the 2-byte rule — exactly the bug that made a rejected flash look like
/// a completed one (2026-08-25, live-debugged on a Heltec V4).
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
        'esptool response data missing status trailer',
      );
    }
    // 4-byte trailer whenever the data can carry one (ESP32-family ROM,
    // this app's only real peer); 2-byte only for short legacy replies.
    final trailerLength = data.length >= 4 ? 4 : 2;
    final trailerStart = data.length - trailerLength;
    final status = data[trailerStart];
    final error = data[trailerStart + 1];
    final value = data.sublist(0, trailerStart);
    return EspFlashResponse(
      opcode: opcode,
      value: value,
      status: status,
      error: error,
    );
  }
}
