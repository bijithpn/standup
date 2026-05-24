import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/companion/controllers/companion_overlay_controller.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

class MenuBarController {
  MenuBarController({EventBus? eventBus})
      : _eventBus = eventBus ?? EventBus.instance,
        _logger = AppLogger();

  final EventBus _eventBus;
  final AppLogger _logger;

  BreakController? _breakController;

  void setDependencies(BreakController breakController) {
    _breakController = breakController;
  }

  Future<void> handleAction(String action) async {
    _logger.info('Menu action: $action');
    _eventBus.emit(TrayActionEvent(action: action));

    final overlayService = sl<OverlayWindowService>();
    final navigation = sl<AppNavigationService>();

    Future<void> openSection(String section) async {
      navigation.openSection(section);
      await overlayService.showDashboard();
    }

    switch (action) {
      case 'open_app':
        await overlayService.showDashboard();
      case 'open_stats':
        await openSection('Statistics');
      case 'toggle_pause':
        _breakController?.togglePause();
      case 'take_break':
        _breakController?.takeBreakNow();
      case 'skip_next':
        _breakController?.skipNextBreak();
      case 'complete_break':
        _breakController?.completeCurrentBreak();
      case 'skip_current_break':
        _breakController?.skipCurrentBreak();
      case 'postpone_break':
        _breakController?.postponeCurrentBreak();
      case 'toggle_companion_optim':
        final settingsRepo = sl<SettingsRepository>();
        final currentVal = settingsRepo.currentSettings.companionOptimization;
        final nextVal = !currentVal;
        try {
          await sl<CompanionOverlayController>().changeOptimization(nextVal);
        } catch (_) {
          final updated = settingsRepo.currentSettings.copyWith(companionOptimization: nextVal);
          await settingsRepo.save(updated);
        }
        sl<TrayManagerService>().setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);
        sl<TrayManagerService>().triggerActionAnimation();
      case 'quit':
        await _quitApp();
      default:
        _logger.error('Unhandled menu action: $action');
    }
  }

  Future<void> _quitApp() async {
    await sl<OverlayWindowService>().reset();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }
}
