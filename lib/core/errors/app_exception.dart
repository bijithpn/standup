enum AppErrorType {
  timer,
  notification,
  storage,
  activityMonitor,
  assetLoadFailure,
  ui,
  ipc,
  native,
  calendar,
  wellness,
  backup,
  general,
}

class AppException implements Exception {
  final String message;
  final AppErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException($type): $message';
}
