import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/app_settings_screen.dart';
import 'package:meshnomad/screens/custom_style_editor_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

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
      appName: 'MeshNomad',
      packageName: 'com.meshnomad.app',
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
        theme: MeshTheme.light().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppSettingsScreen(),
      ),
    );
  }

  group('AppSettingsScreen — Motyw section (theme + profile chip rows)', () {
    testWidgets('Default theme and Green profile are selected by default', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Default'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Green'), findsOneWidget);
    });

    testWidgets('Custom style row lives in the Debug section and opens '
        'CustomStyleEditorScreen (2026-08-22: relocated from Appearance)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // No tune icon left in the theme/profile chip section itself.
      expect(find.byIcon(Icons.tune), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Custom style'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible stops once the row is built, which can leave it
      // just below the fixed test viewport — ensureVisible actually brings
      // it on-screen so the tap lands.
      await tester.ensureVisible(find.text('Custom style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom style'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomStyleEditorScreen), findsOneWidget);
    });

    testWidgets('tapping the Blue profile chip actually switches the '
        'active profile', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Blue'));
      await tester.pumpAndSettle();

      expect(settingsService.settings.activeProfileId, 'blue');
      expect(find.widgetWithText(FilledButton, 'Blue'), findsOneWidget);
    });

    testWidgets('tapping the inert Terminal theme chip shows selection '
        'but does NOT change the persisted active theme', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Terminal'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Terminal'), findsOneWidget);
      expect(settingsService.settings.activeThemeId, 'default');
    });
  });

  group('AppSettingsScreen — About row (D2, 05-settings-entry.md)', () {
    testWidgets('About row is present at the bottom and opens the about '
        'dialog', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The ListView is a lazy sliver — "About" sits well below the fold,
      // so scroll it into view before it exists in the tree at all. Target
      // the main list's own Scrollable by its key — the screen has other
      // Scrollables (an internal TextField, modal sheets) that would
      // otherwise make a positional/type-only finder ambiguous or fragile.
      // The keyed list itself has a nested Scrollable too (a TextField's
      // internal EditableText further down) — `.first` resolves to the
      // list's OWN Scrollable since it's the structural ancestor and a
      // depth-first descendant search finds it before the nested one.
      final outerScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('appSettingsMainList')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('About'),
        500,
        scrollable: outerScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });
  });
}
