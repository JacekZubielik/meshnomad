import 'dart:typed_data';

import 'esp_flash_protocol.dart';
import 'slip_frame_reader.dart';
import '../usb_serial_service.dart';

/// Adapts the app's existing [UsbSerialService] to the [EspFlashPort]
/// contract the esptool protocol layer depends on, and implements the
/// ESP32 "enter bootloader" reset sequence (RTS low resets the chip, DTR
/// low holds GPIO0 down through that reset so it boots into ROM download
/// mode instead of running the app).
///
/// NOTE (Xiao S3, native-USB boards): the classic DTR/RTS reset sequence
/// below is not guaranteed to succeed on every board — see Trap 3 in this
/// task's prompt. Callers (task 07's FlasherScreen) must treat "ask the
/// user to hold the board's BOOT button" as an expected fallback, not an
/// exotic troubleshooting step.
class EspSerialTransport implements EspFlashPort {
  EspSerialTransport(this._usb);

  final UsbSerialService _usb;
  final SlipFrameReader _frameReader = SlipFrameReader();

  // writeRaw, NOT write: UsbSerialService.write() wraps every payload in
  // MeshCore's own `0x3C + length` companion framing and rejects anything
  // over 172 bytes (usb_serial_frame_codec.dart) — esptool SLIP frames are
  // a different protocol entirely, and a FLASH_DATA block (4 KB + header)
  // blows that cap. SYNC only ever worked through write() by luck: the ROM
  // bootloader's SLIP parser skips the 3 spurious header bytes as garbage
  // before the first 0xC0.
  @override
  Future<void> write(Uint8List bytes) => _usb.writeRaw(bytes);

  @override
  Stream<Uint8List> get incoming =>
      _usb.rawByteStream.expand((chunk) => _frameReader.feed(chunk));

  @override
  Future<void> setDtr(bool value) => _usb.setDtr(value);

  @override
  Future<void> setRts(bool value) => _usb.setRts(value);

  /// Classic esptool "classic reset" sequence, timed to match esptool's own
  /// defaults (100ms settle, 50ms reset pulse).
  Future<void> resetIntoBootloader() async {
    await setDtr(false);
    await setRts(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setDtr(true);
    await setRts(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await setDtr(false);
  }
}
