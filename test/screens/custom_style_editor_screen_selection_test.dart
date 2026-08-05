import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/screens/custom_style_editor_screen.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/styles/style_registry.dart';

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
        theme: StyleRegistry.byId('default').light,
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

      await tester.drag(find.byType(ListView), const Offset(0, -800));
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
