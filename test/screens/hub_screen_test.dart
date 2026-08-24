import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/hub_screen.dart';
import 'package:meshnomad/screens/scanner_screen.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

void main() {
  Widget wrap(Widget child) => ChangeNotifierProvider<MeshCoreConnector>.value(
    value: MeshCoreConnector(),
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  testWidgets('HubScreen shows three mode tiles', (tester) async {
    await tester.pumpWidget(wrap(const HubScreen()));

    expect(find.text('Companion'), findsOneWidget);
    expect(find.text('Flasher'), findsOneWidget);
    expect(find.text('Setup USB'), findsOneWidget);
  });

  testWidgets('Tapping Companion navigates to ScannerScreen', (tester) async {
    await tester.pumpWidget(wrap(const HubScreen()));

    await tester.tap(find.text('Companion'));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerScreen), findsOneWidget);

    // ScannerScreen.dispose() calls connector.disconnect(), which debounces
    // notifyListeners() via a Timer. Drain it before test teardown tears
    // down the widget tree, matching the pattern in usb_flow_test.dart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 60));
  });
}
