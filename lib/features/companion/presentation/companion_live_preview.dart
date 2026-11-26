import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';

/// Live review surface: uses the production renderer and behavior engine.
/// Pointer coordinates and eye coordinates are both local to this Flutter view.
class CompanionLivePreview extends StatefulWidget {
  const CompanionLivePreview({
    super.key,
    this.initialSpecies = AvatarSpecies.sheep,
  });

  final AvatarSpecies initialSpecies;

  @override
  State<CompanionLivePreview> createState() => CompanionLivePreviewState();
}

class CompanionLivePreviewState extends State<CompanionLivePreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _stageKey = GlobalKey();
  late final PetBehaviorEngine _engine = PetBehaviorEngine(species: _species)
    ..startLocal();
  late final Ticker _ticker = createTicker(_tick)..start();
  late AvatarSpecies _species = widget.initialSpecies;
  double _size = 440;
  bool _dark = false;
  bool _reducedMotion = false;
  Duration _lastFrame = Duration.zero;

  @visibleForTesting
  PetBehaviorSnapshot get snapshot => _engine.snapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureMotion();
  }

  void _configureMotion() => _engine.configure(
    reducedMotion: _reducedMotion || MediaQuery.disableAnimationsOf(context),
  );

  void _tick(Duration elapsed) {
    if (elapsed - _lastFrame < _engine.frameInterval) return;
    _lastFrame = elapsed;
    _engine.tick(elapsed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _engine.setSuspended(state != AppLifecycleState.resumed);
  }

  void _trackPointer(Offset position) {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _engine
      ..setViewport(box.localToGlobal(Offset.zero) & box.size)
      ..pointerMoved(position);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = _dark
        ? const Color(0xff262824)
        : const Color(0xffece9e2);
    final foreground = _dark
        ? const Color(0xffeeeade)
        : const Color(0xff373b30);
    return Scaffold(
      backgroundColor: background,
      body: MouseRegion(
        onEnter: (event) => _trackPointer(event.position),
        onHover: (event) => _trackPointer(event.position),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(
              _size,
              math.max(160.0, constraints.maxWidth - 48),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      Text(
                        'Your little companion',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move your cursor around the pet. Click its head to say hello.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: foreground),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AvatarSpecies>(
                        key: ValueKey(_species),
                        initialValue: _species,
                        decoration: const InputDecoration(
                          labelText: 'Companion',
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                        items: AvatarSpecies.values
                            .map(
                              (species) => DropdownMenuItem(
                                value: species,
                                child: Text(species.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (species) {
                          if (species == null) return;
                          setState(() => _species = species);
                          _engine.configure(species: species);
                        },
                      ),
                      GestureDetector(
                        key: const ValueKey('live-pet-interaction'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _engine.pet,
                        child: SizedBox(
                          key: _stageKey,
                          width: size,
                          height: size,
                          child: AnimatedBuilder(
                            animation: _engine,
                            builder: (context, _) => Avatar3DView(
                              preset: avatarPresetFor(_species.name),
                              size: size,
                              densityScale: avatarDensityFor(size),
                              snapshot: _engine.snapshot,
                              showShadow: true,
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _engine,
                        builder: (context, _) => Text(
                          _engine.snapshot.activity.name,
                          key: const ValueKey('live-pet-activity'),
                          style: TextStyle(color: foreground),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: _engine.pet,
                            child: const Text('Say hello'),
                          ),
                          OutlinedButton(
                            onPressed: _engine.play,
                            child: const Text('Play'),
                          ),
                          OutlinedButton(
                            onPressed: _engine.feed,
                            child: const Text('Give a treat'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Size', style: TextStyle(color: foreground)),
                          Expanded(
                            child: Slider(
                              value: _size,
                              min: 240,
                              max: 560,
                              divisions: 16,
                              label: '${_size.round()} px',
                              onChanged: (value) =>
                                  setState(() => _size = value),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          FilterChip(
                            label: const Text('Dark background'),
                            selected: _dark,
                            onSelected: (value) =>
                                setState(() => _dark = value),
                          ),
                          FilterChip(
                            label: const Text('Reduced motion'),
                            selected: _reducedMotion,
                            onSelected: (value) {
                              setState(() => _reducedMotion = value);
                              _configureMotion();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
