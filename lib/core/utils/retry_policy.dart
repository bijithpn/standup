import 'package:standup/core/constants/app_constants.dart';

class RetryPolicy {
  final int maxRetries;
  final int initialDelayMs;

  RetryPolicy({
    this.maxRetries = AppConstants.maxRetries,
    this.initialDelayMs = AppConstants.initialRetryDelayMs,
  });

  Future<T> execute<T>(Future<T> Function() action) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;

        final delay = initialDelayMs * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }
}
