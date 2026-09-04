import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/contact.dart';
import 'package:meshnomad/models/path_history.dart';
import 'package:meshnomad/screens/chat_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/chat_text_scale_service.dart';
import 'package:meshnomad/services/path_history_service.dart';
import 'package:meshnomad/services/storage_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/chat_app_bar.dart';
import 'package:meshnomad/widgets/dotted_separator.dart';
import 'package:meshnomad/widgets/mesh_dashed_divider.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
import 'package:meshnomad/widgets/radio_stats_entry.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';
import 'package:meshnomad/widgets/winda_overlay.dart';

class _FakeStorageService extends StorageService {
  @override
  Future<void> savePathHistory(
    String contactPubKeyHex,
    ContactPathHistory history,
  ) async {}
  @override
  Future<ContactPathHistory?> loadPathHistory(String contactPubKeyHex) async =>
      null;
  @override
  Future<void> clearPathHistory(String contactPubKeyHex) async {}
}

class _FakeConnector extends MeshCoreConnector {
  bool loadingContacts = false;

  @override
  bool get isConnected => true;

  @override
  bool get isLoadingContacts => loadingContacts;

  @override
  double? get contactSyncProgress => loadingContacts ? 0.5 : null;
}

final _contact = Contact(
  publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
  name: 'Alice',
  type: 1,
  pathLength: 0,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 9, 1, 12),
);

Future<_FakeConnector> _pump(
  WidgetTester tester, {
  bool loadingContacts = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  PrefsManager.reset();
  await PrefsManager.initialize();
  final connector = _FakeConnector()..loadingContacts = loadingContacts;
  final settings = AppSettingsService();
  await settings.loadSettings();
  final translation = TranslationService(settings);
  addTearDown(translation.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
        ChangeNotifierProvider<AppSettingsService>.value(value: settings),
        ChangeNotifierProvider<TranslationService>.value(value: translation),
        ChangeNotifierProvider<ChatTextScaleService>(
          create: (_) => ChatTextScaleService(),
        ),
        ChangeNotifierProvider<PathHistoryService>(
          create: (_) => PathHistoryService(_FakeStorageService()),
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
        navigatorObservers: [windaRouteObserver],
        builder: (context, navigatorChild) => Stack(
          children: [
            navigatorChild ?? const SizedBox.shrink(),
            const WindaHostOverlay(),
          ],
        ),
        home: ChatScreen(contact: _contact),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return connector;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChatScreen)));

/// MeshCoreConnector.notifyListeners() debounces through a 50ms Timer
/// (setActiveContact fires one on open) — flush it before flutter_test's
/// "no pending timers" invariant runs, then dispose the connector's own
/// timers explicitly (addTearDown runs too late for that check).
Future<void> _finish(WidgetTester tester, MeshCoreConnector connector) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpWidget(const SizedBox());
  connector.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app bar: accent back arrow, one circular menu, no radio stats/flat icon',
    (tester) async {
      final connector = await _pump(tester);

      final arrow = find.byIcon(Icons.arrow_back);
      expect(arrow, findsOneWidget);
      final primary = Theme.of(tester.element(arrow)).colorScheme.primary;
      expect(tester.widget<Icon>(arrow).color, primary);

      expect(
        find.byWidgetPredicate(
          (w) => w is MeshCircleIconButton && w.icon == Icons.more_vert,
        ),
        findsOneWidget,
      );
      expect(find.byType(AppBarMenuIcon), findsNothing);
      expect(find.byType(RadioStatsIconButton), findsNothing);
      await _finish(tester, connector);
    },
  );

  testWidgets('accent dashed rule sits under the app bar, full width', (
    tester,
  ) async {
    final connector = await _pump(tester);

    final divider = find.byType(MeshDashedDivider);
    expect(divider, findsOneWidget);
    final t = MeshTokens.of(tester.element(divider));
    final widget = tester.widget<MeshDashedDivider>(divider);
    expect(widget.indent, 0);
    expect(widget.endIndent, 0);
    expect(
      tester.getSize(divider).width,
      tester.getSize(find.byType(MaterialApp)).width,
    );
    // Directly under the app bar (top of body), not just anywhere.
    expect(tester.getTopLeft(divider).dy, closeTo(kToolbarHeight, 0.5));
    final dottedLine = find.descendant(
      of: divider,
      matching: find.byType(DottedSeparator),
    );
    expect(tester.widget<DottedSeparator>(dottedLine).color, t.secondary);
    // The theme's own solid bottom border is off — no double line.
    final shape = tester.widget<AppBar>(find.byType(AppBar)).shape;
    expect((shape! as Border).bottom.width, 0);
    await _finish(tester, connector);
  });

  testWidgets('header: contact-card badges replace the unread subtitle', (
    tester,
  ) async {
    final connector = await _pump(tester);
    final l10n = _l10n(tester);

    expect(find.text('Alice'), findsOneWidget);
    // Badges live in the ChatBadgeBar under the app bar, not in the title.
    final bar = find.byType(ChatBadgeBar);
    expect(bar, findsOneWidget);
    for (final label in ['GPS', 'SMAZ', 'LANG']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byType(MeshCardEdgeShadow), findsOneWidget);
    expect(find.textContaining(l10n.chat_unread(0)), findsNothing);
    await _finish(tester, connector);
  });

  testWidgets('menu: contact group, clear chat, then the app-wide group', (
    tester,
  ) async {
    final connector = await _pump(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.byType(PopupMenuButton<dynamic>));
    await tester.pumpAndSettle();

    final routing = find.text(l10n.routing_title);
    final info = find.text(l10n.contact_info);
    final telemetry = find.text(l10n.contact_telemetry);
    final contactSettings = find.text(l10n.contact_settings);
    final clear = find.text(l10n.contact_clearChat);
    final settings = find.text(l10n.settings_title);
    final quickStyle = find.text(l10n.appSettings_quickStyleMenuItem);
    final disconnect = find.text(l10n.common_disconnect);
    final about = find.text(l10n.settings_about);
    final ordered = [
      routing,
      info,
      telemetry,
      contactSettings,
      clear,
      settings,
      quickStyle,
      disconnect,
      about,
    ];
    for (final f in ordered) {
      expect(f, findsOneWidget);
    }
    for (var i = 1; i < ordered.length; i++) {
      expect(
        tester.getTopLeft(ordered[i - 1]).dy,
        lessThan(tester.getTopLeft(ordered[i]).dy),
      );
    }
    expect(find.byType(MeshMenuActionRow), findsNWidgets(9));
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await _finish(tester, connector);
  });

  testWidgets('progress winda shows while contacts are syncing', (
    tester,
  ) async {
    final connector = await _pump(tester, loadingContacts: true);
    final l10n = _l10n(tester);
    expect(find.byType(WindaProgress), findsOneWidget);
    expect(find.text(l10n.common_syncingContacts), findsOneWidget);
    await _finish(tester, connector);
  });

  testWidgets('no progress winda when idle', (tester) async {
    final connector = await _pump(tester);
    expect(find.byType(WindaProgress), findsNothing);
    await _finish(tester, connector);
  });
}
