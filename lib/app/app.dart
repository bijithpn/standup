import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/break_system/presentation/break_overlay.dart';
import 'package:standup/features/settings/settings_page.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

class DeskRestApp extends StatefulWidget {
  const DeskRestApp({super.key});

  @override
  State<DeskRestApp> createState() => _DeskRestAppState();
}

class _DeskRestAppState extends State<DeskRestApp> with WindowListener {
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
          // For a clean quit, we remove the preventClose flag
          await windowManager.setPreventClose(false);
          await windowManager.close();
          break;
      }
    };

    // Update tray if controller changes (e.g. idle detection)
    controller.addListener(() {
      tray.updatePauseState(controller.isPaused);
      _handleWindowState(controller.isBreakActive);
    });
  }

  void _handleWindowState(bool isBreakActive) async {
    if (isBreakActive) {
      await windowManager.setAlwaysOnTop(true);
      if (sl<SettingsRepository>().currentSettings.strictMode) {
        await windowManager.setFullScreen(true);
      }
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      if (!sl<SettingsRepository>().currentSettings.strictMode) {
        // Only hide if not manually opened settings
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
            SettingsPage(),
            // The break overlay is always present but hidden when no break is active
            BreakOverlay(),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowClose() async {
    // Hide window instead of quitting when close button is clicked
    await windowManager.hide();
  }
}
