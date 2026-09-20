import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/avatar_breed.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/controllers/pet_3d_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';
import 'package:breakmate/features/companion/services/avatar_web_server.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

// ---------------------------------------------------------------------------
// Color constants matching the reference dark editor theme
// ---------------------------------------------------------------------------
const _kBg = Color(0xFF141414);
const _kSidebar = Color(0xFF1C1C1C);
const _kCard = Color(0xFF232323);
const _kBorder = Color(0xFF2E2E2E);
const _kAccent = Color(0xFFE03030);
const _kText = Color(0xFFEEEEEE);
const _kTextMuted = Color(0xFF888888);

/// Fullscreen 3D Avatar Customizer — reference-matched dark editor with
/// left-sidebar controls and a genuine 3D WebGL Three.js viewport.
class AvatarCustomizerPage extends StatefulWidget {
  final AvatarDefinition? initialDefinition;
  final AvatarEngineController? engineController;
  final ValueChanged<AvatarDefinition>? onSaved;
  final VoidCallback? onCancel;
  final bool isStatic;

  const AvatarCustomizerPage({
    super.key,
    this.initialDefinition,
    this.engineController,
    this.onSaved,
    this.onCancel,
    this.isStatic = false,
  });

  @override
  State<AvatarCustomizerPage> createState() => _AvatarCustomizerPageState();
}

enum _SidebarSection { species, breed, palette, camera, seed }

class _AvatarCustomizerPageState extends State<AvatarCustomizerPage> {
  late AvatarDefinition _definition;
  late AvatarEngineController _controller;
  late Pet3DController _pet3DController;
  bool _ownsController = false;

  // Selected section in the sidebar
  _SidebarSection _selectedSection = _SidebarSection.species;

  // View mode: clean companion 3D vs full OneWorks studio
  bool _isStudioMode = false;

