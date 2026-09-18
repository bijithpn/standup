import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_species_picker.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// A rich customizer sheet allowing full configuration of 3D Avatar Companion
/// including species selection, seeds, OneWorks color palettes, decals, and animation preview.
class AvatarCustomizerSheet extends StatefulWidget {
  final AvatarDefinition initialDefinition;
  final AvatarEngineController? engineController;
  final ValueChanged<AvatarDefinition>? onSaved;
  final ValueChanged<AvatarDefinition>? onChanged;
  final VoidCallback? onCancel;
  final bool showPreview;
  final bool isStatic;

  const AvatarCustomizerSheet({
    super.key,
    required this.initialDefinition,
    this.engineController,
    this.onSaved,
    this.onChanged,
    this.onCancel,
    this.showPreview = true,
    this.isStatic = false,
  });

  @override
  State<AvatarCustomizerSheet> createState() => _AvatarCustomizerSheetState();
}

class _AvatarCustomizerSheetState extends State<AvatarCustomizerSheet> {
  late AvatarDefinition _currentDefinition;
  late TextEditingController _seedController;
  late AvatarEngineController _controller;
  bool _ownsController = false;

  AvatarAnimationClip _selectedPreviewClip = AvatarAnimationClip.celebrate;
  Color _previewBgColor = const Color(0xFF141622);

  static const List<Map<String, dynamic>> _bgPresets = [
    {'name': 'Midnight', 'color': Color(0xFF0F111D)},
    {'name': 'Slate', 'color': Color(0xFF181A26)},
    {'name': 'Deep Space', 'color': Color(0xFF141622)},
    {'name': 'Warm Neutral', 'color': Color(0xFF242129)},
    {'name': 'Transparent', 'color': Colors.transparent},
  ];

  @override
  void didUpdateWidget(AvatarCustomizerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDefinition != widget.initialDefinition) {
      setState(() {
        _currentDefinition = widget.initialDefinition;
        _seedController.text = widget.initialDefinition.seed;
      });
      _controller.setDefinition(widget.initialDefinition);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDefinition = widget.initialDefinition;
    _seedController = TextEditingController(text: _currentDefinition.seed);

    if (widget.engineController != null) {
      _controller = widget.engineController!;
      _ownsController = false;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _seedController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateDefinition(AvatarDefinition newDef) {
    setState(() {
      _currentDefinition = newDef;
      _seedController.text = newDef.seed;
    });
    _controller.setDefinition(newDef);
    widget.onChanged?.call(newDef);
  }

  void _onSpeciesSelected(AvatarSpecies species) {
    final updated = _currentDefinition.copyWith(
      species: species,
      parts: Map<String, dynamic>.from(species.defaultPartConfigurations),
    );
    _updateDefinition(updated);
  }

  void _onPaletteSelected(AvatarPalette palette) {
    final updated = _currentDefinition.copyWith(palette: palette);
    _updateDefinition(updated);
  }

  void _randomizeSeed() {
    final randomValue = (math.Random().nextInt(900000) + 100000).toString();
    final newSeed = '${_currentDefinition.species.name}-$randomValue';
    final generated = AvatarDefinition.fromSeed(newSeed, species: _currentDefinition.species);
    _updateDefinition(generated);
  }

  Future<void> _copySeed() async {
    await Clipboard.setData(ClipboardData(text: _seedController.text));
    if (mounted) {
      Toast.showSuccess(context, 'Seed copied to clipboard!');
    }
  }

  Future<void> _pasteSeed() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      final updated = _currentDefinition.copyWith(seed: text);
      _updateDefinition(updated);
      if (mounted) {
        Toast.showSuccess(context, 'Seed updated from clipboard');
      }
    }
  }

  void _resetToDefault() {
    final def = AvatarDefinition.fromSpecies(
      AvatarSpecies.cat,
      palette: AvatarPalette.defaultPalette,
      seed: 'species-cat',
    );
    _updateDefinition(def);
  }

