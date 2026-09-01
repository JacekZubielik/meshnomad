import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/main.dart';
import 'package:meshnomad/services/app_debug_log_service.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/ble_debug_log_service.dart';
import 'package:meshnomad/services/chat_text_scale_service.dart';
import 'package:meshnomad/services/map_tile_cache_service.dart';
import 'package:meshnomad/services/message_retry_service.dart';
import 'package:meshnomad/services/packet_observation_service.dart';
import 'package:meshnomad/services/path_history_service.dart';
import 'package:meshnomad/services/storage_service.dart';
import 'package:meshnomad/services/timeout_prediction_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/services/ui_view_state_service.dart';
import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/storage/prefs_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Regression test for MeshCoreApp's top-level build. Originally guarded
  // the MaterialApp.builder + SelectionArea + Overlay bug (2026-08-04):
  // WidgetsApp.builder inserts widgets ABOVE the Navigator, so wrapping
  // `child` (the Navigator) directly in SelectionArea left it with no
  // Overlay ancestor ("No Overlay widget found"). Fixed by moving
  // SelectionArea to be per-screen instead of global (07-selection-bugs.md,
  // 2026-08-05) — each screen's SelectionArea now sits inside the
  // Navigator, reaching its Overlay naturally, so builder no longer needs
  // a self-hosted Overlay at all. Kept as a general smoke test.
  testWidgets(
    'MeshCoreApp builds without a FlutterError (SelectionArea/Overlay)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PrefsManager.reset();
      await PrefsManager.initialize();

      final storage = StorageService();
      final settingsService = AppSettingsService();
      await settingsService.loadSettings();
      final connector = MeshCoreConnector();
      final retryService = MessageRetryService();
      final pathHistoryService = PathHistoryService(storage);
      final bleDebugLogService = BleDebugLogService();
      final appDebugLogService = AppDebugLogService();
      final mapTileCacheService = MapTileCacheService(
        appSettingsService: settingsService,
      );
      final chatTextScaleService = ChatTextScaleService();
      final translationService = TranslationService(settingsService);
      final uiViewStateService = UiViewStateService();
      final timeoutPredictionService = TimeoutPredictionService(storage);
      final packetObservationService = PacketObservationService();
      final windaHostController = WindaHostController();
      addTearDown(connector.dispose);
      addTearDown(retryService.dispose);
      addTearDown(pathHistoryService.dispose);
      addTearDown(bleDebugLogService.dispose);
      addTearDown(appDebugLogService.dispose);
      addTearDown(mapTileCacheService.dispose);
      addTearDown(chatTextScaleService.dispose);
      addTearDown(translationService.dispose);
      addTearDown(uiViewStateService.dispose);
      addTearDown(timeoutPredictionService.dispose);

      await tester.pumpWidget(
        MeshCoreApp(
          connector: connector,
          retryService: retryService,
          pathHistoryService: pathHistoryService,
          storage: storage,
          appSettingsService: settingsService,
          bleDebugLogService: bleDebugLogService,
          appDebugLogService: appDebugLogService,
          mapTileCacheService: mapTileCacheService,
          chatTextScaleService: chatTextScaleService,
          translationService: translationService,
          uiViewStateService: uiViewStateService,
          timeoutPredictionService: timeoutPredictionService,
          packetObservationService: packetObservationService,
          windaHostController: windaHostController,
        ),
      );
      // Not pumpAndSettle(): the app legitimately runs indefinite timers
      // (e.g. BLE scan retry/polling), which would never let pumpAndSettle
      // return. A few explicit frames are enough for the initial build (and
      // the SelectionArea/Overlay regression, if present) to surface.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
