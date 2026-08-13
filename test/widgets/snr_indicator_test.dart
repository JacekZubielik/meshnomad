import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/screens/map_screen.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/widgets/snr_indicator.dart';

class _FakeConnector extends MeshCoreConnector {
  final List<DirectRepeater> repeaters = [];

  @override
  List<DirectRepeater> get directRepeaters => repeaters;
}

class _CapturingObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
  }
}

DirectRepeater _repeater() =>
    DirectRepeater(pubkeyPrefix: [0xAB, 0x12], pathHashWidth: 2, snr: 8.0);

Contact _contact({double? latitude, double? longitude}) {
  final publicKey = Uint8List(pubKeySize);
  publicKey[0] = 0xAB;
  publicKey[1] = 0x12;
  return Contact(
    publicKey: publicKey,
    name: 'GDA RPT',
    type: advTypeRepeater,
    pathLength: 0,
    path: Uint8List(0),
    latitude: latitude,
    longitude: longitude,
    lastSeen: DateTime.now(),
  );
}

Widget _wrap(
  Widget child, {
  GlobalKey<NavigatorState>? navigatorKey,
  NavigatorObserver? observer,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: [?observer],
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  group('SNRIndicator app bar layout', () {
    testWidgets('does not render the repeater prefix line under the icon', (
      tester,
    ) async {
      final connector = _FakeConnector();
      connector.repeaters.add(_repeater());
      addTearDown(connector.dispose);

      await tester.pumpWidget(_wrap(SNRIndicator(connector: connector)));
      await tester.pump();

      expect(find.textContaining('AB12'), findsNothing);
    });
  });

  group('NearbyRepeaterTile', () {
    testWidgets('shows the key prefix alongside the matched contact name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NearbyRepeaterTile(repeater: _repeater(), contact: _contact())),
      );
      await tester.pump();

      expect(find.text('GDA RPT'), findsOneWidget);
      expect(find.textContaining('AB12'), findsOneWidget);
    });

    testWidgets('shows coordinates and a map action for a located contact', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NearbyRepeaterTile(
            repeater: _repeater(),
            contact: _contact(latitude: 54.5, longitude: 18.5),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('54.50000, 18.50000'), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('hides coordinates and map action without a location', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NearbyRepeaterTile(repeater: _repeater(), contact: _contact())),
      );
      await tester.pump();

      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.textContaining(','), findsNothing);
    });

    testWidgets('map action pushes MapScreen centered on the repeater', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _CapturingObserver();

      await tester.pumpWidget(
        _wrap(
          NearbyRepeaterTile(
            repeater: _repeater(),
            contact: _contact(latitude: 54.5, longitude: 18.5),
          ),
          navigatorKey: navigatorKey,
          observer: observer,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.map_outlined));

      final route = observer.pushed;
      expect(route, isA<MaterialPageRoute<void>>());
      // Inspect the destination without mounting it — MapScreen needs
      // providers this harness intentionally does not supply.
      final destination = (route as MaterialPageRoute<void>).builder(
        navigatorKey.currentContext!,
      );
      expect(destination, isA<MapScreen>());
      final mapScreen = destination as MapScreen;
      expect(mapScreen.highlightPosition, const LatLng(54.5, 18.5));
      expect(mapScreen.highlightLabel, 'GDA RPT');

      // Remove the route before the next frame so the unmountable MapScreen
      // never actually builds.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    });
  });
}
