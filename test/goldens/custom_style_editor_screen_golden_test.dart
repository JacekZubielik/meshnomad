import 'package:alchemist/alchemist.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  goldenTest(
    'custom style editor screen (dark, no overrides)',
    fileName: 'custom_style_editor_screen',
    pumpBeforeTest: (tester) => tester.pump(const Duration(seconds: 1)),
    builder: () => GoldenTestScenario(
      name: 'editor',
      child: SizedBox(
        width: 420,
        height: 1620,
        child: ChangeNotifierProvider<AppSettingsService>(
          create: (_) => AppSettingsService(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: MeshTheme.dark().copyWith(
              extensions: const [MeshTokens.defaultTokens],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CustomStyleEditorScreen(),
          ),
        ),
      ),
    ),
  );
}
