import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/channel.dart';
import 'package:meshnomad/models/channel_message.dart';
import 'package:meshnomad/screens/channels_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/ui_view_state_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';

class _FakeConnector extends MeshCoreConnector {
  final List<Channel> _testChannels = [
    Channel(index: 0, name: '#unread', psk: Uint8List(16)),
    Channel(index: 1, name: '#quiet', psk: Uint8List(16)),
  ];

  @override
  List<Channel> get channels => List.unmodifiable(_testChannels);

  @override
  Future<void> getChannels({int? maxChannels, bool force = false}) async {}

  @override
  int getUnreadCountForChannel(Channel channel) => channel.index == 0 ? 5 : 0;

  @override
  List<ChannelMessage> getChannelMessages(Channel channel) => [
    ChannelMessage(
      senderName: 'node',
      text: 'hello',
      timestamp: DateTime(2026, 8, 6, 12),
      isOutgoing: false,
    ),
  ];

  @override
  int getTotalContactsUnreadCount() => 0;

  @override
  int getTotalChannelsUnreadCount() => 5;

  @override
  bool get isConnected => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('channel tiles keep equal heights with and without unread', (
    tester,
  ) async {
    // The height drift shows once the right column (time + badge) outgrows
    // the avatar — reproduce the user's enlarged system font.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    final connector = _FakeConnector();
    addTearDown(connector.dispose);
    final settings = AppSettingsService();
    await settings.loadSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
          ChangeNotifierProvider<AppSettingsService>.value(value: settings),
          ChangeNotifierProvider<UiViewStateService>(
            create: (_) => UiViewStateService(),
          ),
          // ChannelsScreen now renders through MeshScreenScaffold
          // (2026-09-02 winda migration), which reads WindaHostController.
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
          // Required for MeshScreenScaffold's RouteAware subscription, same
          // as main.dart and contacts_screen_message_winda_test.dart.
          navigatorObservers: [windaRouteObserver],
          builder: (context, navigatorChild) {
            return Stack(
              children: [
                navigatorChild ?? const SizedBox.shrink(),
                const WindaHostOverlay(),
              ],
            );
          },
          home: const ChannelsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final unreadTile = tester.getSize(find.byKey(const ValueKey('channel_0')));
    final quietTile = tester.getSize(find.byKey(const ValueKey('channel_1')));

    expect(
      unreadTile.height,
      quietTile.height,
      reason:
          'tile with unread badge (${unreadTile.height}) must not be taller '
          'than tile without (${quietTile.height})',
    );
  });
}
