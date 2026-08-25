import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshnomad/services/firmware_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loadCatalog parses the bundled boards.json asset into two sources',
    () async {
      final source = FirmwareSource();

      final sources = await source.loadCatalog();

      expect(sources, hasLength(2));
      final meshcore = sources.firstWhere((s) => s.id == 'meshcore');
      expect(meshcore.romTypes.map((r) => r.id), contains('companion'));
      expect(meshcore.romTypes.map((r) => r.id), contains('repeater'));
      expect(meshcore.romTypes.map((r) => r.id), contains('room_server'));
      expect(meshcore.boardTokenIsSubstring, isFalse);
      final solo = sources.firstWhere((s) => s.id == 'meshcore_solo');
      expect(solo.romTypes, isEmpty);
      expect(solo.boardTokenIsSubstring, isTrue);
    },
  );

  Map<String, dynamic> companionAndSiblingReleases() => {
    'companion-v1.17.1': [
      {
        'name': 'Heltec_v3_companion_radio_ble-v1.17.1-d929643-merged.bin',
        'browser_download_url': 'https://example.test/heltec-merged.bin',
      },
      {
        'name': 'Heltec_v3_companion_radio_ble-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/heltec-update.bin',
      },
      {
        'name': 'Xiao_S3_companion_radio_ble-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/xiao.bin',
      },
    ],
    'repeater-v1.17.1': [
      {
        // Deliberately lowercase — the real repo's streams are inconsistent
        // about capitalization of the same physical board, and the union
        // must dedupe case-insensitively instead of listing it twice.
        'name': 'heltec_v3-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/heltec-repeater.bin',
      },
      {
        'name': 'Station_G2-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/station-repeater.bin',
      },
    ],
    'room-server-v1.17.1': [
      {
        'name': 'Heltec_v3-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/heltec-room.bin',
      },
    ],
  };

  http.Client meshcoreClient() {
    final byTag = companionAndSiblingReleases();
    return MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode(
            byTag.entries
                .map((e) => {'tag_name': e.key, 'assets': e.value})
                .toList(),
          ),
          200,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    });
  }

  test(
    'discoverBoards unions board tokens across companion/repeater/room-server, no static catalog',
    () async {
      final firmwareSource = FirmwareSource(httpClient: meshcoreClient());
      final sources = await firmwareSource.loadCatalog();
      final meshcore = sources.firstWhere((s) => s.id == 'meshcore');

      final boards = await firmwareSource.discoverBoards(source: meshcore);

      // Heltec_v3 appears in all three streams (once spelled lowercase in
      // the repeater stream — deduped case-insensitively into one entry),
      // Xiao_S3 only in companion, Station_G2 only in repeater. Sorted a-z
      // case-insensitively.
      expect(boards, ['Heltec_v3', 'Station_G2', 'Xiao_S3']);
    },
  );

  test(
    'fetchReleases filters both by romType tagPrefix and the selected board token',
    () async {
      final firmwareSource = FirmwareSource(httpClient: meshcoreClient());
      final sources = await firmwareSource.loadCatalog();
      final meshcore = sources.firstWhere((s) => s.id == 'meshcore');
      final companion = meshcore.romTypes.firstWhere(
        (r) => r.id == 'companion',
      );

      final releases = await firmwareSource.fetchReleases(
        source: meshcore,
        romType: companion,
        boardToken: 'Heltec_v3',
      );

      expect(releases, hasLength(1));
      expect(releases.single.tagName, 'companion-v1.17.1');
      // Only Heltec_v3's two assets — Xiao_S3's companion asset is excluded
      // even though it's in the same release, because it doesn't match the
      // selected board.
      expect(releases.single.assets, hasLength(2));
      expect(
        releases.single.assets.every((a) => a.label.startsWith('Heltec_v3')),
        isTrue,
      );
    },
  );

  test(
    'fetchReleases on MeshCore-Solo matches the board token as a substring, not a prefix',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.25',
                'assets': [
                  {
                    'name': 'solo-v1.25-Heltec-v3-merged.bin',
                    'browser_download_url':
                        'https://example.test/solo-merged.bin',
                  },
                  {
                    'name': 'solo-v1.25-heltec-v4-merged.bin',
                    'browser_download_url':
                        'https://example.test/solo-v4-merged.bin',
                  },
                ],
              },
            ]),
            200,
          );
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      final firmwareSource = FirmwareSource(httpClient: client);
      final sources = await firmwareSource.loadCatalog();
      final solo = sources.firstWhere((s) => s.id == 'meshcore_solo');

      final boards = await firmwareSource.discoverBoards(source: solo);
      expect(boards, unorderedEquals(['Heltec-v3', 'heltec-v4']));

      final releases = await firmwareSource.fetchReleases(
        source: solo,
        boardToken: 'Heltec-v3',
      );

      // Only the Heltec-v3 asset — not heltec-v4, despite both containing
      // "heltec" — a real risk this task's design note flags explicitly.
      expect(releases.single.assets, hasLength(1));
      expect(releases.single.assets.single.flashOffset, 0x0);
    },
  );

  test(
    'repeated fetches reuse one cached /releases response per source',
    () async {
      var requestCount = 0;
      final byTag = companionAndSiblingReleases();
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode(
            byTag.entries
                .map((e) => {'tag_name': e.key, 'assets': e.value})
                .toList(),
          ),
          200,
        );
      });
      final firmwareSource = FirmwareSource(httpClient: client);
      final sources = await firmwareSource.loadCatalog();
      final meshcore = sources.firstWhere((s) => s.id == 'meshcore');
      final companion = meshcore.romTypes.firstWhere(
        (r) => r.id == 'companion',
      );
      final repeater = meshcore.romTypes.firstWhere((r) => r.id == 'repeater');

      await firmwareSource.discoverBoards(source: meshcore);
      await firmwareSource.fetchReleases(source: meshcore, romType: companion);
      await firmwareSource.fetchReleases(source: meshcore, romType: repeater);

      // Unauthenticated GitHub allows 60 requests/hour — a single screen
      // session burning one request per board/ROM switch exhausted it in
      // real testing (403). Everything above must share ONE fetch.
      expect(requestCount, 1);
    },
  );

  test('fetchReleases caps the returned list at the given limit', () async {
    final manyReleases = List.generate(
      30,
      (i) => {'tag_name': 'companion-v1.${30 - i}.0', 'assets': []},
    );
    final client = MockClient((request) async {
      return http.Response(jsonEncode(manyReleases), 200);
    });
    final firmwareSource = FirmwareSource(httpClient: client);
    final sources = await firmwareSource.loadCatalog();
    final meshcore = sources.firstWhere((s) => s.id == 'meshcore');
    final companion = meshcore.romTypes.firstWhere((r) => r.id == 'companion');

    final releases = await firmwareSource.fetchReleases(
      source: meshcore,
      romType: companion,
      limit: 20,
    );

    expect(releases, hasLength(20));
  });

  test(
    'fromCustomUrl builds a FirmwareAsset that fetches the given URL',
    () async {
      final client = MockClient((request) async {
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      });
      final source = FirmwareSource(httpClient: client);

      final asset = source.fromCustomUrl(
        'https://example.test/custom.bin',
        flashOffset: 0x10000,
      );
      final bytes = await asset.fetch();

      expect(bytes, orderedEquals([1, 2, 3]));
    },
  );
}
