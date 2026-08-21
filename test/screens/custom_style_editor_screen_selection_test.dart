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

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsService>.value(
          value: settingsService,
        ),
      ],
      child: MaterialApp(
        theme: MeshTheme.light().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CustomStyleEditorScreen(),
      ),
    );
  }

  testWidgets(
    'Font sizes row label can be long-press selected (known-issues pkt 6)',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Font sizes is a collapsed-by-default ExpansionTile (2026-08-21) —
      // expand it first, then bring the row itself on-screen. ensureVisible
      // after scrollUntilVisible because the latter stops as soon as the
      // widget is built, which can leave it below the test viewport.
      await tester.scrollUntilVisible(find.text('Font sizes'), 300);
      await tester.ensureVisible(find.text('Font sizes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Font sizes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Body text'), 300);
      await tester.ensureVisible(find.text('Body text'));
      await tester.pumpAndSettle();
      expect(find.text('Body text'), findsOneWidget);

      await tester.longPress(find.text('Body text'));
      await tester.pumpAndSettle();

      // A selection toolbar with "Copy" surfacing proves the long-press
      // produced a real text selection instead of being swallowed by the
      // adjacent Slider's own gesture recognizer (H3).
      expect(find.text('Copy'), findsOneWidget);
    },
  );
}
