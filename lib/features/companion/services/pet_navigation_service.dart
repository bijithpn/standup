import 'dart:math';
import 'package:flutter/material.dart';

/// Navigation service for autonomous pet movement, cursor interaction,
/// and multi-display roaming with organic, physics-based motion.
class PetNavigationService {
  static final PetNavigationService _instance =
      PetNavigationService._internal();
  factory PetNavigationService() => _instance;
  PetNavigationService._internal();

  // Configuration
  double _wanderSpeed = 60.0;
  double _runSpeed = 180.0;
  double _cursorAttractionRadius = 300.0;
  double _cursorFollowSpeed = 120.0;
  double _edgeSnapThreshold = 50.0;
  double _bounceDamping = 0.7;
  double _gravityStrength = 800.0;
  bool _gravityEnabled = false;

  // State
  Offset _currentPosition = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _targetPosition = Offset.zero;
  Size _screenSize = Size.zero;
  bool _isCursorFollowing = false;
  Offset _cursorPosition = Offset.zero;
  DateTime? _lastWanderTargetTime;
  final Duration _wanderCooldown = const Duration(seconds: 3);

  bool _isWanderingEnabled = true;

  // Getters
  Offset get currentPosition => _currentPosition;
  Offset get velocity => _velocity;
  bool get isCursorFollowing => _isCursorFollowing;
  bool get isWanderingEnabled => _isWanderingEnabled;

