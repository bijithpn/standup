import 'dart:math' as dart_math;

import 'package:breakmate/features/analytics/presentation/widgets/wellness_score_card.dart';
import 'package:breakmate/features/analytics/widgets/productivity_wellness_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:breakmate/features/settings/widgets/general_section.dart';
import 'package:breakmate/features/settings/widgets/focus_section.dart';
import 'package:breakmate/features/settings/widgets/notifications_section.dart';
import 'package:breakmate/features/settings/widgets/about_section.dart';
import 'package:breakmate/features/settings/widgets/update_section.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

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
            actions: [],
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
        return 'Companion';
      default:
        return section;
    }
  }

  Widget _buildContent() {
    switch (widget.section) {
      case 'General':
        return GeneralSection(settings: _settings, onSave: _save);

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
      case 'Updates':
        return UpdateSection(settings: _settings, onSave: _save);
      case 'About':
        return AboutSection(settings: _settings, onSave: _save);
      case 'Statistics':
        return Consumer<StatsService>(
          builder: (context, statsService, _) {
            _stats = statsService.load();
            return _buildStatistics();
          },
        );
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

  int _breaksSubTab = 0;
  int _statsSubTab = 0;

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
                            _subTabButton('Controls', 4, isSmall: true),
                            _subTabButton('Appearance', 2, isSmall: true),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _subTabButton('Profiles', 0),
                        _subTabButton('Intervals', 1),
                        _subTabButton('Controls', 4),
                        _subTabButton('Appearance', 2),
                      ],
                    ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            if (_breaksSubTab == 0) _buildProfileSelector(),
            if (_breaksSubTab == 1) _buildCustomIntervals(),
            if (_breaksSubTab == 2) _buildAppearanceSettings(),

            if (_breaksSubTab == 4) _buildBreakManualControls(),
          ],
        );
      },
    );
  }

  Widget _buildBreakManualControls() {
    final controller = Provider.of<BreakController>(context);
    final isPaused = controller.isPaused;
    final isBreak = controller.isBreakActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Display Options'),
        _buildCard([
          _toggleRow(
            'Show on All Displays',
            'Dim all monitors when taking a break.',
            _settings.showOnAllDisplays,
            (val) {
              _save(_settings.copyWith(showOnAllDisplays: val));
            },
          ),
          _divider(),
          _toggleRow(
            'Show Exercises During Break',
            'Display a random exercise on the break screen.',
            _settings.showExercisesInBreak,
            (val) {
              _save(_settings.copyWith(showExercisesInBreak: val));
            },
          ),
          _divider(),
          _toggleRow(
            'Play LoFi Music During Break',
            'Play relaxing LoFi music when on break.',
            _settings.playMusicDuringBreak,
            (val) {
              _save(_settings.copyWith(playMusicDuringBreak: val));
            },
          ),
          _divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Break Template Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Select the background for your break screen.',
                        style: TextStyle(
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
                AppDropdown<String>(
                  value: _settings.breakTheme,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _save(_settings.copyWith(breakTheme: newValue));
                    }
                  },
                  items: const [
                    AppDropdownItem(value: 'random', label: 'RANDOM THEME'),
                    AppDropdownItem(value: 'image', label: 'NATURE IMAGES'),
                    AppDropdownItem(value: 'ocean', label: 'OCEAN WAVES'),
                    AppDropdownItem(value: 'forest', label: 'FOREST CANOPY'),
                    AppDropdownItem(value: 'minimal', label: 'MINIMAL GLOW'),
                    AppDropdownItem(value: 'sunset', label: 'SUNSET (NEW)'),
                    AppDropdownItem(value: 'nebula', label: 'NEBULA (NEW)'),
                    AppDropdownItem(value: 'midnight', label: 'MIDNIGHT (NEW)'),
                    AppDropdownItem(
                      value: 'cyberpunk',
                      label: 'CYBERPUNK (NEW)',
                    ),
                    AppDropdownItem(value: 'zen', label: 'ZEN GARDEN (NEW)'),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Manual Controls'),
        _buildCard([
          _actionRow(
            label: isPaused ? 'Timer is Paused' : 'Timer is Running',
            subtitle: isPaused
                ? 'Resume to continue your focus session.'
                : 'Pause if you need to step away for a moment.',
            buttonText: isPaused ? 'Resume' : 'Pause',
            buttonColor: isPaused
                ? AppTheme.accentColor
                : AppTheme.longBreakColor,
            onPressed: () => controller.togglePause(),
          ),
          _divider(),
          _actionRow(
            label: 'Take Break Now',
            subtitle: 'Manually trigger a rest session immediately.',
            buttonText: 'Start Break',
            buttonColor: AppTheme.accentColor,
            onPressed: isBreak ? null : () => controller.takeBreakNow(),
          ),
          _divider(),
          _actionRow(
            label: isBreak ? 'Skip Current Break' : 'Skip Next Break',
            subtitle: isBreak
                ? 'End the active break session early.'
                : 'Bypass the upcoming scheduled rest.',
            buttonText: 'Skip',
            buttonColor: Colors.white.withValues(alpha: 0.1),
            textColor: Colors.white,
            onPressed: () {
              if (isBreak) {
                controller.skipCurrentBreak();
              } else {
                controller.skipNextBreak();
              }
            },
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Connected Displays'),
        ListenableBuilder(
          listenable: sl<DisplayController>(),
          builder: (context, _) {
            final displays = sl<DisplayController>().displays;
            if (displays.isEmpty) {
              return _buildCard([
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No external displays detected or plugin not fully initialized.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ]);
            }
            return _buildCard(
              displays.map((display) {
                return _actionRow(
                  label: display.id,
                  subtitle:
                      'Resolution: ${display.width.toInt()}x${display.height.toInt()} • Primary: ${display.isPrimary}',
                  buttonText: 'Active',
                  buttonColor: AppTheme.accentColor.withValues(alpha: 0.2),
                  textColor: AppTheme.accentColor,
                  onPressed: () {},
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _actionRow({
    required String label,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    Color? textColor,
    VoidCallback? onPressed,
  }) {
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
          MinimalButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: buttonColor,
            disabledColor: buttonColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            onPressed: onPressed,
            child: Text(
              buttonText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor ?? Colors.white,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subTabButton(
    String label,
    int index, {
    bool isSmall = false,
    int? currentTab,
    ValueChanged<int>? onTabChanged,
  }) {
    final selectedIdx = currentTab ?? _breaksSubTab;
    final isSelected = selectedIdx == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onTabChanged != null) {
            onTabChanged(index);
          } else {
            setState(() => _breaksSubTab = index);
          }
        },
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isSmall ? 10 : 12,
                letterSpacing: -0.1,
                fontFamily: 'Satoshi',
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
            '',
            trailing: _inlineDropdown(
              '${_settings.shortBreakIntervalMinutes} min',
              List.generate(180, (i) => '${i + 1} min'),
              (v) {
                if (v != null) {
                  _save(
                    _settings.copyWith(
                      shortBreakIntervalMinutes: int.parse(
                        v.replaceAll(' min', ''),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          _divider(),
          _inputRow(
            'Short Break Duration',
            '',
            trailing: _inlineDropdown(
              '${_settings.shortBreakDurationSeconds} sec',
              [
                ...List.generate(12, (i) => '${(i + 1) * 5} sec'),
                '75 sec',
                '90 sec',
                '120 sec',
                '180 sec',
                '300 sec',
              ],
              (v) {
                if (v != null) {
                  _save(
                    _settings.copyWith(
                      shortBreakDurationSeconds: int.parse(
                        v.replaceAll(' sec', ''),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          _divider(),
          _inputRow(
            'Heads-up Before Break',
            'Show a small wrap-up reminder before the overlay opens.',
            trailing: _inlineDropdown(
              '${_settings.preBreakWarningSeconds} sec',
              [
                '0 sec',
                '10 sec',
                '15 sec',
                '20 sec',
                '30 sec',
                '45 sec',
                '60 sec',
              ],
              (v) {
                if (v != null) {
                  _save(
                    _settings.copyWith(
                      preBreakWarningSeconds: int.parse(
                        v.replaceAll(' sec', ''),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          _divider(),
          _inputRow(
            'Long Break Every',
            '',
            trailing: _inlineDropdown(
              '${_settings.longBreakIntervalMinutes} min',
              List.generate(46, (i) => '${15 + (i * 5)} min'),
              (v) {
                if (v != null) {
                  _save(
                    _settings.copyWith(
                      longBreakIntervalMinutes: int.parse(
                        v.replaceAll(' min', ''),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          _divider(),
          _inputRow(
            'Long Break Duration',
            '',
            trailing: _inlineDropdown(
              '${_settings.longBreakDurationMinutes} min',
              List.generate(30, (i) => '${i + 1} min'),
              (v) {
                if (v != null) {
                  _save(
                    _settings.copyWith(
                      longBreakDurationMinutes: int.parse(
                        v.replaceAll(' min', ''),
                      ),
                    ),
                  );
                }
              },
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
        _sectionHeader('Break Templates'),
        const SizedBox(height: 16),
        _buildBreakTemplateGrid(),
        const SizedBox(height: 24),
        // Preview Button
        Center(
          child: MinimalButton(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            onPressed: () => _showBreakTemplatePreview(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.play_circle_fill,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 10),
                Text(
                  'Preview Current Template',
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

  void _showBreakTemplatePreview() {
    try {
      // Show a demo break overlay with current template style
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
              '',
              trailing: _inlineDropdown(
                _settings.clockOutTime,
                ['16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00'],
                (v) {
                  if (v != null) {
                    _save(_settings.copyWith(clockOutTime: v));
                  }
                },
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
                MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => _showExerciseEditor(),
                  child: Text(
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
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: exercise.enabled,
              activeTrackColor: AppTheme.accentColor,
              onChanged: (enabled) =>
                  _upsertExercise(exercise.copyWith(enabled: enabled)),
            ),
          ),
          MinimalButton(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            onPressed: () => _showExerciseEditor(existing: exercise),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          MinimalButton(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
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
                MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  isSecondary: true,
                  onPressed: () {
                    _showPicker(
                      title: 'Select Category',
                      options: ExerciseCategory.values
                          .map((c) => c.name)
                          .toList(),
                      suffix: '',
                      onSelected: (v) {
                        setDialogState(() {
                          category = ExerciseCategory.values.firstWhere(
                            (c) => c.name == v,
                          );
                        });
                      },
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

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Statistics',
          subtitle: 'Detailed insights into your rest and work balance.',
        ),

        // Tab-like segmented control for stats
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _subTabButton(
                'Overview',
                0,
                currentTab: _statsSubTab,
                onTabChanged: (i) => setState(() => _statsSubTab = i),
              ),
              _subTabButton(
                'Wellness Dashboard',
                1,
                currentTab: _statsSubTab,
                onTabChanged: (i) => setState(() => _statsSubTab = i),
              ),
            ],
          ),
        ),

        if (_statsSubTab == 0) ...[
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
        ] else
          _buildWellnessDashboard(),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWellnessDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WellnessScoreCard(
          productivityScore: _stats.productivityScore,
          wellnessScore: _stats.wellnessScore,
        ),
        const SizedBox(height: 24),
        ProductivityWellnessChart(stats: _stats),
        const SizedBox(height: 24),
        _buildCard([
          _statsMetricRow(
            CupertinoIcons.heart_circle,
            const Color(0xFF10B981),
            'Wellness Actions',
            'Stretches and eye rests recorded',
            '${_stats.totalWellnessActions}',
          ),
          _divider(),
          _statsMetricRow(
            CupertinoIcons.graph_square,
            AppTheme.accentColor,
            'Productivity Focus',
            'Estimated active work minutes',
            '${_stats.dailyUsageMinutes}',
          ),
        ]),
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
    // Pre-map for O(1) lookup performance (avoids O(N^2) total lookups in the grid)
    final statsMap = {for (var s in weeklyStats) s.date: s};

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

              final dayStats = statsMap[dateStr];
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
                    child: Transform.scale(
                      scale: 0.85,
                      alignment: Alignment.centerRight,
                      child: MinimalSlider(
                        value: value.clamp(min, max),
                        min: min,
                        max: max,
                        onChanged: onChanged,
                        activeColor: AppTheme.accentColor,
                      ),
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
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: AppTheme.accentColor,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputRow(
    String label,
    String value, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
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
          if (trailing != null)
            trailing
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                      style: TextStyle(
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

  Widget _inlineDropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return AppDropdown<String>(
      value: options.contains(value)
          ? value
          : (options.isNotEmpty ? options.first : ''),
      onChanged: onChanged,
      items: options
          .map(
            (option) => AppDropdownItem<String>(value: option, label: option),
          )
          .toList(),
    );
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required String suffix,
    required ValueChanged<String> onSelected,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 320,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        return InkWell(
                          onTap: () {
                            onSelected(opt);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Center(
                              child: Text(
                                '$opt$suffix',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
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

  Widget _buildBreakTemplateGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700;

        final templates = [
          (
            id: 'classic',
            name: 'Gallery Focus',
            desc: 'Image-backed rest view with a compact progress panel.',
          ),
          (
            id: 'minimal',
            name: 'Quiet Grid',
            desc: 'Fast-loading custom dial with low-stimulus geometry.',
          ),
          (
            id: 'companion',
            name: 'Companion Dock',
            desc: 'Draggable companion layer with a clean command rail.',
          ),
          (
            id: 'zen',
            name: 'Breath Lines',
            desc: 'Minimal breathing guide on a quiet lined surface.',
          ),
          (
            id: 'hud',
            name: 'Signal HUD',
            desc: 'Telemetry-style timer using static grid rendering.',
          ),
          (
            id: 'floating',
            name: 'Floating Dock',
            desc: 'Snappable compact overlay with lazy companion loading.',
          ),
        ];

        if (isSmallScreen) {
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: templates.map((t) {
              return _breakTemplatePreview(
                t.name,
                t.id,
                t.desc,
                _settings.breakTemplate == t.id,
                () => _save(_settings.copyWith(breakTemplate: t.id)),
              );
            }).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: templates.map((t) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _breakTemplatePreview(
                  t.name,
                  t.id,
                  t.desc,
                  _settings.breakTemplate == t.id,
                  () => _save(_settings.copyWith(breakTemplate: t.id)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _breakTemplatePreview(
    String name,
    String id,
    String description,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.contentBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentColor
                      : AppTheme.borderColor.withValues(alpha: 0.8),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    _buildBreakTemplateMock(id),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.accentColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Satoshi',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                fontSize: 10.5,
                height: 1.3,
                fontFamily: 'Satoshi',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakTemplateMock(String id) {
    switch (id) {
      case 'minimal':
        return Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.6),
                    width: 3.5,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '05:00',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'companion':
        return Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black38)),
            Positioned(
              top: 20,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: const Text(
                  'Time to stretch! 🐾',
                  style: TextStyle(fontSize: 8, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Icon(
                CupertinoIcons.paw_solid,
                size: 22,
                color: AppTheme.accentColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        );
      case 'zen':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
            ),
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.wind,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case 'hud':
        return Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 35,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Container(
                    width: 15,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(CupertinoIcons.bolt_fill, size: 8, color: Colors.amber),
                  SizedBox(width: 2),
                  Text(
                    'HUD ACTIVE',
                    style: TextStyle(
                      fontSize: 6,
                      color: Colors.white30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 'floating':
        return Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black26)),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 65,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const Text(
                      '04:59 SKIP',
                      style: TextStyle(
                        fontSize: 6,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
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
                        ? AppTheme.accentColor
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
            _sectionHeader('Companion'),
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
                'Enable Companion',
                'Show or hide your desktop pet companion overlay',
                controller.companionEnabled,
                (v) => controller.toggleCompanion(v),
              ),
            ]),
            if (controller.companionEnabled) ...[
              const SizedBox(height: 32),
              _sectionHeader('Companion'),
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
                _divider(),
                _toggleRow(
                  'Follow Mouse Cursor',
                  'Let the pet companion follow and chase your mouse cursor dynamically',
                  controller.companionFollowMouse,
                  (v) => controller.changeFollowMouse(v),
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
                      Icon(Icons.sync, size: 18, color: AppTheme.accentColor),
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
              _buildCompanionTestInteractions(controller),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Companion',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pet: ${controller.companionPetName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
            const Spacer(),
            AppDropdown<String>(
              value: controller.companionPetTheme,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  controller.changeTheme(newValue);
                }
              },
              items: PetTheme.themes.map((theme) {
                final species = theme.species;
                final isSelected = controller.companionPetTheme == theme.id;

                Color tagColor = Colors.orange;
                switch (species) {
                  case PetSpecies.dog:
                    tagColor = Colors.blue;
                    break;
                  case PetSpecies.rabbit:
                    tagColor = Colors.pink;
                    break;
                  case PetSpecies.fox:
                    tagColor = Colors.deepOrange;
                    break;
                  case PetSpecies.dragon:
                    tagColor = Colors.red;
                    break;
                  case PetSpecies.cat:
                    tagColor = Colors.orange;
                    break;
                }

                return AppDropdownItem<String>(
                  value: theme.id,
                  label: theme.name,
                  customChild: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          species.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: tagColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                final currentTheme = PetTheme.getTheme(
                  controller.companionPetTheme,
                );
                final species = currentTheme.species;
                final random = dart_math.Random();
                final List<String> names;
                switch (species) {
                  case PetSpecies.dog:
                    names = CompanionOverlayController.dogNames;
                    break;
                  case PetSpecies.rabbit:
                    names = CompanionOverlayController.rabbitNames;
                    break;
                  case PetSpecies.fox:
                    names = CompanionOverlayController.foxNames;
                    break;
                  case PetSpecies.dragon:
                    names = CompanionOverlayController.dragonNames;
                    break;
                  case PetSpecies.cat:
                    names = CompanionOverlayController.catNames;
                    break;
                }
                final randomName = names[random.nextInt(names.length)];
                controller.changePetName(randomName);
              },
              child: Icon(
                CupertinoIcons.refresh_bold,
                size: 14,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // Decoupled species validation is handled dynamically via PetTheme.getTheme(themeId).species

  Widget _buildCompanionTestInteractions(
    CompanionOverlayController controller,
  ) {
    final themeId = controller.companionPetTheme;
    final petTheme = PetTheme.getTheme(themeId);
    final species = petTheme.species;

    final List<Map<String, dynamic>> interactions;

    if (themeId == PetTheme.keyPixelCat) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Attack Mode',
          'icon': CupertinoIcons.shield_fill,
          'state': 'angry',
        },
        {
          'label': 'Alert Jump',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Sad Hurt',
          'icon': CupertinoIcons.bandage_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate Jump',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyLargeCat) {
      interactions = [
        {'label': 'Run Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Sad Fall',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Jump Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyCat1 ||
        themeId == PetTheme.keyCat2 ||
        themeId == PetTheme.keyCat4 ||
        themeId == PetTheme.keyCat5 ||
        themeId == PetTheme.keyCat6 ||
        themeId == PetTheme.keyRabbit) {
      interactions = [
        {
          'label': species == PetSpecies.rabbit ? 'Hop Around' : 'Walk Around',
          'icon': CupertinoIcons.paw,
          'state': 'walk',
        },
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Celebrate Stretch',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': species == PetSpecies.rabbit ? 'Nose Twitch' : 'Angry Itch',
          'icon': CupertinoIcons.ant_fill,
          'state': 'angry',
        },
        {
          'label': species == PetSpecies.rabbit ? 'Perk Ears' : 'Meow Alert',
          'icon': CupertinoIcons.chat_bubble_2_fill,
          'state': 'notification',
        },
        {
          'label': 'Lick Paw',
          'icon': CupertinoIcons.heart_fill,
          'state': 'lick1',
        },
        {
          'label': 'Lick Fur',
          'icon': CupertinoIcons.sparkles,
          'state': 'lick2',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyCat3) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Celebrate Stretch',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': 'Angry Meow',
          'icon': CupertinoIcons.chat_bubble_2_fill,
          'state': 'angry',
        },
        {
          'label': 'Meow Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Lick Paw',
          'icon': CupertinoIcons.heart_fill,
          'state': 'lick1',
        },
        {
          'label': 'Lick Fur',
          'icon': CupertinoIcons.sparkles,
          'state': 'lick2',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (species == PetSpecies.dog) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Sad Whimper',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate Jump',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': 'Bark Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Angry Growl',
          'icon': CupertinoIcons.flame_fill,
          'state': 'angry',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else {
      // Fox, Dragon, etc.
      interactions = [
        {
          'label': species == PetSpecies.dragon ? 'Glide / Fly' : 'Walk Around',
          'icon': CupertinoIcons.paw,
          'state': 'walk',
        },
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Sad Pout',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': species == PetSpecies.dragon
              ? 'Breathe Fire'
              : 'Hiss / Angry',
          'icon': CupertinoIcons.flame_fill,
          'state': 'angry',
        },
        {
          'label': 'Jump Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: interactions.map((inter) {
        return _buildInteractionButton(
          inter['label'] as String,
          inter['icon'] as IconData,
          inter['state'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildInteractionButton(String label, IconData icon, String state) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        await NativeBridge.triggerCompanionState(state);
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
            Icon(icon, size: 13, color: AppTheme.accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
