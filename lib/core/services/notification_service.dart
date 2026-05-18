import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/utils/logger.dart';

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
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(macOS: macOS);
      await _plugin.initialize(settings);
      await requestPermission();
      _logger.info('Notification service initialized');
    } catch (e, stackTrace) {
      _logger.error('Notification service unavailable: $e', stackTrace: stackTrace);
    }
  }

  Future<bool> requestPermission() async {
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _logger.info('Notification permission: $granted');
      return granted ?? false;
    } catch (e, stackTrace) {
      _logger.error('Notification permission request failed: $e', stackTrace: stackTrace);
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
    await _show(
      id: 2,
      title: 'Time for a break',
      body: breakTitle,
    );
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
        final macOS = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: _soundEnabled,
        );
        await _plugin.show(id, title, body, NotificationDetails(macOS: macOS));
      },
      errorType: ErrorType.notification,
    );
  }
}