  /// Initialize navigation with screen boundaries and starting position.
  void initialize({required Size screenSize, Offset? startPosition}) {
    _screenSize = screenSize;
    _currentPosition =
        startPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);
    _targetPosition = _currentPosition;
    _lastWanderTargetTime = DateTime.now();
  }

  /// Update configuration values.
  void updateConfig({
    double? wanderSpeed,
    double? runSpeed,
    double? cursorAttractionRadius,
    double? cursorFollowSpeed,
    double? edgeSnapThreshold,
    double? bounceDamping,
    double? gravityStrength,
    bool? gravityEnabled,
  }) {
    _wanderSpeed = wanderSpeed ?? _wanderSpeed;
    _runSpeed = runSpeed ?? _runSpeed;
    _cursorAttractionRadius = cursorAttractionRadius ?? _cursorAttractionRadius;
    _cursorFollowSpeed = cursorFollowSpeed ?? _cursorFollowSpeed;
    _edgeSnapThreshold = edgeSnapThreshold ?? _edgeSnapThreshold;
    _bounceDamping = bounceDamping ?? _bounceDamping;
    _gravityStrength = gravityStrength ?? _gravityStrength;
    _gravityEnabled = gravityEnabled ?? _gravityEnabled;
  }

  /// Update cursor position for attraction/following behavior.
  void updateCursorPosition(Offset cursorPos, {bool? forceFollowing}) {
    _cursorPosition = cursorPos;
    if (forceFollowing != null) {
      _isCursorFollowing = forceFollowing;
    } else {
      final distance = (_cursorPosition - _currentPosition).distance;
      _isCursorFollowing = distance < _cursorAttractionRadius;
    }
  }

  /// Explicitly set whether the pet is currently following the cursor.
  void setCursorFollowing(bool following) {
    _isCursorFollowing = following;
  }

  /// Sets whether the companion is allowed to wander randomly.
  void setWanderingEnabled(bool enabled) {
    _isWanderingEnabled = enabled;
    if (!enabled) {
      _velocity = Offset.zero;
    }
  }

  /// Main update loop - call every frame with delta time.
  Offset update(double dt) {
    if (_screenSize == Size.zero) return _currentPosition;

    if (_isCursorFollowing) {
      _applyCursorAttraction(dt);
    } else {
      _applyWandering(dt);
    }

    if (_gravityEnabled) {
      _applyGravity(dt);
    }

    _applyVelocity(dt);
    _handleScreenBoundaries();
    _applyEdgeSnapping();

    return _currentPosition;
  }

  /// Set a specific target position to move towards.
  void setTarget(Offset target, {double? speed}) {
    _targetPosition = target;
    _lastWanderTargetTime = DateTime.now();
  }

  /// Generate a random wander target within screen bounds.
  void generateWanderTarget() {
    final now = DateTime.now();
    if (_lastWanderTargetTime != null &&
        now.difference(_lastWanderTargetTime!) < _wanderCooldown) {
      return;
    }

    final margin = 50.0;
    _targetPosition = Offset(
      margin + Random().nextDouble() * (_screenSize.width - margin * 2),
      margin + Random().nextDouble() * (_screenSize.height - margin * 2),
    );
    _lastWanderTargetTime = now;
  }

  /// Teleport to a position (for edge wrapping, etc.).
  void teleport(Offset position) {
    _currentPosition = position;
    _velocity = Offset.zero;
  }

  // Private movement methods

  void _applyCursorAttraction(double dt) {
    final direction = _cursorPosition - _currentPosition;
    final distance = direction.distance;

    if (distance < 10.0) {
      // Damping when very close to stop jitter
      _velocity = _velocity * 0.8;
      if (_velocity.distance < 1.0) _velocity = Offset.zero;
      return;
    }

    final normalizedDirection = direction / distance;
    
    // Smooth acceleration
    final targetSpeed = _cursorFollowSpeed *
        (distance / _cursorAttractionRadius).clamp(0.2, 1.5);
    
    final targetVelocity = normalizedDirection * targetSpeed;
    
    // Interpolate velocity for smoothness (acceleration/deceleration)
    _velocity = Offset(
      _velocity.dx + (targetVelocity.dx - _velocity.dx) * 5.0 * dt,
      _velocity.dy + (targetVelocity.dy - _velocity.dy) * 5.0 * dt,
    );
  }

  void _applyWandering(double dt) {
    if (!_isWanderingEnabled) {
      _velocity = Offset.zero;
      return;
    }
    final direction = _targetPosition - _currentPosition;
    final distance = direction.distance;

    if (distance < 10.0) {
      _velocity = Offset.zero;
      generateWanderTarget();
      return;
    }

    final normalizedDirection = direction / distance;
    _velocity = normalizedDirection * _wanderSpeed;
  }

  void _applyGravity(double dt) {
    _velocity = Offset(_velocity.dx, _velocity.dy + _gravityStrength * dt);
  }

  void _applyVelocity(double dt) {
    _currentPosition = Offset(
      _currentPosition.dx + _velocity.dx * dt,
      _currentPosition.dy + _velocity.dy * dt,
    );
  }

  void _handleScreenBoundaries() {
    final halfWidth = 50.0; // Approximate pet width/2
    final halfHeight = 50.0; // Approximate pet height/2

    if (_currentPosition.dx < halfWidth) {
      _currentPosition = Offset(halfWidth, _currentPosition.dy);
      _velocity = Offset(_velocity.dx.abs() * _bounceDamping, _velocity.dy);
    } else if (_currentPosition.dx > _screenSize.width - halfWidth) {
      _currentPosition = Offset(
        _screenSize.width - halfWidth,
        _currentPosition.dy,
      );
      _velocity = Offset(-_velocity.dx.abs() * _bounceDamping, _velocity.dy);
    }

    if (_currentPosition.dy < halfHeight) {
      _currentPosition = Offset(_currentPosition.dx, halfHeight);
      _velocity = Offset(_velocity.dx, _velocity.dy.abs() * _bounceDamping);
    } else if (_currentPosition.dy > _screenSize.height - halfHeight) {
      _currentPosition = Offset(
        _currentPosition.dx,
        _screenSize.height - halfHeight,
      );
      _velocity = Offset(_velocity.dx, -_velocity.dy.abs() * _bounceDamping);
    }
  }

  void _applyEdgeSnapping() {
    if (_velocity.distance < 10.0) {
      if (_currentPosition.dx < _edgeSnapThreshold) {
        _currentPosition = Offset(0.0, _currentPosition.dy);
      } else if (_currentPosition.dx > _screenSize.width - _edgeSnapThreshold) {
        _currentPosition = Offset(_screenSize.width, _currentPosition.dy);
      }

      if (_currentPosition.dy < _edgeSnapThreshold) {
        _currentPosition = Offset(_currentPosition.dx, 0.0);
      } else if (_currentPosition.dy >
          _screenSize.height - _edgeSnapThreshold) {
        _currentPosition = Offset(_currentPosition.dx, _screenSize.height);
      }
    }
  }
}
