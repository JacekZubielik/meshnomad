import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/flasher_screen.dart';
import 'package:meshnomad/services/firmware_catalog.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

String _fixtureCatalog() => jsonEncode({
  'schema': 1,
  'generated': '2026-08-25T10:00:00Z',
  'sources': [
    {
      'id': 'meshcore',
      'displayName': 'MeshCore',
      'boards': [
        {
          'name': 'Heltec_v3',
          'romTypes': [
            {
              'id': 'companion',
              'displayName': 'Companion',
              'versions': [
                {
                  'tag': 'companion-v1.17.1',
                  'files': [
                    {
                      'name':
                          'Heltec_v3_companion_radio_ble-v1.17.1-merged.bin',
                      'url': 'https://example.test/merged.bin',
                      'offset': 0,
                    },
                  ],
                },
              ],
            },
            {
              'id': 'repeater',
              'displayName': 'Repeater',
              'versions': [
                {
                  'tag': 'repeater-v1.17.1',
                  'files': [
                    {
                      'name': 'Heltec_v3-v1.17.1.bin',
                      'url': 'https://example.test/rpt.bin',
                      'offset': 65536,
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'name': 'Xiao_S3',
          'romTypes': [
            {
              'id': 'companion',
              'displayName': 'Companion',
              'versions': [
                {
                  'tag': 'companion-v1.17.1',
                  'files': [
                    {
                      'name': 'Xiao_S3_companion_radio_ble-v1.17.1.bin',
                      'url': 'https://example.test/xiao.bin',
                      'offset': 65536,
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'name': 'Multi_Variant_Board',
          'romTypes': [
            {
              'id': 'companion',
              'displayName': 'Companion',
              'versions': [
                {
                  'tag': 'companion-v1.17.1',
                  'files': [
                    {
                      'name':
                          'Multi_Variant_Board_companion_radio_ble-v1.17.1-merged.bin',
                      'url': 'https://example.test/mvb-ble-merged.bin',
                      'offset': 0,
                    },
                    {
                      'name':
                          'Multi_Variant_Board_companion_radio_ble-v1.17.1.bin',
                      'url': 'https://example.test/mvb-ble.bin',
                      'offset': 65536,
                    },
                    {
                      'name':
                          'Multi_Variant_Board_companion_radio_usb-v1.17.1-merged.bin',
                      'url': 'https://example.test/mvb-usb-merged.bin',
                      'offset': 0,
                    },
                    {
                      'name':
                          'Multi_Variant_Board_companion_radio_usb-v1.17.1.bin',
                      'url': 'https://example.test/mvb-usb.bin',
                      'offset': 65536,
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
    {'id': 'meshcore_solo', 'displayName': 'MeshCore-Solo', 'boards': []},
  ],
});

/// The board field starts closed showing the default-selected board name
/// ("Heltec_v3" in the fixture catalog) — tap it to open the picker, then
/// tap the target board's list tile to select it.
Future<void> _selectBoard(WidgetTester tester, String boardName) async {
  await tester.tap(find.text('Heltec_v3').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(boardName));
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flasher_screen_test');
    File('${tempDir.path}/flasher/catalog.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(_fixtureCatalog());
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  FirmwareCatalogService service({
    http.Client? client,
  }) => FirmwareCatalogService(
    httpClient:
        client ??
        MockClient((request) async {
          if (request.url.toString() == 'https://example.test/merged.bin') {
            return http.Response.bytes([1, 2, 3, 4], 200);
          }
          if (request.url.toString() == 'https://example.test/rpt.bin') {
            return http.Response.bytes([5, 6, 7, 8], 200);
          }
          if (request.url.toString() ==
              'https://example.test/mvb-ble-merged.bin') {
            return http.Response.bytes([10, 11, 12, 13], 200);
          }
          if (request.url.toString() == 'https://example.test/mvb-ble.bin') {
            return http.Response.bytes([14, 15, 16, 17], 200);
          }
          if (request.url.toString() ==
              'https://example.test/mvb-usb-merged.bin') {
            return http.Response.bytes([20, 21, 22, 23], 200);
          }
          if (request.url.toString() == 'https://example.test/mvb-usb.bin') {
            return http.Response.bytes([24, 25, 26, 27], 200);
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
    storageDirectory: tempDir,
  );

  Widget wrap(Widget child) => MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  // FlasherScreen's initState kicks off a real dart:io file read
  // (FirmwareCatalogService.loadCatalog) that flutter test's fake-async
  // pump/pumpAndSettle never drives to completion on their own — the
  // pumpWidget call itself must run inside tester.runAsync() so the
  // fire-and-forget Future it starts is scheduled on the real zone, with a
  // short real delay to let the read actually finish before handing control
  // back to the normal (fake-async) pump machinery.
  Future<void> pumpFlasherScreen(WidgetTester tester, Widget child) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(child);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('screen loads the local catalog without any network call', (
    tester,
  ) async {
    final neverCalled = MockClient((request) async {
      throw StateError('Network must not be touched: ${request.url}');
    });
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service(client: neverCalled))),
    );

    expect(find.text('Heltec_v3'), findsOneWidget); // default-selected board
    expect(find.text('Catalog from Aug 25, 2026'), findsOneWidget);
  });

  testWidgets('ROM-type chips show only for multi-type boards', (tester) async {
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service())),
    );

    // Heltec_v3 (default) has 2 ROM types → chips visible.
    expect(find.text('Companion'), findsOneWidget);
    expect(find.text('Repeater'), findsOneWidget);
  });

  testWidgets('four source chips still offered', (tester) async {
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service())),
    );

    expect(find.text('MeshCore'), findsOneWidget);
    expect(find.text('MeshCore-Solo'), findsOneWidget);
    expect(find.text('Local file'), findsOneWidget);
    expect(find.text('Custom URL'), findsOneWidget);
  });

  testWidgets('tapping an idle Update icon downloads, then shows it ready', (
    tester,
  ) async {
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service())),
    );

    // Heltec_v3/companion has one version (companion-v1.17.1) with only a
    // merged (full-reset) file in the fixture — switch to Repeater, whose
    // single file is an update-offset file, to exercise the Update icon.
    await tester.tap(find.text('Repeater'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.download));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // Downloaded, ready to flash — the completion message appeared and
    // cleared, icon is now in the accent/ready visual (IconButton present,
    // no CircularProgressIndicator left over).
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping a ready Full-Reset icon shows the confirm dialog', (
    tester,
  ) async {
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service())),
    );
    // Heltec_v3/companion's only file is the merged (full-reset) one.

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pump();
      // Must exceed _downloadFile's fixed 900ms completion-message hold
      // with real margin — 1000ms left only 100ms of buffer, a plausible
      // flake source under CI load.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    });
    await tester.pumpAndSettle();
    // Now ready — tap again to flash.
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump();

    expect(find.text('Erase everything?'), findsOneWidget);
  });

  testWidgets('VERSION list is capped to 280px with internal scroll', (
    tester,
  ) async {
    await pumpFlasherScreen(
      tester,
      wrap(FlasherScreen(catalogService: service())),
    );

    // Scope the finder to the VERSION list's own ConstrainedBox (by key) —
    // matching on maxHeight alone would also hit _BoardPickerField's
    // expanded panel, which shares the same 280px cap and only fails to
    // interfere here because it happens to start closed.
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byKey(const Key('flasherVersionListConstrainedBox')),
    );
    expect(constrainedBox.constraints.maxHeight, 280);
  });

  testWidgets(
    'single-variant boards render with no BLE/USB chips (regression guard)',
    (tester) async {
      await pumpFlasherScreen(
        tester,
        wrap(FlasherScreen(catalogService: service())),
      );

      // Heltec_v3 (default board) publishes only one file per offset — the
      // common case that must remain unaffected by the variant-chip feature.
      expect(find.text('BLE'), findsNothing);
      expect(find.text('USB'), findsNothing);
    },
  );

  testWidgets(
    'multi-variant board shows BLE and USB chips, BLE selected by default',
    (tester) async {
      await pumpFlasherScreen(
        tester,
        wrap(FlasherScreen(catalogService: service())),
      );

      await _selectBoard(tester, 'Multi_Variant_Board');

      expect(find.text('BLE'), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);
      // BLE is selected by default (stable variant order: ble, usb,
      // generic) — the row's subLabel names the BLE merged (full-reset)
      // file, proving the Full Reset/Update icons resolve against BLE
      // files, not USB.
      expect(
        find.text('Multi_Variant_Board_companion_radio_ble-v1.17.1-merged.bin'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping the USB chip switches the row to fetch USB firmware URLs',
    (tester) async {
      final requestedUrls = <String>[];
      final trackingClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        switch (request.url.toString()) {
          case 'https://example.test/merged.bin':
            return http.Response.bytes([1, 2, 3, 4], 200);
          case 'https://example.test/rpt.bin':
            return http.Response.bytes([5, 6, 7, 8], 200);
          case 'https://example.test/mvb-ble-merged.bin':
            return http.Response.bytes([10, 11, 12, 13], 200);
          case 'https://example.test/mvb-ble.bin':
            return http.Response.bytes([14, 15, 16, 17], 200);
          case 'https://example.test/mvb-usb-merged.bin':
            return http.Response.bytes([20, 21, 22, 23], 200);
          case 'https://example.test/mvb-usb.bin':
            return http.Response.bytes([24, 25, 26, 27], 200);
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      });

      await pumpFlasherScreen(
        tester,
        wrap(FlasherScreen(catalogService: service(client: trackingClient))),
      );

      await _selectBoard(tester, 'Multi_Variant_Board');

      await tester.tap(find.text('USB'));
      await tester.pumpAndSettle();

      // Selection switched — the row's subLabel now names the USB merged
      // (full-reset) file instead of the BLE one.
      expect(
        find.text('Multi_Variant_Board_companion_radio_usb-v1.17.1-merged.bin'),
        findsOneWidget,
      );

      // Tapping Update after switching to USB must fetch the USB-offset
      // file's URL, not the BLE one — the most direct proof the right file
      // gets resolved after a variant switch.
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.download));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(requestedUrls, contains('https://example.test/mvb-usb.bin'));
      expect(
        requestedUrls,
        isNot(contains('https://example.test/mvb-ble.bin')),
      );
    },
  );
}
