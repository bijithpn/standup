import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/window_service.dart';
import 'package:breakmate/core/services/system_media_service.dart';
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
import 'package:breakmate/features/companion/services/companion_behavior_engine.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Event Bus (singleton for cross-layer communication)
  sl.registerSingleton<EventBus>(EventBus.instance);

  // Core Services
  final storage = StorageService();
  final notifications = NotificationService();
  final displayManager = DisplayManager();

  // Parallelize independent initializations
  await Future.wait([
    storage.init(),
    notifications.init(),
    displayManager.initialize(),
  ]);

  sl.registerSingleton<StorageService>(storage);
  sl.registerSingleton<NotificationService>(notifications);

  final activityMonitor = ActivityMonitor();
  sl.registerSingleton<ActivityMonitor>(activityMonitor);

  sl.registerSingleton<AppNavigationService>(AppNavigationService(storage));

  // Window Service for native macOS window operations
  sl.registerSingleton<WindowService>(WindowService.instance);

  // Overlay Window Service for system-wide displays
  final overlayService = OverlayWindowService();
  sl.registerSingleton<OverlayWindowService>(overlayService);

  sl.registerSingleton<SystemMediaService>(SystemMediaService());

  // Display Management Services
  sl.registerSingleton<DisplayManager>(displayManager);

  sl.registerSingleton<OverlayFitService>(OverlayFitService());
  sl.registerSingleton<DisplayController>(
    DisplayController(displayManager, sl()),
  );

  // Adaptive Break Service for smart timing
  final adaptiveBreakService = AdaptiveBreakService(storage: storage);
  sl.registerSingleton<AdaptiveBreakService>(adaptiveBreakService);

  // Feature Services
  final settingsRepo = SettingsRepository(storage: sl());
  settingsRepo.load();
  sl.registerSingleton<SettingsRepository>(settingsRepo);

  notifications.setNotificationsEnabled(
    settingsRepo.currentSettings.notificationsEnabled,
  );
  notifications.setSoundEnabled(settingsRepo.currentSettings.soundEnabled);

  final smartDetectionService = SmartDetectionService();
  smartDetectionService.start();
  sl.registerSingleton<SmartDetectionService>(smartDetectionService);

  final statsService = StatsService(storage: sl());
  await statsService.initialize();
  sl.registerSingleton<StatsService>(statsService);

  // TimerEngine with EventBus integration
  final timerEngine = TimerEngine(
    activityMonitor: sl(),
    notificationService: sl(),
    settingsRepository: sl(),
    storageService: sl(),
    adaptiveBreakService: sl(),
    smartDetectionService: sl(),
    eventBus: sl(),
  );
  sl.registerSingleton<TimerEngine>(timerEngine);

  // Tray Manager Service (must be before BreakController)
  final trayManager = TrayManagerService();

  // Run tray manager init and companion controller init in parallel
  final petRegistry = PetRegistryService();
  sl.registerSingleton<PetRegistryService>(petRegistry);
  unawaited(petRegistry.discoverFromLegacyAssets());

  final companionOverlayController = CompanionOverlayController(
    settingsRepo: sl(),
  );

  await Future.wait([trayManager.init(), companionOverlayController.init()]);

  sl.registerSingleton<TrayManagerService>(trayManager);

  // Application Controllers
  final meetingDetectionService = MeetingDetectionService();
  sl.registerSingleton<MeetingDetectionService>(meetingDetectionService);

  // Listen for meeting events and broadcast via IPC to all isolates
  meetingDetectionService.isMeetingActiveStream.listen((isActive) {
    IpcBridge.instance.notifyMeetingDetected(isActive);
  });

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

  // Menu Bar Controller (centralized action routing)
  sl.registerSingleton<MenuBarController>(MenuBarController());

  // Wire tray menu with dependencies
  trayManager.setDependencies(timerEngine, sl());
  trayManager.setMenuBarController(sl());

  // Wire menu bar controller with break controller
  sl<MenuBarController>().setDependencies(sl());

  // Companion Services
  final companionStateManager = CompanionStateManager(eventBus: sl());
  companionStateManager.startListening();
  sl.registerSingleton<CompanionStateManager>(companionStateManager);

  // Companion Window Controller
  final companionWindowController = CompanionWindowController();
  sl.registerSingleton<CompanionWindowController>(companionWindowController);

  // Companion Behavior Engine
  final companionBehaviorEngine = CompanionBehaviorEngine(eventBus: sl());
  companionBehaviorEngine.setEnabled(
    settingsRepo.currentSettings.companionEnabled,
  );
  sl.registerSingleton<CompanionBehaviorEngine>(companionBehaviorEngine);

  // Companion Overlay Controller (for settings UI)
  sl.registerSingleton<CompanionOverlayController>(companionOverlayController);

  // Eagerly pre-cache tray icons for the current theme to ensure smooth animation
  try {
    final theme = PetTheme.getTheme(
      settingsRepo.currentSettings.companionPetTheme,
    );
    PetAssetLoader.preCacheTrayIcons(theme);
  } catch (e) {
    debugPrint('Failed to pre-cache tray icons: $e');
  }

  // IPC Bridge: wire native macOS events to EventBus
  _setupIpcBridge();
}

