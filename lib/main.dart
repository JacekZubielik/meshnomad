import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/chrome_required_screen.dart';
import 'screens/hub_screen.dart';
import 'utils/platform_info.dart';
import 'widgets/winda_host_overlay.dart';

import 'connector/meshcore_connector.dart';
import 'services/storage_service.dart';
import 'services/message_retry_service.dart';
import 'services/path_history_service.dart';
import 'services/app_settings_service.dart';
import 'services/notification_service.dart';
import 'services/ble_debug_log_service.dart';
import 'services/app_debug_log_service.dart';
import 'services/background_service.dart';
import 'services/map_tile_cache_service.dart';
import 'services/chat_text_scale_service.dart';
import 'services/translation_service.dart';
import 'services/ui_view_state_service.dart';
import 'services/timeout_prediction_service.dart';
import 'services/packet_observation_service.dart';
import 'services/winda_host_controller.dart';
import 'storage/prefs_manager.dart';
import 'theme/style.dart';
import 'theme/styles/custom_style.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized(autoEnableIndicators: false);
  }

  // On desktop, debugPrint is not suppressed in release builds and every
  // call is a synchronous stdout write. The connector logs heavily on hot
  // paths (frame handling, queue/channel sync), which shows up as syscall
  // overhead on low-end Linux machines (issue #202). The in-app debug log
  // screens are unaffected — they store entries themselves.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Initialize SharedPreferences cache
  await PrefsManager.initialize();

  // Initialize services
  final storage = StorageService();
  final connector = MeshCoreConnector();
  final pathHistoryService = PathHistoryService(storage);
  final retryService = MessageRetryService();
  final appSettingsService = AppSettingsService();
  final bleDebugLogService = BleDebugLogService();
  final appDebugLogService = AppDebugLogService();
  final backgroundService = BackgroundService();
  final mapTileCacheService = MapTileCacheService(
    appSettingsService: appSettingsService,
  );
  final chatTextScaleService = ChatTextScaleService();
  final translationService = TranslationService(appSettingsService);
  final uiViewStateService = UiViewStateService();
  final timeoutPredictionService = TimeoutPredictionService(storage);
  final packetObservationService = PacketObservationService();
  final windaHostController = WindaHostController();
  final windaMenuRouteObserver = WindaMenuRouteObserver(windaHostController);

  // Load settings
  await appSettingsService.loadSettings();

  // Initialize app logger
  appLogger.initialize(
    appDebugLogService,
    enabled: appSettingsService.settings.appDebugLogEnabled,
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await backgroundService.initialize();
  backgroundService.setLanguageOverrideProvider(
    () => appSettingsService.settings.languageOverride,
  );
  _registerThirdPartyLicenses();

  await chatTextScaleService.initialize();
  await translationService.refreshDownloadedModels();
  await uiViewStateService.initialize();
  await timeoutPredictionService.initialize();

  // Wire up connector with services
  connector.initialize(
    retryService: retryService,
    pathHistoryService: pathHistoryService,
    appSettingsService: appSettingsService,
    translationService: translationService,
    bleDebugLogService: bleDebugLogService,
    appDebugLogService: appDebugLogService,
    backgroundService: backgroundService,
    timeoutPredictionService: timeoutPredictionService,
    packetObservationService: packetObservationService,
  );

  await connector.loadContactCache();
  await connector.loadChannelSettings();
  await connector.loadCachedChannels();

  // Load persisted channel messages
  await connector.loadAllChannelMessages();
  await connector.loadUnreadState();

  runApp(
    MeshCoreApp(
      connector: connector,
      retryService: retryService,
      pathHistoryService: pathHistoryService,
      storage: storage,
      appSettingsService: appSettingsService,
      bleDebugLogService: bleDebugLogService,
      appDebugLogService: appDebugLogService,
      mapTileCacheService: mapTileCacheService,
      chatTextScaleService: chatTextScaleService,
      translationService: translationService,
      uiViewStateService: uiViewStateService,
      timeoutPredictionService: timeoutPredictionService,
      packetObservationService: packetObservationService,
      windaHostController: windaHostController,
      windaMenuRouteObserver: windaMenuRouteObserver,
    ),
  );
}

