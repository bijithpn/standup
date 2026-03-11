import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/break_system/presentation/break_overlay.dart';
import 'package:standup/features/break_system/presentation/flash_overlay.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:standup/app/main_layout.dart';
import 'package:standup/core/services/overlay_window_service.dart';

class BreakLoopApp extends StatefulWidget {
  const BreakLoopApp({super.key});

  @override
  State<BreakLoopApp> createState() => _BreakLoopAppState();
}

class _BreakLoopAppState extends State<BreakLoopApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _setupTrayActions();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _setupTrayActions() {
    final tray = sl<TrayManagerService>();
    final controller = sl<BreakController>();

    tray.onMenuAction = (action) async {
      switch (action) {
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
        case 'settings':
          await windowManager.show();
          await windowManager.focus();
          break;
        case 'quit':
          await sl<OverlayWindowService>().reset();
          await windowManager.setPreventClose(false);
          await windowManager.close();
          break;
      }
    };

    controller.addListener(() {
      tray.updatePauseState(controller.isPaused);
      _handleWindowState(controller.isBreakActive);
    });
  }

  void _handleWindowState(bool isBreakActive) async {
    final overlayService = sl<OverlayWindowService>();
    
    if (isBreakActive) {
      // Let the overlay service handle the window state
      await windowManager.setAlwaysOnTop(true);
      if (sl<SettingsRepository>().currentSettings.strictMode) {
        await windowManager.setFullScreen(true);
      }
      await windowManager.show();
      await windowManager.focus();
    } else {
      // Only reset window state if no overlay is visible
      if (!overlayService.isOverlayVisible) {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setFullScreen(false);
      }
    }
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
        home: const Stack(
          children: [
            MainLayout(),
            BreakOverlay(),
            FlashOverlay(),
          ],
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
