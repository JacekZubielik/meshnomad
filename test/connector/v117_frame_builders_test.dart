import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';

void main() {
  final pubKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

  group('buildGetDeviceTimeFrame', () {
    test('is a single byte: the command code, no payload', () {
      final frame = buildGetDeviceTimeFrame();

      expect(frame, Uint8List.fromList([cmdGetDeviceTime]));
    });
  });

  group('buildHasConnectionFrame', () {
    test('is [cmd][pub_key x32]', () {
      final frame = buildHasConnectionFrame(pubKey);

      expect(frame.length, 33);
      expect(frame[0], cmdHasConnection);
      expect(frame.sublist(1), pubKey);
    });
  });

  group('buildLogoutFrame', () {
    test('is [cmd][pub_key x32]', () {
      final frame = buildLogoutFrame(pubKey);

      expect(frame.length, 33);
      expect(frame[0], cmdLogout);
      expect(frame.sublist(1), pubKey);
    });
  });
}
