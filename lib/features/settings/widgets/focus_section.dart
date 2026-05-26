import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';

class FocusSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const FocusSection({super.key, required this.settings, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Focus Mode'),
        buildCard([
          _buildFocusModeToggle(),
          divider(),
          _buildShortBreakInterval(),
          divider(),
          _buildShortBreakDuration(),
          divider(),
          _buildLongBreakInterval(),
          divider(),
          _buildLongBreakDuration(),
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

  Widget _buildShortBreakInterval() {
    return buildListRow(
      'Short Break Interval',
      'How often to take short breaks',
      null,
      CupertinoIcons.timer,
      null,
      trailing: inlineDropdown(
        '${settings.shortBreakIntervalMinutes} min',
        ['10 min', '15 min', '20 min', '25 min', '30 min', '45 min', '60 min'],
        (v) {
          if (v != null) {
            final mins = int.parse(v.replaceAll(' min', ''));
            onSave(settings.copyWith(shortBreakIntervalMinutes: mins));
            sl<TimerEngine>().updateMenuStyle(settings.menuBarStyle);
          }
        },
      ),
    );
  }

  Widget _buildShortBreakDuration() {
    return buildListRow(
      'Short Break Duration',
      'How long short breaks last',
      null,
      CupertinoIcons.hourglass,
      null,
      trailing: inlineDropdown(
        '${settings.shortBreakDurationSeconds} sec',
        ['10 sec', '15 sec', '20 sec', '30 sec', '45 sec', '60 sec'],
        (v) {
          if (v != null) {
            final secs = int.parse(v.replaceAll(' sec', ''));
            onSave(settings.copyWith(shortBreakDurationSeconds: secs));
            sl<TrayManagerService>().triggerActionAnimation();
          }
        },
      ),
    );
  }

  Widget _buildLongBreakInterval() {
    return buildListRow(
      'Long Break Interval',
      'How often to take long breaks',
      null,
      CupertinoIcons.timer_fill,
      null,
      trailing: inlineDropdown(
        '${settings.longBreakIntervalMinutes} min',
        ['30 min', '45 min', '60 min', '90 min', '120 min'],
        (v) {
          if (v != null) {
            final mins = int.parse(v.replaceAll(' min', ''));
            onSave(settings.copyWith(longBreakIntervalMinutes: mins));
            sl<TrayManagerService>().triggerActionAnimation();
          }
        },
      ),
    );
  }

  Widget _buildLongBreakDuration() {
    return buildListRow(
      'Long Break Duration',
      'How long long breaks last',
      null,
      CupertinoIcons.hourglass_bottomhalf_fill,
      null,
      trailing: inlineDropdown(
        '${settings.longBreakDurationMinutes} min',
        ['3 min', '5 min', '10 min', '15 min', '20 min', '30 min'],
        (v) {
          if (v != null) {
            final mins = int.parse(v.replaceAll(' min', ''));
            onSave(settings.copyWith(longBreakDurationMinutes: mins));
            sl<TrayManagerService>().triggerActionAnimation();
          }
        },
      ),
    );
  }
}
