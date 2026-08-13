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
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';

Widget _wrap(
  Widget child, {
  required AppSettingsService settingsService,
  ThemeData? theme,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsService>.value(value: settingsService),
    ],
    child: MaterialApp(
      theme:
          theme ??
          MeshTheme.light().copyWith(
            extensions: const [MeshTokens.defaultTokens],
          ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
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
      // build it into the tree before asserting on it. Scrolling straight to
      // the row (not just the section header) avoids relying on how close
      // the header happens to sit to it.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('fontRow_bodyMedium')),
        300,
      );
      expect(find.text('FONT SIZES'), findsOneWidget);
      expect(find.byKey(const ValueKey('fontRow_bodyMedium')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('fontRow_monoCaptionSize')),
        300,
      );
      expect(
        find.byKey(const ValueKey('fontRow_monoCaptionSize')),
        findsOneWidget,
      );
    });

    testWidgets('Map and LOS sections are collapsed by default and expand '
        'to show their fields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Map'), 300);
      expect(find.text('Map'), findsOneWidget);
      expect(find.byKey(const ValueKey('colorRow_mapOnline')), findsNothing);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('colorRow_mapOnline')), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Line of sight (LOS)'), 300);
      expect(find.text('Line of sight (LOS)'), findsOneWidget);
      expect(find.byKey(const ValueKey('colorRow_losTerrain')), findsNothing);

      await tester.tap(find.text('Line of sight (LOS)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('colorRow_losTerrain')), findsOneWidget);
    });

    testWidgets('editing a map color saves an override applied by '
        'buildCustomStyle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Map'), 300);
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides['mapOnline'],
        isNull,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('colorRow_mapOnline')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('colorRow_mapOnline')));
      await tester.pumpAndSettle();

      final swatch = find.byKey(
        ValueKey('swatch_${const Color(0xFFEF4444).toARGB32()}'),
      );
      await tester.tap(swatch);
      await tester.pumpAndSettle();

      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides['mapOnline'],
        const Color(0xFFEF4444).toARGB32(),
      );
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
        settingsService.activeProfileSavedOverrides.colorOverrides['primary'],
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
        settingsService.activeProfileSavedOverrides.colorOverrides['primary'],
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
        settingsService.activeProfileSavedOverrides.colorOverrides['primary'],
        isNull,
      );
    });

    testWidgets('reset icon is disabled by default, becomes enabled after a '
        'change, clears the override, then disables again (pkt 2)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      // No override yet — the icon is present but disabled, not hidden.
      IconButton resetIcon() => tester.widget<IconButton>(
        find.byKey(const ValueKey('resetIcon_primary')),
      );
      expect(resetIcon().onPressed, isNull);

      await settingsService.setCustomColorOverride(
        'primary',
        const Color(0xFF112233),
      );
      await tester.pumpAndSettle();
      expect(resetIcon().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('resetIcon_primary')));
      await tester.pumpAndSettle();

      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides['primary'],
        isNull,
      );
      expect(resetIcon().onPressed, isNull);
    });

    testWidgets('reset all requires confirmation and then clears every '
        'override', (tester) async {
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('resetAllButton')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('resetAllButton')));
      await tester.pumpAndSettle();

      // Confirmation dialog is up — overrides must survive until confirmed.
      expect(
        find.text('Restore all colors and sizes to their default values?'),
        findsOneWidget,
      );
      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides,
        isNotEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('confirmResetAllButton')));
      await tester.pumpAndSettle();

      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides,
        isEmpty,
      );
      expect(
        settingsService.activeProfileSavedOverrides.fontSizeOverrides,
        isEmpty,
      );
    });

    testWidgets('dismissing the reset-all confirmation keeps overrides', (
      tester,
    ) async {
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('resetAllButton')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('resetAllButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        settingsService.activeProfileSavedOverrides.colorOverrides['primary'],
        isNotNull,
      );
    });
  });

  // TODO(task-5): this whole group tested the brightness SegmentedButton
  // (seeds from the current theme, tapping Light/Dark switches which map is
  // edited, reset clears only the selected brightness's override) — the
  // toggle and its per-brightness split are removed entirely (design spec
  // 2026-08-12, plan Task 5). Delete or rewrite once Task 5 lands; there is
  // no post-Task-5 equivalent to port these assertions to.
  group(
    'CustomStyleEditorScreen brightness switch (pkt 17)',
    skip: true, // TODO(task-5): feature removed, see comment above
    () {
      testWidgets(
        'seeds the switch from the current theme — dark theme '
        'starts on the Dark segment and edits colorOverridesDark',
        (tester) async {},
      );

      testWidgets(
        'tapping Light switches editing to colorOverridesLight, '
        'leaving colorOverridesDark untouched',
        (tester) async {},
      );

      testWidgets(
        'reset icon clears only the override for the currently '
        'selected brightness',
        (tester) async {},
      );
    },
  );

  // TODO(task-6): this group exercises the OLD Default/Custom style_id chip
  // picker UI, removed by the Motyw/Styl chip-row restructure (design spec
  // 2026-08-12, plan Task 6). Rewrite against ThemeChipRow/ProfileChipRow
  // once Task 6 lands.
  group(
    'AppSettingsScreen entry point',
    skip: true, // TODO(task-6): old picker UI removed, see comment above
    () {
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
              theme: MeshTheme.light().copyWith(
                extensions: const [MeshTokens.defaultTokens],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AppSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
    },
  );
}
