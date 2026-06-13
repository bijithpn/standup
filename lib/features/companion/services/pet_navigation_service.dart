import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';

class PetNavigationService {
  PetNavigationService();

  double _wanderSpeed = 0.0;
  double _paddingLeft = 50.0;
  double _paddingRight = 50.0;
  double _paddingTop = 50.0;
  double _paddingBottom = 50.0;
  bool _isWanderingEnabled = true;
  PetSpecies _species = PetSpecies.cat;

  // True while the pet is in the falling state and has touched the floor.
  // Cleared when the falling state exits.
  bool _isLanded = false;

  Offset _pos = Offset.zero;
  Offset _vel = Offset.zero;
  Offset _wanderTarget = Offset.zero;
  Size _screen = Size.zero;
  bool _hasWanderTarget = false;
  DateTime? _lastWanderTime;

  bool _isCursorFollowing = false;
  Offset _cursorPos = Offset.zero;
  double _lookTimer = 0.0; // Cat look-before-move delay

  double _hopY = 0.0;
  double _flyY = 0.0;

  int _cursorMoveCount = 0;
  DateTime _lastCursorMoveReset = DateTime.now();
  static const int _annoyanceThreshold = 15; // moves per 3 seconds
  static const Duration _annoyanceWindow = Duration(seconds: 3);

  Duration _currentWanderCooldown = const Duration(seconds: 3);
  static final _rng = Random();

  Offset get currentPosition => _pos + Offset(0, _hopY + _flyY);
  Offset get velocity => _vel;
  double get speed =>
      _vel.distance; // px/s — used by component to pick walk/run anim
  bool get isCursorFollowing => _isCursorFollowing;
  bool get isWanderingEnabled => _isWanderingEnabled;
  bool get isAnnoyed => _cursorMoveCount > _annoyanceThreshold;
  PetSpecies get species => _species;

  PetState? _lastCurrentState;

  bool get isMoving {
    final bool isPlayState = _lastCurrentState == PetState.chasing || _lastCurrentState == PetState.fetching;
    if (_isCursorFollowing && !isPlayState) {
      final profile = _species.defaultProfile;
      if (profile.lookDelay > 0.0 && _lookTimer < profile.lookDelay) {
        return false;
      }
      return (_cursorPos - _pos).distance > profile.stopRadius;
    } else {
      if ((!_isWanderingEnabled && !isPlayState) || _wanderSpeed <= 0 || !_hasWanderTarget) {
        return false;
      }

      if (_species.movementType == MovementType.walk) {
        return (_wanderTarget.dx - _pos.dx).abs() >= 12.0;
      }

      return (_wanderTarget - _pos).distance >= 12.0;
    }
  }

  bool get needsWanderTarget {
    if (!_isWanderingEnabled || _wanderSpeed <= 0) return false;
    if (!_hasWanderTarget) return true;

    if (_species.movementType == MovementType.walk) {
      return (_wanderTarget.dx - _pos.dx).abs() < 12.0;
    }

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
    _hopY = 0.0;
    _flyY = 0.0;
  }

  void setSpecies(PetSpecies species) {
    _species = species;
  }

  void updatePaddings({
    required double left,
    required double right,
    required double top,
    required double bottom,
  }) {
    _paddingLeft = left;
    _paddingRight = right;
    _paddingTop = top;
    _paddingBottom = bottom;
  }

  /// Resizes the logical screen bounds without resetting movement state.
  /// Use this for window resize events; use [initialize] only on first load
  /// or a deliberate position reset.
  void updateScreenSize(Size newSize) {
    _screen = newSize;
  }

  void updateConfig({double? wanderSpeed}) {
    _wanderSpeed = wanderSpeed ?? _wanderSpeed;
  }

