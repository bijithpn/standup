import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_model.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/analytics/widgets/stats_chart.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/core/utils/toast.dart';

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsModel _settings;
  late StatsModel _stats;

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
        final isSmallScreen = constraints.maxWidth < 700;
        final horizontalPadding = isSmallScreen ? 16.0 : 48.0;
        final verticalPadding = isSmallScreen ? 24.0 : 40.0;
        return MacosScaffold(
          backgroundColor: AppTheme.contentBackground,
          toolBar: ToolBar(
            title: Text(widget.section),
            titleWidth: isSmallScreen ? 120 : 200,
            actions: [
              if (widget.section == 'Flash Reminder')
                ToolBarIconButton(
                  icon: const MacosIcon(CupertinoIcons.play_fill, size: 14),
                  label: isSmallScreen ? '' : 'Play demo',
                  showLabel: !isSmallScreen,
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
            ContentArea(
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? double.infinity : 800,
                    ),
                    child: _buildContent(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent() {
    switch (widget.section) {
      case 'General':
        return _buildGeneral();
      case 'Flash Reminder':
        return _buildFlashReminder();
      case 'Breaks':
      case 'Breaks & Profiles':
      case 'Profiles':
        return _buildBreaks();
      case 'Intelligent Detection':
        return _buildIntelligentDetection();
      case 'Focus Mode':
        return _buildFocusMode();
      case 'Notifications':
        return _buildNotifications();
      case 'Exercises':
        return _buildExercises();
      case 'Clock Out':
        return _buildClockOut();
      case 'About':
        return _buildAbout();
      case 'Statistics':
        return _buildStatistics();
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
        _buildCard([
          _buildListRow(
            'Startup',
            'Run at login',
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
                    Toast.showError(context, 'Could not disable startup launch');
                  }
                }
              } catch (e) {
                if (mounted) {
                  Toast.showError(context, 'Launch at startup requires macOS 10.10+');
                }
              }
            },
          ),
          _divider(),
          _buildListRow(
            'Menu Style',
            'Custom tray look',
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
          _divider(),
          _buildListRow(
            'Flash Highlight',
            'Customize visual break reminder',
            null,
            CupertinoIcons.bolt_fill,
            null,
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
            (v) => _save(_settings.copyWith(strictMode: v)),
          ),
          _divider(),
          _buildListRow(
            'Multi-Display',
            'All screens coverage',
            true,
            CupertinoIcons.tv,
            (v) {},
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
              onSelected: (v) => _save(
                _settings.copyWith(pauseTimerAfterMinutes: int.parse(v)),
              ),
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
              onSelected: (v) => _save(
                _settings.copyWith(resetTimerAfterMinutes: int.parse(v)),
              ),
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
            _buildTimeSelector('Start Time', '09:00'),
            _divider(),
            _buildTimeSelector('End Time', '18:00'),
          ],
        ]),
      ],
    );
  }

  Widget _buildDaysToggle() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.asMap().entries.map((e) {
          final isWeekend = e.key > 4;
          return Column(
            children: [
              Text(e.value, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isWeekend
                      ? AppTheme.contentBackground
                      : AppTheme.accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: isWeekend ? AppTheme.borderColor : AppTheme.accentColor),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.checkmark,
                    size: 14,
                    color: isWeekend ? AppTheme.textMuted : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
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
            onPressed: () {},
            child: Text(time, style: const TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
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
            SizedBox(height: isSmallScreen ? 16 : 24),
            // Tab-like segmented control for sub-sections
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                border: Border.all(color: AppTheme.borderColor),
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
            SizedBox(height: isSmallScreen ? 20 : 32),
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
          padding: EdgeInsets.symmetric(vertical: isSmall ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isSmall ? 11 : 13,
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
    return _buildCard([
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
          onSelected: (v) =>
              _save(_settings.copyWith(longBreakIntervalMinutes: int.parse(v))),
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
          onSelected: (v) =>
              _save(_settings.copyWith(longBreakDurationMinutes: int.parse(v))),
        ),
      ),
    ]);
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
            color: AppTheme.accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            borderRadius: BorderRadius.circular(12),
            onPressed: () => _showClockPreview(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.play_fill, size: 16),
                SizedBox(width: 8),
                Text(
                  'Preview Current Clock Style',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

  Widget _exerciseItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: const Text('Try', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligentDetection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Smart Pausing'),
        const Text(
          'DeskRest automatically pauses your breaks when you are busy.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
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
        _sectionHeader('Clock Out Enforcement'),
        const Text(
          'Break the cycle of endless workdays. Set your ideal rest hours.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildCard([
          _toggleRow(
            'Enable Clock Out',
            'Enforce end of workday',
            _settings.enableClockOut,
            (v) => _save(_settings.copyWith(enableClockOut: v)),
          ),
          if (_settings.enableClockOut) ...[
            _divider(),
            _inputRow(
              'End of day at',
              _settings.clockOutTime,
              onTap: () => _showPicker(
                title: 'End Workday',
                options: ['16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00'],
                suffix: '',
                onSelected: (v) => _save(_settings.copyWith(clockOutTime: v)),
              ),
            ),
          ]
        ]),
      ],
    );
  }

  Widget _buildExercises() {
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No custom exercises yet.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    Toast.showSuccess(context, 'Custom exercises coming in next update!');
                  },
                  child: const Text('Add Exercise', style: TextStyle(color: AppTheme.accentColor, fontSize: 13)),
                ),
              ],
            ),
          )
        ]),
      ],
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor,
                AppTheme.accentColor.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: Icon(CupertinoIcons.infinite, color: Colors.white, size: 40)),
        ),
        const SizedBox(height: 24),
        const Text(
          'BreakMate',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Text(
          'Version 1.2.0',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 40),
        _buildCard([
          _listTile('Website', CupertinoIcons.globe, () {}),
          _divider(),
          _listTile('Support', CupertinoIcons.question_circle, () {}),
        ]),
        const SizedBox(height: 40),
        const Text(
          'Made with ❤️ by Bijith for a healthier workspace',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _listTile(String title, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14))),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white24),
          ],
        ),
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
        Row(
          children: [
            _stylePreview(
              'Default',
              _settings.flashStyle == 'default',
              () => _save(_settings.copyWith(flashStyle: 'default')),
            ),
            const SizedBox(width: 24),
            _stylePreview(
              'Photo Flash',
              _settings.flashStyle == 'photo',
              () => _save(_settings.copyWith(flashStyle: 'photo')),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _sectionHeader('Flash Animation'),
        const SizedBox(height: 24),
        _buildCard([
          _dropdownRow('Animation Type', _settings.flashAnimationType, ['pulse', 'glow', 'fade', 'dim', 'edge'], (v) {
            if (v != null) _save(_settings.copyWith(flashAnimationType: v));
          }),
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
          _textFieldRow('Custom Message', _settings.flashMessage, (v) => _save(_settings.copyWith(flashMessage: v))),
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
                  color: Colors.white,
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
        _sectionHeader('Daily Progress'),
        const SizedBox(height: 16),
        DailyStatsChart(stats: _stats),
        const SizedBox(height: 32),
        _buildStatsCard(),
      ],
    );
  }

  // Helper Widgets
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTheme.sectionTitle,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppTheme.glassCardDecoration,
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
        final padding = isSmallScreen ? 12.0 : 16.0;

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
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isSmallScreen ? 120 : 200,
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

  Widget _dropdownRow(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final padding = isSmallScreen ? 12.0 : 16.0;
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: 6,
                ),
                color: AppTheme.contentBackground,
                borderRadius: BorderRadius.circular(6),
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (BuildContext context) => CupertinoActionSheet(
                      actions: options
                          .map(
                            (o) => CupertinoActionSheetAction(
                              onPressed: () {
                                onChanged(o);
                                Navigator.pop(context);
                              },
                              child: Text(o),
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
                },
                child: Text(
                  value.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: isSmallScreen ? 11 : 13,
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
      padding: const EdgeInsets.all(20),
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
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.accentColor,
              size: 20,
            ),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (value != null)
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.accentColor,
            ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _inlineDropdown(String value, List<String> options, ValueChanged<String?> onChanged) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) => CupertinoActionSheet(
            actions: options.map((o) => CupertinoActionSheetAction(
              onPressed: () {
                onChanged(o);
                Navigator.pop(context);
              },
              child: Text(o),
            )).toList(),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDefaultAction: true,
              child: const Text('Cancel'),
            ),
          ),
        );
      },
      child: Text(
        value.toUpperCase(),
        style: const TextStyle(color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textFieldRow(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          Expanded(
            child: CupertinoTextField(
              placeholder: value,
              placeholderStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: BoxDecoration(
                color: AppTheme.contentBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderColor),
              ),
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
                      color: Colors.white,
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
              const Text('00:20', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
        );
      case 'Desktop':
        return Column(
          children: [
            const Spacer(),
            Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
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
            child: const Center(child: Text('12:00', style: TextStyle(fontSize: 10, color: Colors.white30))),
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
        return const Center(child: Icon(CupertinoIcons.photo, color: Colors.white12, size: 30));
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
                      ? AppTheme.accentColor.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
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
                      size: 22,
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
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.shortIntervalMinutes}m / ${p.shortDurationSeconds}s',
                            style: TextStyle(
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
                        color: AppTheme.accentColor,
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

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: AppTheme.borderColor);

  Widget _buildStatsCard() {
    final rate = (_stats.completionRate * 100).toStringAsFixed(0);
    return _buildCard([
      _statRow('Breaks completed', '${_stats.breaksCompleted}'),
      _divider(),
      _statRow('Breaks skipped', '${_stats.breaksSkipped}'),
      _divider(),
      _statRow('Break completion rate', '$rate%'),
      _divider(),
      _statRow('Today total usage', '${_stats.dailyUsageMinutes} min'),
    ]);
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
