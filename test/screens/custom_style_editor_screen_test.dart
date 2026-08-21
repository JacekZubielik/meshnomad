import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/custom_style_editor_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

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

      // Brightness is a property of the profile now, not an independent
      // editor toggle — the SegmentedButton this key used to identify is
      // removed entirely (design spec 2026-08-12, plan Task 5).
      expect(find.byKey(const ValueKey('brightnessSwitch')), findsNothing);

      // Colors is now a collapsed-by-default ExpansionTile, same as
      // Map/LOS (H audit, 2026-08-15) — its title is the raw ExpansionTile
      // text, not SectionHeader's uppercased label.
      expect(find.text('Colors body'), findsOneWidget);
      expect(find.text('Background'), findsNothing);

      await tester.tap(find.text('Colors body'));
      await tester.pumpAndSettle();

      // A sample of the shortlisted color fields, not the full ~60
      // MeshTokens set.
      expect(find.text('Background'), findsOneWidget);
      expect(find.text('Primary accent'), findsOneWidget);

      // Font sizes is a collapsed-by-default ExpansionTile now, same as the
      // color sections (2026-08-21) — scroll to it, expand, then assert on
      // the rows inside.
      await tester.scrollUntilVisible(find.text('Font sizes'), 300);
      await tester.ensureVisible(find.text('Font sizes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fontRow_bodyMedium')), findsNothing);

      await tester.tap(find.text('Font sizes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fontRow_bodyMedium')), findsOneWidget);
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

      await tester.scrollUntilVisible(find.text('Colors map'), 300);
      expect(find.text('Colors map'), findsOneWidget);
      expect(find.byKey(const ValueKey('colorRow_mapOnline')), findsNothing);

      await tester.tap(find.text('Colors map'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('colorRow_mapOnline')), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Colors Line of sight'), 300);
      // scrollUntilVisible stops once the tile is built, which can leave it
      // just below the 600px test viewport — ensureVisible actually brings
      // it on-screen so the tap lands (2026-08-21, list shortened by the
      // collapsed Font/Spacing/Radius/Card sections).
      await tester.ensureVisible(find.text('Colors Line of sight'));
      await tester.pumpAndSettle();
      expect(find.text('Colors Line of sight'), findsOneWidget);
      expect(find.byKey(const ValueKey('colorRow_losTerrain')), findsNothing);

      await tester.tap(find.text('Colors Line of sight'));
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

      await tester.scrollUntilVisible(find.text('Colors map'), 300);
      await tester.tap(find.text('Colors map'));
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

      await tester.tap(find.text('Colors body'));
      await tester.pumpAndSettle();
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

      await tester.tap(find.text('Colors body'));
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

      await tester.tap(find.text('Colors body'));
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
      // scrollUntilVisible only guarantees a sliver of the target is
      // rendered — with the radius section now 6 rows (pill added), that
      // sliver can land right at the viewport's bottom edge, putting the
      // button's tap-center just outside it. ensureVisible scrolls further
      // so the whole widget (and its center) sits inside the viewport.
      await tester.ensureVisible(find.byKey(const ValueKey('resetAllButton')));
      await tester.pumpAndSettle();
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
      // scrollUntilVisible only guarantees a sliver of the target is
      // rendered — with the radius section now 6 rows (pill added), that
      // sliver can land right at the viewport's bottom edge, putting the
      // button's tap-center just outside it. ensureVisible scrolls further
      // so the whole widget (and its center) sits inside the viewport.
      await tester.ensureVisible(find.byKey(const ValueKey('resetAllButton')));
      await tester.pumpAndSettle();
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

  // The old "AppSettingsScreen entry point" group (Custom chip + tune icon
  // navigation to CustomStyleEditorScreen) tested navigation, not editor
  // behavior — that coverage now lives properly in
  // app_settings_screen_test.dart's Motyw-section group (2026-08-13,
  // design spec plan Task 6), against the new ThemeChipRow/ProfileChipRow.
}
