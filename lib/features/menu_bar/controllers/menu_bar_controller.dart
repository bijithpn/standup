import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/main_common.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/core/services/feed_update_checker.dart';
import 'package:breakmate/core/services/error_toast_service.dart';

class MenuBarController {
  MenuBarController({
    EventBus? eventBus,
    BreakController? breakController,
    Future<int?> Function(bool isFocus)? durationPicker,
  }) : _eventBus = eventBus ?? EventBus.instance,
       _durationPicker = durationPicker,
       _breakController = breakController,
       _logger = AppLogger();

  final EventBus _eventBus;
  final AppLogger _logger;
  final Future<int?> Function(bool isFocus)? _durationPicker;
  bool _durationPickerOpen = false;

  BreakController? _breakController;

  void setDependencies(BreakController breakController) {
    _breakController = breakController;
  }

  Future<void> handleAction(String action) async {
    _logger.info('Handling menu bar action: $action');
    _eventBus.emit(TrayActionEvent(action: action));

    if (action == 'check_for_updates') {
      await _checkForUpdates();
      return;
    }
    if (action == 'focus' || action == 'snooze') {
      await _startTimedAction(isFocus: action == 'focus');
      return;
    }

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
      case 'micro_session':
        breakController.startMicroSession();
        break;
      case 'focus_end':
        breakController.endFocusSession(completed: false);
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
      case 'open_notifications':
        await openSection('Notifications');
        break;
      case 'quit':
        await _quitApp();
        break;
      default:
        _logger.error('Unhandled menu action: $action');
    }
  }

  Future<void> _quitApp() async {
    await gracefulShutdown('MenuBarController._quitApp (menu action)');
  }

  Future<void> _startTimedAction({required bool isFocus}) async {
    if (_durationPickerOpen) return;
    final controller = _breakController ?? sl<BreakController>();
    if (controller.isBreakActive || controller.isFocusSessionActive) return;
    _durationPickerOpen = true;
    try {
      final int? minutes;
      if (_durationPicker != null) {
        minutes = await _durationPicker(isFocus);
      } else {
        final initial = isFocus
            ? 25
            : (sl.isRegistered<SettingsRepository>()
                  ? sl<SettingsRepository>()
                        .currentSettings
                        .lastSnoozeDurationMinutes
                  : 15);
        minutes = await const MethodChannel('com.breakmate/native_enhancements')
            .invokeMethod<int>('showTrayDurationPicker', {
              'isFocus': isFocus,
              'initialMinutes': initial,
            });
      }
      if (minutes == null ||
          minutes < 1 ||
          minutes > 1439 ||
          controller.isBreakActive ||
          controller.isFocusSessionActive) {
        return;
      }
      if (isFocus) {
        controller.startFocusSession(minutes);
      } else {
        controller.snooze(minutes: minutes);
      }
    } catch (error) {
      _logger.error('Unable to start ${isFocus ? "focus" : "snooze"}: $error');
      ErrorToastService.showError(
        'Unable to open the duration picker. Please try again.',
      );
    } finally {
      _durationPickerOpen = false;
    }
  }

  bool _checkingForUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) return;
    _checkingForUpdates = true;
    try {
      if (Platform.isMacOS) {
        // User-facing Sparkle check includes release notes, download, install,
        // and relaunch rather than the Settings informational probe.
        await const MethodChannel(
          'com.breakmate/sparkle',
        ).invokeMethod<void>('startUpdate');
      } else if (Platform.isWindows || Platform.isLinux) {
        await sl<OverlayWindowService>().showDashboard(forceShow: true);
        ErrorToastService.showInfo('Checking for updates…');
        final update = await FeedUpdateChecker().check();
        if (update == null) {
          ErrorToastService.showInfo(
            'You’re using the latest version of BreakMate.',
          );
        } else if (!await launchUrl(
          update.downloadUrl,
          mode: LaunchMode.externalApplication,
        )) {
          ErrorToastService.showError(
            'Unable to open the update download. Please try again.',
          );
        }
      }
    } catch (error) {
      _logger.error('Update check failed: $error');
      await sl<OverlayWindowService>().showDashboard(forceShow: true);
      ErrorToastService.showError(
        'Unable to check for updates. Please try again.',
      );
    } finally {
      _checkingForUpdates = false;
    }
  }
}
