import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  Future<void> init() async {
    try {
      const macOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(macOS: macOS);
      await _plugin.initialize(settings: settings);
      
      // Request permission asynchronously without blocking the app loader
      unawaited(_checkAndRequestPermission());

      _logger.info('Notification service initialized (async permission)');
    } catch (e, stackTrace) {
      _logger.error(
        'Notification service unavailable: $e',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _checkAndRequestPermission() async {
    final granted = await requestPermission();
    if (!granted) {
      _notificationsEnabled = false;

      try {
        // Update settings repo to reflect that notifications are disabled
        final settingsRepo = sl<SettingsRepository>();
        final newSettings = settingsRepo.currentSettings.copyWith(
          notificationsEnabled: false,
        );
        await settingsRepo.save(newSettings);
      } catch (e) {
        _logger.error('Failed to update notification settings: $e');
      }

      // Emit event so the UI can navigate the user to settings
      sl<EventBus>().emit(NotificationPermissionDeniedEvent());
    }
  }

  Future<bool> requestPermission() async {
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _logger.info('Notification permission: $granted');
      return granted ?? false;
    } catch (e, stackTrace) {
      _logger.error(
        'Notification permission request failed: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  Future<void> showEyeRestReminder() async {
    await _show(
      id: 10,
      title: '👁 Eye Rest — 20-20-20',
      body: 'Look 20 feet away for 20 seconds to reduce eye strain.',
    );
  }

  Future<void> showPostureReminder() async {
    await _show(
      id: 11,
      title: '🧘 Posture Check',
      body: 'Sit up straight, roll your shoulders back.',
    );
  }

  Future<void> showBreakStarted({required String breakTitle}) async {
    await _show(id: 2, title: 'Time for a break', body: breakTitle);
  }

  Future<void> showBreakFinished() async {
    await _show(
      id: 3,
      title: 'Break finished',
      body: 'Welcome back! Stay focused.',
    );
  }

  Future<void> showClockOutReminder() async {
    await _show(
      id: 20,
      title: '🌙 Time to Clock Out',
      body: 'Your workday is over. Step away and recharge.',
    );
  }

  Future<void> showReminder({required String message}) async {
    await _show(id: 0, title: 'BreakMate', body: message);
  }

  Future<void> showBreakReminder({required bool isLong}) async {
    await _show(
      id: 1,
      title: 'Break coming up',
      body: isLong
          ? 'Long break starts in 1 minute'
          : 'Short break starts in 30 seconds',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_notificationsEnabled) return;

    await _errorHandler.guard(
      action: () async {
        // Retrieve selected companion theme
        final settingsRepo = sl<SettingsRepository>();
        final selectedThemeId = settingsRepo.currentSettings.companionPetTheme;
        final theme = PetTheme.getTheme(selectedThemeId);

        // Extract the icon for the selected companion theme
        final iconPath = await PetAssetLoader.extractPetIconPath(theme);

        final macOS = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: _soundEnabled,
          attachments: iconPath.isNotEmpty
              ? [DarwinNotificationAttachment(iconPath)]
              : null,
        );
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(macOS: macOS),
        );
      },
      errorType: ErrorType.notification,
    );
  }
}
