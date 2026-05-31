import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'dart:ui';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';

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
  String? _hoveredId;

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
    final currentColor = Color(_settings.clockFaceTextColorHex);
    final currentOpacity = currentColor.a;
    final baseColor = currentColor.withValues(alpha: 1.0);

    final colorPresets = [
      (color: const Color(0xFFF4F4F5), name: 'Pure Zinc'),
      (color: const Color(0xFFEF4444), name: 'Crimson Ember'),
      (color: const Color(0xFF38BDF8), name: 'Ocean Depth'),
      (color: const Color(0xFF34D399), name: 'Emerald Jade'),
      (color: const Color(0xFFF97316), name: 'Sunset Orange'),
      (color: const Color(0xFFC084FC), name: 'Radiant Purple'),
      (color: const Color(0xFFF59E0B), name: 'Amber Glow'),
      (color: const Color(0xFFFFFFFF), name: 'Contrast White'),
    ];

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
        sectionHeader(
          'Colors & Customization',
          subtitle: 'Fine-tune clock accent colors, text opacity, and blur intensity.',
        ),
        const SizedBox(height: 16),
        buildCard([
          // Custom color swatches row
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.color_filter, size: 16, color: AppTheme.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'Clock Face Theme Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: colorPresets.map((preset) {
                    final isSelected = baseColor.toARGB32() == preset.color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        final newColorHex = preset.color.withValues(alpha: currentOpacity).toARGB32();
                        _save(_settings.copyWith(clockFaceTextColorHex: newColorHex));
                      },
                      child: Tooltip(
                        message: preset.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: preset.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentColor
                                  : Colors.white.withValues(alpha: 0.15),
                              width: isSelected ? 3.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: preset.color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : [],
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    CupertinoIcons.checkmark,
                                    size: 14,
                                    color: Colors.black87,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          divider(),
          // Fine-grained Opacity Customizer
          sliderRow(
            'Clock Text Opacity',
            currentOpacity,
            (v) {
              final newColorHex = baseColor.withValues(alpha: v).toARGB32();
              _save(_settings.copyWith(clockFaceTextColorHex: newColorHex));
            },
            min: 0.2,
            max: 1.0,
          ),
          divider(),
          // Background Blur
          sliderRow(
            'Background Blur Intensity',
            _settings.clockFaceBlurEnabled ? 1.0 : 0.0,
            (v) => _save(_settings.copyWith(clockFaceBlurEnabled: v > 0.5)),
            min: 0.0,
            max: 1.0,
          ),
          divider(),
          toggleRow(
            'Custom Wallpaper Background',
            'Use high-fidelity static image backdrop',
            _settings.customImagePath != null,
            (v) async {
              if (v) {
                try {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  );
                  if (result != null && result.files.single.path != null) {
                    _save(_settings.copyWith(customImagePath: result.files.single.path));
                    if (mounted) {
                      Toast.showSuccess(context, 'Custom wallpaper background updated!');
                    }
                  } else {
                    // Do nothing if they cancel, or leave it off if it was off
                  }
                } catch (e) {
                  if (mounted) {
                    Toast.showError(context, 'Failed to select image: ${e.toString()}');
                  }
                }
              } else {
                _save(_settings.copyWith(customImagePath: null));
              }
            },
          ),
          if (_settings.customImagePath != null) ...[
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
                          'Wallpaper Path',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _settings.customImagePath!,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (File(_settings.customImagePath!).existsSync())
                    Container(
                      width: 50,
                      height: 35,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        image: DecorationImage(
                          image: FileImage(File(_settings.customImagePath!)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  MinimalButton(
                    backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                        );
                        if (result != null && result.files.single.path != null) {
                          _save(_settings.copyWith(customImagePath: result.files.single.path));
                          if (mounted) {
                            Toast.showSuccess(context, 'Wallpaper updated!');
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          Toast.showError(context, 'Failed to select image: ${e.toString()}');
                        }
                      }
                    },
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

        return ScrollConfiguration(
          behavior: DesktopDragScrollBehavior(),
          child: SingleChildScrollView(
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
    return _BreakTemplateRealPreview(id: id, settings: _settings);
  }

  Widget _breakTemplatePreview(
    String name,
    String id,
    String description,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isHovered = _hoveredId == id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredId = id),
      onExit: (_) => setState(() => _hoveredId = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isHovered ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 190,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.contentBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor
                          : isHovered
                              ? AppTheme.accentColor.withValues(alpha: 0.5)
                              : AppTheme.borderColor.withValues(alpha: 0.8),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : isHovered
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        _buildBreakTemplateMock(id),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black45,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: AppTheme.accentColor,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.accentColor
                      : isHovered
                          ? Colors.white
                          : AppTheme.textPrimary.withValues(alpha: 0.9),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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

class _BreakTemplateRealPreview extends StatefulWidget {
  final String id;
  final SettingsModel settings;

  const _BreakTemplateRealPreview({required this.id, required this.settings});

  @override
  State<_BreakTemplateRealPreview> createState() => _BreakTemplateRealPreviewState();
}

class _BreakTemplateRealPreviewState extends State<_BreakTemplateRealPreview>
    with TickerProviderStateMixin {
  late AnimationController _kenBurnsController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breakInfo = BreakModel(
      type: BreakType.short,
      durationSeconds: 300,
      title: widget.id == 'activities' ? 'Activity Room' : 'Eye Rest',
      tip: widget.id == 'zen'
          ? 'Slowly breathe in as the visual cue expands...'
          : 'Look away at something 20 feet away.',
      triggerReason: '20-minute focus threshold',
    );

    Widget templateWidget;

    switch (widget.id) {
      case 'classic':
        templateWidget = ClassicSlideshowTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 200,
          totalSeconds: 300,
          onSkip: () {},
          pageController: _pageController,
          kenBurnsController: _kenBurnsController,
          singleImage: AppConstants.wellnessSlideshow.first,
        );
        break;
      case 'companion':
        templateWidget = CompanionInteractiveTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 150,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
      case 'zen':
        templateWidget = ZenModeTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 180,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
      case 'hud':
        templateWidget = ProductivityHudTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 120,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
      case 'floating':
        templateWidget = SoftFloatingWidgetTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 100,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
      case 'activities':
        templateWidget = ActivitiesBreakTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 240,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
      case 'minimal':
      default:
        templateWidget = MinimalFocusTemplate(
          breakInfo: breakInfo,
          settings: widget.settings,
          remainingSeconds: 200,
          totalSeconds: 300,
          onSkip: () {},
        );
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1000,
            height: 650,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(1000, 650),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              child: Theme(
                data: ThemeData.dark(),
                child: templateWidget,
              ),
            ),
          ),
        );
      },
    );
  }
}

class DesktopDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
