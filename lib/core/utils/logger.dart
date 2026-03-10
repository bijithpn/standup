import 'dart:developer' as developer;

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  void info(String message) {
    developer.log(message, name: 'DeskRest');
  }

  void warning(String message) {
    developer.log('WARNING: $message', name: 'DeskRest');
  }

  void error(String message, {StackTrace? stackTrace}) {
    developer.log(
      'ERROR: $message',
      name: 'DeskRest',
      error: message,
      stackTrace: stackTrace,
    );
  }
}
