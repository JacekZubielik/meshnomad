import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/flasher_screen.dart';
import 'package:meshnomad/services/firmware_source.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

void main() {
  // FlasherScreen's build() reads MeshTokens.of(context) (source-picker
  // chips, board picker, success banner) — a plain MaterialApp has no
  // MeshTokens ThemeExtension, so every test needs the same themed
  // MaterialApp used across the rest of this repo's screen tests
  // (see e.g. test/screens/hub_screen_test.dart).
  Widget wrap(Widget child) => MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  // FlasherScreen now fetches release assets from initState() for the
  // default-selected MeshCore chip. That async chain (rootBundle catalog
  // load + a release fetch) must be allowed to fully settle
  // (pumpAndSettle, not just pump) before a test body returns — otherwise
  // its still-pending Future bleeds into the next test in this same file
  // and can starve that test's own asset loading. A shared, always-empty
  // MockClient also keeps every test from opening a real http.Client().
  final emptyReleasesClient = MockClient((_) async => http.Response('[]', 200));

  testWidgets('FlasherScreen starts on the file-pick step', (tester) async {
    await tester.pumpWidget(
      wrap(
        FlasherScreen(
          firmwareSource: FirmwareSource(httpClient: emptyReleasesClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // MeshCore is now the default-selected source chip (task 09) — select
    // "Local file" to reach the same file-pick UI this test originally
    // exercised in task 07, when local file was the only source.
    await tester.tap(find.text('Local file'));
    await tester.pump();

    expect(find.text('Choose firmware file'), findsOneWidget);
    // Start button is disabled until a file is chosen. Disambiguate from
    // the selected source chip (also a FilledButton) by its label.
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('FlasherScreen offers four firmware source chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FlasherScreen(
          firmwareSource: FirmwareSource(httpClient: emptyReleasesClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MeshCore'), findsOneWidget);
    expect(find.text('MeshCore-Solo'), findsOneWidget);
    expect(find.text('Local file'), findsOneWidget);
    expect(find.text('Custom URL'), findsOneWidget);
  });

  testWidgets(
    'Selecting a full-reset MeshCore asset and starting shows a confirm dialog first',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(
            jsonEncode([
              {
                'tag_name': 'companion-v1.17.1',
                'assets': [
                  {
                    'name':
                        'Heltec_v3_companion_radio_ble-v1.17.1-abcdef-merged.bin',
                    'browser_download_url': 'https://example.test/merged.bin',
                  },
                ],
              },
            ]),
            200,
          );
        }
        if (request.url.toString() == 'https://example.test/merged.bin') {
          // Tapping the RadioListTile fetches the asset's bytes immediately
          // (FirmwareAsset.fetch), before Start is even pressed.
          return http.Response.bytes([1, 2, 3, 4], 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      await tester.pumpWidget(
        wrap(FlasherScreen(firmwareSource: FirmwareSource(httpClient: client))),
      );
      // Catalog loads, the only board this mock's companion release exposes
      // (Heltec_v3) is auto-discovered and auto-selected, its default ROM
      // type (Companion) is auto-selected, and the newest matching release
      // (companion-v1.17.1, the only one the mock returns) is auto-selected
      // — the release's real asset list is shown directly.
      await tester.pumpAndSettle();

      // The release's asset isn't auto-selected — the user picks it via its
      // RadioListTile row, same as the real UI flow.
      await tester.tap(find.text('Full reset (erases everything)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('Erase everything?'), findsOneWidget);
    },
  );
}
