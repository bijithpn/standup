import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/utils/logger.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  bool _soundEnabled = true;

  Future<void> init() async {
    const macOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(macOS: macOS);
    await _plugin.initialize(settings);
    _logger.info('Notification service initialized');
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  Future<void> showBreakReminder({required bool isLong}) async {
    await _errorHandler.guard(
      action: () => _show(
        id: 1,
        title: 'Break coming up',
        body: isLong
            ? 'Long break starts in 1 minute'
            : 'Short break starts in 30 seconds',
      ),
      errorType: ErrorType.notification,
    );
  }

  Future<void> showBreakStarted({required String breakTitle}) async {
    await _errorHandler.guard(
      action: () => _show(
        id: 2,
        title: 'Time for a break',
        body: breakTitle,
      ),
      errorType: ErrorType.notification,
    );
  }

  Future<void> showBreakFinished() async {
    await _errorHandler.guard(
      action: () => _show(
        id: 3,
        title: 'Break finished',
        body: 'Welcome back! Stay focused.',
      ),
      errorType: ErrorType.notification,
    );
  }

  Future<void> showBlinkReminder() async {
    await _errorHandler.guard(
      action: () => _show(
        id: 4,
        title: 'Blink Reminder',
        body: 'Take a second to blink your eyes 5 times.',
      ),
      errorType: ErrorType.notification,
      retry: false,
    );
  }

  Future<void> showPostureReminder() async {
    await _errorHandler.guard(
      action: () => _show(
        id: 5,
        title: 'Posture Check',
        body: 'Sit up straight and roll your shoulders.',
      ),
      errorType: ErrorType.notification,
      retry: false,
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    final macOS = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: _soundEnabled,
    );

    final details = NotificationDetails(macOS: macOS);
    await _plugin.show(id, title, body, details);
  }
}
