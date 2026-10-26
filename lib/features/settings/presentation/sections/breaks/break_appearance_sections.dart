// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'break_appearance_settings.dart';

final _colorPresets = [
  (color: const Color(0xFFF4F4F5), name: 'Pure Zinc'),
  (color: const Color(0xFFEF4444), name: 'Crimson Ember'),
  (color: const Color(0xFF38BDF8), name: 'Ocean Depth'),
  (color: const Color(0xFF34D399), name: 'Emerald Jade'),
  (color: const Color(0xFFF97316), name: 'Sunset Orange'),
  (color: const Color(0xFFC084FC), name: 'Radiant Purple'),
  (color: const Color(0xFFF59E0B), name: 'Amber Glow'),
  (color: const Color(0xFFFFFFFF), name: 'Contrast White'),
];

extension _BreakAppearanceSections on _BreakAppearanceSettingsState {
  List<Widget> _buildColorsSection(BuildContext context) {
    final currentColor = Color(widget.settings.clockFaceTextColorHex);
    final currentOpacity = currentColor.a;
    final baseColor = currentColor.withValues(alpha: 1.0);
    return [
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
              Row(
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
                children: _colorPresets.map((preset) {
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
                                    color: preset.color.computeLuminance() > 0.5
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
        dropdownRow(
          'Break Screen Theme',
          _BreakAppearanceSettingsState._themeModeLabels[widget
                  .settings
                  .overlayThemeMode] ??
              'Dark',
          _BreakAppearanceSettingsState._themeModeLabels.values.toList(),
          (label) {
            final mode = _BreakAppearanceSettingsState._themeModeLabels.entries
                .firstWhere(
                  (e) => e.value == label,
                  orElse: () => const MapEntry('dark', 'Dark'),
                )
                .key;
            widget.onSave(widget.settings.copyWith(overlayThemeMode: mode));
          },
        ),
        divider(),
        dropdownRow(
          'Breathing Pattern',
          BreathPreset.byId(widget.settings.breathPreset).label,
          [for (final p in BreathPreset.all) p.label],
          (label) {
            final preset = BreathPreset.all.firstWhere(
              (p) => p.label == label,
              orElse: () => BreathPreset.box,
            );
            widget.onSave(widget.settings.copyWith(breathPreset: preset.id));
          },
        ),
        divider(),
        toggleRow(
          'Completion Chime',
          'Play a soft chime when a break finishes on its own',
          widget.settings.breakChimeEnabled,
          (v) => widget.onSave(widget.settings.copyWith(breakChimeEnabled: v)),
        ),
        divider(),
        toggleRow(
          '"I Looked Away" Button',
          'Show a button during eye-rest breaks; confirmed breaks count as a wellness action',
          widget.settings.lookedAwayPromptEnabled,
          (v) => widget.onSave(
            widget.settings.copyWith(lookedAwayPromptEnabled: v),
          ),
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
                      Text(
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
                            style: TextStyle(
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
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
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
                      if (result != null && result.files.single.path != null) {
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
    ];
  }

  List<Widget> _buildAccentPinSection(BuildContext context) {
    return [
      sectionHeader(
        'Per-Template Accent Pin',
        subtitle:
            'Pin a specific template to always use one accent color, regardless of the app theme.',
      ),
      const SizedBox(height: 16),
      buildCard([
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _accentOverrideTemplateId,
                  dropdownColor: AppTheme.surfaceElevated,
                  isExpanded: true,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                  items: _BreakAppearanceSettingsState._overridableTemplates
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() => _accentOverrideTemplateId = id);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._colorPresets.map((preset) {
                    final overrideInt = widget
                        .settings
                        .templateAccentOverrides[_accentOverrideTemplateId];
                    final isSelected = overrideInt == preset.color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        final updated =
                            Map<String, int>.from(
                                widget.settings.templateAccentOverrides,
                              )
                              ..[_accentOverrideTemplateId] = preset.color
                                  .toARGB32();
                        widget.onSave(
                          widget.settings.copyWith(
                            templateAccentOverrides: updated,
                          ),
                        );
                      },
                      child: Tooltip(
                        message: preset.name,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: preset.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.15),
                              width: isSelected ? 2.2 : 1.5,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Icon(
                                    CupertinoIcons.checkmark,
                                    size: 12,
                                    color: preset.color.computeLuminance() > 0.5
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                  if (widget.settings.templateAccentOverrides.containsKey(
                    _accentOverrideTemplateId,
                  ))
                    GestureDetector(
                      onTap: () {
                        final updated = Map<String, int>.from(
                          widget.settings.templateAccentOverrides,
                        )..remove(_accentOverrideTemplateId);
                        widget.onSave(
                          widget.settings.copyWith(
                            templateAccentOverrides: updated,
                          ),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    ];
  }
}
