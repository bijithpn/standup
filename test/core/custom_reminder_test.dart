import 'package:breakmate/core/services/health_reminder_copy.dart';
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
    const type = '${HealthReminderCopy.customPrefix}Take meds';
    expect(HealthReminderCopy.text(type), 'Take meds');
    expect(HealthReminderCopy.pill(type), 'Take meds');
    expect(HealthReminderCopy.poster(type), 'Take meds');
  });
}
