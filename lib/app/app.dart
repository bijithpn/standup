import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_system/presentation/break_overlay.dart';
import 'package:breakmate/features/break_system/presentation/pre_break_warning_overlay.dart';

import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:breakmate/app/main_layout.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/features/onboarding/presentation/onboarding_page.dart';

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
    final controller = sl<BreakController>();

    controller.addListener(() {
      sl<TrayManagerService>().updatePauseState(controller.isPaused);

      final overlayService = sl<OverlayWindowService>();
      if (!controller.isBreakActive &&
          overlayService.currentOverlayType == OverlayType.breakScreen) {
        overlayService.showDashboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<BreakController>()),
        Provider.value(value: sl<SettingsRepository>()),
        ChangeNotifierProvider.value(value: sl<StatsService>()),
      ],
      child: MacosApp(
        navigatorKey: ErrorToastService.navigatorKey,
        title: 'BreakMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.macosTheme,
        home: Builder(
          builder: (context) {
            final overlayService = sl<OverlayWindowService>();

            return Selector<BreakController, bool>(
              selector: (context, controller) => controller.isBreakActive,
              builder: (context, isBreakActive, _) {
                return ListenableBuilder(
                  listenable: overlayService,
                  builder: (context, _) {
                    final isOverlayVisible = overlayService.isOverlayVisible;

                    final settings = sl<SettingsRepository>().currentSettings;
                    if (!settings.hasCompletedOnboarding) {
                      return const OnboardingPage();
                    }

                    return Stack(
                      children: [
                        Offstage(
                          offstage: isOverlayVisible || isBreakActive,
                          child: const MainLayout(),
                        ),
                        const BreakOverlay(),
                        const PreBreakWarningOverlay(),
                      ],
                    );
                  },
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
