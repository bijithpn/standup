import 'package:get_it/get_it.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/flash_overlay/flash_overlay_service.dart';

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

  final statsService = StatsService(storage: sl());
  sl.registerSingleton<StatsService>(statsService);

  final timerEngine = TimerEngine(
    activityMonitor: sl(),
    notificationService: sl(),
    adaptiveBreakService: sl(),
    settingsRepository: sl(),
  );
  sl.registerSingleton<TimerEngine>(timerEngine);

  final trayManager = TrayManagerService();
  await trayManager.init();
  sl.registerSingleton<TrayManagerService>(trayManager);

  // Application Controllers
  final breakController = BreakController(
    timerEngine: sl(),
    settingsRepo: sl(),
    statsService: sl(),
  );
  breakController.initialize();
  sl.registerSingleton<BreakController>(breakController);

  final flashOverlayService = FlashOverlayService();
  sl.registerSingleton<FlashOverlayService>(flashOverlayService);
}
