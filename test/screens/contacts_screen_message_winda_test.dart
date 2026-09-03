import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/screens/contacts_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/ui_view_state_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'contactSyncTimedOut shows the stall message with a working Resync '
    'button that calls getContacts() again',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PrefsManager.reset();
      await PrefsManager.initialize();
      final connector = MeshCoreConnector();
      final settings = AppSettingsService();
      await settings.loadSettings();

      await tester.pumpWidget(_wrap(connector: connector, settings: settings));
      await tester.pump();
      await tester.pump();

      connector.debugConnectionState = MeshCoreConnectionState.connected;
      connector.debugBeginContactSyncTracking();
      connector.debugTriggerContactSyncTimeout();
      // MeshCoreConnector.notifyListeners() is overridden to debounce
      // through a 50ms Timer (markNotifyDirty/_flushBatchedNotify) rather
      // than notifying synchronously — a bare tester.pump() (no duration)
      // doesn't advance time far enough for that timer to fire, so the
      // widget tree never rebuilds. Advancing past the debounce window is
      // required here.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ContactsScreen)),
      );
      expect(find.text(l10n.contacts_syncStalled), findsOneWidget);

      // Icon-only circular button (2026-09-02 restyle) — the label is now
      // exposed via Semantics (not Tooltip: this widget is hosted by
      // WindaHostOverlay above the Navigator, so there's no ancestor
      // Overlay for Tooltip to attach to). meshMainAppBar's own overflow
      // menu is ALSO a MeshCircleIconButton, so disambiguate by icon
      // (refresh vs. more_vert) rather than by type alone.
      final resyncButton = find.byWidgetPredicate(
        (w) => w is MeshCircleIconButton && w.icon == Icons.refresh,
      );
      expect(resyncButton, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == l10n.common_resync,
        ),
        findsOneWidget,
      );

      // Invoke the real button's callback directly rather than going
      // through tester.tap()'s full gesture/hit-test pipeline: this still
      // exercises the actual production widget and its actual `onPressed`
      // closure (proving Resync is wired to `connector.getContacts()`,
      // not a stand-in), while sidestepping the winda's AnimatedSize/
      // AnimatedSwitcher entrance animation transiently shifting the
      // hit-test target underneath a coordinate-based tap.
      final onPressed = tester
          .widget<MeshCircleIconButton>(resyncButton)
          .onPressed;
      expect(onPressed, isNotNull);

      // getContacts() reaches sendFrame with no real transport attached in
      // this test, rejecting its returned Future — intentionally unawaited
      // by the widget (`onAction` is a bare `VoidCallback`), so it must be
      // caught explicitly here or flutter_test treats it as an unhandled
      // zone error and fails the test immediately, before the rest of this
      // test body (including addTearDown(connector.dispose)) ever runs.
      Object? caughtError;
      await runZonedGuarded(() async {
        onPressed!();
      }, (error, stack) => caughtError = error);
      expect(caughtError, isNotNull);

      // getContacts() calls notifyListeners() synchronously (debounced,
      // same 50ms timer as above) before it reaches sendFrame — enough
      // time to observe the synchronous state-reset it performs first.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      // Tapping Resync re-arms tracking and clears the stale flag —
      // the stall message should be gone.
      expect(find.text(l10n.contacts_syncStalled), findsNothing);

      // getContacts() left the 5s idle-timeout Timer freshly re-armed.
      // Disposed explicitly here (not via addTearDown — empirically,
      // addTearDown callbacks run AFTER flutter_test's own
      // "no pending timers" invariant check for this Flutter version, so
      // they're too late to cancel it) so the Timer doesn't trip that
      // check.
      connector.dispose();
    },
  );
}
