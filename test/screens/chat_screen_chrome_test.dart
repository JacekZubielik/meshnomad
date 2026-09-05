import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/contact.dart';
import 'package:meshnomad/models/message.dart';
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
  List<Message> messages = [];
  final List<Uint8List> sentFrames = [];

  @override
  List<Message> getMessages(Contact contact) => messages;
  final List<Contact> removedContacts = [];
  final List<bool?> favoriteFlags = [];

  @override
  bool get isConnected => true;

  @override
  bool get isLoadingContacts => loadingContacts;

  @override
  double? get contactSyncProgress => loadingContacts ? 0.5 : null;

  @override
  Future<void> sendFrame(
    Uint8List data, {
    String? channelSendQueueId,
    bool expectsGenericAck = false,
    bool waitForGenericAck = false,
  }) async {
    sentFrames.add(data);
  }

  @override
  Future<void> removeContact(Contact contact) async {
    removedContacts.add(contact);
  }

  @override
  Future<void> setContactFlags(
    Contact contact, {
    bool? isFavorite,
    bool? teleBase,
    bool? teleLoc,
    bool? teleEnv,
  }) async {
    favoriteFlags.add(isFavorite);
  }
}

final _contact = Contact(
  publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
  name: 'Alice',
  type: 1,
  pathLength: 0,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 9, 1, 12),
);

const _openChatLabel = 'open chat';

/// Home route that pushes the chat on tap — for tests that need the chat to
/// be a popped-off route (delete contact leaves the chat).
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(contact: _contact),
          ),
        ),
        child: const Text(_openChatLabel),
      ),
    );
  }
}

final _incoming = Message(
  senderKey: _contact.publicKey,
  text: 'hello from alice',
  timestamp: DateTime(2026, 9, 4, 12),
  isOutgoing: false,
);

