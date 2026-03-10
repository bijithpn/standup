import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/core/utils/retry_policy.dart';

class ErrorHandler {
  final AppLogger _logger = AppLogger();
  final RetryPolicy _retryPolicy = RetryPolicy();

  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  Future<T?> guard<T>({
    required Future<T> Function() action,
    required ErrorType errorType,
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

  void handleError(Object error, StackTrace? stack, {ErrorType? type}) {
    final exception = AppException(
      message: error.toString(),
      type: type ?? ErrorType.general,
      originalError: error,
      stackTrace: stack,
    );
    _logger.error(exception.toString(), stackTrace: stack);
  }
}