  void updateCursorPosition(Offset gameSpaceCursor, {bool? forceFollowing}) {
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

    final bool isProwl = _rng.nextDouble() < 0.25;
    if (isProwl) {
      final double widthRange = _screen.width - _paddingLeft - _paddingRight;
      final double heightRange = _screen.height - _paddingTop - _paddingBottom;
      _wanderTarget = Offset(
        _paddingLeft + (widthRange > 0 ? _rng.nextDouble() * widthRange : 0),
        _paddingTop + (heightRange > 0 ? _rng.nextDouble() * heightRange : 0),
      );
    } else {
      final double distance = 100.0 + _rng.nextDouble() * 150.0;
      final double angle = _rng.nextDouble() * 2 * pi;
      final double targetX = (_pos.dx + cos(angle) * distance).clamp(
        _paddingLeft,
        max(_paddingLeft, _screen.width - _paddingRight),
      );
      final double targetY = (_pos.dy + sin(angle) * distance).clamp(
        _paddingTop,
        max(_paddingTop, _screen.height - _paddingBottom),
      );
      _wanderTarget = Offset(targetX, targetY);
    }

    if (_species.movementType == MovementType.walk) {
      _wanderTarget = Offset(_wanderTarget.dx, _paddingTop);
    }

    _hasWanderTarget = true;
    _lastWanderTime = now;

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

  Offset update(double dt, {PetState? currentState}) {
    _lastCurrentState = currentState;
    if (_screen == Size.zero) return _pos;

    // Falling state: apply gravity instead of normal wandering so the pet
    // actually descends. Land when the Y position reaches the floor boundary.
    if (currentState == PetState.falling) {
      const double gravity = 980.0; // px/s^2
      _vel = Offset(_vel.dx, _vel.dy + gravity * dt);
      _pos = Offset(_pos.dx + _vel.dx * dt, _pos.dy + _vel.dy * dt);

      // Clamp X within bounds during fall.
      final minX = _paddingLeft;
      final maxX = _screen.width - _paddingRight;
      if (_pos.dx < minX) {
        _pos = Offset(minX, _pos.dy);
        _vel = Offset(_vel.dx.abs() * 0.3, _vel.dy);
      } else if (_pos.dx > maxX) {
        _pos = Offset(maxX, _pos.dy);
        _vel = Offset(-_vel.dx.abs() * 0.3, _vel.dy);
      }

      // Landing check: floor is at paddingTop for walk-type pets.
      // Emit PetLandedEvent exactly once per landing to update the FSM.
      final floorY = _paddingTop;
      if (_pos.dy >= floorY) {
        _pos = Offset(_pos.dx, floorY);
        _vel = Offset(_vel.dx * 0.4, 0.0);
        if (!_isLanded) {
          _isLanded = true;
          EventBus.instance.emit(PetLandedEvent());
        }
      }

      _hopY = 0.0;
      _flyY = 0.0;
      return _pos;
    }

    // Reset landing guard when we leave the falling state.
    _isLanded = false;

    final bool isPlayState = currentState == PetState.chasing || currentState == PetState.fetching;
    if (_isCursorFollowing && !isPlayState) {
      _updateCursorFollow(dt);
    } else {
      _updateWander(dt, currentState: currentState);
    }

    // Ground-based walking pets should not have vertical velocity to prevent jitter/tilt/stretch deforming
    if (_species.movementType == MovementType.walk) {
      _vel = Offset(_vel.dx, 0.0);
    }

    _pos = Offset(_pos.dx + _vel.dx * dt, _pos.dy + _vel.dy * dt);

    _clampToBounds();

    if (_species.movementType == MovementType.walk) {
      // Force Y position to stay at the vertical limit
      _pos = Offset(_pos.dx, _paddingTop);
      _vel = Offset(_vel.dx, 0.0);
    }

    _hopY = 0.0;
    _flyY = 0.0;

    return _pos;
  }

  void _updateCursorFollow(double dt) {
    final profile = _species.defaultProfile;

    final toTarget = _cursorPos - _pos;
    final dist = toTarget.distance;

    if (dist <= profile.stopRadius) {
      _vel = Offset(_vel.dx * 0.75, _vel.dy * 0.75);
      if (_vel.distance < 0.5) _vel = Offset.zero;
      _lookTimer = 0.0;
      return;
    }

    if (profile.lookDelay > 0.0 && _lookTimer < profile.lookDelay) {
      _lookTimer += dt;
      _vel = Offset(_vel.dx * 0.8, _vel.dy * 0.8);
      return;
    }

    final dir = toTarget / dist;
    final targetSpeed = (profile.acceleration * dist).clamp(
      0.0,
      profile.movementSpeed,
    );
    final targetVel = dir * targetSpeed;

    _vel = Offset(
      _vel.dx + (targetVel.dx - _vel.dx) * profile.damping * dt * 10.0,
      _vel.dy + (targetVel.dy - _vel.dy) * profile.damping * dt * 10.0,
    );
  }

  void _updateWander(double dt, {PetState? currentState}) {
    final bool isPlayState = currentState == PetState.chasing || currentState == PetState.fetching;
    if ((!_isWanderingEnabled && !isPlayState) || _wanderSpeed <= 0) {
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
    final speedFactor = (dist / 80.0).clamp(0.3, 1.0);
    final targetVel = dir * (_wanderSpeed * speedFactor);
    // Smooth velocity change (avoids instant direction snaps)
    _vel = Offset(
      _vel.dx + (targetVel.dx - _vel.dx) * 6.0 * dt,
      _vel.dy + (targetVel.dy - _vel.dy) * 6.0 * dt,
    );
  }

  void _clampToBounds() {
    final minX = _paddingLeft;
    final maxX = _screen.width - _paddingRight;
    final minY = _paddingTop;
    final maxY = _screen.height - _paddingBottom;

    if (_pos.dx < minX) {
      _pos = Offset(minX, _pos.dy);
      _vel = Offset(_vel.dx.abs() * 0.5, _vel.dy); // Soft bounce
      _hasWanderTarget = false;
    } else if (_pos.dx > maxX) {
      _pos = Offset(maxX, _pos.dy);
      _vel = Offset(-_vel.dx.abs() * 0.5, _vel.dy);
      _hasWanderTarget = false;
    }

    if (_pos.dy < minY) {
      _pos = Offset(_pos.dx, minY);
      _vel = Offset(_vel.dx, _vel.dy.abs() * 0.5);
      _hasWanderTarget = false;
    } else if (_pos.dy > maxY) {
      _pos = Offset(_pos.dx, maxY);
      _vel = Offset(_vel.dx, -_vel.dy.abs() * 0.5);
      _hasWanderTarget = false;
    }
  }
}
