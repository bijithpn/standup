import 'dart:math';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/domain/pet_type.dart';



/// Navigation service for autonomous pet movement and cursor following.
/// Uses a spring-damper model for natural, organic motion.
class PetNavigationService {
  PetNavigationService();

  // Config
  double _wanderSpeed = 0.0;
  final double _edgeMargin = 50.0;
  bool _isWanderingEnabled = true;
  PetSpecies _species = PetSpecies.cat;

  // State
  Offset _pos = Offset.zero;
  Offset _vel = Offset.zero;
  Offset _wanderTarget = Offset.zero;
  Size _screen = Size.zero;
  bool _hasWanderTarget = false;
  DateTime? _lastWanderTime;

  // Cursor follow
  bool _isCursorFollowing = false;
  Offset _cursorPos = Offset.zero;
  double _lookTimer = 0.0; // Cat look-before-move delay

  // Hopping and Flying procedural math offsets
  double _hopTimer = 0.0;
  double _hopY = 0.0;
  double _flyTime = 0.0;
  double _flyY = 0.0;

  // Annoyance tracking: if cursor moves too much, pet gets angry
  int _cursorMoveCount = 0;
  DateTime _lastCursorMoveReset = DateTime.now();
  static const int _annoyanceThreshold = 15; // moves per 3 seconds
  static const Duration _annoyanceWindow = Duration(seconds: 3);

  Duration _currentWanderCooldown = const Duration(seconds: 3);
  static final _rng = Random();

  // Getters
  Offset get currentPosition => _pos + Offset(0, _hopY + _flyY);
  Offset get velocity => _vel;
  double get speed => _vel.distance; // px/s — used by component to pick walk/run anim
  bool get isCursorFollowing => _isCursorFollowing;
  bool get isWanderingEnabled => _isWanderingEnabled;
  bool get isAnnoyed => _cursorMoveCount > _annoyanceThreshold;
  PetSpecies get species => _species;

  bool get isMoving {
    if (_isCursorFollowing) {
      final profile = _species.defaultProfile;
      if (profile.lookDelay > 0.0 && _lookTimer < profile.lookDelay) {
        return false;
      }
      return (_cursorPos - _pos).distance > profile.stopRadius;
    } else {
      return _isWanderingEnabled &&
          _wanderSpeed > 0 &&
          _hasWanderTarget &&
          (_wanderTarget - _pos).distance >= 12.0;
    }
  }

  bool get needsWanderTarget {
    if (!_isWanderingEnabled || _wanderSpeed <= 0) return false;
    if (!_hasWanderTarget) return true;
    return (_wanderTarget - _pos).distance < 12.0;
  }