Future<_FakeConnector> _pump(
  WidgetTester tester, {
  bool loadingContacts = false,
  bool pushed = false,
  List<Message> messages = const [],
  MeshTokens tokens = MeshTokens.defaultTokens,
}) async {
  SharedPreferences.setMockInitialValues({});
  PrefsManager.reset();
  await PrefsManager.initialize();
  final connector = _FakeConnector()
    ..loadingContacts = loadingContacts
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
        ChangeNotifierProvider<PathHistoryService>(
          create: (_) => PathHistoryService(_FakeStorageService()),
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
        home: pushed ? const _Launcher() : ChatScreen(contact: _contact),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (pushed) {
    await tester.tap(find.text(_openChatLabel));
    await tester.pumpAndSettle();
  }
  return connector;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<dynamic>));
  await tester.pumpAndSettle();
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

  testWidgets(
    'menu: contact group + card winda actions, clear/delete, app-wide group',
    (tester) async {
      final connector = await _pump(tester);
      final l10n = _l10n(tester);

      await _openMenu(tester);

      final ordered = [
        l10n.routing_title,
        l10n.contact_info,
        l10n.contact_telemetry,
        l10n.contact_settings,
        l10n.contacts_showAdvertPath,
        l10n.listFilter_addToFavorites,
        l10n.contacts_ShareContact,
        l10n.contacts_ShareContactZeroHop,
        l10n.contact_clearChat,
        l10n.contacts_deleteContact,
        l10n.settings_title,
        l10n.appSettings_quickStyleMenuItem,
        l10n.common_disconnect,
        l10n.settings_about,
      ].map(find.text).toList();
      for (final f in ordered) {
        expect(f, findsOneWidget);
      }
      for (var i = 1; i < ordered.length; i++) {
        expect(
          tester.getTopLeft(ordered[i - 1]).dy,
          lessThan(tester.getTopLeft(ordered[i]).dy),
        );
      }
      expect(find.byType(MeshMenuActionRow), findsNWidgets(14));
      // No path known (pathLength 0) → no path-trace row, like the card winda.
      expect(find.text(l10n.contacts_chatTraceRoute), findsNothing);
      expect(find.text(l10n.listFilter_removeFromFavorites), findsNothing);

      final deleteRow = tester.widget<MeshMenuActionRow>(
        find.ancestor(
          of: find.text(l10n.contacts_deleteContact),
          matching: find.byType(MeshMenuActionRow),
        ),
      );
      final scheme = Theme.of(
        tester.element(find.byType(ChatScreen)),
      ).colorScheme;
      expect(deleteRow.iconColor, scheme.error);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await _finish(tester, connector);
    },
  );

  testWidgets('menu: add to favorites sets the favorite flag', (tester) async {
    final connector = await _pump(tester);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.listFilter_addToFavorites));
    await tester.pumpAndSettle();
    expect(connector.favoriteFlags, [true]);
    await _finish(tester, connector);
  });

  testWidgets('menu: share by advert sends the zero-hop share frame', (
    tester,
  ) async {
    final connector = await _pump(tester);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.contacts_ShareContactZeroHop));
    await tester.pumpAndSettle();
    expect(connector.sentFrames, hasLength(1));
    expect(connector.sentFrames.single.first, cmdShareContact);
    expect(find.text(l10n.contacts_zeroHopContactAdvertSent), findsOneWidget);
    // Let the toast expire before the pending-timer check.
    await tester.pump(const Duration(seconds: 5));
    await _finish(tester, connector);
  });

  testWidgets('menu: copy contact sends the export frame', (tester) async {
    final connector = await _pump(tester);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.contacts_ShareContact));
    await tester.pumpAndSettle();
    expect(connector.sentFrames, hasLength(1));
    expect(connector.sentFrames.single.first, cmdExportContact);
    // The fake never answers with the advert payload → the helper gives up
    // and reports the failure instead of hanging.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.contacts_contactAdvertCopyFailed), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _finish(tester, connector);
  });

  testWidgets('menu: delete contact confirms, removes and leaves the chat', (
    tester,
  ) async {
    final connector = await _pump(tester, pushed: true);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.contacts_deleteContact));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contacts_removeConfirm('Alice')), findsOneWidget);
    expect(connector.removedContacts, isEmpty);

    await tester.tap(find.text(l10n.common_delete));
    await tester.pumpAndSettle();

    expect(connector.removedContacts.map((c) => c.name), ['Alice']);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text(_openChatLabel), findsOneWidget);
    await _finish(tester, connector);
  });

  testWidgets('menu: cancelling delete keeps the chat open', (tester) async {
    final connector = await _pump(tester, pushed: true);
    final l10n = _l10n(tester);

    await _openMenu(tester);
    await tester.tap(find.text(l10n.contacts_deleteContact));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.common_cancel));
    await tester.pumpAndSettle();

    expect(connector.removedContacts, isEmpty);
    expect(find.byType(ChatScreen), findsOneWidget);
    await _finish(tester, connector);
  });

  testWidgets('bubble text uses the Chat messages size, same as channels', (
    tester,
  ) async {
    final connector = await _pump(
      tester,
      messages: [_incoming],
      tokens: MeshTokens.defaultTokens.copyWith(bodySize: 17),
    );
    // Was textTheme.titleSmall (10) while the channel chat used bodySize
    // (14) — the same message rendered 4 pt apart between the two chats.
    // Rendered through SelectableLinkify (tests run on desktop); its
    // `style` is what the screen passed, before Linkify's own span merge.
    final linkify = tester.widget<SelectableLinkify>(
      find.byWidgetPredicate(
        (w) => w is SelectableLinkify && w.text == 'hello from alice',
      ),
    );
    expect(linkify.style?.fontSize, 17);
    await _finish(tester, connector);
  });

  /// The bubble is the first Container above the message text that carries
  /// a BoxDecoration with a border radius (the text's own wrappers don't).
  Container bubbleContainer(WidgetTester tester, String text) {
    final containers = find.ancestor(
      of: find.text(text),
      matching: find.byType(Container),
    );
    for (final element in containers.evaluate()) {
      final container = element.widget as Container;
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.borderRadius != null) {
        return container;
      }
    }
    throw StateError('no bubble around "$text"');
  }

  testWidgets('bubble: same inset on every side, channel-chat shadow rule', (
    tester,
  ) async {
    final connector = await _pump(
      tester,
      messages: [_incoming],
      tokens: MeshTokens.defaultTokens.copyWith(
        bubbleRadius: 21,
        bubbleTailRadius: 3,
      ),
    );
    final context = tester.element(find.byType(ChatScreen));
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    expect(t.cardElevated, isTrue);

    final bubble = bubbleContainer(tester, 'hello from alice');
    // Same inset as the contact/channel cards (spacingMd).
    expect(bubble.padding, EdgeInsets.all(t.spacingMd));
    final decoration = bubble.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, t.labelShadow);
    expect(decoration.color, scheme.surfaceContainerHigh);
    // Incoming: tail corner top-left, the other three on the bubble slider.
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 3);
    expect(radius.topRight.x, 21);
    expect(radius.bottomLeft.x, 21);
    expect(radius.bottomRight.x, 21);
    await _finish(tester, connector);
  });

  testWidgets('bubble: dotted rule above the meta row, like the channel chat', (
    tester,
  ) async {
    final connector = await _pump(tester, messages: [_incoming]);
    final scheme = Theme.of(
      tester.element(find.byType(ChatScreen)),
    ).colorScheme;
    final rule = find.descendant(
      of: find.byWidget(bubbleContainer(tester, 'hello from alice')),
      matching: find.byType(DottedSeparator),
    );
    expect(rule, findsOneWidget);
    expect(tester.widget<DottedSeparator>(rule).color, scheme.onSurface);
    await _finish(tester, connector);
  });

  testWidgets('only the message body is selectable', (tester) async {
    final connector = await _pump(tester, messages: [_incoming]);
    final body = find.byWidgetPredicate(
      (w) => w is SelectableLinkify && w.text == 'hello from alice',
    );
    expect(body, findsOneWidget);
    // With a toolbar (Copy / Select all) — see the channel chat test.
    expect(
      tester.widget<SelectableLinkify>(body).contextMenuBuilder,
      isNotNull,
    );
    expect(find.byType(SelectionArea), findsNothing);
    // Inside the bubble the only SelectableText is the SelectableLinkify
    // body itself — name/time/meta are plain Text.
    final bubble = find.byWidget(bubbleContainer(tester, 'hello from alice'));
    final selectable = find
        .descendant(of: bubble, matching: find.byType(SelectableText))
        .evaluate()
        .length;
    final inBody = find
        .descendant(
          of: find.byType(SelectableLinkify),
          matching: find.byType(SelectableText),
        )
        .evaluate()
        .length;
    expect(selectable, inBody);
    expect(inBody, greaterThan(0));
    await _finish(tester, connector);
  });

  Finder body(String text) =>
      find.byWidgetPredicate((w) => w is SelectableLinkify && w.text == text);

  Future<Element> select(WidgetTester tester, String text) async {
    await tester.longPress(body(text));
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: body(text),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(editable).controller.selection.isCollapsed,
      isFalse,
      reason: 'long press should have selected a word',
    );
    return editable.evaluate().single;
  }

  void expectCleared(WidgetTester tester, String text, Element before) {
    final editable = find.descendant(
      of: body(text),
      matching: find.byType(EditableText),
    );
    expect(editable.evaluate().single, isNot(same(before)));
    expect(
      tester.widget<EditableText>(editable).controller.selection.isCollapsed,
      isTrue,
    );
    final focus = FocusManager.instance.primaryFocus?.context;
    expect(focus?.findAncestorWidgetOfExactType<SelectableLinkify>(), isNull);
  }

  testWidgets('a tap outside the message body leaves selection mode', (
    tester,
  ) async {
    final connector = await _pump(tester, messages: [_incoming]);
    final before = await select(tester, 'hello from alice');
    await tester.tapAt(
      tester.getBottomRight(find.byType(ChatBadgeBar)) + const Offset(-20, 200),
    );
    // ChatZoomWrapper listens for double taps, so a single tap is only
    // recognised after the double-tap deadline — advance past it.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expectCleared(tester, 'hello from alice', before);
    await _finish(tester, connector);
  });

  testWidgets('Esc leaves selection mode', (tester) async {
    final connector = await _pump(tester, messages: [_incoming]);
    final before = await select(tester, 'hello from alice');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expectCleared(tester, 'hello from alice', before);
    await _finish(tester, connector);
  });

  testWidgets('bubble: shadow off → outline, no shadow, flat fill', (
    tester,
  ) async {
    final connector = await _pump(
      tester,
      messages: [_incoming],
      tokens: MeshTokens.defaultTokens.copyWith(cardElevated: false),
    );
    final context = tester.element(find.byType(ChatScreen));
    final scheme = Theme.of(context).colorScheme;
    final decoration =
        bubbleContainer(tester, 'hello from alice').decoration!
            as BoxDecoration;
    expect(decoration.boxShadow, isNull);
    expect((decoration.border! as Border).top.color, scheme.outlineVariant);
    expect(decoration.color, scheme.surfaceContainerLow);
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
