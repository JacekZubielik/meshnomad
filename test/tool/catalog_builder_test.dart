import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalog/catalog_builder.dart';

List<Map<String, dynamic>> _meshcoreReleases() => [
  {
    'tag_name': 'room-server-v1.17.1',
    'assets': [
      {
        'name': 'Heltec_v3-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/room-heltec.bin',
      },
    ],
  },
  {
    'tag_name': 'repeater-v1.17.1',
    'assets': [
      {
        // Deliberately lowercase — streams are inconsistent about case and
        // the same physical board must appear exactly once.
        'name': 'heltec_v3-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/rpt-heltec.bin',
      },
      {
        'name': 'Station_G2-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/rpt-station.bin',
      },
    ],
  },
  {
    'tag_name': 'companion-v1.17.1',
    'assets': [
      {
        'name': 'Heltec_v3_companion_radio_ble-v1.17.1-d929643-merged.bin',
        'browser_download_url': 'https://example.test/comp-merged.bin',
      },
      {
        'name': 'Heltec_v3_companion_radio_ble-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/comp-update.bin',
      },
      {
        'name': 'Xiao_S3_companion_radio_ble-v1.17.1-d929643.bin',
        'browser_download_url': 'https://example.test/comp-xiao.bin',
      },
    ],
  },
  {
    'tag_name': 'companion-v1.17.0',
    'assets': [
      {
        'name': 'Heltec_v3_companion_radio_ble-v1.17.0-abc123.bin',
        'browser_download_url': 'https://example.test/comp-old.bin',
      },
    ],
  },
];

List<Map<String, dynamic>> _soloReleases() => [
  {
    'tag_name': 'v1.25',
    'assets': [
      {
        'name': 'solo-v1.25-Heltec-v3-merged.bin',
        'browser_download_url': 'https://example.test/solo-h3.bin',
      },
      {
        'name': 'solo-v1.25-heltec-v4-merged.bin',
        'browser_download_url': 'https://example.test/solo-h4.bin',
      },
    ],
  },
];

Map<String, dynamic> _build() => buildCatalog(
  generatedAt: '2026-08-25T00:00:00Z',
  releasesByRepo: {
    'meshcore-dev/MeshCore': _meshcoreReleases(),
    'MarekZegare4/MeshCore-Solo': _soloReleases(),
  },
);

void main() {
  test(
    'boards are unioned across streams, deduped case-insensitively, sorted a-z',
    () {
      final catalog = _build();
      final meshcore = (catalog['sources'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((s) => s['id'] == 'meshcore');
      final names = (meshcore['boards'] as List)
          .cast<Map<String, dynamic>>()
          .map((b) => b['name'])
          .toList();

      expect(names, ['Heltec_v3', 'Station_G2', 'Xiao_S3']);
    },
  );

  test('a board carries only the ROM types it actually has releases for', () {
    final catalog = _build();
    final meshcore = (catalog['sources'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == 'meshcore');
    final station = (meshcore['boards'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((b) => b['name'] == 'Station_G2');
    final heltec = (meshcore['boards'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((b) => b['name'] == 'Heltec_v3');

    expect((station['romTypes'] as List).map((r) => (r as Map)['id']), [
      'repeater',
    ]);
    expect((heltec['romTypes'] as List).map((r) => (r as Map)['id']), [
      'companion',
      'repeater',
      'room_server',
    ]);
  });

  test(
    'versions keep GitHub order (newest first) with per-board files and offsets',
    () {
      final catalog = _build();
      final meshcore = (catalog['sources'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((s) => s['id'] == 'meshcore');
      final heltec = (meshcore['boards'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['name'] == 'Heltec_v3');
      final companion = (heltec['romTypes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'companion');
      final versions = (companion['versions'] as List)
          .cast<Map<String, dynamic>>();

      expect(versions.map((v) => v['tag']), [
        'companion-v1.17.1',
        'companion-v1.17.0',
      ]);
      final files = (versions.first['files'] as List)
          .cast<Map<String, dynamic>>();
      // Only Heltec files — Xiao's asset from the same release is excluded.
      expect(files, hasLength(2));
      expect(
        files.any(
          (f) =>
              (f['name'] as String).contains('-merged') && f['offset'] == 0x0,
        ),
        isTrue,
      );
      expect(
        files.any(
          (f) =>
              !(f['name'] as String).contains('-merged') &&
              f['offset'] == 0x10000,
        ),
        isTrue,
      );
    },
  );

  test('single-stream source (Solo) gets one synthetic firmware ROM type', () {
    final catalog = _build();
    final solo = (catalog['sources'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == 'meshcore_solo');
    final boards = (solo['boards'] as List).cast<Map<String, dynamic>>();

    expect(boards.map((b) => b['name']), ['Heltec-v3', 'heltec-v4']);
    final romTypes = (boards.first['romTypes'] as List)
        .cast<Map<String, dynamic>>();
    expect(romTypes, hasLength(1));
    expect(romTypes.single['id'], 'firmware');
    // Substring matching must not cross boards: Heltec-v3 gets only its own file.
    final files =
        ((romTypes.single['versions'] as List).first as Map)['files'] as List;
    expect(files, hasLength(1));
  });

  test('no source spec references the obsolete ripplebiz account', () {
    for (final spec in catalogSources) {
      expect(spec.repo.contains('ripplebiz'), isFalse);
    }
  });
}
