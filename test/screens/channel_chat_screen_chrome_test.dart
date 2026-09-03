import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/channel.dart';
import 'package:meshnomad/screens/channel_chat_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/chat_text_scale_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/chat_app_bar.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
import 'package:meshnomad/widgets/radio_stats_entry.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';
import 'package:meshnomad/widgets/winda_overlay.dart';

class _FakeConnector extends MeshCoreConnector {
  bool syncingChannels = false;

  @override
  bool get isConnected => true;

  @override
  bool get isSyncingChannels => syncingChannels;

  @override
  int get channelSyncProgress => syncingChannels ? 40 : 0;
}

final _channel = Channel(index: 1, name: '#test', psk: Uint8List(16));

Future<({_FakeConnector connector, AppSettingsService settings})> _pump(
  WidgetTester tester, {
  bool syncingChannels = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  PrefsManager.reset();
  await PrefsManager.initialize();
  final connector = _FakeConnector()..syncingChannels = syncingChannels;
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
        home: ChannelChatScreen(channel: _channel),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (connector: connector, settings: settings);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChannelChatScreen)));

/// MeshCoreConnector.notifyListeners() debounces through a 50ms Timer
/// (setActiveChannel fires one on open) — flush it before flutter_test's
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
      final env = await _pump(tester);

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
      // Region select is no longer a bare app-bar icon.
      expect(find.byIcon(Icons.landscape), findsNothing);
      await _finish(tester, env.connector);
    },
  );

  testWidgets('header: card badges, no avatar, no privacy word', (
    tester,
  ) async {
    final env = await _pump(tester);
    final l10n = _l10n(tester);

    expect(find.text('#test'), findsOneWidget);
    // Text-only header, same shape as the direct chat's (2026-09-04).
    expect(find.byType(ChannelAvatar), findsNothing);
    // Badges live in the ChatBadgeBar under the app bar, not in the title.
    final bar = find.byType(ChatBadgeBar);
    expect(bar, findsOneWidget);
    for (final label in [
      'CH 1',
      'SMAZ',
      'LANG',
      l10n.channels_badgeRegion.toUpperCase(),
    ]) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byType(MeshCardEdgeShadow), findsOneWidget);
    expect(find.text(l10n.channels_private), findsNothing);
    expect(find.text(l10n.channels_public), findsNothing);
    expect(find.textContaining(l10n.chat_unread(0)), findsNothing);
    await _finish(tester, env.connector);
  });

  testWidgets('menu: region on top, clear chat, then the app-wide group', (
    tester,
  ) async {
    final env = await _pump(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.byType(PopupMenuButton<dynamic>));
    await tester.pumpAndSettle();

    final region = find.text(l10n.channels_regionSelect_Title);
    final clear = find.text(l10n.contact_clearChat);
    final settings = find.text(l10n.settings_title);
    final quickStyle = find.text(l10n.appSettings_quickStyleMenuItem);
    final disconnect = find.text(l10n.common_disconnect);
    final about = find.text(l10n.settings_about);
    for (final f in [region, clear, settings, quickStyle, disconnect, about]) {
      expect(f, findsOneWidget);
    }
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(region), lessThan(y(clear)));
    expect(y(clear), lessThan(y(settings)));
    expect(y(settings), lessThan(y(quickStyle)));
    expect(y(quickStyle), lessThan(y(disconnect)));
    expect(y(disconnect), lessThan(y(about)));
    expect(find.byType(MeshMenuActionRow), findsNWidgets(6));
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await _finish(tester, env.connector);
  });

  testWidgets('progress winda shows while channels are syncing', (
    tester,
  ) async {
    final env = await _pump(tester, syncingChannels: true);
    final l10n = _l10n(tester);
    expect(find.byType(WindaProgress), findsOneWidget);
    expect(find.text(l10n.common_syncingChannels), findsOneWidget);
    await _finish(tester, env.connector);
  });

  testWidgets('no progress winda when idle', (tester) async {
    final env = await _pump(tester);
    expect(find.byType(WindaProgress), findsNothing);
    await _finish(tester, env.connector);
  });
}
