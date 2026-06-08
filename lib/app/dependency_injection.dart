import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/calendar_repository.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_event_service.dart';
import 'package:breakmate/core/services/window_service.dart';
import 'package:breakmate/core/services/system_media_service.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/wellness/domain/wellness_engine.dart';
import 'package:breakmate/features/wellness/data/wellness_library_repository.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/display/services/overlay_fit_service.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/focus_mode_service.dart';
import 'package:breakmate/features/break_system/application/strict_mode_controller.dart';
import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/features/companion/services/companion_window_controller.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:breakmate/core/errors/app_exception.dart';

import 'package:breakmate/app/bootstrapper.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // EventBus coordinates cross-layer communication (IPC <-> Core <-> UI) without tight coupling.
  sl.registerSingleton<EventBus>(EventBus.instance);

  final storage = StorageService();
  await storage.init();

  if (!storage.isReady) {
    throw AppException(
      type: AppErrorType.storage,
      message: 'Storage initialization failed',
    );
  }

  sl.registerSingleton<StorageService>(storage);

  final sessionStateRepository = SessionStateRepository(storage);
  sessionStateRepository.initialize();
  sl.registerSingleton<SessionStateRepository>(sessionStateRepository);

  final settingsRepo = SettingsRepository(storage: storage);
  await settingsRepo.load();
  sl.registerSingleton<SettingsRepository>(settingsRepo);

  final notifications = NotificationService();
  final displayManager = DisplayManager();

  // Parallelize initialization of independent I/O services to optimize app startup time.
  await Future.wait([notifications.init(), displayManager.initialize()]);

  sl.registerSingleton<NotificationService>(notifications);

  final activityMonitor = ActivityMonitor();
  sl.registerSingleton<ActivityMonitor>(activityMonitor);

  sl.registerSingleton<AppNavigationService>(AppNavigationService(storage));

  sl.registerSingleton<WindowService>(WindowService.instance);

  final overlayService = OverlayWindowService();
  sl.registerSingleton<OverlayWindowService>(overlayService);

  sl.registerSingleton<SystemMediaService>(SystemMediaService());

  sl.registerSingleton<DisplayManager>(displayManager);

  sl.registerSingleton<OverlayFitService>(OverlayFitService());
  sl.registerSingleton<DisplayController>(
    DisplayController(displayManager, sl()),
  );

  final wellnessEngine = WellnessEngine(appTracking: AppTrackingService());
  sl.registerSingleton<WellnessEngine>(wellnessEngine);

  final adaptiveBreakService = AdaptiveBreakService(
    storage: storage,
    wellnessEngine: wellnessEngine,
  );
  sl.registerSingleton<AdaptiveBreakService>(adaptiveBreakService);

  notifications.setNotificationsEnabled(
    settingsRepo.currentSettings.notificationsEnabled,
  );
  notifications.setSoundEnabled(settingsRepo.currentSettings.soundEnabled);

  final smartDetectionService = SmartDetectionService();
  sl.registerSingleton<SmartDetectionService>(smartDetectionService);

  final calendarRepository = CalendarRepository();
  sl.registerSingleton<CalendarRepository>(calendarRepository);

  final calendarPermissionService = CalendarPermissionService();
  sl.registerSingleton<CalendarPermissionService>(calendarPermissionService);

  final calendarEventService = CalendarEventService(calendarRepository);
  sl.registerSingleton<CalendarEventService>(calendarEventService);

  final calendarService = CalendarService(
    permissionService: calendarPermissionService,
    eventService: calendarEventService,
  );
  sl.registerSingleton<CalendarService>(calendarService);

  final statsService = StatsService(storage: sl());
  await statsService.initialize();
  sl.registerSingleton<StatsService>(statsService);

  final timerEngine = TimerEngine(
    settingsRepository: sl(),
    smartDetectionService: sl(),
    calendarService: sl(),
    eventBus: sl(),
  );
  sl.registerSingleton<TimerEngine>(timerEngine);

  final trayManager = TrayManagerService();

  // Parallelize tray initialization and companion rendering engine to minimize desktop spawn delay.
  final petRegistry = PetRegistryService();
  sl.registerSingleton<PetRegistryService>(petRegistry);
  unawaited(petRegistry.discoverFromLegacyAssets());

  final companionOverlayController = CompanionOverlayController(
    settingsRepo: sl(),
  );

  await Future.wait([trayManager.init(), companionOverlayController.init()]);

  sl.registerSingleton<TrayManagerService>(trayManager);

  // TimerOrchestrator acts as the primary state machine, driving persistence and native side effects.
  final timerOrchestrator = TimerOrchestrator(
    timerEngine: sl(),
    timerRepository: TimerRepository(sl()),
    sessionStateRepository: sl(),
    activityMonitor: sl(),
    notificationService: sl(),
    statsService: sl(),
    trayManagerService: sl(),
    adaptiveBreakService: sl(),
    settingsRepository: sl(),
    eventBus: sl(),
  );
  timerOrchestrator.initialize();
  sl.registerSingleton<TimerOrchestrator>(timerOrchestrator);

  final meetingDetectionService = MeetingDetectionService();
  sl.registerSingleton<MeetingDetectionService>(meetingDetectionService);

  sl.registerLazySingleton<AppTrackingService>(() => AppTrackingService());
  sl.registerLazySingleton<WellnessLibraryRepository>(
    () => WellnessLibraryRepository(settingsRepo: sl()),
  );

  final focusModeService = FocusModeService();
  sl.registerSingleton<FocusModeService>(focusModeService);

  final strictModeController = StrictModeController(
    meetingDetectionService,
    focusModeService,
  );
  sl.registerSingleton<StrictModeController>(strictModeController);

  final breakController = BreakController(
    timerEngine: sl(),
    settingsRepo: sl(),
    statsService: sl(),
  );
  breakController.initialize();
  sl.registerSingleton<BreakController>(breakController);

  sl.registerSingleton<MenuBarController>(MenuBarController());

  trayManager.setDependencies(timerEngine, sl());
  trayManager.setMenuBarController(sl());

  sl<MenuBarController>().setDependencies(sl());

  final companionStateManager = CompanionStateManager(eventBus: sl());
  companionStateManager.startListening();
  sl.registerSingleton<CompanionStateManager>(companionStateManager);

  final companionWindowController = CompanionWindowController();
  sl.registerSingleton<CompanionWindowController>(companionWindowController);

  sl.registerSingleton<CompanionOverlayController>(companionOverlayController);

  // Pre-cache tray animation frames directly into memory on startup to avoid frame drops on macOS Menubar updates.
  try {
    final theme = PetTheme.getTheme(
      settingsRepo.currentSettings.companionPetTheme,
    );
    PetAssetLoader.preCacheTrayIcons(theme);
  } catch (e) {
    debugPrint('Failed to pre-cache tray icons: $e');
  }

  // IPC Bridge: wire native macOS events to EventBus
  AppBootstrapper.initializeIpc();
}
