import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/app_settings_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

// TODO(task-6): this whole flow exercises the OLD Default/Custom style
// picker UI (text chips 'Custom'/'Default', AppSettings.styleId/
// customStyleOverrides) that Task 6 fully replaces with the Motyw/Styl
// chip-row restructure (design spec 2026-08-12, plan Task 6). The test is
// skipped and _TestApp reduced to a minimal compiling stub — do not
// resurrect the old picker semantics; rewrite this flow against the new
// AppSettingsService.setActiveTheme/setActiveProfile API once Task 6 lands.

/// Minimal harness replicating `MeshCoreApp`'s theme wiring without the
/// full provider tree or the `SelectionArea`-wrapping `builder:` — the
/// latter throws `No Overlay widget found` under
/// `IntegrationTestWidgetsFlutterBinding` specifically (pre-existing
/// app-level `SelectionArea` timing issue unrelated to custom styles,
/// out of scope for this test).
class _TestApp extends StatelessWidget {
  const _TestApp({required this.settingsService});

  final AppSettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsService>.value(
          value: settingsService,
        ),
        ChangeNotifierProvider<MeshCoreConnector>(
          create: (_) => MeshCoreConnector(),
        ),
        ChangeNotifierProvider<TranslationService>(
          create: (_) => TranslationService(settingsService),
        ),
      ],
      child: MaterialApp(
        theme: MeshTheme.dark().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppSettingsScreen(),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'custom style: live preview, default switch, persistence',
    skip: true, // TODO(task-6): rewrite against the new theme/profile API
    (tester) async {
      await PrefsManager.initialize();

      final settingsService = AppSettingsService();
      await settingsService.loadSettings();

      await tester.pumpWidget(_TestApp(settingsService: settingsService));
      await tester.pumpAndSettle();

      // TODO(task-6): the flow that used to live here (select 'Custom',
      // edit primary via the editor, verify live preview, switch back to
      // 'Default', verify persistence) exercised the old style_id/
      // customStyleOverrides picker UI removed by Task 6. Rewrite against
      // AppSettingsService.setActiveTheme/setActiveProfile/
      // activeProfileOverrides once that lands.
    },
  );
}
