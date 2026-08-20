import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/models/companion_core_stats.dart';
import 'package:meshnomad/models/companion_packet_stats.dart';
import 'package:meshnomad/models/companion_radio_stats.dart';
import 'package:meshnomad/screens/companion_radio_stats_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/radio_stats_band_chart.dart';

class _FakeConnector extends MeshCoreConnector {
  int txWindowUsed = 142;

  @override
  bool get isConnected => true;

  @override
  bool get supportsCompanionRadioStats => true;

  @override
  bool get radioStatsAirActivityPulse => false;

  @override
  int get txAirUsedLastHourSecs => txWindowUsed;

  @override
  void acquireRadioStatsPolling() {}

  @override
  void releaseRadioStatsPolling() {}

  @override
  void setPollingInterval(int seconds) {}
}

CompanionRadioStats _stats({
  int noiseFloorDbm = -98,
  int lastRssiDbm = -80,
  double lastSnrDb = 5.0,
  int txAirSecs = 1842,
  int rxAirSecs = 96,
  required DateTime receivedAt,
}) => CompanionRadioStats(
  noiseFloorDbm: noiseFloorDbm,
  lastRssiDbm: lastRssiDbm,
  lastSnrDb: lastSnrDb,
  txAirSecs: txAirSecs,
  rxAirSecs: rxAirSecs,
  receivedAt: receivedAt,
);

Widget _wrap(
  Widget child, {
  required MeshCoreConnector connector,
  required AppSettingsService settings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
      ChangeNotifierProvider<AppSettingsService>.value(value: settings),
    ],
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnector connector;
  late AppSettingsService settingsService;
  final t0 = DateTime(2026, 8, 6, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    connector = _FakeConnector();
    addTearDown(connector.dispose);
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
  });

  Future<void> pushStats(
    WidgetTester tester,
    List<CompanionRadioStats> all,
  ) async {
    for (final s in all) {
      connector.radioStatsNotifier.value = s;
      await tester.pump();
    }
  }

  testWidgets('buffers noise, RSSI and SNR history and renders both charts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const RadioStatsPanel(),
        connector: connector,
        settings: settingsService,
      ),
    );
    await pushStats(tester, [
      _stats(
        noiseFloorDbm: -98,
        lastRssiDbm: -80,
        lastSnrDb: 5,
        receivedAt: t0,
      ),
      _stats(
        noiseFloorDbm: -97,
        lastRssiDbm: -76,
        lastSnrDb: 8,
        receivedAt: t0.add(const Duration(seconds: 1)),
      ),
      _stats(
        noiseFloorDbm: -99,
        lastRssiDbm: -84,
        lastSnrDb: 3.5,
        receivedAt: t0.add(const Duration(seconds: 2)),
      ),
    ]);

    final band =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('radioStatsBandChart')),
                )
                .painter
            as RadioStatsBandChartPainter;
    expect(band.rssi, hasLength(3));
    expect(band.noise, hasLength(3));

    final strip =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('radioStatsSnrStrip')),
                )
                .painter
            as RadioStatsSnrStripPainter;
    expect(strip.snr, hasLength(3));

    // Legend names all three series.
    expect(find.text('RSSI'), findsOneWidget);
    expect(find.text('Noise'), findsOneWidget);
    expect(find.text('SNR'), findsOneWidget);
  });

  testWidgets('airtime card shows 1 h window usage vs duty-cycle limit', (
    tester,
  ) async {
    connector.txWindowUsed = 142;
    await tester.pumpWidget(
      _wrap(
        const RadioStatsPanel(),
        connector: connector,
        settings: settingsService,
      ),
    );
    await pushStats(tester, [
      _stats(txAirSecs: 1842, rxAirSecs: 96, receivedAt: t0),
    ]);

    expect(find.text('TX (1 h window): 142/360 s'), findsOneWidget);
    expect(find.text('39%'), findsOneWidget);
    expect(
      find.text('limit: duty cycle 10% (ETSI) · TX total: 1842 s'),
      findsOneWidget,
    );
    expect(find.text('RX airtime (total): 96 s'), findsOneWidget);
  });

  testWidgets('airtime budget follows the duty-cycle limit setting', (
    tester,
  ) async {
    await settingsService.setTxDutyCyclePercent(25);
    connector.txWindowUsed = 142;
    await tester.pumpWidget(
      _wrap(
        const RadioStatsPanel(),
        connector: connector,
        settings: settingsService,
      ),
    );
    await pushStats(tester, [
      _stats(txAirSecs: 1842, rxAirSecs: 96, receivedAt: t0),
    ]);

    expect(find.text('TX (1 h window): 142/900 s'), findsOneWidget);
    expect(find.text('16%'), findsOneWidget);
    expect(
      find.text('limit: duty cycle 25% (ETSI) · TX total: 1842 s'),
      findsOneWidget,
    );
  });

  testWidgets('horizontal drag over the band chart sets the crosshair', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const RadioStatsPanel(),
        connector: connector,
        settings: settingsService,
      ),
    );
    await pushStats(tester, [
      _stats(receivedAt: t0),
      _stats(receivedAt: t0.add(const Duration(seconds: 1))),
      _stats(receivedAt: t0.add(const Duration(seconds: 2))),
    ]);

    await tester.drag(
      find.byKey(const Key('radioStatsBandChart')),
      const Offset(40, 0),
    );
    await tester.pump();

    final band =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('radioStatsBandChart')),
                )
                .painter
            as RadioStatsBandChartPainter;
    expect(band.cursorIndex, isNotNull);

    final strip =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('radioStatsSnrStrip')),
                )
                .painter
            as RadioStatsSnrStripPainter;
    expect(strip.cursorIndex, band.cursorIndex);
  });

  testWidgets(
    'Device card shows battery, uptime, queue and decoded error flags',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadioStatsPanel(),
          connector: connector,
          settings: settingsService,
        ),
      );
      connector.coreStatsNotifier.value = CompanionCoreStats(
        batteryMillivolts: 4150,
        uptimeSecs: 90000,
        errFlags: 0x3, // queue full + CAD timeout, not RX-start timeout
        queueLen: 2,
        receivedAt: t0,
      );
      await tester.pump();

      expect(find.text('Battery: 4.15 V'), findsOneWidget);
      expect(find.text('Uptime: 90000 s'), findsOneWidget);
      expect(find.text('Queue Length: 2'), findsOneWidget);
      expect(
        find.text('Radio errors: queue full, CAD timeout'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Device card shows "no errors" when errFlags is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const RadioStatsPanel(),
        connector: connector,
        settings: settingsService,
      ),
    );
    connector.coreStatsNotifier.value = CompanionCoreStats(
      batteryMillivolts: 4150,
      uptimeSecs: 90000,
      errFlags: 0,
      queueLen: 0,
      receivedAt: t0,
    );
    await tester.pump();

    expect(find.text('No radio errors'), findsOneWidget);
  });

  testWidgets(
    'Traffic card shows totals, flood/direct breakdown and recv errors',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadioStatsPanel(),
          connector: connector,
          settings: settingsService,
        ),
      );
      connector.packetStatsNotifier.value = CompanionPacketStats(
        recv: 1000,
        sent: 900,
        sentFlood: 300,
        sentDirect: 600,
        recvFlood: 400,
        recvDirect: 600,
        recvErrors: 12,
        receivedAt: t0,
      );
      await tester.pump();

      expect(find.text('Total: 900, Flood: 300, Direct: 600'), findsOneWidget);
      expect(find.text('Total: 1000, Flood: 400, Direct: 600'), findsOneWidget);
      expect(find.text('Recv errors: 12'), findsOneWidget);
    },
  );
}
