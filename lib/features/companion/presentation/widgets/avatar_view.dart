import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_3d_view.dart';

/// A companion viewport widget showcasing the authentic species SVG vector artwork cleanly.
class AvatarView extends StatefulWidget {
  final AvatarDefinition definition;
  final AvatarEngineController? controller;
  final double width;
  final double height;
  final bool isInteractive;
  final bool autoTrackCursor;
  final bool isStatic;
  final CursorTracker? cursorTracker;
  final Widget? fallback;
  final WidgetBuilder? fallbackBuilder;
  final bool transparent;
  final bool prefer3D;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Offset? externalLookAt;

  const AvatarView({
    super.key,
    required this.definition,
    this.controller,
    this.width = 160.0,
    this.height = 160.0,
    this.isInteractive = true,
    this.autoTrackCursor = true,
    this.isStatic = false,
    this.cursorTracker,
    this.fallback,
    this.fallbackBuilder,
    this.transparent = true,
    this.prefer3D = true,
    this.onTap,
    this.onDoubleTap,
    this.externalLookAt,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> with TickerProviderStateMixin {
  late AvatarEngineController _controller;
  bool _ownsController = false;

  late AnimationController _animController;

  StreamSubscription<AvatarEvent>? _eventSub;
  StreamSubscription<ui.Offset>? _cursorSub;
  StreamSubscription<CursorSample>? _feedSub;

  Offset _gazeOffset = Offset.zero;
  Offset _targetGaze = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initController();

    if (widget.externalLookAt != null) {
      _targetGaze = widget.externalLookAt!;
      _gazeOffset = widget.externalLookAt!;
    }

    // Idle breathing and floating animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    if (!widget.isStatic) {
      _animController.repeat(reverse: true);
    }

    _bindControllerEvents();
    _setupCursorTracking();

    _controller.setDefinition(widget.definition);
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
  }

  void _bindControllerEvents() {
    _eventSub?.cancel();
    _eventSub = _controller.eventChannel.events.listen((event) {
      if (!mounted) return;
      if (event is AvatarGazeEvent) {
        setState(() {
          _targetGaze = Offset(event.lookAtX, event.lookAtY);
          _gazeOffset = Offset(
            ui.lerpDouble(_gazeOffset.dx, _targetGaze.dx, 0.35) ??
                _targetGaze.dx,
            ui.lerpDouble(_gazeOffset.dy, _targetGaze.dy, 0.35) ??
                _targetGaze.dy,
          );
        });
      } else if (event is AvatarAnimationStartedEvent ||
          event is AvatarAnimationFinishedEvent) {
        setState(() {});
      }
    });
  }

  Offset _cachedWindowOrigin = Offset.zero;

  void _updateWindowOrigin() async {
    if (Platform.isMacOS || Platform.isWindows) {
      try {
        _cachedWindowOrigin = await windowManager.getPosition();
      } catch (_) {}
    }
  }

  void _setupCursorTracking() {
    if (!widget.autoTrackCursor) return;

    _updateWindowOrigin();
    final tracker = widget.cursorTracker ?? CursorTracker.instance;
    _cursorSub?.cancel();
    _cursorSub = tracker.positionStream.listen((globalCursorPos) {
      if (!mounted) return;
      _handleScreenCursor(globalCursorPos);
    });

    // Screen-wide tracking rides the shared cursor feed rather than a timer of
    // this widget's own. Several of these can be on screen at once, and each
    // one polling the platform every frame is what made the companion
    // expensive to leave running.
    _feedSub?.cancel();
    if (!widget.isStatic &&
        widget.externalLookAt == null &&
        (Platform.isMacOS || Platform.isWindows)) {
      _feedSub = CursorFeed.instance.subscribe((sample) {
        if (!mounted || widget.externalLookAt != null) return;
        _handleScreenCursor(sample.position);
      });
    }
  }

  void _handleScreenCursor(Offset globalCursor) {
    if (!mounted || widget.externalLookAt != null) return;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final localCenter = renderBox.localToGlobal(
        Offset(renderBox.size.width / 2.0, renderBox.size.height / 2.0),
      );
      final widgetScreenCenter = Offset(
        _cachedWindowOrigin.dx + localCenter.dx,
        _cachedWindowOrigin.dy + localCenter.dy,
      );

      final dx = globalCursor.dx - widgetScreenCenter.dx;
      final dy = globalCursor.dy - widgetScreenCenter.dy;

      final normX = (dx / 380.0).clamp(-1.0, 1.0);
      final normY = (dy / 380.0).clamp(-1.0, 1.0);

      _applyTargetLookAt(normX, normY);
    } catch (_) {}
  }

