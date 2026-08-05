import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/screens/app_settings_screen.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/services/translation_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/theme/styles/custom_style.dart';
import 'package:meshcore_open/theme/styles/style_registry.dart';

/// Minimal harness replicating `MeshCoreApp`'s theme-switching wiring
/// (`main.dart` — `_activeStyle`: `styleId == 'custom'` branches to
/// `buildCustomStyle`, otherwise `StyleRegistry.byId`) without the full
/// provider tree or the `SelectionArea`-wrapping `builder:` — the latter
/// throws `No Overlay widget found` under
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
      child: Consumer<AppSettingsService>(
        builder: (context, settings, _) {
          final styleId = settings.settings.styleId;
          final style = styleId == 'custom'
              ? buildCustomStyle(settings.settings.customStyleOverrides)
              : StyleRegistry.byId(styleId);
          return MaterialApp(
            theme: style.light,
            darkTheme: style.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppSettingsScreen(),
          );
        },
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom style: live preview, default switch, persistence', (
    tester,
  ) async {
    await PrefsManager.initialize();

    final settingsService = AppSettingsService();
    await settingsService.loadSettings();
    // Czysty start niezależnie od stanu maszyny:
    await settingsService.resetAllCustomOverrides();
    await settingsService.setStyleId('default');

    await tester.pumpWidget(_TestApp(settingsService: settingsService));
    await tester.pumpAndSettle();

    // 1. Wybierz styl Custom.
    await tester.scrollUntilVisible(find.text('Custom'), 200);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(settingsService.settings.styleId, 'custom');

    // 2. Otwórz edytor i zmień kolor primary.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primary accent'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('swatch_${const Color(0xFFEF4444).toARGB32()}')),
    );
    await tester.pumpAndSettle();

    // 3. LIVE PREVIEW: motyw appki (MaterialApp theme) ma nowy kolor.
    var ctx = tester.element(find.byType(Scaffold).first);
    expect(MeshTokens.of(ctx).primary, const Color(0xFFEF4444));

    // 4. Powrót do Default przywraca oryginał, Custom zachowuje zmianę.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(); // zamknij edytor
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    ctx = tester.element(find.byType(Scaffold).first);
    expect(MeshTokens.of(ctx).primary, MeshTokens.defaultTokens.primary);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    ctx = tester.element(find.byType(Scaffold).first);
    expect(MeshTokens.of(ctx).primary, const Color(0xFFEF4444));

    // 5. PERSYSTENCJA: świeża instancja serwisu czyta realne prefsy z dysku.
    final rereadService = AppSettingsService();
    await rereadService.loadSettings();
    expect(
      rereadService.settings.customStyleOverrides.colorOverrides['primary'],
      0xFFEF4444,
    );

    // Sprzątanie po teście — nie zostawiaj stanu na maszynie dewelopera.
    await settingsService.resetAllCustomOverrides();
    await settingsService.setStyleId('default');
  });
}
