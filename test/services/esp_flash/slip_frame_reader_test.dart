import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/services/esp_flash/slip_frame_reader.dart';

void main() {
  test('feed emits a complete frame delivered in a single chunk', () {
    final reader = SlipFrameReader();

    final frames = reader.feed(
      Uint8List.fromList(<int>[0xC0, 0x01, 0x02, 0xC0]),
    );

    expect(frames, hasLength(1));
    expect(frames.single, orderedEquals(<int>[0xC0, 0x01, 0x02, 0xC0]));
  });

  test('feed discards boot-banner garbage before the first 0xC0', () {
    final reader = SlipFrameReader();
    final bannerAndFrame = Uint8List.fromList(<int>[
      ...'ets ROM:0x40 (RST)\r\n'.codeUnits,
      0xC0,
      0x01,
      0xC0,
    ]);

    final frames = reader.feed(bannerAndFrame);

    expect(frames, hasLength(1));
    expect(frames.single, orderedEquals(<int>[0xC0, 0x01, 0xC0]));
  });

  test('feed assembles a frame split across two chunks', () {
    final reader = SlipFrameReader();

    final firstFrames = reader.feed(
      Uint8List.fromList(<int>[0xC0, 0x01, 0x02]),
    );
    expect(firstFrames, isEmpty); // frame not complete yet

    final secondFrames = reader.feed(Uint8List.fromList(<int>[0x03, 0xC0]));
    expect(secondFrames, hasLength(1));
    expect(
      secondFrames.single,
      orderedEquals(<int>[0xC0, 0x01, 0x02, 0x03, 0xC0]),
    );
  });

  test('feed handles two consecutive complete frames in one chunk', () {
    final reader = SlipFrameReader();

    final frames = reader.feed(
      Uint8List.fromList(<int>[0xC0, 0x01, 0xC0, 0xC0, 0x02, 0xC0]),
    );

    expect(frames, hasLength(2));
    expect(frames[0], orderedEquals(<int>[0xC0, 0x01, 0xC0]));
    expect(frames[1], orderedEquals(<int>[0xC0, 0x02, 0xC0]));
  });
}
