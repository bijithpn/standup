import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Controls the constraint window: a resizable, always-on-top native window
/// that defines the spatial boundary for Constrained Mode.
///
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7
abstract class ConstraintWindowController {
  /// Show the constraint window centered on the primary display.
  Future<void> show({Size initialSize = const Size(300, 300)});

  /// Hide the constraint window.
  Future<void> hide();

  /// Current constraint bounds in global screen coordinates.
  Rect get bounds;

  /// Called by the platform layer when the user resizes or repositions the
  /// constraint window.
  void onBoundsChanged(Rect newBounds);
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

/// [ConstraintWindowController] backed by [NativeBridgePlatform].
class NativeConstraintWindowController implements ConstraintWindowController {
  NativeConstraintWindowController({
    required PhysicsSimulator physicsSimulator,
    required List<DisplayBounds> displays,
    NativeBridgePlatform? bridge,
    EventBus? eventBus,
    AppLogger? logger,
    Size petSize = const Size(64, 64),
  }) : _physics = physicsSimulator,
       _displays = displays,
       _bridge = bridge ?? NativeBridge.instance,
       _eventBus = eventBus ?? EventBus.instance,
       _logger = logger ?? AppLogger(),
       _petSize = petSize {
    // Register the native bounds-changed callback on construction.
    _bridge.registerConstraintWindowBoundsCallback(_onNativeBoundsChanged);
  }

  static const double _minSize = 200.0;
  static const double _maxSize = 800.0;
  static const double _defaultSize = 300.0;

  final PhysicsSimulator _physics;
  final List<DisplayBounds> _displays;
  final NativeBridgePlatform _bridge;
  final EventBus _eventBus;
  final AppLogger _logger;
  final Size _petSize;

  Rect _bounds = Rect.zero;

  // ---- ConstraintWindowController interface --------------------------------

  @override
  Future<void> show({
    Size initialSize = const Size(_defaultSize, _defaultSize),
  }) async {
    // Center on the primary display (fall back to first display, then origin).
    final DisplayBounds? primary = _displays.cast<DisplayBounds?>().firstWhere(
      (d) => d?.isPrimary == true,
      orElse: () => _displays.isNotEmpty ? _displays.first : null,
    );

    double centerX = 0.0;
    double centerY = 0.0;
    if (primary != null) {
      centerX = primary.rect.center.dx;
      centerY = primary.rect.center.dy;
    }

    final double w = initialSize.width.clamp(_minSize, _maxSize);
    final double h = initialSize.height.clamp(_minSize, _maxSize);
    final double x = centerX - w / 2;
    final double y = centerY - h / 2;

    await _bridge.showConstraintWindow(<String, dynamic>{
      'x': x,
      'y': y,
      'width': w,
      'height': h,
    });

    _bounds = Rect.fromLTWH(x, y, w, h);
    _physics.setConstraintBoundary(_bounds);
    _logger.info('ConstraintWindowController: shown at $_bounds');
  }

  @override
  Future<void> hide() async {
    await _bridge.hideConstraintWindow();
    _physics.setConstraintBoundary(null);
    _logger.info('ConstraintWindowController: hidden');
  }

  @override
  Rect get bounds => _bounds;

  @override
  void onBoundsChanged(Rect newBounds) {
    // Clamp each dimension to [max(200, petDim), 800] (req 4.2, 4.7).
    final double clampedWidth = newBounds.width.clamp(
      math.max(_minSize, _petSize.width),
      _maxSize,
    );
    final double clampedHeight = newBounds.height.clamp(
      math.max(_minSize, _petSize.height),
      _maxSize,
    );

    _bounds = Rect.fromLTWH(
      newBounds.left,
      newBounds.top,
      clampedWidth,
      clampedHeight,
    );

    // Update physics boundary within this tick (req 4.3).
    _physics.setConstraintBoundary(_bounds);

    _eventBus.emit(ConstraintWindowBoundsChangedEvent(bounds: _bounds));
    _logger.info('ConstraintWindowController: bounds changed to $_bounds');
  }

  // ---- Private callback from native layer -----------------------------------

  void _onNativeBoundsChanged(Map<String, dynamic> map) {
    final double x = (map['x'] as num?)?.toDouble() ?? _bounds.left;
    final double y = (map['y'] as num?)?.toDouble() ?? _bounds.top;
    final double w = (map['width'] as num?)?.toDouble() ?? _bounds.width;
    final double h = (map['height'] as num?)?.toDouble() ?? _bounds.height;
    onBoundsChanged(Rect.fromLTWH(x, y, w, h));
  }
}
