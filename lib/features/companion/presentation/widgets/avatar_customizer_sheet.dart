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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              if (widget.showPreview) ...[
                _buildLivePreview(),
                const SizedBox(height: 14),
              ],
              _buildSectionCard(
                icon: CupertinoIcons.paw,
                title: 'Species Selection',
                subtitle: 'Choose from 30+ available 3D pets',
                badge: '${AvatarSpecies.values.length} Pets',
                child: AvatarSpeciesPicker(
                  selectedSpecies: _currentDefinition.species,
                  onSpeciesSelected: _onSpeciesSelected,
                  isHorizontal: true,
                ),
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: CupertinoIcons.paintbrush_fill,
                title: 'Color Palette',
                subtitle: 'OneWorks procedural skin and accent shades',
                child: _buildPalettePicker(),
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: CupertinoIcons.sparkles,
                title: 'Pet Seed & Genetics',
                subtitle: 'Procedural seed determining markings and variations',
                child: _buildSeedSection(),
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: CupertinoIcons.play_circle_fill,
                title: 'Animation Lab',
                subtitle: 'Preview poses & behavioral animations',
                child: _buildAnimationSection(),
              ),
              const SizedBox(height: 20),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      CupertinoIcons.cube_box_fill,
                      size: 16,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Customize Companion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Interactive 3D depth viewport & textures',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF8E92A8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191B28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252839)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7E8299),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final accentHex = _currentDefinition.palette.accent;
    final ambientGlowColor = _parseHex(accentHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: _previewBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2C2F44)),
              boxShadow: [
                BoxShadow(
                  color: ambientGlowColor.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient dynamic stage glow
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.65,
                        colors: [
                          ambientGlowColor.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // 3D Avatar View
                AvatarView(
                  definition: _currentDefinition,
                  controller: _controller,
                  width: 145,
                  height: 145,
                  transparent: true,
                  autoTrackCursor: true,
                  isStatic: widget.isStatic,
                ),
                // Species & Palette identification pill
                Positioned(
                  top: 14,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10121C).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ambientGlowColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ambientGlowColor.withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${_currentDefinition.species.displayName} · ${_currentDefinition.palette.name}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 3D Depth Tracker Pill
                Positioned(
                  top: 14,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.viewfinder, size: 12, color: AppTheme.accentColor),
                        const SizedBox(width: 5),
                        Text(
                          '3D Depth Tracking',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                            letterSpacing: 0.2,
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
              const Icon(CupertinoIcons.circle_grid_hex, size: 12, color: Color(0xFF8E92A8)),
              const SizedBox(width: 6),
              const Text(
                'Stage Lighting:',
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
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor.withValues(alpha: 0.22)
                            : const Color(0xFF191B28),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentColor : const Color(0xFF292C3E),
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

  Widget _buildPalettePicker() {
    final palettes = AvatarPalette.presets.values.toList();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: palettes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final pal = palettes[index];
          final isSelected = _currentDefinition.palette.name.toLowerCase() == pal.name.toLowerCase();

          return InkWell(
            key: Key('palette_card_${pal.name.toLowerCase()}'),
            onTap: () => _onPaletteSelected(pal),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor.withValues(alpha: 0.16)
                    : const Color(0xFF131520),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : const Color(0xFF26293A),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildColorDot(pal.primary),
                      const SizedBox(width: 5),
                      _buildColorDot(pal.secondary),
                      const SizedBox(width: 5),
                      _buildColorDot(pal.accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFB0B4C8),
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
    final color = _parseHex(hex);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 3,
          ),
        ],
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: 'e.g. fluffy-cat-101',
              hintStyle: const TextStyle(color: Color(0xFF63677E), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF131520),
              prefixIcon: const Icon(CupertinoIcons.number, size: 16, color: Color(0xFF6F738B)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF26293A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF26293A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.accentColor, width: 1.5),
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
          icon: const Icon(CupertinoIcons.doc_on_doc, size: 18, color: Color(0xFF8E92A8)),
          tooltip: 'Copy Seed',
          onPressed: _copySeed,
        ),
        IconButton(
          key: const Key('paste_seed_button'),
          icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: Color(0xFF8E92A8)),
          tooltip: 'Paste Seed',
          onPressed: _pasteSeed,
        ),
        ElevatedButton.icon(
          key: const Key('randomize_seed_button'),
          icon: const Icon(CupertinoIcons.shuffle, size: 14),
          label: const Text('Randomize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF222536),
            foregroundColor: Colors.white,
            elevation: 0,
            side: const BorderSide(color: Color(0xFF33374E)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        color: isSelected ? Colors.white : const Color(0xFFA0A4B8),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.accentColor,
                    backgroundColor: const Color(0xFF131520),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppTheme.accentColor : const Color(0xFF26293A),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPreviewClip = clip);
                        _controller.playAnimation(clip);
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
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.18),
            foregroundColor: AppTheme.accentColor,
            elevation: 0,
            side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            foregroundColor: const Color(0xFF7E8299),
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
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            elevation: 2,
            shadowColor: AppTheme.accentColor.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            widget.onSaved?.call(_currentDefinition);
          },
        ),
      ],
    );
  }
}
