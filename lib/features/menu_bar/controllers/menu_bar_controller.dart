import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
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
    _logger.info('Handling menu bar action: $action');
    _eventBus.emit(TrayActionEvent(action: action));

    final overlayService = sl<OverlayWindowService>();
    final navigation = sl<AppNavigationService>();
    final breakController = _breakController ?? sl<BreakController>();

    Future<void> openSection(String section) async {
      navigation.openSection(section);
      await overlayService.showDashboard(forceShow: true);
    }

    switch (action) {
      case 'open_app':
        await overlayService.showDashboard(forceShow: true);
        break;
      case 'open_stats':
        await openSection('Statistics');
        break;
      case 'toggle_pause':
        breakController.togglePause();
        break;
      case 'take_break':
        breakController.takeBreakNow();
        break;
      case 'skip_next':
        breakController.skipNextBreak();
        break;
      case 'complete_break':
        await breakController.completeCurrentBreak();
        break;
      case 'skip_current_break':
        await breakController.skipCurrentBreak();
        break;
      case 'postpone_break':
        breakController.postponeCurrentBreak();
        break;
      case 'open_companion':
        await openSection('Companion');
        break;
      case 'quit':
        await _quitApp();
        break;
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
