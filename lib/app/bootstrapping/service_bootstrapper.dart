import 'package:breakmate/app/dependency_injection.dart';
import 'dart:async';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/core/services/daily_reset_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/weekly_digest_service.dart';
import 'package:breakmate/features/analytics/focus_insight_service.dart';
import 'package:breakmate/features/analytics/daily_insight_notifier_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/errors/error_handler.dart';

/// Decoupling initialization from GetIt registration prevents circular dependency
class ServiceBootstrapper {
  static Future<void> bootstrap() async {
    final storage = sl<StorageService>();
    await storage.init();

    if (!storage.isReady) {
      throw AppException(
        type: AppErrorType.storage,
        message: 'Storage initialization failed',
      );
    }

    sl<SessionStateRepository>().initialize();
    sl<CustomEnvironmentRepository>().loadSync();

    final settingsRepo = sl<SettingsRepository>();
    await settingsRepo.load();

    final notifications = sl<NotificationService>();
    final displayManager = sl<DisplayManager>();

    // Parallelize initialization of independent I/O services to optimize startup time.
    await Future.wait([notifications.init(), displayManager.initialize()]);

    notifications.setNotificationsEnabled(
      settingsRepo.currentSettings.notificationsEnabled,
    );
    notifications.setSoundEnabled(settingsRepo.currentSettings.soundEnabled);

    await sl<StatsService>().initialize();

    // Analytics and insight trackers are not needed for the first frame.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () {
        try {
          sl<AppUsageTracker>().start();
          sl<WeeklyDigestService>().start();
          sl<FocusInsightService>().start();
          sl<FocusStreakService>().start();
          sl<DailyInsightNotifierService>().start();
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      }),
    );

    final petRegistry = sl<PetRegistryService>();
    unawaited(petRegistry.discoverFromLegacyAssets());

    final trayManager = sl<TrayManagerService>();
    final companionOverlayController = sl<CompanionOverlayController>();

    await Future.wait([trayManager.init(), companionOverlayController.init()]);

    sl<TimerOrchestrator>().initialize();
    sl<DailyResetService>().start();
    sl<BreakController>().initialize();

    // Pre-cache tray animation frames on startup to avoid frame drops on macOS Menubar updates.
    try {
      final theme = PetTheme.getTheme(
        settingsRepo.currentSettings.companionPetTheme,
      );
      PetAssetLoader.preCacheTrayIcons(theme);
      unawaited(PetAssetLoader.preCacheBackgrounds());
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }
}
