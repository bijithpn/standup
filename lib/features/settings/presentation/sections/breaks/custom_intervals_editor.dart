import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';

class CustomIntervalsEditor extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const CustomIntervalsEditor({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Custom Rhythm',
          subtitle:
              'Fine-tune your break frequency and duration for maximum productivity.',
        ),
        buildCard([
          inputRow(
            'Short Break Every',
            '${settings.shortBreakIntervalMinutes} min',
            onTap: () {
              showPicker(
                context: context,
                title: 'Short Break Interval',
                options: List.generate(180, (i) => '${i + 1}'),
                suffix: ' min',
                onSelected: (v) => onSave(
                  settings.copyWith(shortBreakIntervalMinutes: int.parse(v)),
                ),
              );
            },
          ),
          divider(),
          inputRow(
            'Short Break Duration',
            '${settings.shortBreakDurationSeconds} sec',
            onTap: () {
              showPicker(
                context: context,
                title: 'Short Break Duration',
                options: [
                  ...List.generate(12, (i) => '${(i + 1) * 5}'),
                  '75',
                  '90',
                  '120',
                  '180',
                  '300',
                ],
                suffix: ' sec',
                onSelected: (v) => onSave(
                  settings.copyWith(shortBreakDurationSeconds: int.parse(v)),
                ),
              );
            },
          ),
          divider(),
          inputRow(
            'Preparation Warning',
            '${settings.preBreakWarningSeconds} sec',
            onTap: () {
              showPicker(
                context: context,
                title: 'Heads-up Notification',
                options: ['0', '10', '15', '20', '30', '45', '60'],
                suffix: ' sec',
                onSelected: (v) => onSave(
                  settings.copyWith(preBreakWarningSeconds: int.parse(v)),
                ),
              );
            },
          ),
          divider(),
          inputRow(
            'Long Break Every',
            '${settings.longBreakIntervalMinutes} min',
            onTap: () {
              showPicker(
                context: context,
                title: 'Long Break Interval',
                options: List.generate(46, (i) => '${15 + (i * 5)}'),
                suffix: ' min',
                onSelected: (v) => onSave(
                  settings.copyWith(longBreakIntervalMinutes: int.parse(v)),
                ),
              );
            },
          ),
          divider(),
          inputRow(
            'Long Break Duration',
            '${settings.longBreakDurationMinutes} min',
            onTap: () {
              showPicker(
                context: context,
                title: 'Long Break Duration',
                options: List.generate(30, (i) => '${i + 1}'),
                suffix: ' min',
                onSelected: (v) => onSave(
                  settings.copyWith(longBreakDurationMinutes: int.parse(v)),
                ),
              );
            },
          ),
        ]),
      ],
    );
  }
}