void _setupIpcBridge() {
  final ipc = IpcBridge.instance;
  final eventBus = sl<EventBus>();
  final timerEngine = sl<TimerEngine>();

  ipc.setEventHandler((event, data) {
    switch (event) {
      case IpcEventNames.timerStateChanged:
        final state = data['state'] as String?;
        final countdown = (data['countdownSeconds'] as num?)?.toInt() ?? 0;
        final elapsed = (data['workElapsedSeconds'] as num?)?.toInt() ?? 0;
        final targetEndMs = data['targetEndTime'] as int?;
        final targetEndTime = targetEndMs != null
            ? DateTime.fromMillisecondsSinceEpoch(targetEndMs)
            : null;
        final totalWorkTodaySecs = (data['totalWorkTodaySeconds'] as num?)
            ?.toInt();
        TimerStateEvent? timerState;
        switch (state) {
          case 'running':
            timerState = TimerStateEvent.running;
          case 'breakActive':
            timerState = TimerStateEvent.breakActive;
          case 'paused':
            timerState = TimerStateEvent.paused;
          case 'idle':
            timerState = TimerStateEvent.idle;
        }
        if (timerState != null) {
          eventBus.emit(
            TimerStateChangedEvent(
              state: timerState,
              countdownSeconds: countdown,
              workElapsedSeconds: elapsed,
              targetEndTime: targetEndTime,
              totalWorkTodaySeconds: totalWorkTodaySecs,
            ),
          );
        }
      case IpcEventNames.breakStarted:
        eventBus.emit(
          BreakStartedEvent(
            isLongBreak: data['isLongBreak'] as bool? ?? false,
            durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
            title: data['title'] as String? ?? 'Break',
          ),
        );
      case IpcEventNames.breakEnded:
        eventBus.emit(
          BreakEndedEvent(skipped: data['skipped'] as bool? ?? false),
        );
      case 'detection.meeting':
        eventBus.emit(
          MeetingDetectedEvent(
            isActive: data['isActive'] as bool? ?? false,
            bundleId: data['bundleId'] as String? ?? '',
          ),
        );
      case 'detection.focusMode':
        eventBus.emit(
          FocusModeEvent(isActive: data['isActive'] as bool? ?? false),
        );
      case 'tray.action':
        final action = data['action'] as String?;
        if (action == 'start') {
          timerEngine.startTimers();
        } else if (action == 'pause') {
          timerEngine.pauseTimers(isManual: true);
        } else if (action == 'reset') {
          timerEngine.resetTimers();
        }
      case 'companion.positionChanged':
        eventBus.emit(
          CompanionPositionChangedEvent(
            x: (data['x'] as num?)?.toDouble() ?? 0,
            y: (data['y'] as num?)?.toDouble() ?? 0,
          ),
        );
      case 'companion.stateChanged':
        eventBus.emit(
          CompanionStateChangedEvent(
            state: CompanionState.values.firstWhere(
              (s) => s.name == (data['state'] as String?),
              orElse: () => CompanionState.idle,
            ),
          ),
        );
      case IpcEventNames.companionInteraction:
        eventBus.emit(
          CompanionInteractionEvent(
            interactionType: data['interactionType'] as String? ?? 'click',
            metadata: data['metadata'] != null
                ? Map<String, dynamic>.from(data['metadata'] as Map)
                : null,
          ),
        );
    }
  });
}
