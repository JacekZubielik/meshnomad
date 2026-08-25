import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/esp_serial_transport.dart';
import 'package:meshnomad/services/usb_serial_service_native.dart';

class _RecordingUsbSerialService extends UsbSerialService {
  final List<Uint8List> written = [];
  bool dtr = true;
  bool rts = false;
  final _incoming = StreamController<Uint8List>.broadcast();

  @override
  Future<void> setDtr(bool value) async => dtr = value;

  @override
  Future<void> setRts(bool value) async => rts = value;

  // The transport must use writeRaw (raw pass-through), never write()
  // (which wraps payloads in MeshCore's 172-byte-capped companion framing).
  @override
  Future<void> writeRaw(Uint8List data) async => written.add(data);

  @override
  Stream<Uint8List> get rawByteStream => _incoming.stream;
}

void main() {
  test('write forwards to the underlying UsbSerialService', () async {
    final usb = _RecordingUsbSerialService();
    final transport = EspSerialTransport(usb);

    await transport.write(Uint8List.fromList(<int>[0x01]));

    expect(usb.written, hasLength(1));
  });

  test('resetIntoBootloader ends with DTR and RTS both low', () async {
    final usb = _RecordingUsbSerialService();
    final transport = EspSerialTransport(usb);

    await transport.resetIntoBootloader();

    expect(usb.dtr, isFalse);
    expect(usb.rts, isFalse);
  });

  test(
    'incoming reassembles a frame split across two raw byte chunks and drops boot-banner garbage',
    () async {
      final usb = _RecordingUsbSerialService();
      final transport = EspSerialTransport(usb);
      final received = <Uint8List>[];
      final subscription = transport.incoming.listen(received.add);

      // Simulate the ROM bootloader's boot-banner text, then a SYNC response
      // frame delivered split across two raw chunks — exactly what a real
      // USB driver does after resetIntoBootloader().
      usb._incoming.add(Uint8List.fromList('ets ROM:0x40\r\n'.codeUnits));
      usb._incoming.add(Uint8List.fromList(<int>[0xC0, 0x01, 0x02]));
      usb._incoming.add(Uint8List.fromList(<int>[0x03, 0xC0]));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(received, hasLength(1));
      expect(
        received.single,
        orderedEquals(<int>[0xC0, 0x01, 0x02, 0x03, 0xC0]),
      );
    },
  );
}
