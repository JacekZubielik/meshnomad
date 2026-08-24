import 'dart:typed_data';

import 'slip_codec.dart';

/// Buffers a raw, non-frame-aligned byte stream and emits only complete
/// SLIP frames (`0xC0 ... 0xC0`). Any bytes seen before a frame's opening
/// `0xC0` are silently discarded — this is what makes the reader tolerant
/// of the ESP-ROM bootloader's plain-text boot banner (e.g. `"ets
/// ROM:0x..."`), which is emitted right after a hardware reset and is not
/// SLIP-framed at all.
class SlipFrameReader {
  final BytesBuilder _buffer = BytesBuilder();
  bool _inFrame = false;

  /// Feeds a chunk of raw bytes in; returns zero or more complete SLIP
  /// frames found within (and across) calls to [feed].
  List<Uint8List> feed(Uint8List chunk) {
    final frames = <Uint8List>[];
    for (final byte in chunk) {
      if (!_inFrame) {
        if (byte == slipEnd) {
          _inFrame = true;
          _buffer.addByte(byte);
        }
        // else: garbage before a frame starts (e.g. boot banner text) —
        // discard silently.
        continue;
      }
      _buffer.addByte(byte);
      if (byte == slipEnd && _buffer.length > 1) {
        frames.add(_buffer.toBytes());
        _buffer.clear();
        _inFrame = false;
      }
    }
    return frames;
  }
}
