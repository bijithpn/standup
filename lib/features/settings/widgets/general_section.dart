import 'package:flutter/cupertino.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/core/utils/toast.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';

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
          _buildMenuStyle(),
          divider(),
          _buildMenuBarIcon(),
          _buildStrictMode(),
          divider(),
          _buildMultiDisplay(),
        ]),
        const SizedBox(height: 48),
        sectionHeader('Idle & Inactivity'),
        const SizedBox(height: 24),
        buildCard([
          _buildPauseTimer(context),
          divider(),
          _buildResetTimer(context),
        ]),
        const SizedBox(height: 48),
        sectionHeader('Working Hours'),
        const SizedBox(height: 24),
        buildCard([
          _buildWorkingHoursToggle(),
          if (settings.workingHoursEnabled) ...[
            divider(),
            _buildDaysToggle(),
            divider(),
            _buildTimeSelector(context, 'Start Time', settings.workStartTime),
            divider(),
            _buildTimeSelector(context, 'End Time', settings.workEndTime),
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
          if (v) {
            final result = await launchAtStartup.enable();
            if (result && context.mounted) {
              Toast.showSuccess(context, 'Will launch at startup');
            } else if (context.mounted) {
              Toast.showError(context, 'Launch at startup not available');
            }
          } else {
            final result = await launchAtStartup.disable();
            if (result && context.mounted) {
              Toast.showSuccess(context, 'Startup launch disabled');
            } else if (context.mounted) {
              Toast.showError(context, 'Could not disable startup launch');
            }
          }
        } catch (e) {
          if (context.mounted) {
            Toast.showError(context, 'Launch at startup requires macOS 10.10+');
          }
        }
      },
    );
  }

  Widget _buildMenuStyle() {
    return buildListRow(
      'Menu Style',
      'Countdown display in the menu bar',
      null,
      CupertinoIcons.macwindow,
      null,
      trailing: inlineDropdown(
        settings.menuBarStyle,
        ['countdown', 'progress', 'icon', 'focusdot'],
        (v) {
          final style = v ?? 'countdown';
          onSave(settings.copyWith(menuBarStyle: style));
          sl<TimerEngine>().updateMenuStyle(style);
        },
      ),
    );
  }

  Widget _buildMenuBarIcon() {
    final currentStyle = settings.trayIconStyle == 'cat'
        ? 'companion'
        : settings.trayIconStyle;
    return buildListRow(
      'Menu Bar Icon',
      'Choose default, companion, minimal, or countdown-only',
      null,
      CupertinoIcons.circle_grid_hex,
      null,
      trailing: inlineDropdown(
        currentStyle,
        ['default', 'companion', 'minimal', 'countdown'],
        (v) {
          final style = v ?? 'companion';
          onSave(settings.copyWith(trayIconStyle: style));
          sl<TimerEngine>().updateMenuStyle(settings.menuBarStyle);
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildStrictMode() {
    return buildListRow(
      'Strict Mode',
      'No skipping breaks',
      settings.strictMode,
      CupertinoIcons.lock_shield,
      (v) {
        onSave(settings.copyWith(strictMode: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }

  Widget _buildMultiDisplay() {
    return buildListRow(
      'Multi-Display',
      'All screens coverage',
      true,
      CupertinoIcons.tv,
      (v) => sl<TrayManagerService>().triggerActionAnimation(),
    );
  }

  Widget _buildPauseTimer(BuildContext context) {
    return inputRow(
      'Pause timer after',
      '${settings.pauseTimerAfterMinutes} min',
      onTap: () => showPicker(
        context: context,
        title: 'Pause timer after',
        options: ['1', '2', '3', '5', '10'],
        suffix: ' min',
        onSelected: (v) {
          onSave(settings.copyWith(pauseTimerAfterMinutes: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildResetTimer(BuildContext context) {
    return inputRow(
      'Reset timer after',
      '${settings.resetTimerAfterMinutes} min',
      onTap: () => showPicker(
        context: context,
        title: 'Reset timer after',
        options: ['5', '10', '15', '30', '60'],
        suffix: ' min',
        onSelected: (v) {
          onSave(settings.copyWith(resetTimerAfterMinutes: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
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

  Widget _buildTimeSelector(BuildContext context, String label, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => showPicker(
              context: context,
              title: label,
              options: timeOptions(),
              suffix: '',
              onSelected: (v) {
                if (label.startsWith('Start')) {
                  onSave(settings.copyWith(workStartTime: v));
                } else {
                  onSave(settings.copyWith(workEndTime: v));
                }
              },
            ),
            child: Text(
              time,
              style: const TextStyle(color: AppTheme.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
