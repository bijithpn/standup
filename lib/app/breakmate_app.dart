import 'package:breakmate/shared/utils/accessibility_preferences.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';

import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:breakmate/app/main_layout.dart';
import 'package:breakmate/app/startup_splash.dart';
import 'package:breakmate/main_common.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/features/onboarding/presentation/onboarding_page.dart';
import 'package:breakmate/features/themes/application/theme_controller.dart';

/// Root widget of the main window: providers, theme, onboarding gate and window-event handling.
class BreakMateApp extends StatefulWidget {
  const BreakMateApp({super.key});

  @override
  State<BreakMateApp> createState() => _BreakMateAppState();
}

class _BreakMateAppState extends State<BreakMateApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _setupTrayActions();
    _listenToEvents();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    super.dispose();
  }

  void _listenToEvents() {
    sl<EventBus>().on<NotificationPermissionDeniedEvent>().listen((event) {
      if (mounted) {
        sl<AppNavigationService>().openSection('Notifications');

        ErrorToastService.showInfo(
          'Notifications are disabled. Please enable them in settings to receive reminders.',
        );
      }
    });
  }

  // Closes a leftover break overlay window once the break is no longer active.
  void _setupTrayActions() {
    final controller = sl<BreakController>();

    controller.addListener(() {
      final overlayService = sl<OverlayWindowService>();
      if (!controller.isBreakActive &&
          overlayService.currentOverlayType == OverlayType.breakScreen) {
        overlayService.hideOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: _buildApp()),
        // Splash cover hides the first-frame layout and fades out.
        const Positioned.fill(child: StartupSplashCover()),
      ],
    );
  }

  Widget _buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<ThemeController>()),
        ChangeNotifierProvider.value(value: sl<BreakController>()),
        ChangeNotifierProvider.value(value: sl<SettingsRepository>()),
        ChangeNotifierProvider.value(value: sl<StatsService>()),
        ChangeNotifierProvider.value(value: sl<AppUsageService>()),
        ChangeNotifierProvider.value(value: sl<FocusSessionService>()),
        ChangeNotifierProvider.value(value: sl<BreakHistoryService>()),
        ChangeNotifierProvider.value(value: sl<ContextSwitchTracker>()),
        ChangeNotifierProvider.value(value: sl<FocusStreakService>()),
      ],
      child: Consumer2<ThemeController, SettingsRepository>(
        builder: (context, themeController, repository, child) {
          final preferences = repository.currentSettings;
          AppTheme.highContrast =
              preferences.experience.highContrast ||
              MediaQuery.maybeOf(context)?.highContrast == true;
          AppMotion.reduceMotion =
              preferences.reduceMotion || !preferences.enableAnimations;
          return MacosApp(
            navigatorKey: ErrorToastService.navigatorKey,
            title: 'BreakMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.macosTheme,
            routes: {'/main': (context) => const MainLayout()},
            builder: (context, widget) {
              final settings = context
                  .watch<SettingsRepository>()
                  .currentSettings;
              final media = MediaQuery.of(context);
              final accessible = accessibleMediaData(media, settings);
              AppTheme.highContrast = accessible.highContrast;
              return MediaQuery(
                data: accessible,
                child: Theme(
                  data: AppTheme.materialTheme,
                  child: FocusTraversalGroup(
                    child: ScaffoldMessenger(
                      child: widget ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
            home: child,
          );
        },
        child: Consumer<SettingsRepository>(
          builder: (context, settingsRepo, _) {
            final settings = settingsRepo.currentSettings;

            if (!settings.hasCompletedOnboarding) {
              return const OnboardingPage();
            }

            return const Material(
              type: MaterialType.transparency,
              child: MainLayout(),
            );
          },
        ),
      ),
    );
  }

  @override
  void onWindowMinimize() {
    windowManager.hide();
  }

  @override
  // Close hides to tray unless close prevention is off, in which case the app quits.
  void onWindowClose() async {
    final prevent = await windowManager.isPreventClose();
    if (!prevent) {
      await gracefulShutdown('onWindowClose (prevent=false)');
      return;
    }

    await sl<OverlayWindowService>().reset();
    await windowManager.hide();
  }

  @override
  // Strict mode: pull the window back to the front so the break can't be ignored.
  void onWindowBlur() async {
    final controller = sl<BreakController>();
    final settings = sl<SettingsRepository>().currentSettings;

    if (controller.isBreakActive && settings.strictMode) {
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
