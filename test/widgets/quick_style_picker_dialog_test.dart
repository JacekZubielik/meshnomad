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
import 'package:meshnomad/widgets/quick_style_picker_dialog.dart';

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
    return ChangeNotifierProvider<AppSettingsService>.value(
      value: settingsService,
      child: MaterialApp(
        theme: MeshTheme.light().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showQuickStylePickerDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows both chip rows with theme and profile labels', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Default'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Terminal'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Omarchy'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Green'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Blue'), findsOneWidget);
  });

  testWidgets('tapping Blue re-themes live and sets activeProfileId', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Blue'));
    await tester.pumpAndSettle();

    expect(settingsService.settings.activeProfileId, 'blue');
  });

  testWidgets(
    'tapping Terminal only previews selection; activeThemeId stays default',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Terminal'));
      await tester.pumpAndSettle();

      expect(settingsService.settings.activeThemeId, 'default');
      final terminalChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Terminal'),
      );
      expect(terminalChip.selected, isTrue);
    },
  );

  testWidgets('tune icon opens CustomStyleEditorScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(CustomStyleEditorScreen), findsOneWidget);
  });
}
