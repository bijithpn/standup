import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

/// Controls the constraint window: a resizable, always-on-top native window
/// that defines the spatial boundary for Constrained Mode.
abstract class ConstraintWindowController {
  Future<void> show({Size initialSize = const Size(300, 300)});

  Future<void> hide();

  Rect get bounds;

  void onBoundsChanged(Rect newBounds);
}

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

  @override
  Future<void> show({
    Size initialSize = const Size(_defaultSize, _defaultSize),
  }) async {
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

    await _bridge.showConstraintWindow(
      ConstraintWindowArgs(x: x, y: y, width: w, height: h),
    );

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

    _physics.setConstraintBoundary(_bounds);

    _eventBus.emit(ConstraintWindowBoundsChangedEvent(bounds: _bounds));
    _logger.info('ConstraintWindowController: bounds changed to $_bounds');
  }

  void _onNativeBoundsChanged(ConstraintWindowArgs args) {
    onBoundsChanged(Rect.fromLTWH(args.x, args.y, args.width, args.height));
  }
}
