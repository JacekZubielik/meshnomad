import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';

Widget _wrap(Widget child, AppSettingsService settings) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsService>.value(value: settings),
      ChangeNotifierProvider<MeshCoreConnector>(
        create: (_) => MeshCoreConnector(),
      ),
    ],
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: [child]),
        body: const SizedBox(),
      ),
    ),
  );
}

void main() {
  late AppSettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settings = AppSettingsService();
    await settings.loadSettings();
  });

  testWidgets('offers exactly Quick Style and Settings', (tester) async {
    await tester.pumpWidget(_wrap(const QuickAccessMenuButton(), settings));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Quick style'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(PopupMenuItem<dynamic>), findsNWidgets(2));
  });
}
