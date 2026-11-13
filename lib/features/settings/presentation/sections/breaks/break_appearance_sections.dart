part of 'break_appearance_settings.dart';

const _colorPresets = [
  (color: Color(0xFFA7C4B5), name: 'Sage'),
  (color: Color(0xFFA8BED2), name: 'Slate blue'),
  (color: Color(0xFFBAAFCE), name: 'Lavender'),
  (color: Color(0xFFD0B08A), name: 'Sand'),
  (color: Color(0xFFCB9F96), name: 'Clay'),
];

extension _BreakAppearanceSections on _BreakAppearanceSettingsState {
  List<Widget> _buildColorsSection(BuildContext context) {
    final id = _selectedTemplateId ?? widget.settings.breakTemplate;
    final template = _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => _templates.first,
    );
    // These templates visibly use the accent beyond a keyboard focus ring.
    final supportsAccent = !const {
      'classic',
      'companion',
      'haiku_card',
      'night_sky',
      'wind_down',
    }.contains(id);
    final supportsBreathing = id == 'zen' || id == 'breathe_line';
    final override = widget.settings.templateAccentOverrides[id];
    final hasCustomColor =
        override != null || widget.settings.clockFaceTextColorHex != 0xFFFFFFFF;
    final wallpaper = widget.settings.customImagePath;
    final hasWallpaper = wallpaper != null && wallpaper.isNotEmpty;
    final wallpaperEnabled = hasWallpaper && !wallpaper.startsWith('disabled:');

    return [
      sectionHeader(
        'Customize ${template.name}',
        subtitle: 'Only options supported by this template are shown.',
      ),
      const SizedBox(height: 12),
      if (supportsAccent ||
          hasCustomColor ||
          supportsBreathing ||
          id == 'classic')
        buildCard([
          if (supportsAccent || hasCustomColor)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accent color',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Text stays contrast-adjusted for readability.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Template default'),
                        selected: !hasCustomColor,
                        onSelected: (_) {
                          final colors = Map<String, int>.from(
                            widget.settings.templateAccentOverrides,
                          )..remove(id);
                          widget.onSave(
                            widget.settings.copyWith(
                              templateAccentOverrides: colors,
                              clockFaceTextColorHex: 0xFFFFFFFF,
                            ),
                          );
                        },
                      ),
                      if (supportsAccent)
                        for (final preset in _colorPresets)
                          Tooltip(
                            message: preset.name,
                            child: TapTarget(
                              semanticLabel: '${preset.name} accent',
                              selected: override == preset.color.toARGB32(),
                              onTap: () {
                                final colors = Map<String, int>.from(
                                  widget.settings.templateAccentOverrides,
                                )..[id] = preset.color.toARGB32();
                                widget.onSave(
                                  widget.settings.copyWith(
                                    templateAccentOverrides: colors,
                                    clockFaceTextColorHex: 0xFFFFFFFF,
                                  ),
                                );
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: preset.color,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: override == preset.color.toARGB32()
                                        ? AppTheme.textPrimary
                                        : AppTheme.borderColor,
                                    width: 2,
                                  ),
                                ),
                                child: override == preset.color.toARGB32()
                                    ? const Icon(
                                        CupertinoIcons.checkmark,
                                        size: 16,
                                        color: Color(0xFF202521),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          if (supportsBreathing) ...[
            if (supportsAccent || hasCustomColor) divider(),
            dropdownRow(
              'Breathing pattern',
              BreathPreset.byId(widget.settings.breathPreset).label,
              [for (final p in BreathPreset.all) p.label],
              (label) {
                final preset = BreathPreset.all.firstWhere(
                  (p) => p.label == label,
                );
                widget.onSave(
                  widget.settings.copyWith(breathPreset: preset.id),
                );
              },
            ),
          ],
          if (id == 'classic') ...[
            if (hasCustomColor) divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background image',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wallpaperEnabled
                        ? 'Using your photo'
                        : 'Using the built-in gallery',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _chooseWallpaper(context),
                        icon: const Icon(CupertinoIcons.photo, size: 16),
                        label: Text(
                          wallpaperEnabled ? 'Change image' : 'Choose image',
                        ),
                      ),
                      if (hasWallpaper)
                        TextButton(
                          onPressed: () => widget.onSave(
                            widget.settings.copyWith(customImagePath: ''),
                          ),
                          child: const Text('Use built-in gallery'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ])
      else
        Text(
          'This scene uses its own colors. No extra setup needed.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      const SizedBox(height: 28),
      sectionHeader('Break preferences'),
      const SizedBox(height: 12),
      buildCard([
        toggleRow(
          'Completion chime',
          'Play a soft sound when a break finishes.',
          widget.settings.breakChimeEnabled,
          (value) =>
              widget.onSave(widget.settings.copyWith(breakChimeEnabled: value)),
        ),
        divider(),
        toggleRow(
          'Eye-rest confirmation',
          'Show an “I looked away” button during eye-rest breaks.',
          widget.settings.lookedAwayPromptEnabled,
          (value) => widget.onSave(
            widget.settings.copyWith(lookedAwayPromptEnabled: value),
          ),
        ),
      ]),
    ];
  }

  Future<void> _chooseWallpaper(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final path = result?.files.single.path;
      if (path == null || !context.mounted) return;
      widget.onSave(widget.settings.copyWith(customImagePath: path));
    } catch (_) {
      if (!context.mounted) return;
      Toast.showError(context, 'Could not open the image. Please try again.');
    }
  }
}
