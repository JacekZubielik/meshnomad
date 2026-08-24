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

  @override
  Future<void> write(Uint8List bytes) => _usb.write(bytes);

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
