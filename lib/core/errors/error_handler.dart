import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/utils/retry_policy.dart';

class ErrorHandler {
  final AppLogger _logger = AppLogger();
  final RetryPolicy _retryPolicy = RetryPolicy();

  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  Future<T?> guard<T>({
    required Future<T> Function() action,
    required AppErrorType errorType,
    T? fallback,
    bool retry = true,
  }) async {
    try {
      if (retry) {
        return await _retryPolicy.execute(action);
      }
      return await action();
    } catch (e, stack) {
      final exception = AppException(
        message: e.toString(),
        type: errorType,
        originalError: e,
        stackTrace: stack,
      );
      _logger.error(exception.toString(), stackTrace: stack);
      return fallback;
    }
  }

  void handleError(Object error, StackTrace? stack, {AppErrorType? type, String? message}) {
    final exception = AppException(
      message: message ?? error.toString(),
      type: type ?? AppErrorType.general,
      originalError: error,
      stackTrace: stack,
    );
    _logger.error(exception.toString(), stackTrace: stack);
  }
}
