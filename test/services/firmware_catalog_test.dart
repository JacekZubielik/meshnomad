import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshnomad/services/firmware_catalog.dart';

String _catalogJson({String boardName = 'Test_Board'}) => jsonEncode({
  'schema': 1,
  'generated': '2026-08-25T10:00:00Z',
  'sources': [
    {
      'id': 'meshcore',
      'displayName': 'MeshCore',
      'boards': [
        {
          'name': boardName,
          'romTypes': [
            {
              'id': 'companion',
              'displayName': 'Companion',
              'versions': [
                {
                  'tag': 'companion-v1.17.1',
                  'files': [
                    {
                      'name': '$boardName-v1.17.1-merged.bin',
                      'url': 'https://example.test/fw.bin',
                      'offset': 0,
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fw_catalog_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  http.Client neverCalledClient() => MockClient((request) async {
    throw StateError('Network must not be touched: ${request.url}');
  });

  test(
    'loadCatalog falls back to the bundled asset and persists it locally',
    () async {
      final service = FirmwareCatalogService(
        httpClient: neverCalledClient(),
        storageDirectory: tempDir,
      );

      final catalog = await service.loadCatalog();

      // Bundled snapshot is live-generated (task 01) — assert structure, not
      // exact content.
      expect(catalog.sources, isNotEmpty);
      expect(catalog.generated, isNotNull);
      expect(File('${tempDir.path}/flasher/catalog.json').existsSync(), isTrue);
    },
  );

  test(
    'loadCatalog prefers an existing local file and never touches the network',
    () async {
      final localFile = File('${tempDir.path}/flasher/catalog.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(_catalogJson(boardName: 'Local_Marker'));
      final service = FirmwareCatalogService(
        httpClient: neverCalledClient(),
        storageDirectory: tempDir,
      );

      final catalog = await service.loadCatalog();

      expect(catalog.sources.single.boards.single.name, 'Local_Marker');
      expect(localFile.existsSync(), isTrue);
    },
  );

  test(
    'a corrupted local file falls back to the bundled asset instead of throwing',
    () async {
      File('${tempDir.path}/flasher/catalog.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"schema": 999}');
      final service = FirmwareCatalogService(
        httpClient: neverCalledClient(),
        storageDirectory: tempDir,
      );

      final catalog = await service.loadCatalog();

      expect(catalog.sources, isNotEmpty);
    },
  );

  test(
    'refreshCatalog downloads, validates, persists; next loadCatalog reads it',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), firmwareCatalogUrl);
        return http.Response(_catalogJson(boardName: 'Fresh_Board'), 200);
      });
      final service = FirmwareCatalogService(
        httpClient: client,
        storageDirectory: tempDir,
      );

      final fresh = await service.refreshCatalog();
      expect(fresh.sources.single.boards.single.name, 'Fresh_Board');

      final reloaded = await FirmwareCatalogService(
        httpClient: neverCalledClient(),
        storageDirectory: tempDir,
      ).loadCatalog();
      expect(reloaded.sources.single.boards.single.name, 'Fresh_Board');
    },
  );

  test(
    'refreshCatalog on HTTP error throws and leaves the local copy intact',
    () async {
      File('${tempDir.path}/flasher/catalog.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(_catalogJson(boardName: 'Kept_Board'));
      final service = FirmwareCatalogService(
        httpClient: MockClient((_) async => http.Response('nope', 500)),
        storageDirectory: tempDir,
      );

      await expectLater(service.refreshCatalog(), throwsStateError);
      final kept = await FirmwareCatalogService(
        httpClient: neverCalledClient(),
        storageDirectory: tempDir,
      ).loadCatalog();
      expect(kept.sources.single.boards.single.name, 'Kept_Board');
    },
  );

  test('assetFor downloads bytes from the file url', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(Uint8List.fromList([9, 8, 7]), 200),
    );
    final service = FirmwareCatalogService(
      httpClient: client,
      storageDirectory: tempDir,
    );
    final file = CatalogFile(
      name: 'fw.bin',
      url: 'https://example.test/fw.bin',
      offset: catalogOffsetUpdate,
    );

    final asset = service.assetFor(file);

    expect(asset.flashOffset, catalogOffsetUpdate);
    expect(await asset.fetch(), orderedEquals([9, 8, 7]));
  });

  test(
    'assetFor reports byte progress when the server sends Content-Length',
    () async {
      final payload = Uint8List.fromList(List.generate(40, (i) => i));
      final client = MockClient((request) async {
        return http.Response.bytes(
          payload,
          200,
          headers: {'content-length': payload.length.toString()},
        );
      });
      final service = FirmwareCatalogService(
        httpClient: client,
        storageDirectory: tempDir,
      );
      final file = CatalogFile(
        name: 'fw.bin',
        url: 'https://example.test/fw.bin',
        offset: catalogOffsetUpdate,
      );
      final progressValues = <double>[];

      final bytes = await service
          .assetFor(file)
          .fetch(onProgress: progressValues.add);

      expect(bytes, orderedEquals(payload));
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, 1.0);
      expect(progressValues, everyElement(inInclusiveRange(0.0, 1.0)));
    },
  );

  test('assetFor clamps progress to 1.0 when the body exceeds a '
      'deliberately-understated Content-Length', () async {
    final payload = Uint8List.fromList(List.generate(40, (i) => i));
    final client = MockClient((request) async {
      return http.Response.bytes(
        payload,
        200,
        // Understate the true length so the naive ratio would exceed 1.0.
        headers: {'content-length': (payload.length ~/ 2).toString()},
      );
    });
    final service = FirmwareCatalogService(
      httpClient: client,
      storageDirectory: tempDir,
    );
    final file = CatalogFile(
      name: 'fw.bin',
      url: 'https://example.test/fw.bin',
      offset: catalogOffsetUpdate,
    );
    final progressValues = <double>[];

    final bytes = await service
        .assetFor(file)
        .fetch(onProgress: progressValues.add);

    expect(bytes, orderedEquals(payload));
    expect(progressValues, isNotEmpty);
    expect(progressValues, everyElement(inInclusiveRange(0.0, 1.0)));
  });

  test(
    'assetFor still returns full bytes when onProgress is omitted',
    () async {
      final client = MockClient(
        (_) async => http.Response.bytes(Uint8List.fromList([5, 6, 7]), 200),
      );
      final service = FirmwareCatalogService(
        httpClient: client,
        storageDirectory: tempDir,
      );
      final file = CatalogFile(
        name: 'fw2.bin',
        url: 'https://example.test/fw2.bin',
        offset: catalogOffsetFullReset,
      );

      expect(await service.assetFor(file).fetch(), orderedEquals([5, 6, 7]));
    },
  );

  test('fromCustomUrl keeps the previous contract', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(Uint8List.fromList([1, 2]), 200),
    );
    final service = FirmwareCatalogService(
      httpClient: client,
      storageDirectory: tempDir,
    );

    final asset = service.fromCustomUrl(
      'https://example.test/x.bin',
      flashOffset: catalogOffsetFullReset,
    );

    expect(await asset.fetch(), orderedEquals([1, 2]));
  });
}
