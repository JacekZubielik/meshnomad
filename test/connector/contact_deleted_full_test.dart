// Regression tests for spike 02-transza-S (protocol 13, firmware v1.17.0):
// PUSH_CODE_CONTACT_DELETED (0x8F), PUSH_CODE_CONTACTS_FULL (0x90) and
// RESP_CODE_CURR_TIME (9), plus the maxFrameSize=176 bump. These drive the
// same private handlers production code uses via the @visibleForTesting
// surface on MeshCoreConnector.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/models/contact.dart';
import 'package:meshnomad/models/message.dart';
import 'package:meshnomad/services/app_debug_log_service.dart';

Uint8List _pubKey(int seed) =>
    Uint8List.fromList(List.generate(pubKeySize, (i) => (seed + i) % 256));

Contact _testContact(Uint8List pubKey) => Contact(
  publicKey: pubKey,
  name: 'Test Contact',
  type: advTypeChat,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime.now(),
);

void main() {
  group('PUSH_CODE_CONTACT_DELETED (0x8F)', () {
    test('known pub_key: contact is removed from the list, message history '
        'is preserved', () {
      final connector = MeshCoreConnector();
      final pubKey = _pubKey(1);
      final contact = _testContact(pubKey);
      connector.debugAddContact(contact);
      connector.debugConversations[contact.publicKeyHex] = [
        Message(
          senderKey: pubKey,
          text: 'hello',
          timestamp: DateTime.now(),
          isOutgoing: false,
        ),
      ];
      expect(connector.debugContactCount, 1);

      final frame = Uint8List.fromList([pushCodeContactDeleted, ...pubKey]);
      connector.debugHandleFrame(frame);

      expect(connector.debugContactCount, 0);
      expect(connector.debugConversations[contact.publicKeyHex]?.length, 1);
    });

    test('unknown pub_key: no exception, contact list unchanged', () {
      final connector = MeshCoreConnector();
      final knownKey = _pubKey(1);
      connector.debugAddContact(_testContact(knownKey));
      expect(connector.debugContactCount, 1);

      final unknownKey = _pubKey(200);
      final frame = Uint8List.fromList([pushCodeContactDeleted, ...unknownKey]);

      expect(() => connector.debugHandleFrame(frame), returnsNormally);
      expect(connector.debugContactCount, 1);
    });
  });

  group('PUSH_CODE_CONTACTS_FULL (0x90)', () {
    test(
      'logs a warning and fires a UI event; a second push within the '
      '10-minute cooldown still logs but does not fire another event',
      () async {
        final connector = MeshCoreConnector();
        final logService = AppDebugLogService();
        logService.setEnabled(true);
        connector.debugAppDebugLogService = logService;

        final events = <DateTime>[];
        final subscription = connector.contactsFullWarnings.listen(events.add);

        final frame = Uint8List.fromList([pushCodeContactsFull]);
        connector.debugHandleFrame(frame);
        await Future<void>.delayed(Duration.zero);
        connector.debugHandleFrame(frame);
        await Future<void>.delayed(Duration.zero);

        final fullWarnings = logService.entries
            .where((e) => e.tag == 'Protocol' && e.message.contains('FULL'))
            .toList();
        expect(fullWarnings.length, 2);
        expect(events.length, 1);

        await subscription.cancel();
      },
    );
  });

  group('RESP_CODE_CURR_TIME (9)', () {
    test('parses epoch without throwing', () {
      final connector = MeshCoreConnector();
      final epochBytes = ByteData(4)..setUint32(0, 1700000000, Endian.little);
      final frame = Uint8List.fromList([
        respCodeCurrTime,
        ...epochBytes.buffer.asUint8List(),
      ]);

      expect(() => connector.debugHandleFrame(frame), returnsNormally);
    });
  });

  group('maxFrameSize bump (172 -> 176)', () {
    test('maxContactMessageBytes() is 160', () {
      expect(maxContactMessageBytes(), 160);
    });
  });
}
