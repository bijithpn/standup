import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

class BreakAppearanceSettings extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreakAppearanceSettings({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BreakAppearanceSettings> createState() =>
      _BreakAppearanceSettingsState();
}

class _BreakAppearanceSettingsState extends State<BreakAppearanceSettings> {
  String? _hoveredId;
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = widget.settings.breakTemplate;
  }

  @override
  void didUpdateWidget(covariant BreakAppearanceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.breakTemplate != widget.settings.breakTemplate) {
      _selectedTemplateId = widget.settings.breakTemplate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = Color(widget.settings.clockFaceTextColorHex);
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
        // Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MinimalButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              onPressed: () => _showBreakTemplatePreview(_selectedTemplateId),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.play_circle_fill,
                    size: 14,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preview Selected',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final bool hasChanges =
                    _selectedTemplateId != widget.settings.breakTemplate;
                return MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.accentColor,
                  disabledColor: AppTheme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: hasChanges
                      ? () {
                          widget.onSave(
                            widget.settings.copyWith(
                              breakTemplate: _selectedTemplateId,
                            ),
                          );
                          Toast.showSuccess(
                            context,
                            'Template updated successfully!',
                          );
                        }
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 14,
                        color: hasChanges
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Update Template',
                        style: TextStyle(
                          color: hasChanges
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        sectionHeader(
          'Colors & Customization',
          subtitle:
              'Fine-tune clock accent colors, text opacity, and blur intensity.',
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
                    Icon(
                      CupertinoIcons.color_filter,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
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
                    final isSelected =
                        baseColor.toARGB32() == preset.color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        final newColorHex = preset.color
                            .withValues(alpha: currentOpacity)
                            .toARGB32();
                        widget.onSave(
                          widget.settings.copyWith(
                            clockFaceTextColorHex: newColorHex,
                          ),
                        );
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
                                      color: preset.color.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
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
              widget.onSave(
                widget.settings.copyWith(clockFaceTextColorHex: newColorHex),
              );
            },
            min: 0.2,
            max: 1.0,
          ),
          divider(),
          // Background Blur
          sliderRow(
            'Background Blur Intensity',
            widget.settings.clockFaceBlurEnabled ? 1.0 : 0.0,
            (v) => widget.onSave(
              widget.settings.copyWith(clockFaceBlurEnabled: v > 0.5),
            ),
            min: 0.0,
            max: 1.0,
          ),
          divider(),
          toggleRow(
            'Custom Wallpaper Background',
            'Use high-fidelity static image backdrop during breaks',
            widget.settings.customImagePath != null &&
                !widget.settings.customImagePath!.startsWith("disabled:"),
            (v) async {
              if (v) {
                if (widget.settings.customImagePath != null &&
                    widget.settings.customImagePath!.startsWith("disabled:")) {
                  // Re-enable existing path by removing the prefix
                  final actualPath = widget.settings.customImagePath!.substring(
                    9,
                  );
                  widget.onSave(
                    widget.settings.copyWith(customImagePath: actualPath),
                  );
                  if (!context.mounted) return;
                  Toast.showSuccess(
                    context,
                    'Custom wallpaper background enabled!',
                  );
                } else {
                  // No path exists, pick a new file
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                    );
                    if (result != null && result.files.single.path != null) {
                      widget.onSave(
                        widget.settings.copyWith(
                          customImagePath: result.files.single.path,
                        ),
                      );
                      if (!context.mounted) return;
                      Toast.showSuccess(
                        context,
                        'Custom wallpaper background enabled!',
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    Toast.showError(
                      context,
                      'Failed to select image: ${e.toString()}',
                    );
                  }
                }
              } else {
                // Disable by adding "disabled:" prefix (only if a path exists)
                if (widget.settings.customImagePath != null &&
                    !widget.settings.customImagePath!.startsWith("disabled:")) {
                  widget.onSave(
                    widget.settings.copyWith(
                      customImagePath:
                          'disabled:${widget.settings.customImagePath}',
                    ),
                  );
                  if (!context.mounted) return;
                  Toast.showSuccess(
                    context,
                    'Custom wallpaper background disabled.',
                  );
                }
              }
            },
          ),
          if (widget.settings.customImagePath != null) ...[
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
                        Builder(
                          builder: (context) {
                            final path = widget.settings.customImagePath;
                            final actualPath =
                                path != null && path.startsWith("disabled:")
                                ? path.substring(9)
                                : path;
                            return Text(
                              actualPath ?? '',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Builder(
                    builder: (context) {
                      final path = widget.settings.customImagePath;
                      final actualPath =
                          path != null && path.startsWith("disabled:")
                          ? path.substring(9)
                          : path;
                      if (actualPath != null && File(actualPath).existsSync()) {
                        return Container(
                          width: 50,
                          height: 35,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            image: DecorationImage(
                              image: FileImage(File(actualPath)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  MinimalButton(
                    backgroundColor: AppTheme.longBreakColor.withValues(
                      alpha: 0.1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () {
                      widget.onSave(
                        widget.settings.copyWith(customImagePath: ""),
                      );
                      Toast.showSuccess(
                        context,
                        'Custom wallpaper removed completely.',
                      );
                    },
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        color: AppTheme.longBreakColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MinimalButton(
                    backgroundColor: AppTheme.accentColor.withValues(
                      alpha: 0.1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                        );
                        if (result != null &&
                            result.files.single.path != null) {
                          widget.onSave(
                            widget.settings.copyWith(
                              customImagePath: result.files.single.path,
                            ),
                          );
                          if (!context.mounted) return;
                          Toast.showSuccess(context, 'Wallpaper updated!');
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Toast.showError(
                          context,
                          'Failed to select image: ${e.toString()}',
                        );
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
                _selectedTemplateId == t.id,
                () => setState(() => _selectedTemplateId = t.id),
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
                    _selectedTemplateId == t.id,
                    () => setState(() => _selectedTemplateId = t.id),
                  ),
                );
              }).toList(),
            ),
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
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : isHovered
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.15,
                              ),
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
                        _BreakTemplateRealPreview(
                          id: id,
                          settings: widget.settings,
                        ),
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

  void _showBreakTemplatePreview(String? templateId) {
    try {
      final controller = sl<BreakController>();
      controller.previewBreak(templateId: templateId);

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
  State<_BreakTemplateRealPreview> createState() =>
      _BreakTemplateRealPreviewState();
}

class _BreakTemplateRealPreviewState extends State<_BreakTemplateRealPreview> {
  Timer? _countdownTimer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.settings.shortBreakDurationSeconds > 0
        ? widget.settings.shortBreakDurationSeconds
        : 20;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final total = widget.settings.shortBreakDurationSeconds > 0
          ? widget.settings.shortBreakDurationSeconds
          : 20;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = total;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant _BreakTemplateRealPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.shortBreakDurationSeconds !=
        widget.settings.shortBreakDurationSeconds) {
      setState(() {
        _remainingSeconds = widget.settings.shortBreakDurationSeconds > 0
            ? widget.settings.shortBreakDurationSeconds
            : 20;
      });
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.settings.shortBreakDurationSeconds > 0
        ? widget.settings.shortBreakDurationSeconds
        : 20;

    final progress = (total - _remainingSeconds) / total;
    final timeStr = '00:${_remainingSeconds.toString().padLeft(2, '0')}';

    Widget mockWidget;

    switch (widget.id) {
      case 'classic':
        mockWidget = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.blueGrey.shade900, Colors.black],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 15,
                child: Icon(
                  CupertinoIcons.photo,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Container(
                width: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Rest Your Eyes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        break;

      case 'companion':
        mockWidget = Container(
          color: const Color(0xFF0F1115),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'COMPANION · $timeStr',
                  style: TextStyle(
                    color: AppTheme.longBreakColor.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Icon(
                CupertinoIcons.heart_fill,
                size: 28,
                color: AppTheme.longBreakColor,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Take a deep breath!',
                  style: TextStyle(color: Colors.white70, fontSize: 8),
                ),
              ),
            ],
          ),
        );
        break;

      case 'zen':
        mockWidget = Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF0D2A20), Color(0xFF07080B)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Breathe In',
                style: TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFA7F3D0).withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        break;

      case 'hud':
        mockWidget = Container(
          color: const Color(0xFF0A0F0D),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '[ $timeStr ]',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final filled = progress >= (index + 1) / 5;
                  return Container(
                    width: 12,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: filled
                        ? Colors.greenAccent
                        : Colors.greenAccent.withValues(alpha: 0.15),
                  );
                }),
              ),
            ],
          ),
        );
        break;

      case 'floating':
        mockWidget = Container(
          color: const Color(0xFF08090C),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.shortBreakColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        break;

      case 'activities':
        mockWidget = Container(
          color: const Color(0xFF0D0B0F),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ACTIVITY STUDIO · $timeStr',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.eye,
                      size: 14,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(
                      CupertinoIcons.wind,
                      size: 14,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        break;

      case 'minimal':
      default:
        mockWidget = Container(
          color: const Color(0xFF08090C),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.shortBreakColor.withValues(alpha: 0.1),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${total}s',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 190,
            height: 120,
            child: Theme(data: ThemeData.dark(), child: mockWidget),
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