  // Preview background
  Color _bgColor = const Color(0xFF9B8EC4); // lavender like the reference

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<AvatarWebServer>()) {
      try {
        sl<AvatarWebServer>().start();
      } catch (_) {}
    }

    var initial = widget.initialDefinition ??
        AvatarDefinition.fromSpecies(AvatarSpecies.cat);
    if (initial.breed == null) {
      final breeds = AvatarBreed.forSpecies(initial.species);
      if (breeds.isNotEmpty) {
        initial = initial.copyWith(breed: breeds.first.id);
      }
    }
    _definition = initial;

    if (widget.engineController != null) {
      _controller = widget.engineController!;
      _ownsController = false;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
    _pet3DController = Pet3DController();
    _controller.setDefinition(_definition);
  }

  @override
  void dispose() {
    _pet3DController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _update(AvatarDefinition def) {
    setState(() => _definition = def);
    _controller.setDefinition(def);
  }

  void _randomizeSeed() {
    final rand = (math.Random().nextInt(900000) + 100000).toString();
    final seed = '${_definition.species.name}-$rand';
    _update(AvatarDefinition.fromSeed(seed, species: _definition.species));
  }

  Future<void> _handleSave() async {
    final queryParams = CompanionOverlayController.buildQueryParamsForAvatar(
      species: _definition.species,
      breed: _definition.breed,
      paletteId: _definition.palette.name.toLowerCase(),
    );

    try {
      if (sl.isRegistered<CompanionOverlayController>()) {
        final ctrl = sl<CompanionOverlayController>();
        await ctrl.changeTheme('avatar_${_definition.species.name}');
        await ctrl.saveAvatarUrlParams(queryParams);
      } else {
        try {
          final repo = Provider.of<SettingsRepository>(context, listen: false);
          await repo.save(repo.currentSettings.copyWith(
            companionPetTheme: 'avatar_${_definition.species.name}',
            companionAvatarUrlParams: queryParams,
          ));
        } catch (_) {}
      }
    } catch (_) {}

    widget.onSaved?.call(_definition);
    if (mounted) {
      Toast.showSuccess(context, 'Companion saved!');
      if (Navigator.canPop(context)) Navigator.pop(context, _definition);
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _TopBar(
            onClose: _handleCancel,
            onSave: _handleSave,
            isStudioMode: _isStudioMode,
            onModeChanged: (val) => setState(() => _isStudioMode = val),
          ),
          Expanded(
            child: _isStudioMode
                ? _Viewport(
                    definition: _definition,
                    controller: _controller,
                    pet3DController: _pet3DController,
                    bgColor: _bgColor,
                    isStatic: widget.isStatic,
                    isStudioMode: true,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left sidebar ───────────────────────────────────────────
                      _Sidebar(
                        definition: _definition,
                        selected: _selectedSection,
                        onSectionTap: (s) => setState(() => _selectedSection = s),
                        onUpdate: _update,
                        onRandomize: _randomizeSeed,
                        pet3DController: _pet3DController,
                      ),

                      // ── Main 3D viewport ───────────────────────────────────────
                      Expanded(
                        child: _Viewport(
                          definition: _definition,
                          controller: _controller,
                          pet3DController: _pet3DController,
                          bgColor: _bgColor,
                          isStatic: widget.isStatic,
                          isStudioMode: false,
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Bottom toolbar (only in Companion view) ────────────────────
          if (!_isStudioMode)
            _BottomBar(
              bgColor: _bgColor,
              onBgColorChanged: (c) => setState(() => _bgColor = c),
              onReset: () => _update(AvatarDefinition.fromSpecies(AvatarSpecies.cat)),
              onRandomize: _randomizeSeed,
              onSave: _handleSave,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar — minimal, dark, matching reference
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSave;
  final bool isStudioMode;
  final ValueChanged<bool> onModeChanged;

  const _TopBar({
    required this.onClose,
    required this.onSave,
    required this.isStudioMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double leftInset = Platform.isMacOS ? 84.0 : 16.0;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          color: _kSidebar,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        padding: EdgeInsets.only(left: leftInset, right: 16),
        child: Row(
          children: [
            // App icon / back
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
                ),
                child: const Icon(CupertinoIcons.chevron_left,
                    size: 14, color: _kAccent),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: const Text(
                '3D Pet Customizer',
                style: TextStyle(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Spacer(),
            if (Platform.isMacOS) ...[
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeToggleButton(
                      label: '3D View',
                      icon: CupertinoIcons.cube_box_fill,
                      isSelected: !isStudioMode,
                      onTap: () => onModeChanged(false),
                    ),
                    _ModeToggleButton(
                      label: 'Studio',
                      icon: CupertinoIcons.slider_horizontal_3,
                      isSelected: isStudioMode,
                      onTap: () => onModeChanged(true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(CupertinoIcons.checkmark_alt, size: 14),
              label: const Text('Save',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _kAccent.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? _kAccent : _kTextMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _kAccent : _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left sidebar
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final AvatarDefinition definition;
  final _SidebarSection selected;
  final ValueChanged<_SidebarSection> onSectionTap;
  final ValueChanged<AvatarDefinition> onUpdate;
  final VoidCallback onRandomize;
  final Pet3DController pet3DController;

  const _Sidebar({
    required this.definition,
    required this.selected,
    required this.onSectionTap,
    required this.onUpdate,
    required this.onRandomize,
    required this.pet3DController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: _kSidebar,
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          // Tab row
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final section in _SidebarSection.values) ...[
                  _SidebarTab(
                    label: _sectionLabel(section),
                    icon: _sectionIcon(section),
                    isSelected: selected == section,
                    onTap: () => onSectionTap(section),
                  ),
                  if (section != _SidebarSection.values.last)
                    const SizedBox(width: 4),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  String _sectionLabel(_SidebarSection s) => switch (s) {
        _SidebarSection.species => 'Species',
        _SidebarSection.breed => 'Breed',
        _SidebarSection.palette => 'Colors',
        _SidebarSection.camera => 'Camera',
        _SidebarSection.seed => 'Seed',
      };

  IconData _sectionIcon(_SidebarSection s) => switch (s) {
        _SidebarSection.species => CupertinoIcons.paw,
        _SidebarSection.breed => CupertinoIcons.square_grid_2x2,
        _SidebarSection.palette => CupertinoIcons.paintbrush_fill,
        _SidebarSection.camera => CupertinoIcons.camera_viewfinder,
        _SidebarSection.seed => CupertinoIcons.sparkles,
      };

  Widget _buildContent() {
    return switch (selected) {
      _SidebarSection.species => _SpeciesPanel(
          definition: definition,
          onUpdate: onUpdate,
        ),
      _SidebarSection.breed => _BreedPanel(
          definition: definition,
          onUpdate: onUpdate,
        ),
      _SidebarSection.palette => _PalettePanel(
          definition: definition,
          onUpdate: onUpdate,
        ),
      _SidebarSection.camera => _Camera3DPanel(
          controller: pet3DController,
        ),
      _SidebarSection.seed => _SeedPanel(
          definition: definition,
          onUpdate: onUpdate,
          onRandomize: onRandomize,
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Breed panel
// ---------------------------------------------------------------------------
class _BreedPanel extends StatelessWidget {
  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  const _BreedPanel({required this.definition, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final breeds = AvatarBreed.forSpecies(definition.species);
    final activeBreedId = definition.breed ?? (breeds.isNotEmpty ? breeds.first.id : null);

    if (breeds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Default breed active for ${definition.species.displayName}.',
            style: const TextStyle(color: _kTextMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarSectionHeader(
          icon: CupertinoIcons.square_grid_2x2,
          label: '${definition.species.displayName.toUpperCase()} BREEDS (${breeds.length})',
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.88,
          ),
          itemCount: breeds.length,
          itemBuilder: (context, i) {
            final breed = breeds[i];
            final isSel = breed.id == activeBreedId;
            return Tooltip(
              message: breed.displayName,
              child: InkWell(
                onTap: () {
                  final updated = definition.copyWith(breed: breed.id);
                  onUpdate(updated);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSel ? _kAccent.withValues(alpha: 0.18) : _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? _kAccent : _kBorder,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SvgPicture.asset(
                          breed.svgAssetPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        breed.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSel ? _kAccent : _kText,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SidebarTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? _kAccent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color:
                  isSelected ? _kAccent.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? _kAccent : _kTextMuted),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _kAccent : _kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Species panel
// ---------------------------------------------------------------------------
class _SpeciesPanel extends StatelessWidget {
  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  const _SpeciesPanel({required this.definition, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarSectionHeader(
          icon: CupertinoIcons.paw,
          label: 'AVATAR TYPE',
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
          ),
          itemCount: AvatarSpecies.values.length,
          itemBuilder: (context, i) {
            final species = AvatarSpecies.values[i];
            final isSel = definition.species == species;
            return Tooltip(
              message: species.displayName,
              child: InkWell(
                onTap: () {
                  final breeds = AvatarBreed.forSpecies(species);
                  final defaultBreedId = breeds.isNotEmpty ? breeds.first.id : null;
                  final updated = definition.copyWith(
                    species: species,
                    breed: defaultBreedId,
                    parts: Map<String, dynamic>.from(
                        species.defaultPartConfigurations),
                  );
                  onUpdate(updated);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _kAccent.withValues(alpha: 0.2)
                        : _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? _kAccent : _kBorder,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: SvgPicture.asset(
                            species.svgAssetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          species.displayName,
                          style: TextStyle(
                            fontSize: 8,
                            color: isSel ? _kAccent : _kTextMuted,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Palette panel
// ---------------------------------------------------------------------------
class _PalettePanel extends StatelessWidget {
  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  const _PalettePanel({required this.definition, required this.onUpdate});

  Color _hex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final palettes = AvatarPalette.presets.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarSectionHeader(
          icon: CupertinoIcons.paintbrush_fill,
          label: 'COLOR PALETTE',
        ),
        const SizedBox(height: 8),
        ...palettes.map((pal) {
          final isSel = definition.palette.name.toLowerCase() ==
              pal.name.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onUpdate(definition.copyWith(palette: pal)),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel
                      ? _kAccent.withValues(alpha: 0.12)
                      : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? _kAccent : _kBorder,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Color swatches
                    Row(
                      children: [
                        _ColorSwatch(_hex(pal.primary)),
                        const SizedBox(width: 3),
                        _ColorSwatch(_hex(pal.secondary)),
                        const SizedBox(width: 3),
                        _ColorSwatch(_hex(pal.accent)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pal.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSel ? _kText : _kTextMuted,
                        ),
                      ),
                    ),
                    if (isSel)
                      const Icon(CupertinoIcons.checkmark_circle_fill,
                          size: 14, color: _kAccent),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  const _ColorSwatch(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seed panel
// ---------------------------------------------------------------------------
class _SeedPanel extends StatefulWidget {
  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;
  final VoidCallback onRandomize;

  const _SeedPanel({
    required this.definition,
    required this.onUpdate,
    required this.onRandomize,
  });

  @override
  State<_SeedPanel> createState() => _SeedPanelState();
}

class _SeedPanelState extends State<_SeedPanel> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.definition.seed);
  }

  @override
  void didUpdateWidget(_SeedPanel old) {
    super.didUpdateWidget(old);
    if (old.definition.seed != widget.definition.seed) {
      _ctrl.text = widget.definition.seed;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarSectionHeader(
          icon: CupertinoIcons.sparkles,
          label: 'PET SEED',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          style: const TextStyle(
            color: _kText,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'e.g. fluffy-cat-42',
            hintStyle:
                const TextStyle(color: _kTextMuted, fontSize: 12),
            filled: true,
            fillColor: _kCard,
            prefixIcon: const Icon(CupertinoIcons.number,
                size: 14, color: _kTextMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kAccent),
            ),
          ),
          onSubmitted: (v) {
            final t = v.trim();
            if (t.isNotEmpty) {
              widget.onUpdate(widget.definition.copyWith(seed: t));
            }
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onRandomize,
            icon: const Icon(CupertinoIcons.shuffle, size: 14),
            label: const Text('Randomize Seed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kText,
              side: const BorderSide(color: _kBorder),
              backgroundColor: _kCard,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SidebarSectionHeader(
          icon: CupertinoIcons.info_circle,
          label: 'SEED INFO',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            'The seed determines your pet\'s markings, '
            'patterns, and unique characteristics. '
            'Each seed produces a distinct look.',
            style: const TextStyle(
              color: _kTextMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Camera 3D panel
// ---------------------------------------------------------------------------
class _Camera3DPanel extends StatelessWidget {
  final Pet3DController controller;
  const _Camera3DPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final cam = controller.cameraState;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SidebarSectionHeader(
              icon: CupertinoIcons.camera_viewfinder,
              label: '3D ORBIT CAMERA',
            ),
            const SizedBox(height: 12),
            _buildSliderRow(
              context,
              label: 'Azimuth (Yaw)',
              value: cam.azimuth,
              min: 0,
              max: 360,
              onChanged: (v) => controller.rotateTo(azimuth: v, elevation: cam.elevation),
            ),
            const SizedBox(height: 12),
            _buildSliderRow(
              context,
              label: 'Elevation (Pitch)',
              value: cam.elevation,
              min: -45,
              max: 45,
              onChanged: (v) => controller.rotateTo(azimuth: cam.azimuth, elevation: v),
            ),
            const SizedBox(height: 12),
            _buildSliderRow(
              context,
              label: 'Distance (Zoom)',
              value: cam.distance,
              min: 0.5,
              max: 2.5,
              onChanged: (v) => controller.zoom(v / cam.distance),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.resetCamera,
                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                label: const Text('Reset 3D Camera', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kText,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSliderRow(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: _kText, fontSize: 11, fontWeight: FontWeight.w600)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kAccent,
            inactiveTrackColor: _kBorder,
            thumbColor: Colors.white,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sidebar section header
// ---------------------------------------------------------------------------
class _SidebarSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SidebarSectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: _kTextMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kTextMuted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3D Viewport — big, centered avatar that reacts to mouse
// ---------------------------------------------------------------------------
class _Viewport extends StatefulWidget {
  final AvatarDefinition definition;
  final AvatarEngineController controller;
  final Pet3DController pet3DController;
  final Color bgColor;
  final bool isStatic;
  final bool isStudioMode;

  const _Viewport({
    required this.definition,
    required this.controller,
    required this.pet3DController,
    required this.bgColor,
    required this.isStatic,
    this.isStudioMode = false,
  });

  @override
  State<_Viewport> createState() => _ViewportState();
}

class _ViewportState extends State<_Viewport> {
  final GlobalKey _viewportKey = GlobalKey();
  Offset _mouseLocal = Offset.zero;
  bool _mouseTracking = true;
  Rect? _lastRect;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    _scheduleSyncNative(force: true);
  }

  @override
  void didUpdateWidget(_Viewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition ||
        oldWidget.isStudioMode != widget.isStudioMode ||
        oldWidget.bgColor != widget.bgColor) {
      _scheduleSyncNative(force: true);
    }
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      NativeBridge.hideCustomizerViewport();
    }
    super.dispose();
  }

  void _scheduleSyncNative({bool force = false}) {
    if (!Platform.isMacOS) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncNativeViewport(force: force);
    });
  }

  void _syncNativeViewport({bool force = false}) {
    if (!Platform.isMacOS) return;
    if (!sl.isRegistered<AvatarWebServer>()) return;

    final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

    final webServer = sl<AvatarWebServer>();
    final query = CompanionOverlayController.buildQueryParamsForAvatar(
      species: widget.definition.species,
      breed: widget.definition.breed,
      paletteId: widget.definition.palette.name.toLowerCase(),
    );

    final url = widget.isStudioMode
        ? webServer.buildEditorUrl(queryParams: '$query&animationPanel=0').toString()
        : webServer.buildCompanionUrl(queryParams: query).toString();

    if (force || _lastRect != rect || _lastUrl != url) {
      _lastRect = rect;
      _lastUrl = url;
      NativeBridge.showCustomizerViewport({
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'avatarUrl': url,
        'urlParams': query,
        'mode': widget.isStudioMode ? 'studio' : 'companion',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBreed = widget.definition.breed != null
        ? AvatarBreed.find(widget.definition.species, widget.definition.breed!)
        : null;
    final badgeLabel = activeBreed != null
        ? '${activeBreed.displayName} · ${widget.definition.species.displayName}'
        : '${widget.definition.species.displayName} · ${widget.definition.palette.name}';

    return Container(
      key: _viewportKey,
      child: MouseRegion(
        onHover: (event) {
          setState(() => _mouseLocal = event.localPosition);
          if (Platform.isMacOS && _mouseTracking) {
            final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null && renderBox.hasSize) {
              final w = renderBox.size.width;
              final h = renderBox.size.height;
              final center = Offset(w / 2, h / 2);
              final normX = (((event.localPosition.dx - center.dx) / (w * 0.5)).clamp(-1.0, 1.0));
              final normY = (((event.localPosition.dy - center.dy) / (h * 0.5)).clamp(-1.0, 1.0));
              NativeBridge.updateCustomizerViewport({
                'lookX': normX,
                'lookY': normY,
              });
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _scheduleSyncNative();

            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final center = Offset(w / 2, h / 2);

            // Normalized mouse [-1, 1] relative to viewport center
            final normX = (((_mouseLocal.dx - center.dx) / (w * 0.5))
                .clamp(-1.0, 1.0));
            final normY = (((_mouseLocal.dy - center.dy) / (h * 0.5))
                .clamp(-1.0, 1.0));

            // Avatar size: fill nicely — 60% of the shorter viewport dimension
            final avatarSize =
                math.min(w, h) * 0.60;

            return Stack(
              children: [
                // Background fill — solid color
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.bgColor),
                  ),
                ),

                // Subtle radial highlight on the background
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(normX * 0.3, normY * 0.3),
                          radius: 0.7,
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Fallback avatar view for non-macOS or test runs
                if (!Platform.isMacOS)
                  Center(
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: AvatarView(
                        definition: widget.definition,
                        controller: widget.controller,
                        width: avatarSize,
                        height: avatarSize,
                        transparent: true,
                        externalLookAt: _mouseTracking ? Offset(normX, normY) : Offset.zero,
                        isInteractive: true,
                        autoTrackCursor: false,
                        isStatic: widget.isStatic,
                      ),
                    ),
                  ),

                // Top-left info badge
                if (!widget.isStudioMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _ViewportBadge(
                      label: badgeLabel,
                      color: _kAccent,
                    ),
                  ),

                // Top-right 3D controls & tracker toggle
                if (!widget.isStudioMode)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _mouseTracking = !_mouseTracking),
                          borderRadius: BorderRadius.circular(20),
                          child: _ViewportBadge(
                            icon: _mouseTracking ? CupertinoIcons.viewfinder : CupertinoIcons.eye_slash,
                            label: _mouseTracking ? 'Eye Tracking (ON)' : 'Tracking (OFF)',
                            color: _mouseTracking ? _kAccent : _kTextMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            if (Platform.isMacOS) {
                              NativeBridge.updateCustomizerViewport({'urlParams': 'zoom=1.15'});
                            }
                            widget.pet3DController.zoom(1.15);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: const _ViewportBadge(
                            icon: CupertinoIcons.plus_circle,
                            label: 'Zoom In',
                            color: _kText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            if (Platform.isMacOS) {
                              NativeBridge.updateCustomizerViewport({'urlParams': 'zoom=0.85'});
                            }
                            widget.pet3DController.zoom(0.85);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: const _ViewportBadge(
                            icon: CupertinoIcons.minus_circle,
                            label: 'Zoom Out',
                            color: _kText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            _scheduleSyncNative(force: true);
                            widget.pet3DController.resetCamera();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: const _ViewportBadge(
                            icon: CupertinoIcons.arrow_counterclockwise,
                            label: 'Reset 3D',
                            color: _kText,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bottom hint helper
                if (!widget.isStudioMode)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Drag in 3D to orbit · Move cursor to look · Real WebGL 3D Companion',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewportBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ViewportBadge({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom toolbar
// ---------------------------------------------------------------------------
class _BottomBar extends StatelessWidget {
  final Color bgColor;
  final ValueChanged<Color> onBgColorChanged;
  final VoidCallback onReset;
  final VoidCallback onRandomize;
  final Future<void> Function() onSave;

  static const _bgPresets = [
    (name: 'Lavender', color: Color(0xFF9B8EC4)),
    (name: 'Midnight', color: Color(0xFF0F111D)),
    (name: 'Slate', color: Color(0xFF181A26)),
    (name: 'Deep', color: Color(0xFF141622)),
    (name: 'Warm', color: Color(0xFF242129)),
    (name: 'Clear', color: Colors.transparent),
  ];

  const _BottomBar({
    required this.bgColor,
    required this.onBgColorChanged,
    required this.onReset,
    required this.onRandomize,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: _kSidebar,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Background color presets
          const Icon(CupertinoIcons.paintbrush,
              size: 13, color: _kTextMuted),
          const SizedBox(width: 8),
          const Text(
            'Stage:',
            style: TextStyle(
                color: _kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          ...(_bgPresets.map((p) {
            final isSel = bgColor == p.color;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Tooltip(
                message: p.name,
                child: InkWell(
                  onTap: () => onBgColorChanged(p.color),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: p.color == Colors.transparent ? null : 22,
                    height: 22,
                    padding: p.color == Colors.transparent
                        ? const EdgeInsets.symmetric(horizontal: 6)
                        : null,
                    decoration: BoxDecoration(
                      color: p.color == Colors.transparent
                          ? _kCard
                          : p.color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSel ? _kAccent : _kBorder,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: p.color == Colors.transparent
                        ? Text(p.name,
                            style: const TextStyle(
                                color: _kTextMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600))
                        : null,
                  ),
                ),
              ),
            );
          })),

          const Spacer(),

          // Reset
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise,
                size: 13),
            label: const Text('Reset',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: _kTextMuted),
          ),
          const SizedBox(width: 8),

          // Randomize
          OutlinedButton.icon(
            onPressed: onRandomize,
            icon: const Icon(CupertinoIcons.shuffle, size: 13),
            label: const Text('Randomize',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kText,
              side: const BorderSide(color: _kBorder),
              backgroundColor: _kCard,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Save
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(CupertinoIcons.check_mark_circled_solid,
                size: 14),
            label: const Text('Save Pet',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
