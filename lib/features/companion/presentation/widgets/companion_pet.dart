import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';

/// A live companion drawn inside an ordinary window.
///
/// Owns one [PetBehaviorEngine] on one ticker and reads the shared
/// [CursorFeed], so every surface that shows the pet — the fullscreen
/// companion panel, the break overlay — moves the same way and costs the same.
/// The picture-in-picture window does this itself, because there the window
/// *is* the pet and its viewport comes straight from the window manager.
class CompanionPet extends StatefulWidget {
  const CompanionPet({
    super.key,
    required this.size,
    this.definition,
    this.blobName,
    this.trackCursor = true,
    this.isStatic = false,
    this.showShadow = true,
    this.onTap,
    this.onDoubleTap,
  });

  /// Edge length of the square the pet is drawn into.
  final double size;

  /// The illustrated companion. Ignored when [blobName] is set.
  final AvatarDefinition? definition;

  /// Renders the generative blob for this name instead of artwork.
  final String? blobName;

  /// Whether the pet watches the cursor across the whole screen.
  final bool trackCursor;

  /// Freezes motion, for tests and golden captures.
  final bool isStatic;

  final bool showShadow;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<CompanionPet> createState() => CompanionPetState();
}

class CompanionPetState extends State<CompanionPet>
    with SingleTickerProviderStateMixin {
  /// The pet's own window rarely moves, and being a moment stale only shifts
  /// where it thinks it is by a few pixels.
  static const Duration _originRefresh = Duration(seconds: 2);

  late final PetBehaviorEngine _engine = PetBehaviorEngine(
    reducedMotion: widget.isStatic,
  );
  Ticker? _ticker;
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastFrameElapsed = Duration.zero;
  Timer? _restTimer;
  static const Duration _restInterval = Duration(milliseconds: 250);
  StreamSubscription<CursorSample>? _cursorSub;
  Timer? _originTimer;

  /// Where this window sits on screen, so widget coordinates can be compared
  /// with the cursor's.
  Offset _windowOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _engine.startLocal();

    if (!widget.isStatic) {
      _ticker = createTicker(_tickEngine)..start();
      _engine.onNeedsFrames = _requestFrames;
      _refreshOrigin();
      _originTimer = Timer.periodic(_originRefresh, (_) => _refreshOrigin());
    }
    _bindCursor();
  }

  @override
  void didUpdateWidget(CompanionPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackCursor != widget.trackCursor ||
        oldWidget.isStatic != widget.isStatic) {
      _bindCursor();
    }
  }

  @override
  void dispose() {
    _cursorSub?.cancel();
    _originTimer?.cancel();
    _restTimer?.cancel();
    _engine.onNeedsFrames = null;
    _ticker?.dispose();
    _engine.dispose();
    super.dispose();
  }

  /// Runs the frame ticker again after something gave the pet work to do.
  void _requestFrames() {
    final ticker = _ticker;
    if (!mounted || ticker == null) return;
    _restTimer?.cancel();
    _restTimer = null;
    if (!ticker.isActive) ticker.start();
  }

  void _tickEngine(Duration _) {
    final now = _clock.elapsed;
    if (now - _lastFrameElapsed < _engine.frameInterval) return;
    _lastFrameElapsed = now;
    _engine.tick(now);
    if (_engine.isSettled) _enterRest();
  }

  /// Nothing is moving: stop asking Flutter for frames and tick slowly so the
  /// slow feelings (drowsiness, loneliness) still advance.
  void _enterRest() {
    _ticker?.stop();
    _restTimer ??= Timer.periodic(_restInterval, (_) {
      if (!mounted) return;
      _engine.tick(_clock.elapsed);
      if (!_engine.isSettled) _requestFrames();
    });
  }

  void _bindCursor() {
    _cursorSub?.cancel();
    _cursorSub = null;
    if (!widget.trackCursor || widget.isStatic) return;
    _cursorSub = CursorFeed.instance.subscribe(_onCursorSample);
  }

  Future<void> _refreshOrigin() async {
    if (!Platform.isMacOS && !Platform.isWindows) return;
    try {
      _windowOrigin = await windowManager.getPosition();
    } catch (_) {
      // Secondary engines do not all carry the window plugin. A fullscreen
      // overlay sits at the origin anyway, which is the common case here.
    }
  }

  void _onCursorSample(CursorSample sample) {
    if (!mounted) return;
    final viewport = _screenRect();
    if (viewport == null) return;
    _engine
      ..setViewport(viewport)
      ..pointerMoved(sample.position);
  }

  /// This widget's rectangle in screen coordinates.
  Rect? _screenRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      _windowOrigin.dx + topLeft.dx,
      _windowOrigin.dy + topLeft.dy,
      box.size.width,
      box.size.height,
    );
  }

  /// Reacts to being petted. Exposed so the window hosting the pet can trigger
  /// it from its own gestures or from an incoming state change.
  void pet() => _engine.pet();

  /// Gets the pet's attention without touching it.
  void nudge() => _engine.nudge();

  void _handleTap() {
    _engine.pet();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _engine,
        builder: (context, _) => PetStage(
          snapshot: _engine.snapshot,
          size: widget.size,
          definition: widget.blobName == null ? widget.definition : null,
          blobName: widget.blobName,
          showShadow: widget.showShadow,
          onTap: _handleTap,
          onDoubleTap: widget.onDoubleTap,
        ),
      ),
    );
  }
}
