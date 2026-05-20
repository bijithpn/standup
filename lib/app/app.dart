import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/break_system/presentation/break_overlay.dart';
import 'package:standup/features/break_system/presentation/pre_break_warning_overlay.dart';

import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:standup/app/main_layout.dart';
import 'package:standup/core/services/overlay_window_service.dart';


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
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    super.dispose();
  }

  void _setupTrayActions() {
    final tray = sl<TrayManagerService>();
    final controller = sl<BreakController>();

    final timerEngine = controller.timerEngine;

    // Connect tray to timer engine for dynamic menu updates
    tray.setDependencies(timerEngine, controller);

    // tray.onMenuAction is no longer strictly needed for default actions 
    // as TrayManagerService handles them internally now.
    
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

            final overlayService = sl<OverlayWindowService>();
            
            return ListenableBuilder(
              listenable: Listenable.merge([overlayService, sl<BreakController>()]),
              builder: (context, _) {
                final isBreakActive = sl<BreakController>().isBreakActive;
                final isOverlayVisible = overlayService.isOverlayVisible;
                
                return Stack(
                  children: [
                    if (!isOverlayVisible && !isBreakActive) const MainLayout(),
                    const BreakOverlay(),
                    const PreBreakWarningOverlay(),
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
