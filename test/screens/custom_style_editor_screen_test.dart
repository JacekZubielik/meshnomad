import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Widget _wrap(Widget child, {required AppSettingsService settingsService}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsService>.value(value: settingsService),
    ],
    child: MaterialApp(theme: StyleRegistry.byId('default').light, home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
  });

  group('CustomStyleEditorScreen', () {
    testWidgets('renders the shortlist of colors and font size roles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      // SectionHeader uppercases its label.
      expect(find.text('COLORS'), findsOneWidget);
      // A sample of the shortlisted color fields, not the full ~60
      // MeshTokens set.
      expect(find.text('Background'), findsOneWidget);
      expect(find.text('Primary accent'), findsOneWidget);

      // The font sizes section sits below the fold — scroll the ListView to
      // build it into the tree before asserting on it.
      await tester.scrollUntilVisible(find.text('FONT SIZES'), 300);
      expect(find.text('FONT SIZES'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Mono caption'), 300);
      expect(find.text('Mono caption'), findsOneWidget);
    });

    testWidgets('tapping a preset swatch updates and persists the override', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        settingsService.settings.customStyleOverrides.colorOverrides['primary'],
        isNull,
      );

      await tester.tap(find.text('Primary accent'));
      await tester.pumpAndSettle();

      // Sheet is open — tap a preset swatch distinct from the default primary.
      final swatch = find.byKey(
        ValueKey('swatch_${const Color(0xFFEF4444).toARGB32()}'),
      );
      await tester.tap(swatch);
      await tester.pumpAndSettle();

      expect(
        settingsService.settings.customStyleOverrides.colorOverrides['primary'],
        isNotNull,
      );
    });

    testWidgets('invalid hex shows an inline error and does not apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primary accent'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not-a-color');
      await tester.tap(find.byKey(const ValueKey('applyHexButton')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a hex color like #RRGGBB'), findsOneWidget);
      expect(
        settingsService.settings.customStyleOverrides.colorOverrides['primary'],
        isNull,
      );
    });

    testWidgets('reset icon clears a single override', (tester) async {
      await settingsService.setCustomColorOverride(
        'primary',
        const Color(0xFF112233),
      );

      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();

      expect(
        settingsService.settings.customStyleOverrides.colorOverrides['primary'],
        isNull,
      );
    });

    testWidgets('reset all clears every override', (tester) async {
      await settingsService.setCustomColorOverride(
        'primary',
        const Color(0xFF112233),
      );
      await settingsService.setCustomFontSizeOverride('bodyMedium', 20);

      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset all'));
      await tester.pumpAndSettle();

      expect(
        settingsService.settings.customStyleOverrides.colorOverrides,
        isEmpty,
      );
      expect(
        settingsService.settings.customStyleOverrides.fontSizeOverrides,
        isEmpty,
      );
    });
  });

  group('AppSettingsScreen entry point', () {
    testWidgets('Custom chip + tune icon open CustomStyleEditorScreen', (
      tester,
    ) async {
      final connector = MeshCoreConnector();
      final translationService = TranslationService(settingsService);
      addTearDown(translationService.dispose);

      await tester.pumpWidget(
        MultiProvider(
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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.byType(CustomStyleEditorScreen), findsOneWidget);
    });
  });
}
