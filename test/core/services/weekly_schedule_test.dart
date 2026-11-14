import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/work_schedule.dart';
import '../../helpers/in_memory_settings_repository.dart';

void main() {
  bool active(SettingsModel settings, DateTime now) => withClock(
    Clock.fixed(now),
    () => TimerContextManager(
      settingsRepository: InMemorySettingsRepository(settings),
    ).isWithinWorkingHours(),
  );

  test('existing working hours keep exclusive end and selected days', () {
    const settings = SettingsModel(workingHoursEnabled: true);
    expect(active(settings, DateTime(2026, 11, 16, 9)), isTrue);
    expect(active(settings, DateTime(2026, 11, 16, 18)), isFalse);
    expect(active(settings, DateTime(2026, 11, 15, 10)), isFalse);
  });

  test('daily override excludes lunch and resumes at its end', () {
    const settings = SettingsModel(
      workingHoursEnabled: true,
      weeklySchedule: {
        1: WorkSchedule(
          start: '10:00',
          end: '16:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
        ),
      },
    );
    expect(active(settings, DateTime(2026, 11, 16, 9)), isFalse);
    expect(active(settings, DateTime(2026, 11, 16, 10)), isTrue);
    expect(active(settings, DateTime(2026, 11, 16, 12)), isFalse);
    expect(active(settings, DateTime(2026, 11, 16, 13)), isTrue);
    expect(active(settings, DateTime(2026, 11, 17, 9)), isTrue);
  });

  test('Friday shift crosses midnight into a disabled Saturday with lunch', () {
    const settings = SettingsModel(
      workingHoursEnabled: true,
      workingDays: [5],
      weeklySchedule: {
        5: WorkSchedule(
          start: '22:00',
          end: '06:00',
          lunchStart: '01:00',
          lunchEnd: '01:30',
        ),
      },
    );
    expect(active(settings, DateTime(2026, 11, 20, 22)), isTrue);
    expect(active(settings, DateTime(2026, 11, 21, 0, 59)), isTrue);
    expect(active(settings, DateTime(2026, 11, 21, 1)), isFalse);
    expect(active(settings, DateTime(2026, 11, 21, 1, 30)), isTrue);
    expect(active(settings, DateTime(2026, 11, 21, 6)), isFalse);
    expect(active(settings, DateTime(2026, 11, 22, 2)), isFalse);
  });

  test(
    'disabling schedules permits reminders and empty days suppress them',
    () {
      expect(
        active(const SettingsModel(workingDays: []), DateTime(2026, 11, 16)),
        isTrue,
      );
      expect(
        active(
          const SettingsModel(workingHoursEnabled: true, workingDays: []),
          DateTime(2026, 11, 16, 10),
        ),
        isFalse,
      );
    },
  );

  test(
    'next working time reports end of overnight lunch and next weekly shift',
    () {
      final repo = InMemorySettingsRepository(
        const SettingsModel(
          workingHoursEnabled: true,
          workingDays: [5],
          weeklySchedule: {
            5: WorkSchedule(
              start: '22:00',
              end: '06:00',
              lunchStart: '01:00',
              lunchEnd: '01:30',
            ),
          },
        ),
      );
      final context = TimerContextManager(settingsRepository: repo);
      withClock(
        Clock.fixed(DateTime(2026, 11, 21, 1, 10)),
        () => expect(context.nextWorkingTime(), DateTime(2026, 11, 21, 1, 30)),
      );
      withClock(
        Clock.fixed(DateTime(2026, 11, 21, 7)),
        () => expect(context.nextWorkingTime(), DateTime(2026, 11, 27, 22)),
      );
    },
  );

  test('rejects invalid times and lunch outside shift', () {
    expect(const WorkSchedule(start: '24:00').isValid, isFalse);
    expect(const WorkSchedule(start: '09:00', end: '09:00').isValid, isFalse);
    expect(
      const WorkSchedule(lunchStart: '19:00', lunchEnd: '20:00').isValid,
      isFalse,
    );
    expect(
      const WorkSchedule(
        start: '22:00',
        end: '06:00',
        lunchStart: '23:45',
        lunchEnd: '00:15',
      ).isValid,
      isTrue,
    );
  });

  test(
    'backup round trip preserves schedules and older backups use defaults',
    () {
      const settings = SettingsModel(
        weeklySchedule: {
          1: WorkSchedule(
            start: '10:00',
            end: '16:00',
            lunchStart: '12:00',
            lunchEnd: '13:00',
          ),
        },
      );
      final restored = SettingsModel.fromMap(settings.toMap());
      expect(restored.weeklySchedule[1]!.lunchEnd, '13:00');
      expect(SettingsModel.fromMap({}).weeklySchedule, isEmpty);
      expect(
        WorkSchedule.decode({
          '1': {'start': 'broken'},
          '9': {},
        }),
        isEmpty,
      );
    },
  );
}
