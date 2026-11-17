import 'package:breakmate/core/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows activation without an id opens the update download', () async {
    final opened = <Uri>[];
    final service = NotificationService(
      launchUpdateDownload: (url) async {
        opened.add(url);
        return true;
      },
    );
    service.handleNotificationResponse(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'breakmate-update:https://example.com/BreakMate.exe',
      ),
    );
    expect(opened, [Uri.parse('https://example.com/BreakMate.exe')]);
  });

  test('reminder clicks and unsafe update payloads do not launch URLs', () {
    final opened = <Uri>[];
    final service = NotificationService(
      launchUpdateDownload: (url) async {
        opened.add(url);
        return true;
      },
    );
    for (final payload in [
      null,
      'reminder',
      'https://example.com',
      'breakmate-update:file:///tmp/install',
      'breakmate-update:javascript:alert(1)',
      'breakmate-update:/download',
      'breakmate-update:https://',
    ]) {
      service.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: payload,
        ),
      );
    }
    expect(opened, isEmpty);
  });
}
