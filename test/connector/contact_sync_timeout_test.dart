import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Frame layout matches the one already used in test/models/model_changes_test.dart:
// [respCode(1)][pubKey(32)][type(1)][flags(1)][pathLen(1)][path(64)][name(32)][timestamp(4)][lat(4)][lon(4)]
Uint8List _buildContactFrame({Uint8List? pubKey}) {
  final writer = BytesBuilder();
  writer.addByte(respCodeContact);
  writer.add(pubKey ?? Uint8List.fromList(List.generate(32, (i) => i + 1)));
  writer.addByte(1); // type
  writer.addByte(0); // flags
  writer.addByte(0); // pathLen
  writer.add(Uint8List(64)); // path
  final nameBytes = Uint8List(32);
  const name = 'TestNode';
  for (var i = 0; i < name.length; i++) {
    nameBytes[i] = name.codeUnitAt(i);
  }
  writer.add(nameBytes);
  writer.add(Uint8List.fromList([0x01, 0x00, 0x00, 0x00])); // timestamp
  writer.add(Uint8List(4)); // lat
  writer.add(Uint8List(4)); // lon
  return Uint8List.fromList(writer.toBytes());
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsManager.initialize();
  });

  test('idle timeout: armed on start, fires and sets contactSyncTimedOut when '
      'triggered, a fresh sync clears the stale flag and re-arms', () {
    final connector = MeshCoreConnector();
    expect(connector.contactSyncTimedOut, isFalse);
    expect(connector.debugContactSyncTimeoutArmed, isFalse);

    connector.debugBeginContactSyncTracking();
    expect(connector.debugContactSyncTimeoutArmed, isTrue);
    expect(connector.contactSyncTimedOut, isFalse);

    connector.debugTriggerContactSyncTimeout();
    expect(connector.contactSyncTimedOut, isTrue);
    expect(connector.debugContactSyncTimeoutArmed, isFalse);

    connector.debugBeginContactSyncTracking();
    expect(connector.contactSyncTimedOut, isFalse);
    expect(connector.debugContactSyncTimeoutArmed, isTrue);
  });

  test('receiving a contact frame keeps the idle timer armed (resets it, '
      'does not cancel it outright)', () {
    final connector = MeshCoreConnector();
    connector.debugBeginContactSyncTracking();
    expect(connector.debugContactSyncTimeoutArmed, isTrue);

    connector.debugHandleFrame(_buildContactFrame());
    expect(connector.debugContactSyncTimeoutArmed, isTrue);
  });

  test('respCodeEndOfContacts cancels the pending idle timeout', () {
    final connector = MeshCoreConnector();
    connector.debugBeginContactSyncTracking();
    expect(connector.debugContactSyncTimeoutArmed, isTrue);

    connector.debugHandleFrame(Uint8List.fromList([respCodeEndOfContacts]));
    expect(connector.debugContactSyncTimeoutArmed, isFalse);
  });

  test(
    'getContacts() resets contactSyncTimedOut and re-arms, once connected',
    () async {
      final connector = MeshCoreConnector();
      connector.debugConnectionState = MeshCoreConnectionState.connected;
      connector.debugBeginContactSyncTracking();
      connector.debugTriggerContactSyncTimeout();
      expect(connector.contactSyncTimedOut, isTrue);

      // sendFrame throws without a real transport attached (no RX
      // characteristic) — that's expected here; this test only verifies
      // the synchronous state-reset getContacts() performs before it
      // reaches sendFrame.
      await connector.getContacts().catchError((_) {});

      expect(connector.contactSyncTimedOut, isFalse);
      expect(connector.debugContactSyncTimeoutArmed, isTrue);
    },
  );
}
