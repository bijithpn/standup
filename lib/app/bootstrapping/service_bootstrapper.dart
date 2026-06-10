import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:breakmate/app/dependency_injection.dart';

/// Orchestrates the asynchronous initialization sequence of all core services.
/// Decoupling initialization from GetIt registration prevents circular dependency
/// deadlocks and ensures I/O bound setups are run in the correct sequence.
class ServiceBootstrapper {
  static final _logger = AppLogger();

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

    final settingsRepo = sl<SettingsRepository>();
    await settingsRepo.load();

    final notifications = sl<NotificationService>();
    final displayManager = sl<DisplayManager>();

    // Parallelize initialization of independent I/O services to optimize startup time.
    await Future.wait([
      notifications.init(),
      displayManager.initialize(),
    ]);

    notifications.setNotificationsEnabled(
      settingsRepo.currentSettings.notificationsEnabled,
    );
    notifications.setSoundEnabled(settingsRepo.currentSettings.soundEnabled);

    await sl<StatsService>().initialize();

    final petRegistry = sl<PetRegistryService>();
    unawaited(petRegistry.discoverFromLegacyAssets());

    final trayManager = sl<TrayManagerService>();
    final companionOverlayController = sl<CompanionOverlayController>();

    await Future.wait([
      trayManager.init(),
      companionOverlayController.init(),
    ]);

    sl<TimerOrchestrator>().initialize();
    sl<BreakController>().initialize();

    trayManager.setDependencies(sl<TimerEngine>(), sl());
    trayManager.setMenuBarController(sl());

    sl<MenuBarController>().setDependencies(sl());

    // Pre-cache tray animation frames on startup to avoid frame drops on macOS Menubar updates.
    try {
      final theme = PetTheme.getTheme(
        settingsRepo.currentSettings.companionPetTheme,
      );
      PetAssetLoader.preCacheTrayIcons(theme);
    } catch (e) {
      _logger.error('Failed to pre-cache tray icons: $e');
    }
  }
}
