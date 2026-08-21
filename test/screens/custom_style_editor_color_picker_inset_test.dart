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

Widget _wrap(Widget child, {required AppSettingsService settingsService}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsService>.value(value: settingsService),
    ],
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
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

  group('color picker sheet system inset', () {
    testWidgets('hex field stays above the system navigation bar', (
      tester,
    ) async {
      // Simulate an Android system navigation bar: 48 logical px at the
      // default test devicePixelRatio of 3.0 (FakeViewPadding is physical).
      const navBarLogical = 48.0;
      tester.view.viewPadding = FakeViewPadding(
        bottom: navBarLogical * tester.view.devicePixelRatio,
      );
      tester.view.padding = FakeViewPadding(
        bottom: navBarLogical * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const CustomStyleEditorScreen(),
          settingsService: settingsService,
        ),
      );
      await tester.pumpAndSettle();

      // Colors is a collapsed-by-default ExpansionTile (H audit, 2026-08-15).
      await tester.tap(find.text('Colors body'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Background'));
      await tester.pumpAndSettle();

      final hexField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      expect(hexField, findsOneWidget);

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final fieldBottom = tester.getRect(hexField).bottom;
      expect(
        fieldBottom,
        lessThanOrEqualTo(screenHeight - navBarLogical),
        reason:
            'Hex input must not be covered by the system navigation bar '
            '(field bottom $fieldBottom vs safe area limit '
            '${screenHeight - navBarLogical})',
      );
    });
  });
}
