import 'dart:typed_data';

/// SLIP (RFC 1055) framing used by the esptool ROM bootloader serial
/// protocol: every command/response packet is wrapped between two 0xC0
/// bytes, with 0xC0 and 0xDB inside the payload escaped as 0xDB 0xDC and
/// 0xDB 0xDD respectively.
const int slipEnd = 0xC0;
const int slipEsc = 0xDB;
const int slipEscEnd = 0xDC;
const int slipEscEsc = 0xDD;

Uint8List slipEncode(Uint8List payload) {
  final out = BytesBuilder();
  out.addByte(slipEnd);
  for (final byte in payload) {
    if (byte == slipEnd) {
      out.addByte(slipEsc);
      out.addByte(slipEscEnd);
    } else if (byte == slipEsc) {
      out.addByte(slipEsc);
      out.addByte(slipEscEsc);
    } else {
      out.addByte(byte);
    }
  }
  out.addByte(slipEnd);
  return out.toBytes();
}

Uint8List slipDecode(Uint8List framed) {
  if (framed.length < 2 || framed.first != slipEnd || framed.last != slipEnd) {
    throw const FormatException('SLIP frame missing END delimiters');
  }
  final out = BytesBuilder();
  var i = 1;
  final end = framed.length - 1;
  while (i < end) {
    final byte = framed[i];
    if (byte == slipEsc) {
      if (i + 1 >= end) {
        throw const FormatException('SLIP frame truncated after ESC byte');
      }
      final next = framed[i + 1];
      if (next == slipEscEnd) {
        out.addByte(slipEnd);
      } else if (next == slipEscEsc) {
        out.addByte(slipEsc);
      } else {
        throw FormatException(
          'Unknown SLIP escape sequence: 0x${next.toRadixString(16)}',
        );
      }
      i += 2;
    } else {
      out.addByte(byte);
      i += 1;
    }
  }
  return out.toBytes();
}
