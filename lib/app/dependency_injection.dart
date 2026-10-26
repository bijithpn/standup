import 'package:get_it/get_it.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/focus_filter_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/core/services/daily_reset_service.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/calendar_repository.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_event_service.dart';
import 'package:breakmate/core/services/window_service.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/wellness/domain/wellness_engine.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/weekly_digest_service.dart';
import 'package:breakmate/features/analytics/focus_insight_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/analytics/daily_insight_notifier_service.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/display/services/overlay_fit_service.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/global_hotkey_service.dart';
import 'package:breakmate/core/native/explain_hotkey_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/native/focus_mode_service.dart';
import 'package:breakmate/features/break_system/application/strict_mode_controller.dart';
import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:breakmate/features/themes/application/theme_controller.dart';

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
  sl.registerSingleton<DisplayManager>(DisplayManager());
  sl.registerSingleton<OverlayFitService>(OverlayFitService());

  sl.registerSingleton<DisplayController>(DisplayController(sl(), sl()));

  sl.registerLazySingleton<AppTrackingService>(() => AppTrackingService());

  sl.registerSingleton<WellnessEngine>(
    WellnessEngine(appTracking: sl<AppTrackingService>()),
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
  sl.registerLazySingleton<CalendarSyncController>(
    () => CalendarSyncController(
      settingsRepository: sl(),
      permissionService: sl(),
      calendarService: sl(),
    ),
  );
  sl.registerSingleton<AppUsageService>(AppUsageService(storage: sl()));
  sl.registerSingleton<FocusSessionService>(FocusSessionService(storage: sl()));
  sl.registerSingleton<BreakHistoryService>(BreakHistoryService(storage: sl()));
  sl.registerSingleton<ContextSwitchTracker>(ContextSwitchTracker());
  sl.registerLazySingleton<AppIconCache>(() => AppIconCache(appTracking: sl()));
  sl.registerSingleton<ActivitySegmentRepository>(
    ActivitySegmentRepository(storage: sl()),
  );
  sl.registerSingleton<ProductivityRepository>(
    ProductivityRepository(segments: sl<ActivitySegmentRepository>()),
  );
  sl.registerSingleton<AppUsageTracker>(
    AppUsageTracker(
      appTracking: sl(),
      usageService: sl(),
      settingsRepo: sl(),
      activityMonitor: sl(),
      focusSessionService: sl(),
      contextSwitchTracker: sl(),
      segmentRepository: sl(),
      eventBus: sl(),
    ),
  );
  sl.registerSingleton<CompanionStreakService>(
    CompanionStreakService(statsService: sl(), storage: sl(), eventBus: sl()),
  );
  sl.registerSingleton<WeeklyDigestService>(
    WeeklyDigestService(
      storage: sl(),
      statsService: sl(),
      focusSessionService: sl(),
      streakService: sl(),
      notificationService: sl(),
      usageService: sl(),
      settingsRepository: sl(),
    ),
  );
  sl.registerSingleton<FocusInsightService>(
    FocusInsightService(
      storage: sl(),
      breakHistoryService: sl(),
      focusSessionService: sl(),
      notificationService: sl(),
    ),
  );
  sl.registerSingleton<FocusStreakService>(
    FocusStreakService(
      focusSessionService: sl(),
      usageService: sl(),
      storage: sl(),
      eventBus: sl(),
    ),
  );
  sl.registerSingleton<DailyInsightNotifierService>(
    DailyInsightNotifierService(
      storage: sl(),
      usageService: sl(),
      focusSessionService: sl(),
      breakHistoryService: sl(),
      streakService: sl(),
      settingsRepository: sl(),
      notificationService: sl(),
    ),
  );
  sl.registerSingleton<PresentationDetectionService>(
    PresentationDetectionService(),
  );
  sl.registerSingleton<MeetingDetectionService>(MeetingDetectionService());
  sl.registerSingleton<TimerEngine>(
    TimerEngine(
      settingsRepository: sl(),
      smartDetectionService: sl(),
      calendarService: sl(),
      presentationDetectionService: sl(),
      meetingDetectionService: sl(),
      contextSwitchTracker: sl(),
      eventBus: sl(),
    ),
  );

  sl.registerSingleton<PetRegistryService>(PetRegistryService());
  sl.registerSingleton<CustomEnvironmentRepository>(
    CustomEnvironmentRepository(),
  );
  sl.registerSingleton<CompanionOverlayController>(
    CompanionOverlayController(settingsRepo: sl()),
  );
  sl.registerSingleton<BreakController>(
    BreakController(timerEngine: sl(), settingsRepo: sl(), statsService: sl()),
  );
  sl.registerSingleton<MenuBarController>(
    MenuBarController(eventBus: sl(), breakController: sl()),
  );
  sl.registerSingleton<TrayManagerService>(
    TrayManagerService(
      timerEngine: sl(),
      breakController: sl(),
      menuBarController: sl(),
      settingsRepository: sl(),
    ),
  );

  sl.registerSingleton<TimerRepository>(TimerRepository(sl()));

  sl.registerSingleton<TimerOrchestrator>(
    TimerOrchestrator(
      timerEngine: sl(),
      timerRepository: sl(),
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

  sl.registerSingleton<DailyResetService>(
    DailyResetService(
      storage: sl(),
      timerEngine: sl(),
      statsService: sl(),
      sessionStateRepository: sl(),
    ),
  );

  sl.registerSingleton<GlobalHotkeyService>(GlobalHotkeyService());
  sl.registerSingleton<ExplainHotkeyService>(ExplainHotkeyService());

  sl.registerSingleton<FocusModeService>(FocusModeService());
  sl.registerSingleton<FocusFilterService>(
    FocusFilterService(focusModeService: sl(), smartDetection: sl()),
  );
  sl.registerSingleton<StrictModeController>(StrictModeController(sl(), sl()));

  sl.registerSingleton<CompanionStateManager>(
    CompanionStateManager(eventBus: sl()),
  );
  sl.registerSingleton<ThemeController>(ThemeController(storage: sl()));
}
