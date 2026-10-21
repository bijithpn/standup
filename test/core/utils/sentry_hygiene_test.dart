import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:breakmate/core/utils/sentry_hygiene.dart';

void main() {
  group('SentryHygiene', () {
    test('configure disables default PII and attaches filters', () {
      final options = SentryFlutterOptions();
      SentryHygiene.configure(options);

      expect(options.sendDefaultPii, isFalse);
      expect(options.beforeSend, isNotNull);
      expect(options.beforeBreadcrumb, isNotNull);
    });

    test('filterEvent redacts local user file system paths from messages', () {
      final event = SentryEvent(
        message: SentryMessage('Crash at /Users/john_doe/Projects/standup/main.dart:42'),
      );
      final sanitized = SentryHygiene.filterEvent(event, Hint());

      expect(sanitized, isNotNull);
      expect(
        sanitized!.message?.formatted,
        'Crash at [REDACTED_USER_PATH]/Projects/standup/main.dart:42',
      );
    });

    test('filterEvent redacts tag metadata containing app or window names', () {
      final event = SentryEvent(
        tags: {
          'activeAppName': 'Xcode',
          'windowTitle': 'Private Project - SecretCode.swift',
          'bundleId': 'com.apple.dt.Xcode',
          'safeTag': 'break_screen',
        },
      );
      final sanitized = SentryHygiene.filterEvent(event, Hint());

      expect(sanitized, isNotNull);
      expect(sanitized!.tags?['activeAppName'], '[REDACTED_PRIVACY]');
      expect(sanitized.tags?['windowTitle'], '[REDACTED_PRIVACY]');
      expect(sanitized.tags?['bundleId'], '[REDACTED_PRIVACY]');
      expect(sanitized.tags?['safeTag'], 'break_screen');
    });

    test('filterBreadcrumb drops active app and window tracking breadcrumbs', () {
      final b1 = Breadcrumb(message: 'Switched to active app: Safari');
      final b2 = Breadcrumb(message: 'Window changed: Banking Portal');
      final b3 = Breadcrumb(message: 'Timer state changed to running');

      expect(SentryHygiene.filterBreadcrumb(b1, Hint()), isNull);
      expect(SentryHygiene.filterBreadcrumb(b2, Hint()), isNull);
      expect(SentryHygiene.filterBreadcrumb(b3, Hint()), isNotNull);
    });

    test('filterBreadcrumb redacts user home paths in breadcrumb messages', () {
      final b = Breadcrumb(message: 'Loaded file from /home/alice/data.json');
      final sanitized = SentryHygiene.filterBreadcrumb(b, Hint());

      expect(sanitized, isNotNull);
      expect(sanitized!.message, 'Loaded file from [REDACTED_USER_PATH]/data.json');
    });
  });
}
