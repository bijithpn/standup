import 'package:flutter/cupertino.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';

class FocusSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const FocusSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Focus Mode'),
        buildCard([
          _buildFocusModeToggle(),
          divider(),
          _buildShortBreakInterval(context),
          divider(),
          _buildShortBreakDuration(context),
          divider(),
          _buildLongBreakInterval(context),
          divider(),
          _buildLongBreakDuration(context),
        ]),
      ],
    );
  }

  Widget _buildFocusModeToggle() {
    return toggleRow(
      'Focus Mode',
      'Enable Pomodoro-style focus sessions',
      settings.focusModeEnabled,
      (v) => onSave(settings.copyWith(focusModeEnabled: v)),
    );
  }

  Widget _buildShortBreakInterval(BuildContext context) {
    return inputRow(
      'Short Break Interval',
      'Every ${settings.shortBreakIntervalMinutes} minutes',
      onTap: () => showPicker(
        context: context,
        title: 'Short Break Interval',
        options: ['10', '15', '20', '25', '30', '45', '60'],
        suffix: ' min',
        onSelected: (v) {
          onSave(settings.copyWith(shortBreakIntervalMinutes: int.parse(v)));
          sl<TimerEngine>().updateMenuStyle(settings.menuBarStyle);
        },
      ),
    );
  }

  Widget _buildShortBreakDuration(BuildContext context) {
    return inputRow(
      'Short Break Duration',
      '${settings.shortBreakDurationSeconds} seconds',
      onTap: () => showPicker(
        context: context,
        title: 'Short Break Duration',
        options: ['10', '15', '20', '30', '45', '60'],
        suffix: ' sec',
        onSelected: (v) {
          onSave(settings.copyWith(shortBreakDurationSeconds: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildLongBreakInterval(BuildContext context) {
    return inputRow(
      'Long Break Interval',
      'Every ${settings.longBreakIntervalMinutes} minutes',
      onTap: () => showPicker(
        context: context,
        title: 'Long Break Interval',
        options: ['30', '45', '60', '90', '120'],
        suffix: ' min',
        onSelected: (v) {
          onSave(settings.copyWith(longBreakIntervalMinutes: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildLongBreakDuration(BuildContext context) {
    return inputRow(
      'Long Break Duration',
      '${settings.longBreakDurationMinutes} minutes',
      onTap: () => showPicker(
        context: context,
        title: 'Long Break Duration',
        options: ['3', '5', '10', '15', '20', '30'],
        suffix: ' min',
        onSelected: (v) {
          onSave(settings.copyWith(longBreakDurationMinutes: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }
}
