import 'dart:io';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/break_system/presentation/break_overlay.dart';
import 'package:standup/features/break_system/presentation/pre_break_warning_overlay.dart';
import 'package:standup/features/break_system/presentation/flash_overlay.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:standup/app/main_layout.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/features/flash_overlay/flash_overlay_service.dart';
import 'package:standup/features/flash_overlay/flash_overlay_screen.dart';

class BreakMateApp extends StatefulWidget {
  const BreakMateApp({super.key});

  @override
  State<BreakMateApp> createState() => _BreakMateAppState();
}

class _BreakMateAppState extends State<BreakMateApp> with WindowListener {
  FlashOverlayService? _flashOverlayService;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _setupTrayActions();
    _initFlashOverlay();
  }

  void _initFlashOverlay() {
    _flashOverlayService = sl<FlashOverlayService>();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _flashOverlayService?.dispose();
    super.dispose();
  }

  void _setupTrayActions() {
    final tray = sl<TrayManagerService>();
    final controller = sl<BreakController>();
    final flashOverlayService = sl<FlashOverlayService>();

    tray.onMenuAction = (action) async {
      final overlayService = sl<OverlayWindowService>();
      final navigation = sl<AppNavigationService>();

      Future<void> openSection(String section) async {
        navigation.openSection(section);
        await overlayService.showDashboard();
      }

      switch (action) {
        case 'open_dashboard':
        case 'settings':
          await openSection('Companion');
          break;
        case 'open_settings':
          await openSection('General');
          break;
        case 'open_flash':
          await openSection('Flash Reminder');
          break;
        case 'open_exercises':
          await openSection('Exercises');
          break;
        case 'open_stats':
          await openSection('Statistics');
          break;
        case 'toggle_pause':
          controller.togglePause();
          tray.updatePauseState(controller.isPaused);
          break;
        case 'take_break':
          controller.takeBreakNow();
          break;
        case 'skip_next':
          controller.skipNextBreak();
          break;
        case 'posture_reminder':
          await flashOverlayService.showOverlay();
          break;
        case 'quit':
          await overlayService.reset();
          flashOverlayService.dispose();
          await windowManager.setPreventClose(false);
          await windowManager.destroy();
          exit(0);
          break;
      }
    };

    controller.addListener(() {
      tray.updatePauseState(controller.isPaused);
      
      final overlayService = sl<OverlayWindowService>();
      if (!controller.isBreakActive && overlayService.currentOverlayType == OverlayType.breakScreen) {
        overlayService.hideOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<BreakController>()),
        Provider.value(value: sl<SettingsRepository>()),
        Provider.value(value: sl<StatsService>()),
      ],
      child: MacosApp(
        title: 'BreakMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.macosTheme,
        home: Builder(
          builder: (context) {
            final flashService = sl<FlashOverlayService>();
            final overlayService = sl<OverlayWindowService>();
            
            return ListenableBuilder(
              listenable: Listenable.merge([flashService, overlayService, sl<BreakController>()]),
              builder: (context, _) {
                final isBreakActive = sl<BreakController>().isBreakActive;
                final isOverlayVisible = overlayService.isOverlayVisible;
                
                return Stack(
                  children: [
                    if (!isOverlayVisible && !isBreakActive) const MainLayout(),
                    const BreakOverlay(),
                    const PreBreakWarningOverlay(),
                    const FlashOverlay(),
                    // Flash overlay screen for full-screen posture reminders
                    if (flashService.isOverlayVisible)
                      FlashOverlayScreen(overlayService: flashService),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void onWindowClose() async {
    await sl<OverlayWindowService>().reset();
    await windowManager.hide();
  }

  @override
  void onWindowBlur() async {
    final controller = sl<BreakController>();
    final settings = sl<SettingsRepository>().currentSettings;

    if (controller.isBreakActive && settings.strictMode) {
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
