import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/avatar_breed.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The companion studio: pick a species, a breed, a palette and a seed, and
/// watch the result behave exactly as it will on the desktop.
///
/// There is one surface here on purpose. The page used to carry a second
/// "3D view" mode with an orbit camera beside this one, which duplicated every
/// control and only ever worked on macOS.
class AvatarCustomizerPage extends StatefulWidget {
  const AvatarCustomizerPage({
    super.key,
    this.initialDefinition,
    this.engineController,
    this.onSaved,
    this.onCancel,
    this.isStatic = false,
  });

  final AvatarDefinition? initialDefinition;
  final AvatarEngineController? engineController;
  final ValueChanged<AvatarDefinition>? onSaved;
  final VoidCallback? onCancel;

  /// Freezes the preview's motion, for tests and golden captures.
  final bool isStatic;

  @override
  State<AvatarCustomizerPage> createState() => _AvatarCustomizerPageState();
}

enum _StudioSection {
  species('Species', Icons.pets_rounded),
  breed('Breed', Icons.auto_awesome_mosaic_rounded),
  palette('Palette', Icons.palette_rounded),
  seed('Seed', Icons.casino_rounded);

  const _StudioSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The backdrops the preview can be checked against. A companion that reads
/// well on one background can disappear on another, so the studio makes it
/// easy to try the extremes before saving.
const List<Color> _backdrops = <Color>[
  Color(0xFF1B1B20),
  Color(0xFF0B1220),
  Color(0xFF243B34),
  Color(0xFF4B3F63),
  Color(0xFF8A6A52),
  Color(0xFFE7E5E4),
];

class _AvatarCustomizerPageState extends State<AvatarCustomizerPage>
    with SingleTickerProviderStateMixin {
  late AvatarDefinition _definition;
  late AvatarEngineController _controller;
  bool _ownsController = false;

  late final PetBehaviorEngine _engine = PetBehaviorEngine(
    reducedMotion: widget.isStatic,
  );
  Ticker? _ticker;

  _StudioSection _section = _StudioSection.species;
  Color _backdrop = _backdrops.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    var initial =
        widget.initialDefinition ?? AvatarDefinition.fromSpecies(AvatarSpecies.cat);
    if (initial.breed == null) {
      final breeds = AvatarBreed.forSpecies(initial.species);
      if (breeds.isNotEmpty) initial = initial.copyWith(breed: breeds.first.id);
    }
    _definition = initial;

    if (widget.engineController != null) {
      _controller = widget.engineController!;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
    _controller.setDefinition(_definition);

    // The preview drives the pet from its own pointer rather than the global
    // cursor feed, so it stays correct no matter where the window sits.
    _engine.startLocal();
    if (!widget.isStatic) {
      _ticker = createTicker(_engine.tick)..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _engine.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _update(AvatarDefinition definition) {
    setState(() => _definition = definition);
    _controller.setDefinition(definition);
    _engine.nudge();
  }

  void _selectSpecies(AvatarSpecies species) {
    final breeds = AvatarBreed.forSpecies(species);
    _update(
      _definition.copyWith(
        species: species,
        // A breed belongs to one species, so carrying the old one over would
        // ask for artwork that does not exist.
        breed: breeds.isNotEmpty ? breeds.first.id : null,
        seed: 'species-${species.name}',
      ),
    );
  }

  void _randomize() {
    final roll = math.Random().nextInt(900000) + 100000;
    _update(
      AvatarDefinition.fromSeed(
        '${_definition.species.name}-$roll',
        species: _definition.species,
      ).copyWith(breed: _definition.breed),
    );
  }

  void _reset() {
    final species = _definition.species;
    final breeds = AvatarBreed.forSpecies(species);
    _update(
      AvatarDefinition.fromSpecies(
        species,
        breed: breeds.isNotEmpty ? breeds.first.id : null,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    var persisted = true;
    try {
      if (sl.isRegistered<CompanionOverlayController>()) {
        final controller = sl<CompanionOverlayController>();
        await controller.changeTheme('avatar_${_definition.species.name}');
        await controller.saveAvatarDefinition(_definition);
      } else {
        final repo = _settingsRepository();
        await repo?.save(
          repo.currentSettings.copyWith(
            companionPetTheme: 'avatar_${_definition.species.name}',
            companionAvatarDefinition: jsonEncode(_definition.toJson()),
          ),
        );
      }
    } catch (_) {
      persisted = false;
    }

    widget.onSaved?.call(_definition);
    if (!mounted) return;
    setState(() => _saving = false);

    if (persisted) {
      Toast.showSuccess(context, 'Companion saved');
      if (Navigator.canPop(context)) Navigator.pop(context, _definition);
    } else {
      Toast.showError(context, 'Could not save your companion.');
    }
  }

  /// The settings store, when one is in scope. A standalone studio has none.
  SettingsRepository? _settingsRepository() {
    try {
      return Provider.of<SettingsRepository>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _cancel() {
    widget.onCancel?.call();
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: <Widget>[
          _StudioTopBar(
            subtitle: _summary,
            saving: _saving,
            onClose: _cancel,
            onSave: _save,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 288,
                  child: _StudioSidebar(
                    definition: _definition,
                    section: _section,
                    onSectionChanged: (s) => setState(() => _section = s),
                    onSpeciesSelected: _selectSpecies,
                    onUpdate: _update,
                    onRandomize: _randomize,
                  ),
                ),
                Expanded(
                  child: _StudioPreview(
                    definition: _definition,
                    engine: _engine,
                    backdrop: _backdrop,
                    onBackdropChanged: (c) => setState(() => _backdrop = c),
                    onRandomize: _randomize,
                    onReset: _reset,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _summary {
    final breedId = _definition.breed;
    final breed =
        breedId == null ? null : AvatarBreed.find(_definition.species, breedId);
    final name = breed?.displayName ?? _definition.species.displayName;
    return '$name · ${_definition.palette.name}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({
    required this.subtitle,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final String subtitle;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: <Widget>[
            _IconAction(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: onClose,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Companion Studio',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(saving ? 'Saving' : 'Save companion'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.gray950,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _StudioSidebar extends StatelessWidget {
  const _StudioSidebar({
    required this.definition,
    required this.section,
    required this.onSectionChanged,
    required this.onSpeciesSelected,
    required this.onUpdate,
    required this.onRandomize,
  });

  final AvatarDefinition definition;
  final _StudioSection section;
  final ValueChanged<_StudioSection> onSectionChanged;
  final ValueChanged<AvatarSpecies> onSpeciesSelected;
  final ValueChanged<AvatarDefinition> onUpdate;
  final VoidCallback onRandomize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SectionTabs(
              selected: section,
              onChanged: onSectionChanged,
            ),
          ),
          Expanded(child: _buildPanel()),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    switch (section) {
      case _StudioSection.species:
        return _SpeciesPanel(
          definition: definition,
          onSelected: onSpeciesSelected,
        );
      case _StudioSection.breed:
        return _BreedPanel(definition: definition, onUpdate: onUpdate);
      case _StudioSection.palette:
        return _PalettePanel(definition: definition, onUpdate: onUpdate);
      case _StudioSection.seed:
        return _SeedPanel(
          definition: definition,
          onUpdate: onUpdate,
          onRandomize: onRandomize,
        );
    }
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onChanged});

  final _StudioSection selected;
  final ValueChanged<_StudioSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          for (final section in _StudioSection.values)
            Expanded(
              child: _SectionTab(
                section: section,
                isSelected: section == selected,
                onTap: () => onChanged(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final _StudioSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.accent : AppTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(section.icon, size: 15, color: color),
            const SizedBox(height: 4),
            Text(
              section.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared chrome for a scrollable panel of choices.
class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A selectable artwork tile.
///
/// The grids these sit in scroll lazily on purpose: the breed list alone is
/// 129 illustrations, and building them all at once was the single biggest
/// stall in this page.
class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({
    required this.recipe,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AvatarArtworkRecipe recipe;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Expanded(child: AvatarArtwork(recipe: recipe)),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesPanel extends StatelessWidget {
  const _SpeciesPanel({required this.definition, required this.onSelected});

  final AvatarDefinition definition;
  final ValueChanged<AvatarSpecies> onSelected;

  @override
  Widget build(BuildContext context) {
    final species = AvatarSpecies.values;
    return _PanelScaffold(
      title: '${species.length} species',
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: species.length,
        itemBuilder: (context, index) {
          final entry = species[index];
          return _ArtworkTile(
            recipe: AvatarArtworkRecipe(assetKey: entry.svgAssetPath),
            label: entry.displayName,
            isSelected: entry == definition.species,
            onTap: () => onSelected(entry),
          );
        },
      ),
    );
  }
}

class _BreedPanel extends StatelessWidget {
  const _BreedPanel({required this.definition, required this.onUpdate});

  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  @override
  Widget build(BuildContext context) {
    final breeds = AvatarBreed.forSpecies(definition.species);

    if (breeds.isEmpty) {
      return _PanelScaffold(
        title: 'Breeds',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${definition.species.displayName} has a single look.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    final selected = definition.breed ?? breeds.first.id;
    return _PanelScaffold(
      title: '${definition.species.displayName} · ${breeds.length} breeds',
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.86,
        ),
        itemCount: breeds.length,
        itemBuilder: (context, index) {
          final breed = breeds[index];
          return _ArtworkTile(
            recipe: AvatarArtworkRecipe(assetKey: breed.svgAssetPath),
            label: breed.displayName,
            isSelected: breed.id == selected,
            onTap: () => onUpdate(definition.copyWith(breed: breed.id)),
          );
        },
      ),
    );
  }
}

class _PalettePanel extends StatelessWidget {
  const _PalettePanel({required this.definition, required this.onUpdate});

  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  @override
  Widget build(BuildContext context) {
    final palettes = AvatarPalette.presets.values.toList();

    return _PanelScaffold(
      title: 'Palette',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: palettes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final palette = palettes[index];
          final isSelected = palette.name == definition.palette.name;
          return InkWell(
            onTap: () => onUpdate(definition.copyWith(palette: palette)),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.12)
                    : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : AppTheme.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  _PaletteSwatches(palette: palette),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _titleCase(palette.name),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        size: 15, color: AppTheme.accent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _titleCase(String value) {
    final spaced = value.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.palette});

  final AvatarPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = <String>[
      palette.primary,
      palette.secondary,
      palette.accent,
      palette.belly,
    ];

    return SizedBox(
      width: 52,
      height: 20,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 11.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _parse(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _parse(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? AppTheme.gray500 : Color(0xFF000000 | value);
  }
}

class _SeedPanel extends StatefulWidget {
  const _SeedPanel({
    required this.definition,
    required this.onUpdate,
    required this.onRandomize,
  });

  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;
  final VoidCallback onRandomize;

  @override
  State<_SeedPanel> createState() => _SeedPanelState();
}

class _SeedPanelState extends State<_SeedPanel> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.definition.seed);

  @override
  void didUpdateWidget(_SeedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.seed != widget.definition.seed) {
      _controller.text = widget.definition.seed;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    widget.onUpdate(widget.definition.copyWith(seed: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Seed',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: <Widget>[
          TextField(
            controller: _controller,
            onSubmitted: _commit,
            onEditingComplete: () => _commit(_controller.text),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.surfaceCard,
              hintText: 'e.g. fluffy-cat-42',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onRandomize,
              icon: const Icon(Icons.shuffle_rounded, size: 15),
              label: const Text('Randomize'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.surfaceCard,
                side: BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              'The seed picks the palette and markings when you randomize. '
              'The same seed always produces the same companion.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.55,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview
// ─────────────────────────────────────────────────────────────────────────────

class _StudioPreview extends StatelessWidget {
  const _StudioPreview({
    required this.definition,
    required this.engine,
    required this.backdrop,
    required this.onBackdropChanged,
    required this.onRandomize,
    required this.onReset,
  });

  final AvatarDefinition definition;
  final PetBehaviorEngine engine;
  final Color backdrop;
  final ValueChanged<Color> onBackdropChanged;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              // The engine works in whatever space its viewport is given. Here
              // that is the preview's own box, so local pointer positions can
              // be fed straight in.
              engine.setViewport(Rect.fromLTWH(0, 0, width, height));
              final stageSize = math.min(width, height) * 0.62;

              return MouseRegion(
                onHover: (event) => engine.pointerMoved(event.localPosition),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.25),
                            radius: 1.1,
                            colors: <Color>[
                              Color.alphaBlend(
                                Colors.white.withValues(alpha: 0.07),
                                backdrop,
                              ),
                              backdrop,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedBuilder(
                        animation: engine,
                        builder: (context, _) => PetStage(
                          snapshot: engine.snapshot,
                          size: stageSize,
                          definition: definition,
                          onTap: engine.pet,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: engine,
                        builder: (context, _) => _ActivityChip(
                          label: engine.snapshot.activity.name,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 16,
                      bottom: 16,
                      child: _PreviewHint(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _PreviewToolbar(
          backdrop: backdrop,
          onBackdropChanged: onBackdropChanged,
          onRandomize: onRandomize,
          onReset: onReset,
        ),
      ],
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHint extends StatelessWidget {
  const _PreviewHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: const Text(
        'Move your cursor to get its attention · click to pet',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.backdrop,
    required this.onBackdropChanged,
    required this.onRandomize,
    required this.onReset,
  });

  final Color backdrop;
  final ValueChanged<Color> onBackdropChanged;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'BACKDROP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          for (final color in _backdrops) ...<Widget>[
            _BackdropSwatch(
              color: color,
              isSelected: color.toARGB32() == backdrop.toARGB32(),
              onTap: () => onBackdropChanged(color),
            ),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onRandomize,
            icon: const Icon(Icons.shuffle_rounded, size: 15),
            label: const Text('Surprise me'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropSwatch extends StatelessWidget {
  const _BackdropSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
