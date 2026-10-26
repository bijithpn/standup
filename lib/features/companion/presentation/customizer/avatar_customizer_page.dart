import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/avatar_breed.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

part 'avatar_customizer_top_bar.dart';
part 'avatar_customizer_panels.dart';
part 'avatar_customizer_preview.dart';

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
  style('Style', Icons.tune_rounded),
  seed('Seed', Icons.casino_rounded);

  const _StudioSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The backdrops the preview can be checked against.
///
/// The first is the colour the companion was authored with, which is what the
/// editor shows; the rest are there because a companion that reads well on one
/// background can disappear on another.
const List<Color> _backdrops = <Color>[
  kSceneAuthoredBackground,
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
        widget.initialDefinition ??
        AvatarDefinition.fromSpecies(AvatarSpecies.cat);
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
    final breed = breedId == null
        ? null
        : AvatarBreed.find(_definition.species, breedId);
    final name = breed?.displayName ?? _definition.species.displayName;
    return '$name · ${_definition.palette.name}';
  }
}

