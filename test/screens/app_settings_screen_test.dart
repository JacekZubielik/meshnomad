import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/screens/app_settings_screen.dart';
import 'package:meshcore_open/screens/custom_style_editor_screen.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/services/translation_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/styles/style_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettingsService settingsService;
  late MeshCoreConnector connector;
  late TranslationService translationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    // _AboutTile calls PackageInfo.fromPlatform() — mock it so the widget
    // test doesn't hit a real (unavailable) platform channel.
    PackageInfo.setMockInitialValues(
      appName: 'MeshCore Open',
      packageName: 'com.meshcore.meshcore_open',
      version: '9.5.0',
      buildNumber: '13',
      buildSignature: '',
    );
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
    connector = MeshCoreConnector();
    translationService = TranslationService(settingsService);
  });

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsService>.value(
          value: settingsService,
        ),
        ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
        ChangeNotifierProvider<TranslationService>.value(
          value: translationService,
        ),
      ],
      child: MaterialApp(
        theme: StyleRegistry.byId('default').light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppSettingsScreen(),
      ),
    );
  }

  group(
    'AppSettingsScreen — Style section entry icon (05-settings-entry.md)',
    () {
      testWidgets('editor icon is hidden while styleId is default', (
        tester,
      ) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(settingsService.settings.styleId, 'default');
        expect(find.byIcon(Icons.tune), findsNothing);
      });

      testWidgets('editor icon appears once Custom is selected and navigates '
          'to CustomStyleEditorScreen', (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();

        expect(settingsService.settings.styleId, 'custom');
        expect(find.byIcon(Icons.tune), findsOneWidget);

        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();

        expect(find.byType(CustomStyleEditorScreen), findsOneWidget);
      });

      testWidgets('editor icon disappears again after switching back to '
          'Default', (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.tune), findsOneWidget);

        await tester.tap(find.text('Default'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.tune), findsNothing);
      });
    },
  );

  group('AppSettingsScreen — About row (D2, 05-settings-entry.md)', () {
    testWidgets('About row is present at the bottom and opens the about '
        'dialog', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The ListView is a lazy sliver — "About" sits well below the fold,
      // so drag straight to the bottom before it exists in the tree at all.
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });
  });
}
