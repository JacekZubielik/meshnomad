import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/utils/keys.dart';

void main() {
  group('verifyAdvertSignature', () {
    late SimpleKeyPair keyPair;
    late Uint8List publicKey;
    final timestampBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
    final appData = Uint8List.fromList(List.generate(20, (i) => i));

    setUp(() async {
      keyPair = await Ed25519().newKeyPair();
      publicKey = Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
    });

    Future<Uint8List> signMessage(List<int> message) async {
      final signature = await Ed25519().sign(message, keyPair: keyPair);
      return Uint8List.fromList(signature.bytes);
    }

    test('accepts a signature over pubkey + timestamp + app_data', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);

      final ok = await verifyAdvertSignature(
        publicKey: publicKey,
        timestampBytesLE: timestampBytes,
        signature: signature,
        appData: appData,
      );

      expect(ok, isTrue);
    });

    test('rejects a tampered signature', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);
      signature[0] ^= 0xFF;

      final ok = await verifyAdvertSignature(
        publicKey: publicKey,
        timestampBytesLE: timestampBytes,
        signature: signature,
        appData: appData,
      );

      expect(ok, isFalse);
    });

    test('rejects when app_data was altered after signing', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);
      final tamperedAppData = Uint8List.fromList(appData);
      tamperedAppData[0] ^= 0xFF;

      final ok = await verifyAdvertSignature(
        publicKey: publicKey,
        timestampBytesLE: timestampBytes,
        signature: signature,
        appData: tamperedAppData,
      );

      expect(ok, isFalse);
    });

    test('rejects when timestamp bytes were altered after signing', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);
      final tamperedTimestamp = Uint8List.fromList([0x99, 0x02, 0x03, 0x04]);

      final ok = await verifyAdvertSignature(
        publicKey: publicKey,
        timestampBytesLE: tamperedTimestamp,
        signature: signature,
        appData: appData,
      );

      expect(ok, isFalse);
    });

    test('rejects a signature from a different key pair', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);
      final otherKeyPair = await Ed25519().newKeyPair();
      final otherPublicKey = Uint8List.fromList(
        (await otherKeyPair.extractPublicKey()).bytes,
      );

      final ok = await verifyAdvertSignature(
        publicKey: otherPublicKey,
        timestampBytesLE: timestampBytes,
        signature: signature,
        appData: appData,
      );

      expect(ok, isFalse);
    });

    test('only the first 32 bytes of app_data are covered by the signature '
        '(firmware MAX_ADVERT_DATA_SIZE cap)', () async {
      final cappedAppData = Uint8List.fromList(List.generate(32, (i) => i));
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...cappedAppData,
      ]);
      // Longer app_data sharing the same signed 32-byte prefix still
      // verifies — matches the firmware, which never signed the tail.
      final longerAppData = Uint8List.fromList([...cappedAppData, 1, 2, 3]);

      final ok = await verifyAdvertSignature(
        publicKey: publicKey,
        timestampBytesLE: timestampBytes,
        signature: signature,
        appData: longerAppData,
      );

      expect(ok, isTrue);
    });

    test('rejects malformed-length inputs instead of throwing', () async {
      final signature = await signMessage([
        ...publicKey,
        ...timestampBytes,
        ...appData,
      ]);

      expect(
        await verifyAdvertSignature(
          publicKey: Uint8List(31),
          timestampBytesLE: timestampBytes,
          signature: signature,
          appData: appData,
        ),
        isFalse,
      );
      expect(
        await verifyAdvertSignature(
          publicKey: publicKey,
          timestampBytesLE: Uint8List(3),
          signature: signature,
          appData: appData,
        ),
        isFalse,
      );
      expect(
        await verifyAdvertSignature(
          publicKey: publicKey,
          timestampBytesLE: timestampBytes,
          signature: Uint8List(63),
          appData: appData,
        ),
        isFalse,
      );
    });
  });
}
