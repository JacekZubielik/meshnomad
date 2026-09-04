import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/channel.dart';
import 'package:meshnomad/models/channel_message.dart';
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
import 'package:meshnomad/widgets/dotted_separator.dart';
import 'package:meshnomad/widgets/mesh_dashed_divider.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
import 'package:meshnomad/widgets/radio_stats_entry.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';
import 'package:meshnomad/widgets/winda_overlay.dart';

class _FakeConnector extends MeshCoreConnector {
  bool syncingChannels = false;
  final List<int> deletedChannelIndices = [];
  List<ChannelMessage> messages = [];

  @override
  List<ChannelMessage> getChannelMessages(Channel channel) => messages;

  @override
  bool get isConnected => true;

  @override
  bool get isSyncingChannels => syncingChannels;

  @override
  int get channelSyncProgress => syncingChannels ? 40 : 0;

  @override
  Future<void> deleteChannel(int index) async {
    deletedChannelIndices.add(index);
  }
}

final _channel = Channel(index: 1, name: '#test', psk: Uint8List(16));

const _openChatLabel = 'open chat';

/// Home route that pushes the chat on tap — for tests that need the chat to
/// be a popped-off route (delete channel leaves the chat).
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChannelChatScreen(channel: _channel),
          ),
        ),
        child: const Text(_openChatLabel),
      ),
    );
  }
}

final _incoming = ChannelMessage(
  senderName: 'Bob',
  text: 'hello from bob',
  timestamp: DateTime(2026, 9, 4, 12),
  isOutgoing: false,
  reactions: {'👍': 2},
);
final _outgoing = ChannelMessage(
  senderName: 'Me',
  text: 'hi bob',
  timestamp: DateTime(2026, 9, 4, 12, 1),
  isOutgoing: true,
);

