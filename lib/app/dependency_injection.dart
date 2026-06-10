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

final sl = GetIt.instance;

Future<void> initDependencies() async {
  sl.registerSingleton<EventBus>(EventBus.instance);
  sl.registerSingleton<StorageService>(StorageService());
  sl.registerSingleton<SessionStateRepository>(SessionStateRepository(sl()));
  sl.registerSingleton<SettingsRepository>(SettingsRepository(storage: sl()));
  sl.registerSingleton<NotificationService>(NotificationService());
  sl.registerSingleton<ActivityMonitor>(ActivityMonitor());
  sl.registerSingleton<AppNavigationService>(AppNavigationService(sl()));
  sl.registerSingleton<WindowService>(WindowService.instance);
  sl.registerSingleton<OverlayWindowService>(OverlayWindowService());
  sl.registerSingleton<SystemMediaService>(SystemMediaService());
  sl.registerSingleton<DisplayManager>(DisplayManager());
  sl.registerSingleton<OverlayFitService>(OverlayFitService());

  sl.registerSingleton<DisplayController>(DisplayController(sl(), sl()));

  sl.registerSingleton<WellnessEngine>(
    WellnessEngine(appTracking: AppTrackingService()),
  );
  sl.registerSingleton<AdaptiveBreakService>(
    AdaptiveBreakService(storage: sl(), wellnessEngine: sl()),
  );
  sl.registerSingleton<SmartDetectionService>(SmartDetectionService());

  sl.registerSingleton<CalendarRepository>(CalendarRepository());
  sl.registerSingleton<CalendarPermissionService>(CalendarPermissionService());
  sl.registerSingleton<CalendarEventService>(CalendarEventService(sl()));
  sl.registerSingleton<CalendarService>(
    CalendarService(permissionService: sl(), eventService: sl()),
  );

  sl.registerSingleton<StatsService>(StatsService(storage: sl()));
  sl.registerSingleton<TimerEngine>(
    TimerEngine(
      settingsRepository: sl(),
      smartDetectionService: sl(),
      calendarService: sl(),
      eventBus: sl(),
    ),
  );

  sl.registerSingleton<PetRegistryService>(PetRegistryService());
  sl.registerSingleton<CompanionOverlayController>(
    CompanionOverlayController(settingsRepo: sl()),
  );
  sl.registerSingleton<TrayManagerService>(TrayManagerService());

  sl.registerSingleton<TimerOrchestrator>(
    TimerOrchestrator(
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
    ),
  );

  sl.registerSingleton<MeetingDetectionService>(MeetingDetectionService());
  sl.registerLazySingleton<AppTrackingService>(() => AppTrackingService());
  sl.registerLazySingleton<WellnessLibraryRepository>(
    () => WellnessLibraryRepository(settingsRepo: sl()),
  );

  sl.registerSingleton<FocusModeService>(FocusModeService());
  sl.registerSingleton<StrictModeController>(StrictModeController(sl(), sl()));

  sl.registerSingleton<BreakController>(
    BreakController(timerEngine: sl(), settingsRepo: sl(), statsService: sl()),
  );
  sl.registerSingleton<MenuBarController>(MenuBarController());

  sl.registerSingleton<CompanionStateManager>(
    CompanionStateManager(eventBus: sl()),
  );
  sl.registerSingleton<CompanionWindowController>(CompanionWindowController());
}
