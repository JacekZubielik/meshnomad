import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';

Uint8List randomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

class MCKeyPair {
  final Uint8List public;
  final Uint8List private;
  MCKeyPair(this.public, this.private);
}

/// Verifies a MeshCore advert signature. Firmware signs
/// `pubkey(32B) + timestamp(4B LE) + app_data(up to 32B, capped by
/// MAX_ADVERT_DATA_SIZE)` — the 64-byte signature itself is not part of the
/// signed message (firmware `src/Mesh.cpp:415-434` sign / `:259-283`
/// verify). `app_data` is whatever the wire has after the signature
/// (flags + optional location + optional name); bytes beyond the first 32
/// are never covered by the signature, even if the advert carries more —
/// that's a firmware-side limit, not something this function can widen.
///
/// [timestampBytesLE] must be the raw 4 wire bytes, not a re-encoded int —
/// signing uses the exact wire representation.
Future<bool> verifyAdvertSignature({
  required Uint8List publicKey,
  required Uint8List timestampBytesLE,
  required Uint8List signature,
  required Uint8List appData,
}) async {
  if (publicKey.length != 32 ||
      timestampBytesLE.length != 4 ||
      signature.length != 64) {
    return false;
  }
  final signedAppData = appData.length > 32 ? appData.sublist(0, 32) : appData;
  final message = Uint8List.fromList([
    ...publicKey,
    ...timestampBytesLE,
    ...signedAppData,
  ]);
  try {
    return await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } catch (e) {
    return false;
  }
}

Future<MCKeyPair> generateKeyPair() async {
  final algo = Ed25519();
  final seed = randomBytes(32);
  final SimpleKeyPair keys = await algo.newKeyPairFromSeed(seed);
  final Uint8List pubKeyBytes = Uint8List.fromList(
    (await keys.extractPublicKey()).bytes,
  );
  // Ed25519 gives 32-byte public and private keys, but MeshCore
  // uses an expanded 64-byte private key, so we have to make it
  // ourselves. Luckily, we can do it such that it has the same public
  // key, which we'd otherwise be unable to compute, since although the
  // crypto library implements the elliptic curve computations we need,
  // it doesn't make them available.
  final Uint8List hash = Uint8List.fromList((await Sha512().hash(seed)).bytes);
  hash[0] &= 248; // Clamp the scalar. This keeps the chosen point in the
  hash[31] &= 63; // large elliptic curve subgroup, and is demanded both by
  hash[31] |= 64; // Ed25519 and by the MeshCore repeater key validation code.
  return MCKeyPair(pubKeyBytes, hash);
}

class _KeyHashPrefix {
  Uint8List _bytes = Uint8List(0);
  Uint8List _mask = Uint8List(0);
  _KeyHashPrefix(String prefix) {
    final bool lengthIsOdd = (prefix.length % 2 == 1) ? true : false;
    final String decodableString = lengthIsOdd ? "${prefix}0" : prefix;
    _bytes = hex.decoder.convert(decodableString);
    _mask = Uint8List(_bytes.length);
    for (var i = 0; i < _mask.length; i++) {
      _mask[i] = 0xff;
    }
    if (lengthIsOdd) {
      _mask[_mask.length - 1] = 0xf0;
    }
  }

  bool matches(List<int> keyBytes) {
    if (keyBytes.length < _bytes.length) {
      return false;
    }
    for (var i = 0; i < _bytes.length; i++) {
      if (keyBytes[i] & _mask[i] != _bytes[i]) {
        return false;
      }
    }
    return true;
  }
}

class KeyPairSearcher {
  Future<MCKeyPair?> findMatchingKeyPair(
    String prefixStr,
    int maxMilliseconds,
  ) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int endTime = now + maxMilliseconds;
    final _KeyHashPrefix keyHashPrefix = _KeyHashPrefix(prefixStr);
    while (DateTime.now().millisecondsSinceEpoch < endTime) {
      final MCKeyPair keys = await generateKeyPair();
      if (keyHashPrefix.matches(keys.public)) {
        return keys;
      }
    }
    return null;
  }
}