void _registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['Open-Meteo Elevation API Data'],
      '''
Data used by LOS elevation lookups is provided by Open-Meteo.

Open-Meteo terms and attribution:
https://open-meteo.com/en/terms

Elevation API:
https://open-meteo.com/en/docs/elevation-api

Attribution license reference:
Creative Commons Attribution 4.0 International (CC BY 4.0)
https://creativecommons.org/licenses/by/4.0/
''',
    );
  });
}

class MeshCoreApp extends StatelessWidget {
  final MeshCoreConnector connector;
  final MessageRetryService retryService;
  final PathHistoryService pathHistoryService;
  final StorageService storage;
  final AppSettingsService appSettingsService;
  final BleDebugLogService bleDebugLogService;
  final AppDebugLogService appDebugLogService;
  final MapTileCacheService mapTileCacheService;
  final ChatTextScaleService chatTextScaleService;
  final TranslationService translationService;
  final UiViewStateService uiViewStateService;
  final TimeoutPredictionService timeoutPredictionService;
  final PacketObservationService packetObservationService;
  final WindaHostController windaHostController;
  final WindaMenuRouteObserver windaMenuRouteObserver;

  const MeshCoreApp({
    super.key,
    required this.connector,
    required this.retryService,
    required this.pathHistoryService,
    required this.storage,
    required this.appSettingsService,
    required this.bleDebugLogService,
    required this.appDebugLogService,
    required this.mapTileCacheService,
    required this.chatTextScaleService,
    required this.translationService,
    required this.uiViewStateService,
    required this.timeoutPredictionService,
    required this.packetObservationService,
    required this.windaHostController,
    required this.windaMenuRouteObserver,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connector),
        ChangeNotifierProvider.value(value: retryService),
        ChangeNotifierProvider.value(value: pathHistoryService),
        ChangeNotifierProvider.value(value: appSettingsService),
        ChangeNotifierProvider.value(value: bleDebugLogService),
        ChangeNotifierProvider.value(value: appDebugLogService),
        ChangeNotifierProvider.value(value: chatTextScaleService),
        ChangeNotifierProvider.value(value: translationService),
        ChangeNotifierProvider.value(value: uiViewStateService),
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: mapTileCacheService),
        ChangeNotifierProvider.value(value: timeoutPredictionService),
        ChangeNotifierProvider.value(value: packetObservationService),
        ChangeNotifierProvider.value(value: windaHostController),
      ],
      child: Consumer<AppSettingsService>(
        builder: (context, settingsService, child) {
          return MaterialApp(
            title: 'MeshCore Open',
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _localeFromSetting(
              settingsService.settings.languageOverride,
            ),
            theme: _activeStyle(settingsService).theme,
            navigatorObservers: [windaRouteObserver, windaMenuRouteObserver],
            builder: (context, child) {
              // Update notification service with resolved locale
              final locale = Localizations.localeOf(context);
              NotificationService().setLocale(locale);
              // Text selection (07-selection-bugs.md) is scoped per-screen
              // now (each screen wraps its own body in SelectionArea) rather
              // than globally here above the Navigator — a single app-wide
              // SelectionArea's "select all" swept up text from OTHER,
              // offstage routes still mounted via MaterialPageRoute's
              // default maintainState:true (confirmed 2026-08-05: known-
              // issues pkt 2/6). Per-screen SelectionArea also sits INSIDE
              // the Navigator, so it reaches the Navigator's own Overlay
              // ancestor naturally — no self-hosted Overlay workaround
              // needed here anymore (see commit 80b358a for the old issue).
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: _systemUiOverlayStyle(context),
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    const WindaHostOverlay(),
                  ],
                ),
              );
            },
            home: (PlatformInfo.isWeb && !PlatformInfo.isChrome)
                ? const ChromeRequiredScreen()
                : const HubScreen(),
          );
        },
      ),
    );
  }

  MeshStyle _activeStyle(AppSettingsService settingsService) {
    return buildCustomStyle(settingsService.activeProfileOverrides);
  }

  SystemUiOverlayStyle _systemUiOverlayStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;

    // Keep Android system bars aligned with the resolved Flutter theme.
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colorScheme.surface,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: colorScheme.surface,
      systemNavigationBarContrastEnforced: false,
    );
  }

  Locale? _localeFromSetting(String? languageCode) {
    if (languageCode == null) return null;
    return Locale(languageCode);
  }
}