  Future<void> _playPreviewAnimation() async {
    await _controller.playAnimation(_selectedPreviewClip);
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151620),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (widget.showPreview) ...[
                _buildLivePreview(),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('Species Selection', 'Choose from 30+ available 3D pets'),
              const SizedBox(height: 10),
              AvatarSpeciesPicker(
                selectedSpecies: _currentDefinition.species,
                onSpeciesSelected: _onSpeciesSelected,
                isHorizontal: true,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Color Palette', 'OneWorks procedural skin and accent shades'),
              const SizedBox(height: 10),
              _buildPalettePicker(),
              const SizedBox(height: 24),
              _buildSectionTitle('Pet Seed & Genetics', 'Procedural seed determining markings and variations'),
              const SizedBox(height: 10),
              _buildSeedSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('Animation Lab', 'Preview poses & behavioral animations'),
              const SizedBox(height: 10),
              _buildAnimationSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize Companion',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Interactive 3D viewport and styling',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E92A8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLivePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: _previewBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2C3E)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AvatarView(
                  definition: _currentDefinition,
                  controller: _controller,
                  width: 170,
                  height: 170,
                  transparent: true,
                  autoTrackCursor: true,
                  isStatic: widget.isStatic,
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentDefinition.species.displayName} · ${_currentDefinition.palette.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Background:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E92A8),
                ),
              ),
              const SizedBox(width: 8),
              ..._bgPresets.map((preset) {
                final color = preset['color'] as Color;
                final name = preset['name'] as String;
                final isSelected = _previewBgColor == color;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _previewBgColor = color),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor.withValues(alpha: 0.2)
                            : const Color(0xFF1E202C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentColor : const Color(0xFF2C2F42),
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.accentColor : const Color(0xFFA2A6BC),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPalettePicker() {
    final palettes = AvatarPalette.presets.values.toList();

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: palettes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pal = palettes[index];
          final isSelected = _currentDefinition.palette.name.toLowerCase() == pal.name.toLowerCase();

          return InkWell(
            key: Key('palette_card_${pal.name.toLowerCase()}'),
            onTap: () => _onPaletteSelected(pal),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                    : AppTheme.surfaceElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : AppTheme.border,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildColorDot(pal.primary),
                      const SizedBox(width: 4),
                      _buildColorDot(pal.secondary),
                      const SizedBox(width: 4),
                      _buildColorDot(pal.accent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.accentColor : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorDot(String hex) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _parseHex(hex),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
      ),
    );
  }

  Widget _buildSeedSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('seed_text_field'),
            controller: _seedController,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: 'e.g. fluffy-cat-101',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surfaceElevated.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.accentColor),
              ),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                final updated = _currentDefinition.copyWith(seed: trimmed);
                _updateDefinition(updated);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('copy_seed_button'),
          icon: Icon(CupertinoIcons.doc_on_doc, size: 18, color: AppTheme.textSecondary),
          tooltip: 'Copy Seed',
          onPressed: _copySeed,
        ),
        IconButton(
          key: const Key('paste_seed_button'),
          icon: Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppTheme.textSecondary),
          tooltip: 'Paste Seed',
          onPressed: _pasteSeed,
        ),
        ElevatedButton.icon(
          key: const Key('randomize_seed_button'),
          icon: const Icon(CupertinoIcons.shuffle, size: 15),
          label: const Text('Randomize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceElevated,
            foregroundColor: AppTheme.accentColor,
            elevation: 0,
            side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _randomizeSeed,
        ),
      ],
    );
  }

  Widget _buildAnimationSection() {
    const clips = [
      AvatarAnimationClip.idle,
      AvatarAnimationClip.celebrate,
      AvatarAnimationClip.bounce,
      AvatarAnimationClip.sleep,
      AvatarAnimationClip.walk,
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: clips.map((clip) {
                final isSelected = _selectedPreviewClip == clip;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      clip.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.accentColor,
                    backgroundColor: AppTheme.surfaceElevated.withValues(alpha: 0.5),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? AppTheme.accentColor : AppTheme.border),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPreviewClip = clip);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          key: const Key('preview_animation_button'),
          icon: const Icon(CupertinoIcons.play_arrow_solid, size: 14),
          label: const Text('Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            foregroundColor: AppTheme.accentColor,
            elevation: 0,
            side: BorderSide(color: AppTheme.accentColor),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _playPreviewAnimation,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          key: const Key('reset_default_button'),
          icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 15),
          label: const Text('Reset to Default', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
          ),
          onPressed: _resetToDefault,
        ),
        ElevatedButton.icon(
          key: const Key('save_pet_button'),
          icon: const Icon(CupertinoIcons.check_mark_circled_solid, size: 16),
          label: const Text('Save Pet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            widget.onSaved?.call(_currentDefinition);
          },
        ),
      ],
    );
  }
}
