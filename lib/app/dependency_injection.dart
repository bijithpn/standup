import 'package:get_it/get_it.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/smart_detection_service.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/core/native/meeting_detection_service.dart';
import 'package:standup/core/native/focus_mode_service.dart';
import 'package:standup/features/break_system/application/strict_mode_controller.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core Services
  final storage = StorageService();
  await storage.init();
  sl.registerSingleton<StorageService>(storage);

  final notifications = NotificationService();
  await notifications.init();
  sl.registerSingleton<NotificationService>(notifications);

  final activityMonitor = ActivityMonitor();
  sl.registerSingleton<ActivityMonitor>(activityMonitor);

  sl.registerSingleton<AppNavigationService>(AppNavigationService());

  // Overlay Window Service for system-wide displays
  final overlayService = OverlayWindowService();
  sl.registerSingleton<OverlayWindowService>(overlayService);

  // Adaptive Break Service for smart timing
  final adaptiveBreakService = AdaptiveBreakService(storage: storage);
  sl.registerSingleton<AdaptiveBreakService>(adaptiveBreakService);

  // Feature Services
  final settingsRepo = SettingsRepository(storage: sl());
  settingsRepo.load();
  sl.registerSingleton<SettingsRepository>(settingsRepo);

  notifications.setNotificationsEnabled(settingsRepo.currentSettings.notificationsEnabled);
  notifications.setSoundEnabled(settingsRepo.currentSettings.soundEnabled);

  final smartDetectionService = SmartDetectionService();
  smartDetectionService.start();
  sl.registerSingleton<SmartDetectionService>(smartDetectionService);

  final statsService = StatsService(storage: sl());
  sl.registerSingleton<StatsService>(statsService);

  final timerEngine = TimerEngine(
    activityMonitor: sl(),
    notificationService: sl(),
    adaptiveBreakService: sl(),
    settingsRepository: sl(),
    smartDetectionService: sl(),
  );
  sl.registerSingleton<TimerEngine>(timerEngine);

  final trayManager = TrayManagerService();
  await trayManager.init();
  sl.registerSingleton<TrayManagerService>(trayManager);

  // Application Controllers
  final meetingDetectionService = MeetingDetectionService();
  sl.registerSingleton<MeetingDetectionService>(meetingDetectionService);

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

}
