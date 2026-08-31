import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/companion_radio_stats.dart';
import 'package:meshnomad/screens/companion_radio_stats_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/mesh_info_dialog.dart';
import 'package:meshnomad/widgets/battery_indicator.dart';
import 'package:meshnomad/widgets/radio_stats_entry.dart';
import 'package:meshnomad/widgets/snr_indicator.dart';

class _FakeConnector extends MeshCoreConnector {
  final List<DirectRepeater> repeaters = [];
  MeshCoreTransportType transport = MeshCoreTransportType.bluetooth;
  int? rssi;
  String? usbLabel;
  int? usbBaud;
  String? tcpEndpoint;

  @override
  List<DirectRepeater> get directRepeaters => repeaters;

  @override
  int? get batteryMillivolts => 3700;

  @override
  int? get batteryPercent => 75;

  @override
  bool get isConnected => true;

  @override
  bool get supportsCompanionRadioStats => true;

  @override
  bool get radioStatsAirActivityPulse => false;

  @override
  MeshCoreTransportType get activeTransport => transport;

  @override
  int? get bleLinkRssi => rssi;

  @override
  String? get activeUsbPortDisplayLabel => usbLabel;

  @override
  int? get activeUsbBaudRate => usbBaud;

  @override
  String? get activeTcpEndpoint => tcpEndpoint;

  @override
  void acquireRadioStatsPolling() {}

  @override
  void releaseRadioStatsPolling() {}

  @override
  void acquireBleRssiPolling() {}

  @override
  void releaseBleRssiPolling() {}

  @override
  void setPollingInterval(int seconds) {}
}

CompanionRadioStats _stats({int noiseFloorDbm = -98}) => CompanionRadioStats(
  noiseFloorDbm: noiseFloorDbm,
  lastRssiDbm: -80,
  lastSnrDb: 5.0,
  txAirSecs: 0,
  rxAirSecs: 0,
  receivedAt: DateTime.now(),
);

