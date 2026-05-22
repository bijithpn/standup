import 'dart:math';
import 'package:flutter/material.dart';

/// Per-species cursor-follow profile.
/// Cats: cautious — look first, slow approach, stop before reaching cursor.
/// Dogs: eager — fast rush, overshoot slightly, settle with wiggle.
class _FollowProfile {
  final double springStiffness; // How fast velocity catches up to target
  final double damping;         // How quickly oscillation dies (1.0 = critically damped)
  final double maxSpeed;        // px/s cap
  final double stopRadius;      // Stop this many px away from cursor (cats stay aloof)
  final double lookDelay;       // Seconds of "looking" before moving (cats only)

  const _FollowProfile({
    required this.springStiffness,
    required this.damping,
    required this.maxSpeed,
    required this.stopRadius,
    required this.lookDelay,
  });

  static const cat = _FollowProfile(
    springStiffness: 6.0,
    damping: 0.85,
    maxSpeed: 90.0,
    stopRadius: 40.0,
    lookDelay: 0.4,
  );

  static const dog = _FollowProfile(
    springStiffness: 14.0,
    damping: 0.65,
    maxSpeed: 200.0,
    stopRadius: 8.0,
    lookDelay: 0.0,
  );
}

/// Navigation service for autonomous pet movement and cursor following.
/// Uses a spring-damper model for natural, organic motion.
///
/// Each [PetCompanionService] owns its own instance (no singleton).
class PetNavigationService {
  PetNavigationService();

  // Config
  double _wanderSpeed = 0.0;
  final double _edgeMargin = 50.0;
  bool _isWanderingEnabled = true;
  bool _isDog = false;

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

  // Annoyance tracking: if cursor moves too much, cat gets angry
  int _cursorMoveCount = 0;
  DateTime _lastCursorMoveReset = DateTime.now();
  static const int _annoyanceThreshold = 15; // moves per 3 seconds
  static const Duration _annoyanceWindow = Duration(seconds: 3);

  static const Duration _wanderCooldown = Duration(seconds: 3);
  static final _rng = Random();

  // Getters
  Offset get currentPosition => _pos;
  Offset get velocity => _vel;
  double get speed => _vel.distance; // px/s — used by component to pick walk/run anim
  bool get isCursorFollowing => _isCursorFollowing;
  bool get isWanderingEnabled => _isWanderingEnabled;
  bool get isAnnoyed => _cursorMoveCount > _annoyanceThreshold;

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
  }

  void setSpecies({required bool isDog}) {
    _isDog = isDog;
  }

  void updateConfig({double? wanderSpeed}) {
    _wanderSpeed = wanderSpeed ?? _wanderSpeed;
  }

  /// Called with the raw cursor position in the game/canvas coordinate space.
  /// The caller (CompanionGame) is responsible for converting window coords to
  /// game coords before calling this.
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
        now.difference(_lastWanderTime!) < _wanderCooldown) {
      return;
    }
    final m = _edgeMargin;
    _wanderTarget = Offset(
      m + _rng.nextDouble() * (_screen.width - m * 2),
      m + _rng.nextDouble() * (_screen.height - m * 2),
    );
    _hasWanderTarget = true;
    _lastWanderTime = now;
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
    return _pos;
  }

  void _updateCursorFollow(double dt) {
    final profile = _isDog ? _FollowProfile.dog : _FollowProfile.cat;
    final toTarget = _cursorPos - _pos;
    final dist = toTarget.distance;

    // Within stop radius — damp to rest
    if (dist <= profile.stopRadius) {
      _vel = Offset(_vel.dx * 0.75, _vel.dy * 0.75);
      if (_vel.distance < 0.5) _vel = Offset.zero;
      _lookTimer = 0.0;
      return;
    }

    // Cat look-delay: stand still and "look" before moving
    if (!_isDog && _lookTimer < profile.lookDelay) {
      _lookTimer += dt;
      _vel = Offset(_vel.dx * 0.8, _vel.dy * 0.8);
      return;
    }

    // Spring-damper: F = stiffness * displacement - damping * velocity
    final dir = toTarget / dist;
    // Effective target velocity proportional to distance, capped at maxSpeed
    final targetSpeed = (profile.springStiffness * dist).clamp(0.0, profile.maxSpeed);
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
