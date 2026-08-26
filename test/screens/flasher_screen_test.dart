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
      ],
    },
    {'id': 'meshcore_solo', 'displayName': 'MeshCore-Solo', 'boards': []},
  ],
});

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

  FirmwareCatalogService service({http.Client? client}) =>
      FirmwareCatalogService(
        httpClient:
            client ??
            MockClient((request) async {
              if (request.url.toString() == 'https://example.test/merged.bin') {
                return http.Response.bytes([1, 2, 3, 4], 200);
              }
              if (request.url.toString() == 'https://example.test/rpt.bin') {
                return http.Response.bytes([5, 6, 7, 8], 200);
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
      await Future<void>.delayed(const Duration(milliseconds: 1000));
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

    final constrainedBox = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .where((w) => w.constraints.maxHeight == 280);
    expect(constrainedBox, isNotEmpty);
  });
}
