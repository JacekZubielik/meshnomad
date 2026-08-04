import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/main.dart';
import 'package:meshcore_open/services/app_debug_log_service.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/services/ble_debug_log_service.dart';
import 'package:meshcore_open/services/chat_text_scale_service.dart';
import 'package:meshcore_open/services/map_tile_cache_service.dart';
import 'package:meshcore_open/services/message_retry_service.dart';
import 'package:meshcore_open/services/path_history_service.dart';
import 'package:meshcore_open/services/storage_service.dart';
import 'package:meshcore_open/services/timeout_prediction_service.dart';
import 'package:meshcore_open/services/translation_service.dart';
import 'package:meshcore_open/services/ui_view_state_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Regression test for the MaterialApp.builder + SelectionArea + Overlay
  // bug (2026-08-04): WidgetsApp.builder inserts widgets ABOVE the
  // Navigator, so wrapping `child` (the Navigator) directly in
  // SelectionArea leaves SelectionArea with no Overlay ancestor —
  // `assert(debugCheckHasOverlay(context))` in SelectableRegion.build()
  // throws "No Overlay widget found." The fix wraps SelectionArea in a
  // self-hosted Overlay inside the builder.
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