  void initialize({required Size screenSize, Offset? startPosition}) {
    _screen = screenSize;
    _pos = startPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);
    _vel = Offset.zero;
    _wanderTarget = _pos;
    _hasWanderTarget = false;
    _lastWanderTime = null;
    _lookTimer = 0.0;
    _hopTimer = 0.0;
    _hopY = 0.0;
    _flyTime = 0.0;
    _flyY = 0.0;
  }

  void setSpecies(PetSpecies species) {
    _species = species;
  }

  void updateConfig({double? wanderSpeed}) {
    _wanderSpeed = wanderSpeed ?? _wanderSpeed;
  }

  /// Called with the raw cursor position in the game/canvas coordinate space.
  void updateCursorPosition(Offset gameSpaceCursor, {bool? forceFollowing}) {
    // Track cursor movement for annoyance detection
    if ((_cursorPos - gameSpaceCursor).distance > 5.0) {
      _cursorMoveCount++;
      final now = DateTime.now();
      if (now.difference(_lastCursorMoveReset) > _annoyanceWindow) {
        _cursorMoveCount = 0;
        _lastCursorMoveReset = now;
      }
    }

    _cursorPos = gameSpaceCursor;
    if (forceFollowing != null) {
      if (forceFollowing && !_isCursorFollowing) {
        _lookTimer = 0.0; // Reset look delay on new follow
      }
      _isCursorFollowing = forceFollowing;
    }
  }

  void setCursorFollowing(bool following) {
    if (following && !_isCursorFollowing) _lookTimer = 0.0;
    _isCursorFollowing = following;
  }

  void setWanderingEnabled(bool enabled) {
    _isWanderingEnabled = enabled;
    if (!enabled) {
      _vel = Offset.zero;
      _hasWanderTarget = false;
    }
  }

  void generateWanderTarget() {
    final now = DateTime.now();
    if (_lastWanderTime != null &&
        now.difference(_lastWanderTime!) < _currentWanderCooldown) {
      return;
    }
    final m = _edgeMargin;
    
    // Rabbit edge-seeking wandering target logic
    if (_species == PetSpecies.rabbit && _rng.nextDouble() < 0.70) {
      final double edge = _rng.nextInt(4).toDouble();
      double tx = m;
      double ty = m;
      if (edge == 0) { // Left edge
        tx = m + _rng.nextDouble() * 20.0;
        ty = m + _rng.nextDouble() * (_screen.height - m * 2);
      } else if (edge == 1) { // Right edge
        tx = _screen.width - m - _rng.nextDouble() * 20.0;
        ty = m + _rng.nextDouble() * (_screen.height - m * 2);
      } else if (edge == 2) { // Top edge
        tx = m + _rng.nextDouble() * (_screen.width - m * 2);
        ty = m + _rng.nextDouble() * 20.0;
      } else { // Bottom edge
        tx = m + _rng.nextDouble() * (_screen.width - m * 2);
        ty = _screen.height - m - _rng.nextDouble() * 20.0;
      }
      _wanderTarget = Offset(tx, ty);
    } else {
      // Unpredictable movement: 75% chance of short local wanders, 25% chance of long-distance prowls
      final bool isProwl = _rng.nextDouble() < 0.25;
      if (isProwl) {
        _wanderTarget = Offset(
          m + _rng.nextDouble() * (_screen.width - m * 2),
          m + _rng.nextDouble() * (_screen.height - m * 2),
        );
      } else {
        // Local wander within 100 to 250 pixels of current position
        final double distance = 100.0 + _rng.nextDouble() * 150.0;
        final double angle = _rng.nextDouble() * 2 * pi;
        final double targetX = (_pos.dx + cos(angle) * distance).clamp(m, _screen.width - m);
        final double targetY = (_pos.dy + sin(angle) * distance).clamp(m, _screen.height - m);
        _wanderTarget = Offset(targetX, targetY);
      }
    }
    
    _hasWanderTarget = true;
    _lastWanderTime = now;
    
    // Dynamic unpredictable cooldown: 2 to 7 seconds
    _currentWanderCooldown = Duration(seconds: 2 + _rng.nextInt(6));
  }

  void setTarget(Offset target) {
    _wanderTarget = target;
    _hasWanderTarget = true;
    _lastWanderTime = DateTime.now();
  }

  void teleport(Offset position) {
    _pos = position;
    _vel = Offset.zero;
  }

  Offset update(double dt) {
    if (_screen == Size.zero) return _pos;

    if (_isCursorFollowing) {
      _updateCursorFollow(dt);
    } else {
      _updateWander(dt);
    }

    _pos = Offset(
      _pos.dx + _vel.dx * dt,
      _pos.dy + _vel.dy * dt,
    );

    _clampToBounds();

    // Procedural movement calculations (doesn't affect horizontal clamps/physics)
    if (_species == PetSpecies.rabbit) {
      _updateHopPhysics(dt);
    } else {
      _hopY = 0.0;
      _hopTimer = 0.0;
    }

    if (_species == PetSpecies.dragon) {
      _updateFlyPhysics(dt);
    } else {
      _flyY = 0.0;
      _flyTime = 0.0;
    }

    return _pos;
  }

  void _updateHopPhysics(double dt) {
    const double hopDuration = 0.6; // single hop length (s)
    const double hopInterval = 0.45; // wait before next hop (s)

    if (speed > 5.0) {
      _hopTimer += dt;
      if (_hopTimer < hopDuration) {
        final double progress = _hopTimer / hopDuration;
        _hopY = -22.0 * sin(progress * pi); // Parabolic curve
      } else {
        _hopY = 0.0;
        // Dampen velocity to zero during rest interval
        _vel = Offset(_vel.dx * 0.1, _vel.dy * 0.1);
        if (_hopTimer >= hopDuration + hopInterval) {
          _hopTimer = 0.0;
        }
      }
    } else {
      _hopY = 0.0;
      _hopTimer = 0.0;
    }
  }

  void _updateFlyPhysics(double dt) {
    _flyTime += dt;
    // Sinusoidal floating hover effect
    _flyY = sin(_flyTime * 3.2) * 10.0;
  }

  void _updateCursorFollow(double dt) {
    final profile = _species.defaultProfile;

    final toTarget = _cursorPos - _pos;
    final dist = toTarget.distance;

    // Within stop radius — damp to rest
    if (dist <= profile.stopRadius) {
      _vel = Offset(_vel.dx * 0.75, _vel.dy * 0.75);
      if (_vel.distance < 0.5) _vel = Offset.zero;
      _lookTimer = 0.0;
      return;
    }

    // Species look-delay: stand still and "look" before moving
    if (profile.lookDelay > 0.0 && _lookTimer < profile.lookDelay) {
      _lookTimer += dt;
      _vel = Offset(_vel.dx * 0.8, _vel.dy * 0.8);
      return;
    }

    // Spring-damper: F = stiffness * displacement - damping * velocity
    final dir = toTarget / dist;
    final targetSpeed = (profile.acceleration * dist).clamp(0.0, profile.movementSpeed);
    final targetVel = dir * targetSpeed;

    // Critically-damped spring integration
    _vel = Offset(
      _vel.dx + (targetVel.dx - _vel.dx) * profile.damping * dt * 10.0,
      _vel.dy + (targetVel.dy - _vel.dy) * profile.damping * dt * 10.0,
    );
  }

  void _updateWander(double dt) {
    if (!_isWanderingEnabled || _wanderSpeed <= 0) {
      // Decelerate smoothly
      final decay = (1.0 - 8.0 * dt).clamp(0.0, 1.0);
      _vel = Offset(_vel.dx * decay, _vel.dy * decay);
      if (_vel.distance < 0.5) _vel = Offset.zero;
      return;
    }

    final toTarget = _wanderTarget - _pos;
    final dist = toTarget.distance;
    if (dist < 12.0) {
      _vel = Offset.zero;
      _hasWanderTarget = false;
      return;
    }

    final dir = toTarget / dist;
    // Ease in/out: slow down as we approach target
    final speedFactor = (dist / 80.0).clamp(0.3, 1.0);
    final targetVel = dir * (_wanderSpeed * speedFactor);
    // Smooth velocity change (avoids instant direction snaps)
    _vel = Offset(
      _vel.dx + (targetVel.dx - _vel.dx) * 6.0 * dt,
      _vel.dy + (targetVel.dy - _vel.dy) * 6.0 * dt,
    );
  }

  void _clampToBounds() {
    final m = _edgeMargin;
    final maxX = _screen.width - m;
    final maxY = _screen.height - m;

    if (_pos.dx < m) {
      _pos = Offset(m, _pos.dy);
      _vel = Offset(_vel.dx.abs() * 0.5, _vel.dy); // Soft bounce
      _hasWanderTarget = false;
    } else if (_pos.dx > maxX) {
      _pos = Offset(maxX, _pos.dy);
      _vel = Offset(-_vel.dx.abs() * 0.5, _vel.dy);
      _hasWanderTarget = false;
    }

    if (_pos.dy < m) {
      _pos = Offset(_pos.dx, m);
      _vel = Offset(_vel.dx, _vel.dy.abs() * 0.5);
      _hasWanderTarget = false;
    } else if (_pos.dy > maxY) {
      _pos = Offset(_pos.dx, maxY);
      _vel = Offset(_vel.dx, -_vel.dy.abs() * 0.5);
      _hasWanderTarget = false;
    }
  }
}
