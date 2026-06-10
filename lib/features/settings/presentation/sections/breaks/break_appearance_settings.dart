import 'dart:ui';
import 'dart:io';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  final ScrollController _gridScrollController = ScrollController();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const _templates = [
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
      name: 'Focus Card',
      desc: 'Spacious timer with a single progress bar.',
    ),
    (
      id: 'floating',
      name: 'Floating Dock',
      desc: 'Snappable compact overlay, desktop stays visible.',
    ),
    (
      id: 'activities',
      name: 'Activity Studio',
      desc: 'Guided breathing & eye sync exercises.',
    ),
    (
      id: 'soft_arc',
      name: 'Soft Arc',
      desc: 'Icon, large countdown, and a 1.5px arc. Nothing else.',
    ),
    (
      id: 'breathe_line',
      name: 'Breathe Line',
      desc: 'Animated line expands and contracts with your breath.',
    ),
    (
      id: 'clock_face',
      name: 'Clock Face',
      desc: 'Analog-style clock ring with a progress arc.',
    ),
    (
      id: 'one_word',
      name: 'One Word',
      desc: '"Rest" or "Pause" — giant, quiet, minimal.',
    ),
    (
      id: 'open_field',
      name: 'Open Field',
      desc: 'Full photo backdrop with bottom text overlay.',
    ),
    (
      id: 'haiku_card',
      name: 'Haiku',
      desc: 'A rotating haiku poem with your countdown below.',
    ),
    (
      id: 'ring_only',
      name: 'Ring Only',
      desc: 'Single arc ring, icon, and time. Nothing outside.',
    ),
    (
      id: 'step_guide',
      name: 'Step Guide',
      desc: 'Numbered steps from your break tip.',
    ),
    (
      id: 'time_slice',
      name: 'Time Slice',
      desc: 'Full-width progress bar, big word, optional tip.',
    ),
    (
      id: 'day_stack',
      name: 'Day Stack',
      desc: 'Today\'s break count + countdown stacked cleanly.',
    ),
    (
      id: 'pulse_dot',
      name: 'Pulse Dot',
      desc: 'Pulsing circle border with countdown center.',
    ),
    (
      id: 'mono_time',
      name: 'Mono Time',
      desc: 'Monospace terminal-style countdown with accent bar.',
    ),
    (
      id: 'split_view',
      name: 'Split View',
      desc: 'Tip text left, arc + timer right.',
    ),
    (
      id: 'warm_amber',
      name: 'Warm Amber',
      desc: 'Sunset-toned wind-down with daily break count.',
    ),
    (
      id: 'focus_orb',
      name: 'Focus Orb',
      desc: 'Static radial glow behind a clean countdown.',
    ),
    (
      id: 'wave_calm',
      name: 'Wave Calm',
      desc: 'Animated sine waves behind a centered timer.',
    ),
    (
      id: 'iris_rest',
      name: 'Iris Rest',
      desc: 'Giant eye icon, a rule, countdown, one-line instruction.',
    ),
    (
      id: 'quiet_pill',
      name: 'Quiet Pill',
      desc: 'Draggable floating pill — desktop stays fully visible.',
    ),
    (
      id: 'paper_light',
      name: 'Paper Light',
      desc: 'Light mode template on warm paper background.',
    ),
    (
      id: 'dusk_glow',
      name: 'Dusk Glow',
      desc: 'Deep purple gradient with moon icon and progress bar.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = widget.settings.breakTemplate;
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_selectedTemplateId != null) ...[
              Text(
                'Selected: ',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              Builder(
                builder: (context) {
                  final selectedTemplate = _templates.firstWhere(
                    (t) => t.id == _selectedTemplateId,
                    orElse: () => _templates.first,
                  );
                  return Text(
                    selectedTemplate.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            Tooltip(
              message: 'Preview Selected',
              child: MinimalButton(
                padding: const EdgeInsets.all(8),
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _showBreakTemplatePreview(_selectedTemplateId),
                child: Icon(
                  CupertinoIcons.eye,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final bool hasChanges =
                    _selectedTemplateId != widget.settings.breakTemplate;
                return Tooltip(
                  message: 'Update Template',
                  child: MinimalButton(
                    padding: const EdgeInsets.all(8),
                    backgroundColor: AppTheme.accentColor,
                    disabledColor: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
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
                    child: Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: hasChanges
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        CupertinoTextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          placeholder: 'Search templates...',
          placeholderStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.search,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          suffix: _searchQuery.isNotEmpty
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 16,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : null,
          decoration: BoxDecoration(
            color: AppTheme.contentBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _searchFocusNode.hasFocus
                  ? AppTheme.accentColor
                  : AppTheme.borderColor.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
        ),
        const SizedBox(height: 16),
        _buildBreakTemplateGrid(),
        const SizedBox(height: 32),
        sectionHeader(
          'Colors & Customization',
          subtitle:
              'Fine-tune clock accent colors, text opacity, and blur intensity.',
        ),
        const SizedBox(height: 16),
        buildCard([
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
                        child: AnimatedScale(
                          scale: isSelected ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: preset.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                width: isSelected ? 2.2 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: preset.color.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? Center(
                                    child: Icon(
                                      CupertinoIcons.checkmark,
                                      size: 14,
                                      color:
                                          preset.color.computeLuminance() > 0.5
                                          ? Colors.black87
                                          : Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          divider(),
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
    final filteredTemplates = _templates.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.desc.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: AppTheme.contentBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: filteredTemplates.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 32,
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No templates found matching "$_searchQuery"',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              )
            : Scrollbar(
                controller: _gridScrollController,
                thumbVisibility: true,
                child: GridView.builder(
                  controller: _gridScrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 195,
                  ),
                  itemCount: filteredTemplates.length,
                  itemBuilder: (context, index) {
                    final t = filteredTemplates[index];
                    return _breakTemplatePreview(
                      t.name,
                      t.id,
                      t.desc,
                      _selectedTemplateId == t.id,
                      () => setState(() => _selectedTemplateId = t.id),
                    );
                  },
                ),
              ),
      ),
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
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: isHovered ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 120,
                  clipBehavior: Clip.none,
                  decoration: BoxDecoration(
                    color: AppTheme.contentBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor
                          : isHovered
                          ? AppTheme.accentColor.withValues(alpha: 0.4)
                          : AppTheme.borderColor.withValues(alpha: 0.6),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : isHovered
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _BreakTemplateIconPreview(id: id),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.accentColor
                      : isHovered
                      ? Colors.white
                      : AppTheme.textPrimary.withValues(alpha: 0.9),
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
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
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

class _BreakTemplateIconPreview extends StatelessWidget {
  final String id;

  const _BreakTemplateIconPreview({required this.id});

  @override
  Widget build(BuildContext context) {
    final config = _templateConfig(id);

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: config.gradient,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              clipBehavior: Clip.none,
              child: CustomPaint(painter: _DotGridPainter(config.accentColor)),
            ),
          ),
          Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.accentColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: config.accentColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: config.accentColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(config.icon, size: 18, color: config.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  static _TemplateConfig _templateConfig(String id) {
    switch (id) {
      case 'classic':
        return _TemplateConfig(
          icon: LucideIcons.image,
          accentColor: const Color(0xFF60A5FA),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2E), Color(0xFF0A0D14)],
          ),
          label: 'GALLERY FOCUS',
        );
      case 'companion':
        return _TemplateConfig(
          icon: LucideIcons.cat,
          accentColor: const Color(0xFFF472B6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0D17), Color(0xFF0F0C14)],
          ),
          label: 'COMPANION DOCK',
        );
      case 'zen':
        return _TemplateConfig(
          icon: LucideIcons.wind,
          accentColor: const Color(0xFF6EE7B7),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071A12), Color(0xFF070B0A)],
          ),
          label: 'BREATH LINES',
        );
      case 'hud':
        return _TemplateConfig(
          icon: LucideIcons.layoutGrid,
          accentColor: const Color(0xFF4ADE80),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060F08), Color(0xFF060907)],
          ),
          label: 'SIGNAL HUD',
        );
      case 'floating':
        return _TemplateConfig(
          icon: LucideIcons.layers,
          accentColor: const Color(0xFF8B5CF6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF100E1A), Color(0xFF0B0910)],
          ),
          label: 'FLOATING DOCK',
        );
      case 'activities':
        return _TemplateConfig(
          icon: LucideIcons.activity,
          accentColor: const Color(0xFFC084FC),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF130D1C), Color(0xFF0D0910)],
          ),
          label: 'ACTIVITY STUDIO',
        );
      case 'soft_arc':
        return _TemplateConfig(
          icon: LucideIcons.circle,
          accentColor: const Color(0xFF7EC8E3),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B14), Color(0xFF06080C)],
          ),
          label: 'SOFT ARC',
        );
      case 'breathe_line':
        return _TemplateConfig(
          icon: LucideIcons.wind,
          accentColor: const Color(0xFF7EC8E3),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07090D), Color(0xFF05070A)],
          ),
          label: 'BREATHE LINE',
        );
      case 'clock_face':
        return _TemplateConfig(
          icon: LucideIcons.clock,
          accentColor: const Color(0xFFF9A875),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14100A), Color(0xFF0A0807)],
          ),
          label: 'CLOCK FACE',
        );
      case 'one_word':
        return _TemplateConfig(
          icon: LucideIcons.type,
          accentColor: const Color(0xFFD4D4D8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D12), Color(0xFF08080C)],
          ),
          label: 'ONE WORD',
        );
      case 'open_field':
        return _TemplateConfig(
          icon: LucideIcons.image,
          accentColor: const Color(0xFF86EFAC),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF091409), Color(0xFF060A06)],
          ),
          label: 'OPEN FIELD',
        );
      case 'haiku_card':
        return _TemplateConfig(
          icon: LucideIcons.scrollText,
          accentColor: const Color(0xFFD4D4D8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0F), Color(0xFF09090B)],
          ),
          label: 'HAIKU',
        );
      case 'ring_only':
        return _TemplateConfig(
          icon: LucideIcons.circle,
          accentColor: const Color(0xFF818CF8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0C18), Color(0xFF08080F)],
          ),
          label: 'RING ONLY',
        );
      case 'step_guide':
        return _TemplateConfig(
          icon: LucideIcons.listOrdered,
          accentColor: const Color(0xFF6EE7B7),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071410), Color(0xFF05090A)],
          ),
          label: 'STEP GUIDE',
        );
      case 'time_slice':
        return _TemplateConfig(
          icon: LucideIcons.minus,
          accentColor: const Color(0xFF5BB898),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071210), Color(0xFF05090A)],
          ),
          label: 'TIME SLICE',
        );
      case 'day_stack':
        return _TemplateConfig(
          icon: LucideIcons.layers2,
          accentColor: const Color(0xFF93C5FD),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B14), Color(0xFF060810)],
          ),
          label: 'DAY STACK',
        );
      case 'pulse_dot':
        return _TemplateConfig(
          icon: LucideIcons.loader,
          accentColor: const Color(0xFF6EE7B7),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071410), Color(0xFF05090A)],
          ),
          label: 'PULSE DOT',
        );
      case 'mono_time':
        return _TemplateConfig(
          icon: LucideIcons.terminal,
          accentColor: const Color(0xFFB5CC7A),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0D08), Color(0xFF08090A)],
          ),
          label: 'MONO TIME',
        );
      case 'split_view':
        return _TemplateConfig(
          icon: LucideIcons.columns2,
          accentColor: const Color(0xFF86EFAC),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF091409), Color(0xFF060A06)],
          ),
          label: 'SPLIT VIEW',
        );
      case 'warm_amber':
        return _TemplateConfig(
          icon: LucideIcons.sunset,
          accentColor: const Color(0xFFC49A4A),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1005), Color(0xFF0A0807)],
          ),
          label: 'WARM AMBER',
        );
      case 'focus_orb':
        return _TemplateConfig(
          icon: LucideIcons.circle,
          accentColor: const Color(0xFF8BC9D4),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080C0D), Color(0xFF06090A)],
          ),
          label: 'FOCUS ORB',
        );
      case 'wave_calm':
        return _TemplateConfig(
          icon: LucideIcons.waves,
          accentColor: const Color(0xFF93C5FD),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B14), Color(0xFF060810)],
          ),
          label: 'WAVE CALM',
        );
      case 'iris_rest':
        return _TemplateConfig(
          icon: LucideIcons.eye,
          accentColor: const Color(0xFF7EC8E3),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B14), Color(0xFF06080C)],
          ),
          label: 'IRIS REST',
        );
      case 'quiet_pill':
        return _TemplateConfig(
          icon: LucideIcons.layers,
          accentColor: const Color(0xFF7EC8E3),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B0D), Color(0xFF060809)],
          ),
          label: 'QUIET PILL',
        );
      case 'paper_light':
        return _TemplateConfig(
          icon: LucideIcons.leaf,
          accentColor: const Color(0xFF2D6A4F),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F3EE), Color(0xFFECE9E4)],
          ),
          label: 'PAPER LIGHT',
        );
      case 'dusk_glow':
        return _TemplateConfig(
          icon: LucideIcons.moon,
          accentColor: const Color(0xFFC4B5FD),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0F14), Color(0xFF06070A)],
          ),
          label: 'DUSK GLOW',
        );
      case 'minimal':
      default:
        return _TemplateConfig(
          icon: LucideIcons.circle,
          accentColor: const Color(0xFF38BDF8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B12), Color(0xFF06080C)],
          ),
          label: 'QUIET GRID',
        );
    }
  }
}

class _TemplateConfig {
  final IconData icon;
  final Color accentColor;
  final LinearGradient gradient;
  final String label;

  const _TemplateConfig({
    required this.icon,
    required this.accentColor,
    required this.gradient,
    required this.label,
  });
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..strokeCap = StrokeCap.round;
    const spacing = 14.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => oldDelegate.color != color;
}

class DesktopDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