Widget _wrap(Widget child, {required MeshCoreConnector connector}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
      // RadioStatsPanel (RF popup) watches the duty-cycle limit setting.
      ChangeNotifierProvider<AppSettingsService>(
        create: (_) => AppSettingsService(),
      ),
    ],
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Widget _wrapAppBar({
  required String title,
  required MeshCoreConnector connector,
}) {
  return _wrap(
    Builder(
      builder: (context) => Scaffold(
        appBar: meshMainAppBar(
          context,
          title: title,
          menuItemBuilder: (context) => const [],
        ),
      ),
    ),
    connector: connector,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnector connector;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    connector = _FakeConnector();
    addTearDown(connector.dispose);
  });

  testWidgets('battery and signal captions share font size and family', (
    tester,
  ) async {
    connector.repeaters.add(
      DirectRepeater(pubkeyPrefix: [0xAB, 0x12], pathHashWidth: 2, snr: 8.0),
    );

    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            BatteryIndicator(connector: connector),
            SNRIndicator(connector: connector),
          ],
        ),
        connector: connector,
      ),
    );
    await tester.pump();

    final batteryCaption = tester.widget<Text>(find.text('75%'));
    final signalCaption = tester.widget<Text>(
      find.descendant(
        of: find.byType(SNRIndicator),
        matching: find.byType(Text),
      ),
    );

    expect(
      signalCaption.style?.fontSize,
      batteryCaption.style?.fontSize,
      reason: 'signal caption font size must match battery caption',
    );
    expect(
      signalCaption.style?.fontFamily,
      batteryCaption.style?.fontFamily,
      reason: 'signal caption font family must match battery caption',
    );
    expect(
      signalCaption.style?.fontWeight,
      batteryCaption.style?.fontWeight,
      reason: 'signal caption font weight must match battery caption',
    );

    final batteryIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(BatteryIndicator),
        matching: find.byType(Icon),
      ),
    );
    final signalIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(SNRIndicator),
        matching: find.byType(Icon),
      ),
    );
    expect(signalIcon.size, batteryIcon.size);
  });

  testWidgets('compact radio stats shows an RF icon with a placeholder '
      'caption before stats arrive', (tester) async {
    await tester.pumpWidget(
      _wrap(const RadioStatsIconButton(compact: true), connector: connector),
    );
    await tester.pump();

    expect(find.byIcon(Icons.wifi_tethering), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_tethering));
    expect(icon.size, 18);
  });

  testWidgets('compact radio stats caption shows the noise floor', (
    tester,
  ) async {
    connector.radioStatsNotifier.value = _stats(noiseFloorDbm: -98);

    await tester.pumpWidget(
      _wrap(const RadioStatsIconButton(compact: true), connector: connector),
    );
    await tester.pump();

    expect(find.text('-98dBm'), findsOneWidget);
  });

  testWidgets('AppBarMenuIcon renders more_vert at the shared indicator size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppBarMenuIcon(), connector: connector),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.more_vert));
    expect(icon.size, 18);
  });

  testWidgets(
    'meshMainAppBar\'s trailing menu uses the circular icon treatment, '
    'not the flat dots (2026-09-01 — matches Flasher\'s _FlasherMenuButton)',
    (tester) async {
      await tester.pumpWidget(
        _wrapAppBar(title: 'Kontakty', connector: connector),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBarMenuIcon), findsNothing);
      // MeshCircleIconButton renders a 32x32 circular DecoratedBox — assert
      // on that shape directly rather than a private implementation detail.
      final circleFinder = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CircleBorder,
      );
      expect(circleFinder, findsWidgets);
    },
  );

  group('TransportIndicator', () {
    testWidgets('BLE shows bluetooth icon with the link RSSI', (tester) async {
      connector.transport = MeshCoreTransportType.bluetooth;
      connector.rssi = -58;

      await tester.pumpWidget(
        _wrap(TransportIndicator(connector: connector), connector: connector),
      );
      await tester.pump();

      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.text('-58dBm'), findsOneWidget);
    });

    testWidgets('BLE shows a placeholder before the first RSSI read', (
      tester,
    ) async {
      connector.transport = MeshCoreTransportType.bluetooth;
      connector.rssi = null;

      await tester.pumpWidget(
        _wrap(TransportIndicator(connector: connector), connector: connector),
      );
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('USB shows the baud rate, TCP the endpoint', (tester) async {
      connector.transport = MeshCoreTransportType.usb;
      connector.usbBaud = 115200;

      await tester.pumpWidget(
        _wrap(TransportIndicator(connector: connector), connector: connector),
      );
      await tester.pump();
      expect(find.byIcon(Icons.usb), findsOneWidget);
      expect(find.text('115200'), findsOneWidget);

      connector.transport = MeshCoreTransportType.tcp;
      connector.tcpEndpoint = '192.168.40.10:5000';

      await tester.pumpWidget(
        _wrap(TransportIndicator(connector: connector), connector: connector),
      );
      await tester.pump();
      expect(find.byIcon(Icons.lan), findsOneWidget);
      expect(find.text('192.168.40.10:5000'), findsOneWidget);
    });
  });

  group('indicator popups (MeshInfoDialog pattern)', () {
    testWidgets('battery tap opens the info popup with charge and voltage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BatteryIndicator(connector: connector), connector: connector),
      );
      await tester.pump();

      await tester.tap(find.byType(BatteryIndicator));
      await tester.pumpAndSettle();

      expect(find.byType(MeshInfoDialog), findsOneWidget);
      expect(find.text('75%'), findsWidgets);
      expect(find.text('3.70 V'), findsOneWidget);
    });

    testWidgets('transport tap opens the info popup with BLE details', (
      tester,
    ) async {
      connector.transport = MeshCoreTransportType.bluetooth;
      connector.rssi = -58;

      await tester.pumpWidget(
        _wrap(TransportIndicator(connector: connector), connector: connector),
      );
      await tester.pump();

      await tester.tap(find.byType(TransportIndicator));
      await tester.pumpAndSettle();

      expect(find.byType(MeshInfoDialog), findsOneWidget);
      expect(find.text('-58 dBm'), findsOneWidget);
    });

    testWidgets('RF tap opens radio stats as a popup, not a route', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RadioStatsIconButton(compact: true), connector: connector),
      );
      await tester.pump();

      await tester.tap(find.byType(RadioStatsIconButton));
      // No pumpAndSettle: the waiting-for-stats spinner animates forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MeshInfoDialog), findsOneWidget);
      expect(find.byType(RadioStatsPanel), findsOneWidget);
    });

    testWidgets('signal tap opens nearby repeaters as the info popup', (
      tester,
    ) async {
      connector.repeaters.add(
        DirectRepeater(pubkeyPrefix: [0xAB, 0x12], pathHashWidth: 2, snr: 8.0),
      );

      await tester.pumpWidget(
        _wrap(SNRIndicator(connector: connector), connector: connector),
      );
      await tester.pump();

      await tester.tap(find.byType(SNRIndicator));
      await tester.pumpAndSettle();

      expect(find.byType(MeshInfoDialog), findsOneWidget);
      expect(find.byType(NearbyRepeaterTile), findsOneWidget);
    });
  });

  group('AppBarTitle indicator row', () {
    testWidgets('separates every indicator with a vertical line', (
      tester,
    ) async {
      connector.repeaters.add(
        DirectRepeater(pubkeyPrefix: [0xAB, 0x12], pathHashWidth: 2, snr: 8.0),
      );
      connector.rssi = -58;

      await tester.pumpWidget(
        _wrap(const AppBarTitle('T'), connector: connector),
      );
      await tester.pump();

      // Four indicators (battery, signal, RF, transport): three lines
      // between them plus a trailing line before the actions menu.
      expect(
        find.byKey(const ValueKey('appBarIndicatorSeparator')),
        findsNWidgets(4),
      );
    });

    testWidgets('keeps all indicators visible on a narrow bar', (tester) async {
      connector.repeaters.add(
        DirectRepeater(pubkeyPrefix: [0xAB, 0x12], pathHashWidth: 2, snr: 8.0),
      );
      connector.rssi = -58;

      await tester.pumpWidget(
        _wrap(
          SizedBox(width: 320, child: AppBarTitle('Channels')),
          connector: connector,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.byIcon(Icons.wifi_tethering), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BatteryIndicator),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SNRIndicator),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
    });
  });
}
