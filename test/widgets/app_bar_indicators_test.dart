import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/models/companion_radio_stats.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/styles/style_registry.dart';
import 'package:meshcore_open/widgets/app_bar.dart';
import 'package:meshcore_open/widgets/battery_indicator.dart';
import 'package:meshcore_open/widgets/radio_stats_entry.dart';
import 'package:meshcore_open/widgets/snr_indicator.dart';

class _FakeConnector extends MeshCoreConnector {
  final List<DirectRepeater> repeaters = [];

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
  void acquireRadioStatsPolling() {}

  @override
  void releaseRadioStatsPolling() {}
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
  return ChangeNotifierProvider<MeshCoreConnector>.value(
    value: connector,
    child: MaterialApp(
      theme: StyleRegistry.byId('default').light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
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

    expect(find.text('-98 dBm'), findsOneWidget);
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
}
