import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/features/settings/widgets/menu_bar_mode_picker.dart';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';

class GeneralSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const GeneralSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Application'),
        buildCard([
          _buildLaunchAtStartup(context),
          divider(),
          _buildMenuBarDisplay(),
          // divider(),
          // _buildStrictMode(),
          divider(),
          _buildSessionResume(),
          divider(),
          _buildQuietModePresets(),
          divider(),
          _buildGlobalHotkey(),
        ]),
        const SizedBox(height: 48),
        sectionHeader('Idle & Inactivity'),
        const SizedBox(height: 24),
        buildCard([_buildPauseTimer(), divider(), _buildResetTimer()]),
        const SizedBox(height: 48),
        sectionHeader('Working Hours'),
        const SizedBox(height: 24),
        buildCard([
          _buildWorkingHoursToggle(),
          if (settings.workingHoursEnabled) ...[
            divider(),
            _buildDaysToggle(),
            divider(),
            _buildTimeSelector('Start Time', settings.workStartTime),
            divider(),
            _buildTimeSelector('End Time', settings.workEndTime),
          ],
        ]),
      ],
    );
  }

  Widget _buildLaunchAtStartup(BuildContext context) {
    return buildListRow(
      'Launch at Startup',
      'Start BreakMate automatically when you log in',
      settings.autoStart,
      CupertinoIcons.rocket,
      (v) async {
        onSave(settings.copyWith(autoStart: v));
        try {
          final ok = v
              ? await launchAtStartup.enable()
              : await launchAtStartup.disable();
          if (ok) {
            if (context.mounted) {
              Toast.showSuccess(
                context,
                v ? 'Will launch at startup' : 'Startup launch disabled',
              );
            }
            return;
          }
        } catch (_) {}
        // Couldn't change it: put the toggle back and tell the user.
        onSave(settings.copyWith(autoStart: !v));
        if (context.mounted) {
          await showCupertinoDialog<void>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Launch at Startup unavailable'),
              content: Text(
                v
                    ? "This feature can't be enabled on this system."
                    : "This feature can't be disabled on this system.",
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  // Windows tray uses a static .ico, so only the modes that work there show.
  static final _menuBarModes = Platform.isWindows
      ? const {'companion': 'Companion', 'countdown': 'Countdown timer'}
      : const {
          'companion': 'Companion',
          'progress': 'Progress ring',
          'focusdot': 'Focus dot',
          'countdown': 'Countdown timer',
          'minimal': 'Icon only',
        };

  String get _currentMenuBarMode {
    final mode = menuBarModeFromStyles(
      settings.trayIconStyle,
      settings.menuBarStyle,
    );
    return _menuBarModes.containsKey(mode) ? mode : 'countdown';
  }

  void _selectMenuBarMode(String mode) {
    final (:iconStyle, :menuStyle) = menuBarModeToStyles(mode);
    onSave(
      settings.copyWith(trayIconStyle: iconStyle, menuBarStyle: menuStyle),
    );
    sl<TrayManagerService>()
      ..setIconModeFromStyle(iconStyle)
      ..setMenuStyle(menuStyle)
      ..triggerActionAnimation();
    sl<TimerEngine>().updateMenuStyle(menuStyle);
  }

  Widget _buildMenuBarDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildListRow(
          'Menu Bar Display',
          'What the menu bar shows while your next break approaches',
          null,
          CupertinoIcons.macwindow,
          null,
        ),
        MenuBarModePicker(
          modes: _menuBarModes,
          selected: _currentMenuBarMode,
          onSelected: _selectMenuBarMode,
        ),
      ],
    );
  }

  // Widget _buildStrictMode() {
  //   return buildListRow(
  //     'Strict Mode',
  //     'No skipping breaks',
  //     settings.strictMode,
  //     CupertinoIcons.lock_shield,
  //     (v) {
  //       onSave(settings.copyWith(strictMode: v));
  //       sl<TrayManagerService>().triggerActionAnimation();
  //     },
  //   );
  // }

  Widget _buildQuietModePresets() {
    return buildListRow(
      'Quiet Mode Preset',
      'Choose a behavior for silences (e.g. Deep Work blocks all)',
      null,
      CupertinoIcons.moon_zzz,
      null,
      trailing: inlineDropdown(
        settings.quietModePreset,
        ['none', 'presenting', 'meeting', 'deep_work', 'low_battery'],
        (v) {
          onSave(settings.copyWith(quietModePreset: v ?? 'none'));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildGlobalHotkey() {
    final shortcutLabel = Platform.isMacOS ? '⌘⌥B' : 'Ctrl+Alt+B';
    return buildListRow(
      'Global Hotkey',
      'Press $shortcutLabel anywhere to take a break, or skip one already running',
      settings.globalHotkeyEnabled,
      CupertinoIcons.keyboard,
      (v) => onSave(settings.copyWith(globalHotkeyEnabled: v)),
    );
  }

  Widget _buildPauseTimer() {
    return buildListRow(
      'Pause timer after',
      'Inactivity time before pausing the timer',
      null,
      CupertinoIcons.pause_circle,
      null,
      trailing: inlineDropdown(
        '${settings.pauseTimerAfterMinutes} min',
        ['1 min', '2 min', '3 min', '5 min', '10 min'],
        (v) {
          if (v != null) {
            final mins = int.parse(v.replaceAll(' min', ''));
            onSave(settings.copyWith(pauseTimerAfterMinutes: mins));
            sl<TrayManagerService>().triggerActionAnimation();
          }
        },
      ),
    );
  }

  Widget _buildResetTimer() {
    return buildListRow(
      'Reset timer after',
      'Inactivity time before resetting progress',
      null,
      CupertinoIcons.refresh,
      null,
      trailing: inlineDropdown(
        '${settings.resetTimerAfterMinutes} min',
        ['5 min', '10 min', '15 min', '30 min', '60 min'],
        (v) {
          if (v != null) {
            final mins = int.parse(v.replaceAll(' min', ''));
            onSave(settings.copyWith(resetTimerAfterMinutes: mins));
            sl<TrayManagerService>().triggerActionAnimation();
          }
        },
      ),
    );
  }

  Widget _buildWorkingHoursToggle() {
    return toggleRow(
      'Working Hours',
      'Specify on which days and at what time you want to use the app.',
      settings.workingHoursEnabled,
      (v) => onSave(settings.copyWith(workingHoursEnabled: v)),
    );
  }

  Widget _buildDaysToggle() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 400;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.asMap().entries.map((e) {
              final day = e.key + 1;
              final selected = settings.workingDays.contains(day);
              return Column(
                children: [
                  Text(
                    e.value,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  TapTarget(
                    selected: selected,
                    onTap: () {
                      final days = List<int>.from(settings.workingDays);
                      selected ? days.remove(day) : days.add(day);
                      days.sort();
                      onSave(settings.copyWith(workingDays: days));
                    },
                    child: Container(
                      width: isSmall ? 24 : 28,
                      height: isSmall ? 24 : 28,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accentColor.withValues(alpha: 0.2)
                            : AppTheme.contentBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppTheme.accentColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          selected
                              ? CupertinoIcons.checkmark
                              : CupertinoIcons.minus,
                          size: isSmall ? 12 : 14,
                          color: selected
                              ? AppTheme.accentColor
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTimeSelector(String label, String time) {
    return buildListRow(
      label,
      label.startsWith('Start')
          ? 'When your workday begins'
          : 'When your workday ends',
      null,
      CupertinoIcons.clock,
      null,
      trailing: inlineDropdown(time, timeOptions(), (v) {
        if (v != null) {
          if (label.startsWith('Start')) {
            onSave(settings.copyWith(workStartTime: v));
          } else {
            onSave(settings.copyWith(workEndTime: v));
          }
        }
      }),
    );
  }

  Widget _buildSessionResume() {
    return buildListRow(
      'Resume Progress',
      'Continue from where you left off on app restart (same day only)',
      settings.enableSessionResume,
      CupertinoIcons.arrow_counterclockwise,
      (v) {
        onSave(settings.copyWith(enableSessionResume: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }
}
