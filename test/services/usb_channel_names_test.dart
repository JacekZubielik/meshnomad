import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/usb_serial_service_native.dart';

/// The Android USB serial bridge is a hand-written Kotlin driver talking to
/// Dart over two platform channels. Their names live in two files that no
/// compiler cross-checks — a mismatch silently breaks USB on Android (no
/// error, the calls just never arrive). This pins both sides to each other,
/// and pins them to the post-rebrand identity (2026-09-05: they still carried
/// the fork's name three weeks after the rebrand).
void main() {
  const kotlinPath =
      'android/app/src/main/kotlin/com/meshnomad/app/MeshcoreUsbFunctions.kt';

  test('Kotlin USB bridge declares the same channel names as Dart', () {
    final kotlin = File(kotlinPath).readAsStringSync();
    expect(
      kotlin,
      contains('"${UsbSerialService.androidMethodChannelName}"'),
      reason: 'method channel name drifted between Kotlin and Dart',
    );
    expect(
      kotlin,
      contains('"${UsbSerialService.androidEventChannelName}"'),
      reason: 'event channel name drifted between Kotlin and Dart',
    );
  });

  test('channel names carry the app identity, not the old fork name', () {
    for (final name in [
      UsbSerialService.androidMethodChannelName,
      UsbSerialService.androidEventChannelName,
    ]) {
      expect(name, startsWith('meshnomad/'));
      expect(name, isNot(contains('meshcore_open')));
    }
  });
}
