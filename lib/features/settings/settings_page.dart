import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/settings/exercise_model.dart';
import 'package:standup/features/analytics/stats_model.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/core/utils/toast.dart';
import 'package:standup/features/companion/controllers/companion_overlay_controller.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/features/settings/widgets/general_section.dart';
import 'package:standup/features/settings/widgets/focus_section.dart';
import 'package:standup/features/settings/widgets/notifications_section.dart';
import 'package:standup/features/settings/widgets/about_section.dart';

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsModel _settings;
  late StatsModel _stats;
  int _selectedStatsTab = 3;

  int get _calculatedBreaks {
    switch (_selectedStatsTab) {
      case 0: // Today
        if (_stats.weeklyData.isNotEmpty) {
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          return _stats.weeklyData
              .firstWhere(
                (d) => d.date == today,
                orElse: () => _stats.weeklyData.last,
              )
              .breaksCompleted;
        }
        return 0;
      case 1: // Week
        return _stats.weeklyData.fold<int>(
          0,
          (sum, day) => sum + day.breaksCompleted,
        );
      case 2: // Month
      case 3: // All
      default:
        return _stats.breaksCompleted;
    }
  }

  int get _calculatedSkipped {
    switch (_selectedStatsTab) {
      case 0: // Today
        if (_stats.weeklyData.isNotEmpty) {
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          return _stats.weeklyData
              .firstWhere(
                (d) => d.date == today,
                orElse: () => _stats.weeklyData.last,
              )
              .breaksSkipped;
        }
        return 0;
      case 1: // Week
        return _stats.weeklyData.fold<int>(
          0,
          (sum, day) => sum + day.breaksSkipped,
        );
      case 2: // Month
      case 3: // All
      default:
        return _stats.breaksSkipped;
    }
  }

  double get _calculatedCompletionRate {
    final total = _calculatedBreaks + _calculatedSkipped;
    if (total == 0) return 0.0;
    return _calculatedBreaks / total;
  }

  @override
  void initState() {
    super.initState();
    final repo = Provider.of<SettingsRepository>(context, listen: false);
    final statsService = Provider.of<StatsService>(context, listen: false);
    _settings = repo.currentSettings;
    _stats = statsService.load();
  }

  void _save(SettingsModel updated) {
    try {
      setState(() => _settings = updated);
      final repo = Provider.of<SettingsRepository>(context, listen: false);
      repo.save(updated);
      Provider.of<BreakController>(context, listen: false).refreshSettings();
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to save settings: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final horizontalPadding = isSmallScreen ? 16.0 : 40.0;
        final verticalPadding = isSmallScreen ? 20.0 : 32.0;

        final content = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isSmallScreen ? double.infinity : 760,
              ),
              child: _buildContent(),
            ),
          ),
        );

        if (isSmallScreen) {
          return Scaffold(
            backgroundColor: AppTheme.contentBackground,
            body: content,
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.contentBackground,
          toolBar: ToolBar(
            title: Text(
              _sectionDisplayName(widget.section),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            titleWidth: 260,
            actions: [
              if (widget.section == 'Flash Reminder')
                ToolBarIconButton(
                  icon: const MacosIcon(CupertinoIcons.play_fill, size: 13),
                  label: 'Play demo',
                  showLabel: true,
                  onPressed: () {
                    final settings = sl<SettingsRepository>().currentSettings;
                    sl<TimerEngine>().triggerFlashDemo(
                      color: Color(settings.flashColorHex),
                      style: settings.flashStyle,
                      animation: settings.flashAnimationType,
                      intensity: settings.flashIntensity,
                      durationMs: settings.flashDurationMs,
                    );
                  },
                ),
            ],
          ),
          children: [
            ContentArea(builder: (context, scrollController) => content),
          ],
        );
      },
    );
  }

  String _sectionDisplayName(String section) {
    switch (section) {
      case 'Breaks & Profiles':
        return 'Breaks';
      case 'Intelligent Detection':
        return 'Focus mode';
      case 'Companion':
        return 'Desktop Companion';
      default:
        return section;
    }
  }

  Widget _buildContent() {
    switch (widget.section) {
      case 'General':
        return GeneralSection(settings: _settings, onSave: _save);
      case 'Flash Reminder':
        return _buildFlashReminder();
      case 'Breaks':
      case 'Breaks & Profiles':
      case 'Profiles':
        return _buildBreaks();
      case 'Intelligent Detection':
        return _buildIntelligentDetection();
      case 'Focus Mode':
        return FocusSection(settings: _settings, onSave: _save);
      case 'Notifications':
        return NotificationsSection(settings: _settings, onSave: _save);
      case 'Exercises':
        return _buildExercises();
      case 'Clock Out':
        return _buildClockOut();
      case 'About':
        return AboutSection(settings: _settings, onSave: _save);
      case 'Statistics':
        return _buildStatistics();
      case 'Companion':
        return _buildCompanion();
      default:
        return Center(
          child: Text(
            'Coming soon: ${widget.section}',
            style: AppTheme.tipStyle,
          ),
        );
    }
  }

  Widget _buildGeneral() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Application'),
        _buildCard([
          _buildListRow(
            'Launch at Startup',
            'Start BreakMate automatically when you log in',
            _settings.autoStart,
            CupertinoIcons.rocket,
            (v) async {
              _save(_settings.copyWith(autoStart: v));
              try {
                if (v) {
                  final result = await launchAtStartup.enable();
                  if (result && mounted) {
                    Toast.showSuccess(context, 'Will launch at startup');
                  } else if (mounted) {
                    Toast.showError(context, 'Launch at startup not available');
                  }
                } else {
                  final result = await launchAtStartup.disable();
                  if (result && mounted) {
                    Toast.showSuccess(context, 'Startup launch disabled');
                  } else if (mounted) {
                    Toast.showError(
                      context,
                      'Could not disable startup launch',
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Toast.showError(
                    context,
                    'Launch at startup requires macOS 10.10+',
                  );
                }
              }
            },
          ),
          _divider(),
          _buildListRow(
            'Menu Style',
            'Countdown display in the menu bar',
            null,
            CupertinoIcons.macwindow,
            null,
            trailing: _inlineDropdown(
              _settings.menuBarStyle,
              ['countdown', 'progress', 'icon', 'focusdot'],
              (v) {
                final style = v ?? 'countdown';
                _save(_settings.copyWith(menuBarStyle: style));
                sl<TimerEngine>().updateMenuStyle(style);
              },
            ),
          ),
          _divider(),
          _buildListRow(
            'Menu Bar Icon',
            'Choose default, cat, minimal, or countdown-only',
            null,
            CupertinoIcons.circle_grid_hex,
            null,
            trailing: _inlineDropdown(
              _settings.trayIconStyle,
              ['default', 'cat', 'minimal', 'countdown'],
              (v) {
                final style = v ?? 'cat';
                _save(_settings.copyWith(trayIconStyle: style));
                sl<TimerEngine>().updateMenuStyle(_settings.menuBarStyle);
                sl<TrayManagerService>().triggerActionAnimation();
              },
            ),
          ),
          _divider(),
          _buildListRow(
            'Flash Highlight',
            'Customize visual break reminder',
            null,
            CupertinoIcons.bolt_fill,
            null,
            onTap: () {
              sl<AppNavigationService>().openSection('Flash Reminder');
            },
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppTheme.accentColor,
            ),
          ),
          _divider(),
          _buildListRow(
            'Strict Mode',
            'No skipping breaks',
            _settings.strictMode,
            CupertinoIcons.lock_shield,
            (v) {
              _save(_settings.copyWith(strictMode: v));
              sl<TrayManagerService>().triggerActionAnimation();
            },
          ),
          _divider(),
          _buildListRow(
            'Multi-Display',
            'All screens coverage',
            true,
            CupertinoIcons.tv,
            (v) => sl<TrayManagerService>().triggerActionAnimation(),
          ),
        ]),
        const SizedBox(height: 48),
        _sectionHeader('Idle & Inactivity'),
        const SizedBox(height: 24),
        _buildCard([
          _inputRow(
            'Pause timer after',
            '${_settings.pauseTimerAfterMinutes} min',
            onTap: () => _showPicker(
              title: 'Pause timer after',
              options: ['1', '2', '3', '5', '10'],
              suffix: ' min',
              onSelected: (v) {
                _save(_settings.copyWith(pauseTimerAfterMinutes: int.parse(v)));
                sl<TrayManagerService>().triggerActionAnimation();
              },
            ),
          ),
          _divider(),
          _inputRow(
            'Reset timer after',
            '${_settings.resetTimerAfterMinutes} min',
            onTap: () => _showPicker(
              title: 'Reset timer after',
              options: ['5', '10', '15', '30', '60'],
              suffix: ' min',
              onSelected: (v) {
                _save(_settings.copyWith(resetTimerAfterMinutes: int.parse(v)));
                sl<TrayManagerService>().triggerActionAnimation();
              },
            ),
          ),
        ]),
        const SizedBox(height: 48),
        _sectionHeader('Working Hours'),
        const SizedBox(height: 24),
        _buildCard([
          _toggleRow(
            'Working Hours',
            'Specify on which days and at what time you want to use the app.',
            _settings.workingHoursEnabled,
            (v) => _save(_settings.copyWith(workingHoursEnabled: v)),
          ),
          if (_settings.workingHoursEnabled) ...[
            _divider(),
            _buildDaysToggle(),
            _divider(),
            _buildTimeSelector('Start Time', _settings.workStartTime),
            _divider(),
            _buildTimeSelector('End Time', _settings.workEndTime),
          ],
        ]),
      ],
    );
  }

  Widget _buildDaysToggle() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.asMap().entries.map((e) {
              final day = e.key + 1;
              final selected = _settings.workingDays.contains(day);
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
                      final days = List<int>.from(_settings.workingDays);
                      selected ? days.remove(day) : days.add(day);
                      days.sort();
                      _save(_settings.copyWith(workingDays: days));
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
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showPicker(
              title: label,
              options: _timeOptions(),
              suffix: '',
              onSelected: (v) {
                if (label.startsWith('Start')) {
                  _save(_settings.copyWith(workStartTime: v));
                } else {
                  _save(_settings.copyWith(workEndTime: v));
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

  List<String> _timeOptions() {
    return [
      for (var hour = 0; hour < 24; hour++)
        for (final minute in const [0, 30])
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    ];
  }

  int _breaksSubTab = 0;

  Widget _buildBreaks() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Break Configuration'),
            const SizedBox(height: 8),
            // Tab-like segmented control for sub-sections
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: isSmallScreen
                  ? Column(
                      children: [
                        Row(
                          children: [
                            _subTabButton('Profiles', 0, isSmall: true),
                            _subTabButton('Intervals', 1, isSmall: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _subTabButton('Appearance', 2, isSmall: true),
                            _subTabButton('Flash', 3, isSmall: true),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _subTabButton('Profiles', 0),
                        _subTabButton('Intervals', 1),
                        _subTabButton('Appearance', 2),
                        _subTabButton('Flash', 3),
                      ],
                    ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            if (_breaksSubTab == 0) _buildProfileSelector(),
            if (_breaksSubTab == 1) _buildCustomIntervals(),
            if (_breaksSubTab == 2) _buildAppearanceSettings(),
            if (_breaksSubTab == 3) _buildFlashReminder(),
          ],
        );
      },
    );
  }

  Widget _subTabButton(String label, int index, {bool isSmall = false}) {
    final isSelected = _breaksSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _breaksSubTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: isSmall ? 11 : 13,
                letterSpacing: -0.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomIntervals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Duration & Frequency'),
        _buildCard([
          _inputRow(
            'Short Break Every',
            '${_settings.shortBreakIntervalMinutes} min',
            onTap: () => _showPicker(
              title: 'Short Break Every',
              options: List.generate(60, (i) => (i + 1).toString()),
              suffix: ' min',
              onSelected: (v) => _save(
                _settings.copyWith(shortBreakIntervalMinutes: int.parse(v)),
              ),
            ),
          ),
          _divider(),
          _inputRow(
            'Short Break Duration',
            '${_settings.shortBreakDurationSeconds} sec',
            onTap: () => _showPicker(
              title: 'Short Break Duration',
              options: ['15', '20', '30', '45', '60', '90', '120'],
              suffix: ' sec',
              onSelected: (v) => _save(
                _settings.copyWith(shortBreakDurationSeconds: int.parse(v)),
              ),
            ),
          ),
          _divider(),
          _inputRow(
            'Long Break Every',
            '${_settings.longBreakIntervalMinutes} min',
            onTap: () => _showPicker(
              title: 'Long Break Every',
              options: ['30', '45', '60', '90', '120', '150', '180'],
              suffix: ' min',
              onSelected: (v) => _save(
                _settings.copyWith(longBreakIntervalMinutes: int.parse(v)),
              ),
            ),
          ),
          _divider(),
          _inputRow(
            'Long Break Duration',
            '${_settings.longBreakDurationMinutes} min',
            onTap: () => _showPicker(
              title: 'Long Break Duration',
              options: ['5', '10', '15', '20', '30'],
              suffix: ' min',
              onSelected: (v) => _save(
                _settings.copyWith(longBreakDurationMinutes: int.parse(v)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Clock Styles'),
        const SizedBox(height: 16),
        _buildStyleGrid(),
        const SizedBox(height: 24),
        // Preview Button
        Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showClockPreview(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.play_circle_fill,
                    size: 18,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Preview Current Style',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _sectionHeader('Colors & Effects'),
        const SizedBox(height: 16),
        _buildCard([
          _colorRow('Clock Text Color', Color(_settings.clockFaceTextColorHex)),
          _divider(),
          _sliderRow(
            'Background Blur',
            _settings.clockFaceBlurEnabled ? 1.0 : 0.0,
            (v) => _save(_settings.copyWith(clockFaceBlurEnabled: v > 0.5)),
            min: 0.0,
            max: 1.0,
          ),
          _divider(),
          _toggleRow(
            'Custom Wallpaper',
            'Use your own image background',
            _settings.customImagePath != null,
            (v) => _save(
              _settings.copyWith(customImagePath: v ? 'default_path' : null),
            ),
          ),
        ]),
      ],
    );
  }

  void _showClockPreview() {
    try {
      // Show a demo break overlay with current clock style
      final controller = sl<BreakController>();

      // Trigger a short preview break
      controller.timerEngine.triggerBreakNow(isLong: false);

      // Auto-hide after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (controller.timerEngine.activeBreak != null &&
            controller.timerEngine.countdownSeconds <= 10) {
          // Complete the break early if it's still the preview
          controller.skipCurrentBreak();
        }
      });

      if (mounted) {
        Toast.showSuccess(
          context,
          'Preview started! Break overlay will appear.',
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to start preview: ${e.toString()}');
      }
    }
  }

  Widget _buildFocusMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard([
          _toggleRow(
            'Enable Focus Mode',
            'Automatically block notifications during work',
            _settings.focusModeEnabled,
            (v) => _save(_settings.copyWith(focusModeEnabled: v)),
          ),
          _divider(),
          _toggleRow(
            'DND Integration',
            'Sync with macOS Do Not Disturb',
            false,
            (v) {},
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Focus Goals'),
        const Text(
          'Set a daily target for focused deep work.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _inputRow('Daily Goal', '4 hours'),
          _divider(),
          _inputRow('Session Length', '25 min'),
        ]),
      ],
    );
  }

  Widget _buildNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard([
          _toggleRow(
            'Enable Notifications',
            'Receive system-level notifications for breaks and reminders',
            _settings.notificationsEnabled,
            (v) => _save(_settings.copyWith(notificationsEnabled: v)),
          ),
          _divider(),
          _toggleRow(
            'Sound Effects',
            'Play a soft chime when break starts',
            _settings.soundEnabled,
            (v) => _save(_settings.copyWith(soundEnabled: v)),
          ),
          _divider(),
          _toggleRow(
            'Repeated Alerts',
            'Notify every 30 seconds if break is ignored',
            true,
            (v) {},
          ),
          _divider(),
          _toggleRow(
            'Dock Bounce',
            'Bounce the app icon on break start',
            false,
            (v) {},
          ),
          _divider(),
          _buildListRow(
            'Flash Notifications',
            'Full customization of visual alerts',
            null,
            CupertinoIcons.bolt,
            null,
            trailing: const MacosIcon(CupertinoIcons.chevron_right, size: 14),
          ),
        ]),
      ],
    );
  }

  Widget _buildIntelligentDetection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Smart Detection'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Automatically pauses your breaks when you are busy.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        _buildCard([
          _toggleRow(
            'Video Calls Detection',
            'Pause breaks during Zoom, Meet, Teams, etc.',
            _settings.detectVideoCalls,
            (v) => _save(_settings.copyWith(detectVideoCalls: v)),
          ),
          _divider(),
          _toggleRow(
            'Meeting Detection',
            'Sync with calendar to pause during meetings',
            _settings.detectMeetings,
            (v) => _save(_settings.copyWith(detectMeetings: v)),
          ),
          _divider(),
          _toggleRow(
            'Focus Mode Detection',
            'Respect macOS Do Not Disturb & Focus Modes',
            _settings.respectFocusMode,
            (v) => _save(_settings.copyWith(respectFocusMode: v)),
          ),
        ]),
      ],
    );
  }

  Widget _buildClockOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Balance'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Establish healthy boundaries with fixed rest hours.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        _buildCard([
          _toggleRow(
            'Workday Enforcement',
            'Remind me to clock out at end of day',
            _settings.enableClockOut,
            (v) => _save(_settings.copyWith(enableClockOut: v)),
          ),
          if (_settings.enableClockOut) ...[
            _divider(),
            _inputRow(
              'End Workday At',
              _settings.clockOutTime,
              onTap: () => _showPicker(
                title: 'End Workday',
                options: [
                  '16:00',
                  '16:30',
                  '17:00',
                  '17:30',
                  '18:00',
                  '18:30',
                  '19:00',
                ],
                suffix: '',
                onSelected: (v) => _save(_settings.copyWith(clockOutTime: v)),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildExercises() {
    final exercises = _settings.exercises.isEmpty
        ? ExerciseModel.defaults
        : _settings.exercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Custom Exercises'),
        const Text(
          'Create unlimited custom break routines targeting your specific needs.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Expanded(child: Text('Exercise Library')),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => _showExerciseEditor(),
                  child: const Text(
                    'Add Exercise',
                    style: TextStyle(color: AppTheme.accentColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          for (final exercise in exercises) ...[
            _divider(),
            _exerciseSettingsItem(exercise),
          ],
        ]),
      ],
    );
  }

  Widget _exerciseSettingsItem(ExerciseModel exercise) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _exerciseIcon(exercise.category),
            color: AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${exercise.durationSeconds}s • ${exercise.category.name} • ${exercise.instructions}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: exercise.enabled,
            activeTrackColor: AppTheme.accentColor,
            onChanged: (enabled) =>
                _upsertExercise(exercise.copyWith(enabled: enabled)),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showExerciseEditor(existing: exercise),
            child: const Icon(CupertinoIcons.pencil, size: 18),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _deleteExercise(exercise),
            child: const Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  IconData _exerciseIcon(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.eyeRest:
        return CupertinoIcons.eye;
      case ExerciseCategory.posture:
        return CupertinoIcons.person_crop_circle;
      case ExerciseCategory.breathing:
        return CupertinoIcons.wind;
      case ExerciseCategory.movement:
        return CupertinoIcons.arrow_2_circlepath;
      case ExerciseCategory.stretch:
        return CupertinoIcons.person_2;
    }
  }

  void _upsertExercise(ExerciseModel exercise) {
    final exercises = List<ExerciseModel>.from(
      _settings.exercises.isEmpty
          ? ExerciseModel.defaults
          : _settings.exercises,
    );
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index == -1) {
      exercises.add(exercise);
    } else {
      exercises[index] = exercise;
    }
    _save(_settings.copyWith(exercises: exercises));
  }

  void _deleteExercise(ExerciseModel exercise) {
    final exercises = List<ExerciseModel>.from(
      _settings.exercises.isEmpty
          ? ExerciseModel.defaults
          : _settings.exercises,
    )..removeWhere((e) => e.id == exercise.id);
    _save(_settings.copyWith(exercises: exercises));
  }

  void _showExerciseEditor({ExerciseModel? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final durationController = TextEditingController(
      text: (existing?.durationSeconds ?? 20).toString(),
    );
    final instructionsController = TextEditingController(
      text: existing?.instructions ?? '',
    );
    var category = existing?.category ?? ExerciseCategory.stretch;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
            content: Column(
              children: [
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: 'Title',
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: durationController,
                  placeholder: 'Duration seconds',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: instructionsController,
                  placeholder: 'Instructions',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (_) => CupertinoActionSheet(
                        actions: ExerciseCategory.values
                            .map(
                              (c) => CupertinoActionSheetAction(
                                onPressed: () {
                                  setDialogState(() => category = c);
                                  Navigator.pop(context);
                                },
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    );
                  },
                  child: Text('Category: ${category.name}'),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final title = titleController.text.trim();
                  final duration =
                      int.tryParse(durationController.text.trim()) ?? 20;
                  final instructions = instructionsController.text.trim();
                  if (title.isEmpty || instructions.isEmpty) return;
                  _upsertExercise(
                    ExerciseModel(
                      id:
                          existing?.id ??
                          'custom_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      durationSeconds: duration.clamp(5, 600),
                      category: category,
                      instructions: instructions,
                      enabled: existing?.enabled ?? true,
                    ),
                  );
                  Navigator.pop(context);
                },
                isDefaultAction: true,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 52),
        // ── App icon ──────────────────────────────────────────
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.infinite,
              color: Color(0xFF1C1C1E),
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // ── Two-toned app name ────────────────────────────────
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Break',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.6,
                  fontFamily: 'Satoshi',
                ),
              ),
              TextSpan(
                text: 'Mate',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentColor,
                  letterSpacing: -0.6,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Version badge ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.cardBackgroundElevated.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor, width: 0.5),
          ),
          child: const Text(
            'Version 1.0.0 (1)',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              fontFamily: 'Satoshi',
            ),
          ),
        ),
        const SizedBox(height: 52),
        // ── "Crafted with Care" section ───────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cleanCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crafted with Care',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Healthy work habits for everyone.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildAboutCard(
                      CupertinoIcons.globe,
                      'Website',
                      'Visit our home',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAboutCard(
                      CupertinoIcons.lock_shield,
                      'Privacy',
                      'Your data',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAboutCard(
                      CupertinoIcons.doc_text,
                      'Terms',
                      'Legal details',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildAboutCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackgroundElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accentColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashReminder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Flash Color'),
        const SizedBox(height: 24),
        _buildCard([_flashColorPicker()]),
        const SizedBox(height: 48),
        _sectionHeader('Choose Your Flash Style'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _stylePreview(
              'Default',
              _settings.flashStyle == 'default',
              () => _save(_settings.copyWith(flashStyle: 'default')),
            ),
            _stylePreview(
              'Photo Flash',
              _settings.flashStyle == 'photo',
              () => _save(_settings.copyWith(flashStyle: 'photo')),
            ),
            _stylePreview(
              'Stretch Cat',
              _settings.flashStyle == 'cat',
              () => _save(_settings.copyWith(flashStyle: 'cat')),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _sectionHeader('Flash Animation'),
        const SizedBox(height: 24),
        _buildCard([
          _dropdownRow(
            'Animation Type',
            _settings.flashAnimationType,
            ['pulse', 'glow', 'fade', 'dim', 'edge'],
            (v) {
              if (v != null) _save(_settings.copyWith(flashAnimationType: v));
            },
          ),
          _divider(),
          _sliderRow(
            'Intensity',
            _settings.flashIntensity,
            (v) => _save(_settings.copyWith(flashIntensity: v)),
            min: 0.0,
            max: 1.0,
          ),
          _divider(),
          _sliderRow(
            'Duration (s)',
            _settings.flashDurationMs / 1000,
            (v) =>
                _save(_settings.copyWith(flashDurationMs: (v * 1000).toInt())),
            min: 0.5,
            max: 10.0,
          ),
          _divider(),
          _textFieldRow(
            'Custom Message',
            _settings.flashMessage,
            (v) => _save(_settings.copyWith(flashMessage: v)),
          ),
        ]),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoButton(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                sl<TimerEngine>().triggerFlashDemo(
                  color: Color(_settings.flashColorHex),
                  style: _settings.flashStyle,
                  animation: _settings.flashAnimationType,
                  intensity: _settings.flashIntensity,
                  durationMs: _settings.flashDurationMs,
                );
              },
              child: const Text(
                'Play Demo Flash',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            CupertinoButton(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                _save(
                  _settings.copyWith(
                    flashColorHex: 0xFFF87171,
                    flashStyle: 'default',
                    flashMessage: 'Take a deep breath',
                    flashAnimationType: 'pulse',
                    flashIntensity: 0.5,
                    flashDurationMs: 2500,
                  ),
                );
              },
              child: const Text(
                'Reset to Defaults',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Statistics',
          subtitle: 'Detailed insights into your rest and work balance.',
        ),
        // ── Break Activity heatmap ─────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cleanCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Break Activity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 16),
              _buildHeatmapMonthLabels(),
              const SizedBox(height: 6),
              _buildHeatmapGrid(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Less',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(width: 4),
                      _heatSquare(AppTheme.cardBackgroundElevated),
                      const SizedBox(width: 3),
                      _heatSquare(
                        AppTheme.shortBreakColor.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 3),
                      _heatSquare(
                        AppTheme.shortBreakColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 3),
                      _heatSquare(AppTheme.shortBreakColor),
                      const SizedBox(width: 4),
                      const Text(
                        'More',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_calculatedBreaks breaks completed',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // ── Break Statistics card ──────────────────────────────
        _buildBreakStatisticsCard(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeatmapMonthLabels() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: months
          .map(
            (m) => Text(
              m,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textMuted,
                fontFamily: 'Satoshi',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHeatmapGrid() {
    // 5 rows × 52 columns
    final weeklyStats = _stats.weeklyData;
    final now = DateTime.now();
    return Column(
      children: List.generate(5, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: List.generate(52, (col) {
              final dayOffset = (51 - col) * 5 + (4 - row);
              final cellDate = now.subtract(Duration(days: dayOffset));
              final dateStr =
                  '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';

              final dayStats = weeklyStats
                  .where((d) => d.date == dateStr)
                  .firstOrNull;
              final hasActivity =
                  dayStats != null && dayStats.breaksCompleted > 0;
              final intensity = dayStats != null
                  ? (dayStats.breaksCompleted / 8).clamp(0.2, 1.0)
                  : 0.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? AppTheme.shortBreakColor.withValues(
                              alpha: intensity,
                            )
                          : AppTheme.cardBackgroundElevated.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _heatSquare(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBreakStatisticsCard() {
    return Container(
      decoration: AppTheme.cleanCardDecoration.copyWith(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Performance Metrics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Satoshi',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildSegmentedFilter(
                  ['Today', 'Week', 'Month', 'All'],
                  _selectedStatsTab,
                  (i) => setState(() => _selectedStatsTab = i),
                ),
              ],
            ),
          ),
          _statsMetricRow(
            CupertinoIcons.check_mark_circled,
            AppTheme.accentColor,
            'Total Breaks',
            'Completed rest sessions',
            '$_calculatedBreaks',
          ),
          _divider(),
          _statsMetricRow(
            CupertinoIcons.clock,
            AppTheme.shortBreakColor,
            'Short Breaks',
            'Quick micro-breaks',
            '${(_calculatedBreaks * 0.8).round()}',
          ),
          _divider(),
          _statsMetricRow(
            CupertinoIcons.pause_circle,
            AppTheme.longBreakColor,
            'Long Breaks',
            'Extended recovery rest',
            '${(_calculatedBreaks * 0.2).round()}',
          ),
          _divider(),
          _statsMetricRow(
            CupertinoIcons.chart_pie,
            AppTheme.upcomingBreakColor,
            'Completion Rate',
            'Success frequency',
            '${(_calculatedCompletionRate * 100).toInt()}%',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter(
    List<String> options,
    int selected,
    ValueChanged<int> onSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onSelected(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statsMetricRow(
    IconData icon,
    Color color,
    String label,
    String subtitle,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Satoshi',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: 'Satoshi',
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 0, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
              fontFamily: 'Satoshi',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppTheme.cleanCardDecoration.copyWith(
        color: AppTheme.cardBackground.withValues(alpha: 0.4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double min = 0.0,
    double max = 1.0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final padding = isSmallScreen ? 16.0 : 20.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isSmallScreen ? 13 : 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isSmallScreen ? 120 : 180,
                    child: CupertinoSlider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      onChanged: onChanged,
                      activeColor: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dropdownRow(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final padding = isSmallScreen ? 16.0 : 20.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: options.contains(value)
                          ? value
                          : (options.isNotEmpty ? options.first : null),
                      dropdownColor: const Color(0xFF1E1E1E),
                      icon: const Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: AppTheme.accentColor,
                      ),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Satoshi',
                      ),
                      onChanged: onChanged,
                      items: options.map<DropdownMenuItem<String>>((
                        String option,
                      ) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option.toUpperCase()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggleRow(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Satoshi',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _inputRow(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required String suffix,
    required ValueChanged<String> onSelected,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: options
            .map(
              (opt) => CupertinoActionSheetAction(
                onPressed: () {
                  onSelected(opt);
                  Navigator.pop(context);
                },
                child: Text('$opt$suffix'),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildListRow(
    String label,
    String subtitle,
    bool? value,
    IconData icon,
    ValueChanged<bool>? onChanged, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.accentColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (value != null)
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.accentColor,
            ),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing,
        ],
      ),
    );

    if (onTap != null) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _inlineDropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options.contains(value)
                ? value
                : (options.isNotEmpty ? options.first : null),
            dropdownColor: const Color(0xFF1E1E1E),
            icon: const Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: Colors.white54,
            ),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Satoshi',
            ),
            onChanged: onChanged,
            items: options.map<DropdownMenuItem<String>>((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option.toUpperCase()),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _textFieldRow(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: CupertinoTextField(
              placeholder: value,
              placeholderStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            width: 40,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flashColorPicker() {
    final colors = [
      0xFFEF4444,
      0xFFF59E0B,
      0xFFEAB308,
      0xFF22C55E,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFFEC4899,
      0xFF6B7280,
      0xFF000000,
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.map((c) {
          final isSelected = _settings.flashColorHex == c;
          return GestureDetector(
            onTap: () => _save(_settings.copyWith(flashColorHex: c)),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Color(c).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: AppTheme.textPrimary,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stylePreview(String name, bool isSelected, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 150;
        final width = isSmallScreen ? 100.0 : 140.0;
        final height = isSmallScreen ? 70.0 : 90.0;
        final iconSize = isSmallScreen ? 20.0 : 28.0;
        final fontSize = isSmallScreen ? 11.0 : 12.0;

        return GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: AppTheme.contentBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor
                        : AppTheme.borderColor,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    _buildStyleMock(name),
                    if (isSelected)
                      Center(
                        child: Icon(
                          Icons.check_circle,
                          color: AppTheme.accentColor,
                          size: iconSize,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.accentColor
                      : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: fontSize,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStyleMock(String name) {
    switch (name) {
      case 'BreakLoop':
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.shortBreakColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '00:20',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      case 'Desktop':
        return Column(
          children: [
            const Spacer(),
            Container(
              width: 60,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(height: 10, color: Colors.white.withValues(alpha: 0.05)),
          ],
        );
      case 'Ambient':
        return Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text(
                '12:00',
                style: TextStyle(fontSize: 10, color: Colors.white30),
              ),
            ),
          ),
        );
      case 'Focus':
        return Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      case 'Default': // Flash Style
        return Center(
          child: Container(
            width: 100,
            height: 60,
            color: Colors.red.withValues(alpha: 0.1),
          ),
        );
      case 'Photo Flash':
        return const Center(
          child: Icon(CupertinoIcons.photo, color: Colors.white12, size: 30),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildStyleGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700;

        if (isSmallScreen) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stylePreview(
                'BreakLoop',
                _settings.clockFaceStyle == 'breakloop',
                () => _save(_settings.copyWith(clockFaceStyle: 'breakloop')),
              ),
              _stylePreview(
                'Desktop',
                _settings.clockFaceStyle == 'desktop',
                () => _save(_settings.copyWith(clockFaceStyle: 'desktop')),
              ),
              _stylePreview(
                'Personal',
                _settings.clockFaceStyle == 'personal',
                () => _save(_settings.copyWith(clockFaceStyle: 'personal')),
              ),
              _stylePreview(
                'Ambient',
                _settings.clockFaceStyle == 'ambient',
                () => _save(_settings.copyWith(clockFaceStyle: 'ambient')),
              ),
              _stylePreview(
                'Focus',
                _settings.clockFaceStyle == 'focus',
                () => _save(_settings.copyWith(clockFaceStyle: 'focus')),
              ),
            ],
          );
        }

        return Row(
          children: [
            _stylePreview(
              'BreakLoop',
              _settings.clockFaceStyle == 'breakloop',
              () => _save(_settings.copyWith(clockFaceStyle: 'breakloop')),
            ),
            const SizedBox(width: 16),
            _stylePreview(
              'Desktop',
              _settings.clockFaceStyle == 'desktop',
              () => _save(_settings.copyWith(clockFaceStyle: 'desktop')),
            ),
            const SizedBox(width: 16),
            _stylePreview(
              'Personal',
              _settings.clockFaceStyle == 'personal',
              () => _save(_settings.copyWith(clockFaceStyle: 'personal')),
            ),
            const SizedBox(width: 16),
            _stylePreview(
              'Ambient',
              _settings.clockFaceStyle == 'ambient',
              () => _save(_settings.copyWith(clockFaceStyle: 'ambient')),
            ),
            const SizedBox(width: 16),
            _stylePreview(
              'Focus',
              _settings.clockFaceStyle == 'focus',
              () => _save(_settings.copyWith(clockFaceStyle: 'focus')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileSelector() {
    return _buildCard(
      BreakProfile.presets.map((p) {
        final isSelected = _settings.selectedProfileId == p.id;
        return Column(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Provider.of<BreakController>(
                  context,
                  listen: false,
                ).changeProfile(p);
                setState(
                  () => _settings = sl<SettingsRepository>().currentSettings,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.shortIntervalMinutes}m interval • ${p.shortDurationSeconds}s duration',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Colors.white24,
                      ),
                  ],
                ),
              ),
            ),
            if (p != BreakProfile.presets.last) _divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: AppTheme.separatorColor,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildCompanion() {
    final controller = sl<CompanionOverlayController>();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Desktop Companion'),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 24),
              child: Text(
                'Spawn a cute virtual pet that sits on your desktop, wanders around, and reacts to your focus and break sessions.',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
            _buildCard([
              _toggleRow(
                'Enable Desktop Companion',
                'Show or hide your desktop pet companion overlay',
                controller.companionEnabled,
                (v) => controller.toggleCompanion(v),
              ),
            ]),
            if (controller.companionEnabled) ...[
              const SizedBox(height: 32),
              _sectionHeader(controller.companionPetName),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Personalize your companion name and keep it synced with the desktop pet overlay.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              _buildCompanionNameField(controller),
              const SizedBox(height: 32),
              _sectionHeader('Companion Breed'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Choose the theme and look of your animated pet companion.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              _buildCompanionThemeDropdown(controller),
              const SizedBox(height: 32),
              _sectionHeader('Overlay Settings'),
              _buildCard([
                _sliderRow(
                  'Scale Factor (${controller.companionScale.toStringAsFixed(1)}x)',
                  controller.companionScale,
                  (v) {
                    final snapped = (v * 2.0).roundToDouble() / 2.0;
                    controller.changeScale(snapped);
                  },
                  min: 2.0,
                  max: 8.0,
                ),
                _divider(),
                _toggleRow(
                  'Ignore Mouse Clicks',
                  'Enable click-through mode so you can interact with windows behind the pet',
                  controller.companionClickThrough,
                  (v) => controller.changeClickThrough(v),
                ),
              ]),
              const SizedBox(height: 16),
              // Instant refresh button — forces a clean re-spawn with all current settings
              _buildCard([
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sync,
                        size: 18,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refresh Companion',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Re-spawn companion with all current settings applied instantly',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.refreshCompanion(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 32),
              _sectionHeader('Test Interactions'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Trigger instant animations to see how your pet reacts to different app states.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              _buildCompanionTestInteractions(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompanionThemeDropdown(CompanionOverlayController controller) {
    return _buildCard([
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text(
              'Selected Breed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.companionCatTheme,
                    dropdownColor: const Color(0xFF1E1E1E),
                    icon: const Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: AppTheme.accentColor,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        controller.changeTheme(newValue);
                      }
                    },
                    items: CatTheme.themes.map<DropdownMenuItem<String>>((theme) {
                      return DropdownMenuItem<String>(
                        value: theme.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_petSymbol(theme.id)),
                            const SizedBox(width: 8),
                            Text(theme.name),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  String _petSymbol(String themeId) {
    return {
      CatTheme.keyCollie,
      CatTheme.keyCorgi,
      CatTheme.keyDalmatian,
      CatTheme.keyHusky,
      CatTheme.keyLabrador,
      CatTheme.keyGoldie,
      CatTheme.keyRealisticGoldie,
    }.contains(themeId)
        ? '🐕'
        : '🐱';
  }

  Widget _buildCompanionNameField(CompanionOverlayController controller) {
    return _buildCard([
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pet Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Used in companion state and future pet messages',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 220,
              child: TextFormField(
                initialValue: controller.companionPetName,
                onChanged: controller.changePetName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                ),
                cursorColor: AppTheme.accentColor,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.accentColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCompanionTestInteractions() {
    final interactions = [
      {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
      {
        'label': 'Take Nap',
        'icon': CupertinoIcons.moon_zzz_fill,
        'state': 'sleep',
      },
      {
        'label': 'Jump',
        'icon': CupertinoIcons.arrow_up_circle_fill,
        'state': 'notification',
      },
      {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: interactions.map((inter) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            if (Platform.isMacOS) {
              await MacOSBridge.triggerCompanionState(inter['state'] as String);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  inter['icon'] as IconData,
                  size: 13,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  inter['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