  void _applyTargetLookAt(double normX, double normY) {
    _targetGaze = Offset(normX, normY);
    _controller.setLookAt(normX, normY);
    if (!mounted) return;
    setState(() {
      _gazeOffset = Offset(
        ui.lerpDouble(_gazeOffset.dx, _targetGaze.dx, 0.28) ?? _targetGaze.dx,
        ui.lerpDouble(_gazeOffset.dy, _targetGaze.dy, 0.28) ?? _targetGaze.dy,
      );
    });
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalLookAt != null &&
        widget.externalLookAt != oldWidget.externalLookAt) {
      _applyTargetLookAt(widget.externalLookAt!.dx, widget.externalLookAt!.dy);
    }

    if (oldWidget.controller != widget.controller) {
      _cursorSub?.cancel();
      _feedSub?.cancel();
      _eventSub?.cancel();
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      _bindControllerEvents();
      _controller.setDefinition(widget.definition);
    }

    if (oldWidget.definition != widget.definition) {
      _controller.setDefinition(widget.definition);
      setState(() {});
    }

    if (oldWidget.cursorTracker != widget.cursorTracker ||
        oldWidget.autoTrackCursor != widget.autoTrackCursor) {
      _setupCursorTracking();
    }
  }

  @override
  void dispose() {
    _cursorSub?.cancel();
    _feedSub?.cancel();
    _eventSub?.cancel();
    _animController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (!widget.autoTrackCursor || widget.externalLookAt != null) return;
    final w = widget.width > 0 ? widget.width : 160.0;
    final h = widget.height > 0 ? widget.height : 160.0;

    final normalizedX = ((event.localPosition.dx / (w / 2.0)) - 1.0).clamp(
      -1.0,
      1.0,
    );
    final normalizedY = ((event.localPosition.dy / (h / 2.0)) - 1.0).clamp(
      -1.0,
      1.0,
    );

    _applyTargetLookAt(normalizedX, normalizedY);
  }

  void _handleTap() {
    if (!widget.isInteractive) return;
    widget.onTap?.call();
    _controller.eventChannel.emit(AvatarTapEvent());
  }

  void _handleDoubleTap() {
    if (!widget.isInteractive) return;
    widget.onDoubleTap?.call();
    _controller.eventChannel.emit(AvatarDoubleTapEvent());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!(context);
    }
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    if (widget.prefer3D) {
      return MouseRegion(
        onHover: _handlePointerHover,
        child: Pet3DView(
          definition: widget.definition,
          width: widget.width,
          height: widget.height,
          enableRotation: widget.isInteractive,
          enableZoom: widget.isInteractive,
          transparentBackground: widget.transparent,
          isStatic: widget.isStatic,
          externalLookAt: widget.externalLookAt ?? _gazeOffset,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
        ),
      );
    }

    final double avatarWidth = widget.width > 0 ? widget.width : 160.0;
    final double avatarHeight = widget.height > 0 ? widget.height : 160.0;
    final double avatarSize = math.min(avatarWidth, avatarHeight);

    Widget avatarContent = AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final breath = widget.isStatic
            ? 0.0
            : math.sin(_animController.value * math.pi) * 0.015;

        return Center(
          child: Transform.scale(
            scale: 1.0 + breath,
            alignment: Alignment.center,
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: AvatarArtwork.definition(widget.definition),
            ),
          ),
        );
      },
    );

    Widget interactiveContent = MouseRegion(
      onHover: _handlePointerHover,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: avatarContent,
        ),
      ),
    );

    if (widget.transparent) {
      return ColoredBox(color: Colors.transparent, child: interactiveContent);
    }

    return interactiveContent;
  }
}
