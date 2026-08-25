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

  /// Runs both bootloader-entry sequences back to back:
  ///
  /// 1. esptool's "classic reset" (100ms settle, 50ms pulse) — the
  ///    two-transistor circuit on external UART bridges (CP210x/CH340).
  /// 2. esptool's `UsbJtagSerialReset` line dance — the native ESP32-S3/C3
  ///    USB-Serial/JTAG peripheral (VID 303A PID 1001) emulates the reset
  ///    circuit with a pattern matcher that the classic timing does NOT
  ///    trigger (verified live 2026-08-25 on a Heltec V4: classic-only
  ///    reset never entered the bootloader, the user always had to hold
  ///    BOOT by hand).
  ///
  /// Running the wrong sequence for a given adapter is harmless — the
  /// matcher simply doesn't fire — so both are sent unconditionally and
  /// `sync()`'s retries take it from there.
  Future<void> resetIntoBootloader() async {
    // Classic UART-bridge sequence.
    await setDtr(false);
    await setRts(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setDtr(true);
    await setRts(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await setDtr(false);
    // UsbJtagSerialReset sequence (esptool's exact ordering, including the
    // deliberate pass through DTR=1/RTS=1 instead of 0/0).
    await setRts(false);
    await setDtr(false); // idle
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setDtr(true); // pull down GPIO0
    await setRts(false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setRts(true); // reset, passing through the (1,1) state
    await setDtr(false);
    await setRts(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setDtr(false);
    await setRts(false);
  }

  /// esptool-style hard reset: pulse the EN/RST line (RTS) with BOOT (DTR)
  /// released, so the chip reboots into whatever is in flash. FLASH_END
  /// deliberately leaves the chip parked in the ROM loader (see
  /// EspFlashProtocol.flashImage) — without this pulse the board keeps
  /// running the downloader and the user sees "nothing changed" until they
  /// power-cycle it by hand.
  Future<void> hardReset() async {
    await setDtr(false);
    await setRts(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await setRts(false);
  }
}