Future<({_FakeConnector connector, AppSettingsService settings})> _pump(
  WidgetTester tester, {
  bool syncingChannels = false,
  bool pushed = false,
  List<ChannelMessage> messages = const [],
  MeshTokens tokens = MeshTokens.defaultTokens,
}) async {
  SharedPreferences.setMockInitialValues({});
  PrefsManager.reset();
  await PrefsManager.initialize();
  final connector = _FakeConnector()
    ..syncingChannels = syncingChannels
    ..messages = messages;
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
        theme: MeshTheme.light().copyWith(extensions: [tokens]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [windaRouteObserver],
        builder: (context, navigatorChild) => Stack(
          children: [
            navigatorChild ?? const SizedBox.shrink(),
            const WindaHostOverlay(),
          ],
        ),
        home: pushed ? const _Launcher() : ChannelChatScreen(channel: _channel),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (pushed) {
    await tester.tap(find.text(_openChatLabel));
    await tester.pumpAndSettle();
  }
  return (connector: connector, settings: settings);
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<dynamic>));
  await tester.pumpAndSettle();
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

  testWidgets('accent dashed rule sits under the app bar, full width', (
    tester,
  ) async {
    final env = await _pump(tester);

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
    await _finish(tester, env.connector);
  });

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

  testWidgets(
    'menu: region, edit, mute; clear chat, delete channel; app-wide group',
    (tester) async {
      final env = await _pump(tester);
      final l10n = _l10n(tester);

      await _openMenu(tester);

      final ordered = [
        l10n.channels_regionSelect_Title,
        l10n.channels_editChannel,
        l10n.channels_muteChannel,
        l10n.contact_clearChat,
        l10n.channels_deleteChannel,
        l10n.settings_title,
        l10n.appSettings_quickStyleMenuItem,
        l10n.common_disconnect,
        l10n.settings_about,
      ].map(find.text).toList();
      for (final f in ordered) {
        expect(f, findsOneWidget);
      }
      double y(Finder f) => tester.getTopLeft(f).dy;
      for (var i = 1; i < ordered.length; i++) {
        expect(y(ordered[i - 1]), lessThan(y(ordered[i])));
      }
      expect(find.byType(MeshMenuActionRow), findsNWidgets(9));
      expect(find.text(l10n.channels_unmuteChannel), findsNothing);

      // Delete channel is destructive → error-tinted icon, like Clear chat.
      final deleteRow = tester.widget<MeshMenuActionRow>(
        find.ancestor(
          of: find.text(l10n.channels_deleteChannel),
          matching: find.byType(MeshMenuActionRow),
        ),
      );
      final scheme = Theme.of(
        tester.element(find.byType(ChannelChatScreen)),
      ).colorScheme;
      expect(deleteRow.iconColor, scheme.error);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await _finish(tester, env.connector);
    },
  );

  testWidgets('menu: mute toggles the channel and flips to unmute', (
    tester,
  ) async {
    final env = await _pump(tester);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.channels_muteChannel));
    await tester.pumpAndSettle();
    expect(env.settings.isChannelMuted('#test'), isTrue);

    await _openMenu(tester);
    expect(find.text(l10n.channels_unmuteChannel), findsOneWidget);
    expect(find.text(l10n.channels_muteChannel), findsNothing);
    await tester.tap(find.text(l10n.channels_unmuteChannel));
    await tester.pumpAndSettle();
    expect(env.settings.isChannelMuted('#test'), isFalse);
    await _finish(tester, env.connector);
  });

  testWidgets('menu: edit channel opens the edit sheet', (tester) async {
    final env = await _pump(tester);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.channels_editChannel));
    await tester.pumpAndSettle();

    expect(find.text(l10n.channels_editChannelTitle(1)), findsOneWidget);
    expect(find.text(l10n.common_save), findsOneWidget);

    await tester.tap(find.text(l10n.common_cancel));
    await tester.pumpAndSettle();
    await _finish(tester, env.connector);
  });

  testWidgets('menu: delete channel confirms, deletes and leaves the chat', (
    tester,
  ) async {
    final env = await _pump(tester, pushed: true);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.channels_deleteChannel));
    await tester.pumpAndSettle();

    // Confirmation first — nothing deleted yet.
    expect(
      find.text(l10n.channels_deleteChannelConfirm('#test')),
      findsOneWidget,
    );
    expect(env.connector.deletedChannelIndices, isEmpty);

    await tester.tap(find.text(l10n.common_delete));
    await tester.pumpAndSettle();

    expect(env.connector.deletedChannelIndices, [1]);
    expect(find.byType(ChannelChatScreen), findsNothing);
    expect(find.text(_openChatLabel), findsOneWidget);
    await _finish(tester, env.connector);
  });

  testWidgets('menu: cancelling delete keeps the chat open', (tester) async {
    final env = await _pump(tester, pushed: true);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.channels_deleteChannel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.common_cancel));
    await tester.pumpAndSettle();

    expect(env.connector.deletedChannelIndices, isEmpty);
    expect(find.byType(ChannelChatScreen), findsOneWidget);
    await _finish(tester, env.connector);
  });

  /// The bubble is the first Container above the message text that carries
  /// a BoxDecoration with a border radius (the text's own wrappers don't).
  BoxDecoration bubbleDecoration(WidgetTester tester, String text) {
    final containers = find.ancestor(
      of: find.text(text),
      matching: find.byType(Container),
    );
    for (final element in containers.evaluate()) {
      final decoration = (element.widget as Container).decoration;
      if (decoration is BoxDecoration && decoration.borderRadius != null) {
        return decoration;
      }
    }
    throw StateError('no bubble around "$text"');
  }

  BoxDecoration reactionChipDecoration(WidgetTester tester) =>
      bubbleDecoration(tester, '👍');

  testWidgets(
    'bubbles: shadow on → drop shadow, no outline, fill bumped like MeshCard',
    (tester) async {
      final env = await _pump(tester, messages: [_incoming, _outgoing]);
      final context = tester.element(find.byType(ChannelChatScreen));
      final scheme = Theme.of(context).colorScheme;
      final t = MeshTokens.of(context);
      expect(t.cardElevated, isTrue);

      final incoming = bubbleDecoration(tester, 'hello from bob');
      expect(incoming.border, isNull);
      expect(incoming.boxShadow, MeshCard.dropShadow(context));
      expect(incoming.color, scheme.surfaceContainerHigh);

      final outgoing = bubbleDecoration(tester, 'hi bob');
      expect(outgoing.border, isNull);
      expect(outgoing.boxShadow, MeshCard.dropShadow(context));
      expect(outgoing.color, t.me);

      final chip = reactionChipDecoration(tester);
      expect(chip.border, isNull);
      expect(chip.boxShadow, t.labelShadow);
      await _finish(tester, env.connector);
    },
  );

  testWidgets('bubbles: shadow off → outline, no shadow, flat fill', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      messages: [_incoming, _outgoing],
      tokens: MeshTokens.defaultTokens.copyWith(cardElevated: false),
    );
    final context = tester.element(find.byType(ChannelChatScreen));
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);

    final incoming = bubbleDecoration(tester, 'hello from bob');
    expect(incoming.boxShadow, isNull);
    expect((incoming.border! as Border).top.color, scheme.outlineVariant);
    expect(incoming.color, scheme.surfaceContainerLow);

    final outgoing = bubbleDecoration(tester, 'hi bob');
    expect(outgoing.boxShadow, isNull);
    expect((outgoing.border! as Border).top.color, t.meBorder);
    expect(outgoing.color, t.me);

    final chip = reactionChipDecoration(tester);
    expect(chip.boxShadow, isNull);
    expect((chip.border! as Border).top.color, scheme.outlineVariant);
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
