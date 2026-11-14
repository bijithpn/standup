import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/native_enhancements_service.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/weekly_digest.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Shows system notifications for reminders, breaks and insights; each helper maps to a fixed notification id/copy.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  // Permission is requested without awaiting so startup is not blocked on the system prompt.
  Future<void> init() async {
    try {
      const macOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const windows = WindowsInitializationSettings(
        appName: 'BreakMate',
        appUserModelId: 'com.bijith.breakmate',
        guid: 'd49b0314-ee68-4b06-9a59-9a4a6f91c2e5',
      );
      const settings = InitializationSettings(macOS: macOS, windows: windows);
      await _plugin.initialize(settings: settings);

      unawaited(_checkAndRequestPermission());

      _logger.info('Notification service initialized (async permission)');
    } catch (e, stackTrace) {
      _logger.error(
        'Notification service unavailable: $e',
        stackTrace: stackTrace,
      );
    }
  }

  // Denied permission turns notifications off in settings and emits NotificationPermissionDeniedEvent for the UI.
  Future<void> _checkAndRequestPermission() async {
    final granted = await requestNotificationPermission();
    if (!granted) {
      _notificationsEnabled = false;

      try {
        final settingsRepo = sl<SettingsRepository>();
        final newSettings = settingsRepo.currentSettings.copyWith(
          notificationsEnabled: false,
        );
        await settingsRepo.save(newSettings);
      } catch (e) {
        _logger.error('Failed to update notification settings: $e');
      }

      sl<EventBus>().emit(NotificationPermissionDeniedEvent());
    }
  }

  /// Read-only status. Null means this platform cannot report the permission.
  Future<bool?> permissionAllowed() async {
    if (!Platform.isMacOS) return null;
    try {
      return (await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions())
          ?.isEnabled;
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestNotificationPermission() async {
    // Windows toasts need no runtime permission.
    if (Platform.isWindows) return true;
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
      title: 'Eye rest',
      body: 'Look at something 20 feet away for 20 seconds.',
    );
  }

  Future<void> showPostureReminder() async {
    await _show(
      id: 11,
      title: 'Posture',
      body: 'Sit up and roll your shoulders back.',
    );
  }

  Future<void> showBreakStarted({required String breakTitle}) async {
    await _show(id: 2, title: 'Break time', body: breakTitle);
  }

  Future<void> showBreakFinished() async {
    await _show(id: 3, title: 'Break over', body: 'Back to it.');
  }

  Future<void> showClockOutReminder() async {
    await _show(
      id: 20,
      title: 'Time to stop',
      body: 'Your workday is done. Close the laptop.',
    );
  }

  Future<void> showWeeklyDigest(WeeklyDigest digest) async {
    await _show(id: 30, title: 'Your week', body: digest.toMessage());
  }

  Future<void> showFocusCorrelationInsight(
    BreakFocusCorrelation correlation,
  ) async {
    await _show(
      id: 31,
      title: 'Something in your data',
      body: correlation.describe(),
    );
  }

  Future<void> showDailyInsight(String text) async {
    await _show(id: 32, title: 'Worth a look', body: text);
  }

  Future<void> showEndOfDaySummary(String text) async {
    await _show(id: 33, title: 'Your day', body: text);
  }

  Future<void> showEveningEyeCare(bool warmedScreen) async {
    await _show(
      id: 34,
      title: 'Evening',
      body: warmedScreen
          ? 'Night Shift is on. Lower your brightness a bit too.'
          : 'Turn on a warmer screen tint and lower the brightness.',
    );
  }

  Future<void> showReminder({required String message}) async {
    await _show(id: 0, title: 'BreakMate', body: message);
  }

  Future<void> showBreakReminder({required bool isLong}) async {
    await _show(
      id: 1,
      title: 'Break soon',
      body: isLong ? 'Long break in 1 minute' : 'Short break in 30 seconds',
    );
  }

  Future<void> showMeetingBreakReminder({bool isPresenting = false}) async {
    await _show(
      id: 12,
      title: 'Break waiting',
      body: isPresenting
          ? 'You\'re presenting, so this stays quiet.'
          : 'You\'re in a meeting, so this stays quiet.',
    );
  }

  // Single funnel for all notifications: honours the enabled flag, then shows a native toast (macOS) plus a pet-icon notification.
  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_notificationsEnabled) return;

    await _errorHandler.guard(
      action: () async {
        NotificationDetails notificationDetails;

        if (Platform.isWindows) {
          notificationDetails = const NotificationDetails(
            windows: WindowsNotificationDetails(),
          );
        } else {
          final settingsRepo = sl<SettingsRepository>();
          final selectedThemeId =
              settingsRepo.currentSettings.companionPetTheme;
          final theme = PetTheme.getTheme(selectedThemeId);
          final iconPath = await PetAssetLoader.extractPetIconPath(theme);

          unawaited(
            NativeEnhancementsService.instance.showToast(
              title: title,
              body: body,
              sound: _soundEnabled,
            ),
          );

          final macOS = DarwinNotificationDetails(
            presentAlert: true,
            // Banner off because the native toast above is the visible alert; list keeps it in Notification Center.
            presentBanner: false,
            presentList: true,
            presentSound: false,
            attachments: iconPath.isNotEmpty
                ? [DarwinNotificationAttachment(iconPath)]
                : null,
          );
          notificationDetails = NotificationDetails(macOS: macOS);
        }

        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
        );
      },
      errorType: AppErrorType.notification,
    );
  }
}
