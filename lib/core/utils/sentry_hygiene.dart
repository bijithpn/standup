import 'package:sentry_flutter/sentry_flutter.dart';

/// Privacy filter for Sentry: honours the crash-reporting opt-out, strips user paths and drops window/app-name data from events and breadcrumbs.
class SentryHygiene {
  static final RegExp _userPathRegex = RegExp(
    r'(/Users/[^/\s]+|/home/[^/\s]+|[A-Za-z]:\\Users\\[^\s\\]+)',
  );

  // Returns false when the user disabled crash reporting; events are then dropped.
  static bool Function()? isEnabled;

  static void configure(SentryFlutterOptions options) {
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
    options.beforeSend = filterEvent;
    options.beforeBreadcrumb = filterBreadcrumb;
  }

  static String _scrub(String value) =>
      value.replaceAll(_userPathRegex, '[REDACTED_USER_PATH]');

  static SentryEvent? filterEvent(SentryEvent event, Hint hint) {
    if (isEnabled?.call() == false) return null;

    final message = event.message?.formatted;
    if (message != null && _userPathRegex.hasMatch(message)) {
      event.message = SentryMessage(_scrub(message));
    }

    for (final exception in event.exceptions ?? const <SentryException>[]) {
      final value = exception.value;
      if (value != null) exception.value = _scrub(value);
      for (final frame
          in exception.stackTrace?.frames ?? const <SentryStackFrame>[]) {
        final absPath = frame.absPath;
        if (absPath != null) frame.absPath = _scrub(absPath);
        final fileName = frame.fileName;
        if (fileName != null) frame.fileName = _scrub(fileName);
      }
    }

    event.serverName = null;

    final tags = event.tags;
    if (tags != null) {
      for (final key in tags.keys.toList()) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('window') ||
            lowerKey.contains('appname') ||
            lowerKey.contains('bundleid') ||
            lowerKey.contains('path') ||
            lowerKey.contains('title')) {
          tags[key] = '[REDACTED_PRIVACY]';
        }
      }
    }

    return event;
  }

  static Breadcrumb? filterBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    final message = breadcrumb.message;
    if (message != null) {
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('window') ||
          lowerMsg.contains('active app') ||
          lowerMsg.contains('bundleid')) {
        return null;
      }
      if (_userPathRegex.hasMatch(message)) {
        breadcrumb.message = _scrub(message);
      }
    }
    return breadcrumb;
  }
}
