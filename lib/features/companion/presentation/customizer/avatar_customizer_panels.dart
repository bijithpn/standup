part of 'avatar_customizer_page.dart';

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
            child: _SectionTabs(selected: section, onChanged: onSectionChanged),
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
      case _StudioSection.style:
        return _StylePanel(definition: definition, onUpdate: onUpdate);
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
    required this.species,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.palette,
    this.style = AvatarSceneStyle.authored,
    this.fallbackAsset,
  });

  /// The species the tile previews, as an app-side enum name.
  final String species;

  /// Applied so a tile shows the companion as it would actually look.
  final AvatarPalette? palette;

  /// Ditto for the scene styling, so a lit-from-the-left companion is lit
  /// that way in the grid the user picks it from.
  final AvatarSceneStyle style;

  /// Flat artwork for anything the scene catalog cannot build.
  final String? fallbackAsset;

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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final extent = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (!hasAvatarScene(species)) {
                      return AvatarArtwork(
                        recipe: AvatarArtworkRecipe(
                          assetKey: fallbackAsset ?? '',
                        ),
                      );
                    }
                    return Avatar3DView(
                      preset: avatarPresetFor(species),
                      size: extent,
                      palette: palette,
                      style: style,
                      // A grid of tiles is the one place the mesh cost
                      // multiplies, so each one is drawn coarsely.
                      densityScale: 0.4,
                      showShadow: false,
                    );
                  },
                ),
              ),
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
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
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
            species: entry.name,
            fallbackAsset: entry.svgAssetPath,
            palette: definition.palette == AvatarPalette.defaultPalette
                ? null
                : definition.palette,
            style: avatarStyleFrom(definition.parts),
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
            // Breeds are variations of one species, so each tile previews the
            // species scene; the breed's own artwork is the fallback.
            species: definition.species.name,
            fallbackAsset: breed.svgAssetPath,
            palette: definition.palette == AvatarPalette.defaultPalette
                ? null
                : definition.palette,
            style: avatarStyleFrom(definition.parts),
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, size: 15, color: AppTheme.accent),
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

/// Everything about the companion's look that is not its species or its
/// colours.
///
/// These were all in the scene data from the start and none of them were
/// reachable, so every companion wore exactly the look its illustrator picked:
/// the same light, the same outline weight, the same face proportions. Each
/// control here is an override, and "Reset" puts every one of them back to
/// whatever the scene was authored with rather than to some global default.
class _StylePanel extends StatelessWidget {
  const _StylePanel({required this.definition, required this.onUpdate});

  final AvatarDefinition definition;
  final ValueChanged<AvatarDefinition> onUpdate;

  AvatarSceneStyle get _style => avatarStyleFrom(definition.parts);

  /// The scene as authored, when the catalog has it. Used for the starting
  /// position of controls the user has not touched, so a slider at rest shows
  /// the truth rather than a made-up default.
  AvatarScene? get _authored => AvatarSceneCatalog.instance.sceneFor(
    avatarPresetFor(definition.species.name),
  );

  void _apply(AvatarSceneStyle style) {
    onUpdate(
      definition.copyWith(parts: withAvatarStyle(definition.parts, style)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final scene = _authored;

    return _PanelScaffold(
      title: 'Style',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: <Widget>[
          _StyleGroup(
            label: 'Light',
            children: <Widget>[
              _StyleSlider(
                label: 'Direction',
                value:
                    style.lightAzimuth ??
                    scene?.lightAzimuth ??
                    kDefaultLightAzimuth,
                min: -180,
                max: 180,
                format: (v) => '${v.round()}°',
                onChanged: (v) =>
                    _apply(style.copyWith(lightAzimuth: normaliseAzimuth(v))),
              ),
              _StyleSlider(
                label: 'Height',
                value:
                    style.lightElevation ??
                    scene?.lightElevation ??
                    kDefaultLightElevation,
                min: AvatarSceneStyle.minElevation,
                max: AvatarSceneStyle.maxElevation,
                format: (v) => '${v.round()}°',
                onChanged: (v) => _apply(style.copyWith(lightElevation: v)),
              ),
            ],
          ),
          _StyleGroup(
            label: 'Linework',
            children: <Widget>[
              _StyleSwitch(
                label: 'Outline',
                value: style.showOutline ?? scene?.showOutline ?? true,
                onChanged: (v) => _apply(style.copyWith(showOutline: v)),
              ),
              _StyleSlider(
                label: 'Weight',
                value: style.outlineWidth ?? 1.0,
                min: AvatarSceneStyle.minOutlineWidth,
                max: AvatarSceneStyle.maxOutlineWidth,
                format: (v) => '${v.toStringAsFixed(2)}x',
                enabled: style.showOutline ?? scene?.showOutline ?? true,
                onChanged: (v) => _apply(style.copyWith(outlineWidth: v)),
              ),
              _StyleSwitch(
                label: 'Drop shadow',
                value: style.showShadow ?? scene?.showAvatarShadow ?? true,
                onChanged: (v) => _apply(style.copyWith(showShadow: v)),
              ),
            ],
          ),
          _StyleGroup(
            label: 'Face',
            children: <Widget>[
              _StyleSlider(
                label: 'Size',
                value: style.faceScale ?? 1.0,
                min: AvatarSceneStyle.minFaceScale,
                max: AvatarSceneStyle.maxFaceScale,
                format: (v) => '${v.toStringAsFixed(2)}x',
                onChanged: (v) => _apply(style.copyWith(faceScale: v)),
              ),
              _StyleSlider(
                label: 'Eye spacing',
                value: style.eyeSpacing ?? 1.0,
                min: AvatarSceneStyle.minEyeSpacing,
                max: AvatarSceneStyle.maxEyeSpacing,
                format: (v) => '${v.toStringAsFixed(2)}x',
                onChanged: (v) => _apply(style.copyWith(eyeSpacing: v)),
              ),
              _StyleSwitch(
                label: 'Eye sparkle',
                value:
                    style.eyeSparkle ??
                    scene?.faceStyle.highlightEnabled ??
                    false,
                onChanged: (v) => _apply(style.copyWith(eyeSparkle: v)),
              ),
              _StyleSwitch(
                label: 'Nose',
                value: style.nose ?? scene?.faceStyle.noseEnabled ?? false,
                onChanged: (v) => _apply(style.copyWith(nose: v)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: style.isAuthored
                  ? null
                  : () => _apply(AvatarSceneStyle.authored),
              icon: const Icon(Icons.restart_alt_rounded, size: 15),
              label: const Text('Back to the original look'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleGroup extends StatelessWidget {
  const _StyleGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = enabled ? AppTheme.textSecondary : AppTheme.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              Text(
                format(value),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: AppTheme.accent,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleSwitch extends StatelessWidget {
  const _StyleSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: value,
              activeThumbColor: AppTheme.accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
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
                  border: Border.all(
                    color: AppTheme.surfaceElevated,
                    width: 1.5,
                  ),
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
  late final TextEditingController _controller = TextEditingController(
    text: widget.definition.seed,
  );

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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
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

