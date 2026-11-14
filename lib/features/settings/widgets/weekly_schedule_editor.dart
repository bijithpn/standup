import 'settings_widgets.dart';
import 'package:flutter/material.dart';
import '../settings_model.dart';
import '../work_schedule.dart';

class WeeklyScheduleEditor extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;
  const WeeklyScheduleEditor({
    super.key,
    required this.settings,
    required this.onSave,
  });
  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _edit(BuildContext context, int day) async {
    final current =
        settings.weeklySchedule[day] ??
        WorkSchedule(start: settings.workStartTime, end: settings.workEndTime);
    final start = TextEditingController(text: current.start);
    final end = TextEditingController(text: current.end);
    final lunchStart = TextEditingController(
      text: current.lunchStart ?? '12:00',
    );
    final lunchEnd = TextEditingController(text: current.lunchEnd ?? '13:00');
    bool lunch = current.lunchStart != null;
    final form = GlobalKey<FormState>();
    final result = await showDialog<WorkSchedule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${days[day - 1]} hours'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Use 24-hour times. An end before the start continues into the next day.',
                    ),
                    for (final entry in [
                      (start, 'Start'),
                      (end, 'End'),
                      if (lunch) (lunchStart, 'Lunch start'),
                      if (lunch) (lunchEnd, 'Lunch end'),
                    ])
                      TextFormField(
                        controller: entry.$1,
                        decoration: InputDecoration(
                          labelText: entry.$2,
                          hintText: '09:00',
                        ),
                        validator: (value) =>
                            WorkSchedule.minutes(value) == null
                            ? 'Enter a valid time as HH:mm.'
                            : null,
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Exclude lunch'),
                      value: lunch,
                      onChanged: (value) => setState(() => lunch = value),
                    ),
                    FormField<bool>(
                      validator: (_) =>
                          WorkSchedule(
                            start: start.text,
                            end: end.text,
                            lunchStart: lunch ? lunchStart.text : null,
                            lunchEnd: lunch ? lunchEnd.text : null,
                          ).isValid
                          ? null
                          : 'Use different start and end times, with lunch inside the shift.',
                      builder: (field) => field.hasError
                          ? Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    WorkSchedule(
                      start: start.text,
                      end: end.text,
                      lunchStart: lunch ? lunchStart.text : null,
                      lunchEnd: lunch ? lunchEnd.text : null,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Dispose after the dialog's closing animation has removed its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in [start, end, lunchStart, lunchEnd]) {
      controller.dispose();
    }
    if (result != null && context.mounted) {
      onSave(
        settings.copyWith(
          weeklySchedule: {...settings.weeklySchedule, day: result},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Customize each working day, including overnight shifts and lunch.',
        ),
      ),
      for (final day in settings.workingDays.where(
        (day) => day >= 1 && day <= 7,
      )) ...[
        divider(),
        ListTile(
          title: Text(
            days[day - 1],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _summary(day),
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          trailing: const Icon(Icons.edit_outlined),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          onTap: () => _edit(context, day),
        ),
      ],
      if (settings.workingDays.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Choose at least one working day to receive scheduled breaks.',
          ),
        ),
    ],
  );

  String _summary(int day) {
    final shift =
        settings.weeklySchedule[day] ??
        WorkSchedule(start: settings.workStartTime, end: settings.workEndTime);
    final overnight =
        (WorkSchedule.minutes(shift.end) ?? 0) <
        (WorkSchedule.minutes(shift.start) ?? 0);
    return '${shift.start} – ${shift.end}${overnight ? ' (next day)' : ''}${shift.lunchStart == null ? '' : ' · Lunch ${shift.lunchStart}–${shift.lunchEnd}'}';
  }
}
