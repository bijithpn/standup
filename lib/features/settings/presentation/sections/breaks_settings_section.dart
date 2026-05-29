import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/features/settings/break_profile.dart';

class BreaksSettingsSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreaksSettingsSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BreaksSettingsSection> createState() => _BreaksSettingsSectionState();
}

class _BreaksSettingsSectionState extends State<BreaksSettingsSection> {
  int _breaksSubTab = 0;

  SettingsModel get _settings => widget.settings;
  void _save(SettingsModel s) => widget.onSave(s);

  @override
  Widget build(BuildContext context) {
    return _buildBreaks();
  }

  Widget _buildBreaks() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'Break Configuration',
              subtitle: 'Customize your rhythm, focus intensity, and break aesthetics.',
            ),
            const SizedBox(height: 12),
            
            // Modern segmented control for sub-sections
            segmentedControl(
              ['Profiles', 'Custom', 'Intensity', 'Themes'],
              _breaksSubTab,
              (i) => setState(() => _breaksSubTab = i),
              isSmall: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            if (_breaksSubTab == 0) _buildProfileSelector(),
            if (_breaksSubTab == 1) _buildCustomIntervals(),
            if (_breaksSubTab == 2) _buildBreakManualControls(),
            if (_breaksSubTab == 3) _buildAppearanceSettings(),
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
        sectionHeader('Break Intensity'),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Strictness Level',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Gentle allows easy skips; Locked requires full focus.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AppDropdown<String>(
                  value: _settings.intensityLevel,
                  onChanged: (v) {
                    if (v != null) {
                      _save(_settings.copyWith(intensityLevel: v));
                    }
                  },
                  items: const [
                    AppDropdownItem(value: 'gentle', label: 'GENTLE'),
                    AppDropdownItem(value: 'standard', label: 'STANDARD'),
                    AppDropdownItem(value: 'strict', label: 'STRICT'),
                    AppDropdownItem(value: 'locked', label: 'LOCKED'),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        sectionHeader('Display Options'),
        buildCard([
          toggleRow(
            'Show on All Displays',
            'Dim all monitors when taking a break.',
            _settings.showOnAllDisplays,
            (val) {
              _save(_settings.copyWith(showOnAllDisplays: val));
            },
          ),
          divider(),
          toggleRow(
            'Show Exercises During Break',
            'Display a random exercise on the break screen.',
            _settings.showExercisesInBreak,
            (val) {
              _save(_settings.copyWith(showExercisesInBreak: val));
            },
          ),
          divider(),
          toggleRow(
            'Play LoFi Music During Break',
            'Play relaxing LoFi music when on break.',
            _settings.playMusicDuringBreak,
            (val) {
              _save(_settings.copyWith(playMusicDuringBreak: val));
            },
          ),
          divider(),
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
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Select the background for your break screen.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0,
                          fontFamily: 'Inter',
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
        const SizedBox(height: 16),
        sectionHeader('Manual Controls'),
        buildCard([
          actionRow(
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
          divider(),
          actionRow(
            label: 'Take Break Now',
            subtitle: 'Manually trigger a rest session immediately.',
            buttonText: 'Start Break',
            buttonColor: AppTheme.accentColor,
            onPressed: isBreak ? null : () => controller.takeBreakNow(),
          ),
          divider(),
          actionRow(
            label: isBreak ? 'Skip Current Break' : 'Skip Next Break',
            subtitle: isBreak
                ? 'End the active break session early.'
                : 'Bypass the upcoming scheduled rest.',
            buttonText: 'Skip',
            buttonColor: AppTheme.textSecondary,
            onPressed: () {
              if (isBreak) {
                controller.skipCurrentBreak();
              } else {
                controller.skipNextBreak();
              }
            },
          ),
        ]),
        const SizedBox(height: 16),
        sectionHeader('Connected Displays'),
        ListenableBuilder(
          listenable: sl<DisplayController>(),
          builder: (context, _) {
            final displays = sl<DisplayController>().displays;
            if (displays.isEmpty) {
              return buildCard([
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No external displays detected or plugin not fully initialized.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ]);
            }
            return buildCard(
              displays.map((display) {
                return actionRow(
                  label: display.id,
                  subtitle:
                      'Resolution: ${display.width.toInt()}x${display.height.toInt()} • Primary: ${display.isPrimary}',
                  buttonText: 'Active',
                  buttonColor: AppTheme.accentColor,
                  onPressed: () {},
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomIntervals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Custom Rhythm',
          subtitle: 'Fine-tune your break frequency and duration for maximum productivity.',
        ),
        buildCard([
          inputRow(
            'Short Break Every',
            '${_settings.shortBreakIntervalMinutes} min',
            onTap: () {
               showPicker(
                context: context,
                title: 'Short Break Interval',
                options: List.generate(180, (i) => '${i + 1}'),
                suffix: ' min',
                onSelected: (v) => _save(_settings.copyWith(shortBreakIntervalMinutes: int.parse(v))),
              );
            },
          ),
          divider(),
          inputRow(
            'Short Break Duration',
            '${_settings.shortBreakDurationSeconds} sec',
             onTap: () {
               showPicker(
                context: context,
                title: 'Short Break Duration',
                options: [
                  ...List.generate(12, (i) => '${(i + 1) * 5}'),
                  '75', '90', '120', '180', '300',
                ],
                suffix: ' sec',
                onSelected: (v) => _save(_settings.copyWith(shortBreakDurationSeconds: int.parse(v))),
              );
            },
          ),
          divider(),
          inputRow(
            'Preparation Warning',
            '${_settings.preBreakWarningSeconds} sec',
             onTap: () {
               showPicker(
                context: context,
                title: 'Heads-up Notification',
                options: ['0', '10', '15', '20', '30', '45', '60'],
                suffix: ' sec',
                onSelected: (v) => _save(_settings.copyWith(preBreakWarningSeconds: int.parse(v))),
              );
            },
          ),
          divider(),
          inputRow(
            'Long Break Every',
            '${_settings.longBreakIntervalMinutes} min',
             onTap: () {
               showPicker(
                context: context,
                title: 'Long Break Interval',
                options: List.generate(46, (i) => '${15 + (i * 5)}'),
                suffix: ' min',
                onSelected: (v) => _save(_settings.copyWith(longBreakIntervalMinutes: int.parse(v))),
              );
            },
          ),
          divider(),
          inputRow(
            'Long Break Duration',
            '${_settings.longBreakDurationMinutes} min',
             onTap: () {
               showPicker(
                context: context,
                title: 'Long Break Duration',
                options: List.generate(30, (i) => '${i + 1}'),
                suffix: ' min',
                onSelected: (v) => _save(_settings.copyWith(longBreakDurationMinutes: int.parse(v))),
              );
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Break Templates'),
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
        sectionHeader('Colors & Effects'),
        const SizedBox(height: 16),
        buildCard([
          colorRow('Clock Text Color', Color(_settings.clockFaceTextColorHex)),
          divider(),
          sliderRow(
            'Background Blur',
            _settings.clockFaceBlurEnabled ? 1.0 : 0.0,
            (v) => _save(_settings.copyWith(clockFaceBlurEnabled: v > 0.5)),
            min: 0.0,
            max: 1.0,
          ),
          divider(),
          toggleRow(
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
          (
            id: 'activities',
            name: 'Activity Studio',
            desc: 'Guided breathing & eye sync exercises for active recovery.',
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

  Widget _buildProfileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Recommended Presets',
          subtitle: 'Choose a scientifically-backed rhythm for your work day.',
        ),
        buildCard(
          BreakProfile.presets.map((p) {
            final isSelected = _settings.selectedProfileId == p.id;
            return Column(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      Provider.of<BreakController>(
                        context,
                        listen: false,
                      ).changeProfile(p);
                      _save(_settings.copyWith(selectedProfileId: p.id));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppTheme.accentColor.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? CupertinoIcons.checkmark_alt
                                  : _getProfileIcon(p.id),
                              color: isSelected
                                  ? AppTheme.accentColor
                                  : AppTheme.textMuted,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isSelected
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.shortIntervalMinutes}m interval • ${p.shortDurationSeconds}s duration',
                                  style: TextStyle(
                                    color: isSelected 
                                        ? AppTheme.textSecondary.withValues(alpha: 0.7) 
                                        : AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (p != BreakProfile.presets.last) divider(),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getProfileIcon(String id) {
    switch (id) {
      case 'balanced': return CupertinoIcons.infinite;
      case 'deep_work': return CupertinoIcons.flame;
      case 'pomodoro': return CupertinoIcons.timer;
      default: return CupertinoIcons.layers;
    }
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
      case 'activities':
        return Container(
          color: const Color(0xFF070A0D),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Segmented tab mock
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.wind,
                            size: 7,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Breathe',
                            style: TextStyle(
                              fontSize: 6,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.eye,
                            size: 7,
                            color: Colors.white54,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Eye Sync',
                            style: TextStyle(
                              fontSize: 6,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Breathing ring mock
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7DD3FC).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'In',
                      style: TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox();
    }
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
                fontFamily: 'Inter',
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
                fontFamily: 'Inter',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
}
