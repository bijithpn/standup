import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/core/services/native_enhancements_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'headings distinguish categories and keep custom content in the body',
    () {
      expect(HealthReminderMessages.heading('hydration'), 'Drink some water');
      expect(HealthReminderMessages.heading('posture'), 'Sit up');
      expect(
        HealthReminderMessages.heading('custom:Take medicine'),
        'Your reminder',
      );
      expect(HealthReminderMessages.heading(null), 'A moment for you');
    },
  );
  test(
    'native card receives category, heading and dismissal setting',
    () async {
      const channel = MethodChannel('com.breakmate/native_enhancements');
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await NativeEnhancementsService.instance.triggerFlashReminder(
        text: 'Have a glass of water.',
        reminderType: 'hydration',
        durationMs: 10000,
        dismissOnMouseMove: true,
      );
      expect(received!.method, 'triggerFlashReminder');
      expect(received!.arguments['title'], 'Drink some water');
      expect(received!.arguments['text'], 'Have a glass of water.');
      expect(received!.arguments['reminderType'], 'hydration');
      expect(received!.arguments['dismissOnMouseMove'], true);
    },
  );
}
