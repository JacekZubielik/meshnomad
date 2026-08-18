import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';

void main() {
  final pubKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

  group('buildGetAdvertPathFrame', () {
    test('is [cmd][reserved][pub_key x32]', () {
      final frame = buildGetAdvertPathFrame(pubKey);

      expect(frame.length, 34);
      expect(frame[0], cmdGetAdvertPath);
      expect(frame[1], 0);
      expect(frame.sublist(2), pubKey);
    });
  });

  group('buildSetFloodScopeUnscopedFrame', () {
    test('is [cmd][1], no payload', () {
      final frame = buildSetFloodScopeUnscopedFrame();

      expect(frame, Uint8List.fromList([cmdSetFloodScope, 1]));
    });
  });

  group('buildSetDefaultFloodScopeFrame', () {
    test('is [cmd][name x31 zero-padded C-string][key x16]', () {
      final frame = buildSetDefaultFloodScopeFrame('home-mesh');

      expect(frame.length, 48);
      expect(frame[0], cmdSetDefaultFloodScope);
      final nameField = frame.sublist(1, 32);
      expect(nameField.sublist(0, 'home-mesh'.length), 'home-mesh'.codeUnits);
      expect(nameField[9], 0); // NUL terminator right after the name
    });

    test(
      'derives the same scope key as buildSetFloodScopeFrame for the same region',
      () {
        final defaultFrame = buildSetDefaultFloodScopeFrame('home-mesh');
        final channelFrame = buildSetFloodScopeFrame('home-mesh');

        // channelFrame is [cmd][0][key x16]; defaultFrame is [cmd][name x31][key x16].
        expect(defaultFrame.sublist(32), channelFrame.sublist(2));
      },
    );
  });

  group('buildClearDefaultFloodScopeFrame', () {
    test('is a single byte: the command code, no payload', () {
      final frame = buildClearDefaultFloodScopeFrame();

      expect(frame, Uint8List.fromList([cmdSetDefaultFloodScope]));
    });
  });

  group('buildGetDefaultFloodScopeFrame', () {
    test('is a single byte: the command code, no payload', () {
      final frame = buildGetDefaultFloodScopeFrame();

      expect(frame, Uint8List.fromList([cmdGetDefaultFloodScope]));
    });
  });

  group('parseAdvertPathFrame', () {
    Uint8List buildRespFrame({
      required int recvTimestamp,
      required int pathLenRaw,
      required Uint8List pathHash,
    }) {
      final writer = BufferWriter();
      writer.writeByte(respCodeAdvertPath);
      writer.writeUInt32LE(recvTimestamp);
      writer.writeByte(pathLenRaw);
      writer.writeBytes(pathHash);
      return writer.toBytes();
    }

    test('decodes timestamp and a 1-byte-per-hop path hash (2 hops)', () {
      // hashCount=2 (bits 0-5), hashSize code=0 -> 1 byte/hop (bits 6-7)
      final pathHash = Uint8List.fromList([0xAB, 0xCD]);
      final frame = buildRespFrame(
        recvTimestamp: 1700000000,
        pathLenRaw: 2,
        pathHash: pathHash,
      );

      final result = parseAdvertPathFrame(frame);

      expect(result, isNotNull);
      expect(
        result!.recvTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
      expect(result.pathHash, pathHash);
    });

    test('decodes a 2-bytes-per-hop path hash using the hash-size bits', () {
      // hashCount=2, hashSize code=1 (bits 6-7 = 0b01) -> 2 bytes/hop
      final pathLenRaw = 2 | (1 << 6);
      final pathHash = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final frame = buildRespFrame(
        recvTimestamp: 1700000000,
        pathLenRaw: pathLenRaw,
        pathHash: pathHash,
      );

      final result = parseAdvertPathFrame(frame);

      expect(result!.pathHash, pathHash);
    });

    test('returns an empty path hash for a zero-hop (direct) path', () {
      final frame = buildRespFrame(
        recvTimestamp: 1700000000,
        pathLenRaw: 0,
        pathHash: Uint8List(0),
      );

      final result = parseAdvertPathFrame(frame);

      expect(result!.pathHash, isEmpty);
    });

    test(
      'returns null for a non-ADVERT_PATH response code (e.g. generic error)',
      () {
        final frame = Uint8List.fromList([respCodeErr, 2]);

        expect(parseAdvertPathFrame(frame), isNull);
      },
    );

    test('returns null for an empty frame', () {
      expect(parseAdvertPathFrame(Uint8List(0)), isNull);
    });

    test('returns null for a truncated frame', () {
      final frame = Uint8List.fromList([respCodeAdvertPath, 1, 2]);

      expect(parseAdvertPathFrame(frame), isNull);
    });
  });

  group('parseDefaultFloodScopeFrame', () {
    test('decodes name and key from a 49-byte response', () {
      final writer = BufferWriter();
      writer.writeByte(respCodeDefaultFloodScope);
      writer.writeCString('home-mesh', 31);
      final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      writer.writeBytes(key);

      final result = parseDefaultFloodScopeFrame(writer.toBytes());

      expect(result, isNotNull);
      expect(result!.name, 'home-mesh');
      expect(result.key, key);
    });

    test(
      'returns null when the firmware reports no default set (1-byte frame)',
      () {
        final frame = Uint8List.fromList([respCodeDefaultFloodScope]);

        expect(parseDefaultFloodScopeFrame(frame), isNull);
      },
    );

    test('returns null for a non-DEFAULT_FLOOD_SCOPE response code', () {
      final frame = Uint8List.fromList([respCodeErr, 2]);

      expect(parseDefaultFloodScopeFrame(frame), isNull);
    });

    test('returns null for an empty frame', () {
      expect(parseDefaultFloodScopeFrame(Uint8List(0)), isNull);
    });
  });
}
