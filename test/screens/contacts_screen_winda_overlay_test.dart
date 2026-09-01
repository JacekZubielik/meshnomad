import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/contact.dart';
import 'package:meshnomad/screens/contacts_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/ui_view_state_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';

/// A cold-start fake: connected, but still loading the first batch of
/// contacts (`hasLoadedContacts` is false and the list is still empty) —
/// this is the `waitingForFirstContact` branch in
/// `_buildContactsBody`, which used to `return` before the method ever
/// reached the Stack/WindaOverlay wiring further down.
class _ColdStartFakeConnector extends MeshCoreConnector {
  @override
  bool get isConnected => true;

  @override
  bool isLoadingContacts = true;

  @override
  bool hasLoadedContacts = false;

  @override
  List<Contact> get contacts => const [];

  @override
  double? contactSyncProgress = 0.3;

  @override
  bool isSyncingChannels = false;
}

Widget _wrap({
  required MeshCoreConnector connector,
  required AppSettingsService settings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
      ChangeNotifierProvider<AppSettingsService>.value(value: settings),
      ChangeNotifierProvider<UiViewStateService>(
        create: (_) => UiViewStateService(),
      ),
      ChangeNotifierProvider<WindaHostController>(
        create: (_) => WindaHostController(),
      ),
    ],
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Required for MeshScreenScaffold's RouteAware subscription and to
      // actually render the registered message, exactly as in main.dart.
      navigatorObservers: [windaRouteObserver],
      builder: (context, navigatorChild) {
        return Stack(
          children: [
            navigatorChild ?? const SizedBox.shrink(),
            const WindaHostOverlay(),
          ],
        );
      },
      home: const ContactsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cold-start (isLoadingContacts true, contacts empty) shows the winda '
    'sync label, not just the bare spinner',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PrefsManager.reset();
      await PrefsManager.initialize();
      final connector = _ColdStartFakeConnector();
      addTearDown(connector.dispose);
      final settings = AppSettingsService();
      await settings.loadSettings();

      await tester.pumpWidget(_wrap(connector: connector, settings: settings));
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(ContactsScreen));
      final l10n = AppLocalizations.of(context);

      // The bare-spinner regression: winda-overlay content must be present
      // during the cold-start wait, not just the CircularProgressIndicator.
      expect(find.text(l10n.common_syncingContacts), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
}
