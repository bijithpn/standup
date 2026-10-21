import 'package:sentry_flutter/sentry_flutter.dart';

/// Privacy and security sanitizer for Sentry telemetry.
/// Ensures no sensitive personal data, local user paths, active app names,
/// or window titles leave the device in crash reports or breadcrumbs.
class SentryHygiene {
  static final RegExp _userPathRegex = RegExp(
    r'(/Users/[^/\s]+|/home/[^/\s]+|[A-Za-z]:\\Users\\[^\s\\]+)',
  );

  /// Configures Sentry options with strict privacy boundaries.
  static void configure(SentryFlutterOptions options) {
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
    options.beforeSend = filterEvent;
    options.beforeBreadcrumb = filterBreadcrumb;
  }

  static String _scrub(String value) =>
      value.replaceAll(_userPathRegex, '[REDACTED_USER_PATH]');

  /// Sanitizes Sentry crash events before transmission.
  static SentryEvent? filterEvent(SentryEvent event, Hint hint) {
    // Redact local user directories from messages
    final message = event.message?.formatted;
    if (message != null && _userPathRegex.hasMatch(message)) {
      event.message = SentryMessage(_scrub(message));
    }

    // Exception values and stack frames routinely embed file paths
    // (FileSystemException, build paths in frames).
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

    // The machine's host name is often the user's real name.
    event.serverName = null;

    // Redact sensitive contexts or tags that could contain window titles or app names
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

  /// Sanitizes or drops breadcrumbs containing private workspace or window context.
  static Breadcrumb? filterBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    final message = breadcrumb.message;
    if (message != null) {
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('window') ||
          lowerMsg.contains('active app') ||
          lowerMsg.contains('bundleid')) {
        return null; // Drop sensitive active application/window tracking breadcrumbs
      }
      if (_userPathRegex.hasMatch(message)) {
        breadcrumb.message = _scrub(message);
      }
    }
    return breadcrumb;
  }
}
