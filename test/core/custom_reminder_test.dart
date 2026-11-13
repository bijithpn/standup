import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom reminders survive a settings round trip', () {
    final s = const SettingsModel().copyWith(
      customReminders: const [CustomReminder(title: 'Take meds', minutes: 90)],
    );
    final back = SettingsModel.fromMap(s.toMap());
    expect(back.customReminders.single.title, 'Take meds');
    expect(back.customReminders.single.minutes, 90);
  });

  test('custom reminder copy uses the user text', () {
    const type = '${HealthReminderMessages.customPrefix}Take meds';
    expect(HealthReminderMessages.text(type), 'Take meds');
    expect(HealthReminderMessages.pill(type), 'Take meds');
    expect(HealthReminderMessages.poster(type), 'Take meds');
  });
}
