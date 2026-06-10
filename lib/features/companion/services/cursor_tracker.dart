import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';

class CursorTracker {
  CursorTracker({NativeBridgePlatform? bridge, EventBus? eventBus})
    : _bridge = bridge ?? NativeBridge.instance,
      _eventBus = eventBus ?? EventBus.instance;

  static const double interactionZoneRadius = 80.0; // logical px
  static const double fastVelocityThreshold = 800.0; // logical px/s
  static const double dwellTimeThreshold = 3.0; // seconds
  static const double _emaAlpha = 0.4;
  static const double _stationarySpeedThreshold = 5.0; // px/s

  final NativeBridgePlatform _bridge;
  final EventBus _eventBus;

  Offset _lastPosition = Offset.zero;
  Offset _velocity = Offset.zero; // EMA-smoothed px/s

  bool _inZone = false;

  double _dwellSeconds = 0.0;
  bool _dwellEmitted = false;

  Offset get lastPosition => _lastPosition;
  Offset get velocity => _velocity;

  Future<void> sample(double dt, Offset petCenter) async {
    if (dt <= 0) return;

    var rawPos = await _bridge.getCursorPosition();

    // macOS returns coordinates in screen-bottom-left origin.
    if (Platform.isMacOS) {
      rawPos = _convertMacOSOrigin(rawPos);
    }

    final Offset instantaneous = (rawPos - _lastPosition) / dt;

    _velocity = Offset(
      (1 - _emaAlpha) * _velocity.dx + _emaAlpha * instantaneous.dx,
      (1 - _emaAlpha) * _velocity.dy + _emaAlpha * instantaneous.dy,
    );
    _lastPosition = rawPos;

    final double speed = _velocityMagnitude(_velocity);
    final double distToPet = (rawPos - petCenter).distance;
    final bool nowInZone = distToPet <= interactionZoneRadius;

    if (speed > fastVelocityThreshold) {
      _eventBus.emit(CursorFastMoveEvent(velocity: speed));
      _dwellSeconds = 0;
      _dwellEmitted = false;
    }

    if (nowInZone && !_inZone) {
      if (speed <= fastVelocityThreshold) {
        _eventBus.emit(CursorEnteredZoneEvent(velocity: speed));
      }
      _inZone = true;
      _dwellSeconds = 0;
      _dwellEmitted = false;
    } else if (!nowInZone && _inZone) {
      _eventBus.emit(CursorExitedZoneEvent());
      _inZone = false;
      _dwellSeconds = 0;
      _dwellEmitted = false;
    }

    if (_inZone && speed < _stationarySpeedThreshold) {
      _dwellSeconds += dt;
      if (_dwellSeconds >= dwellTimeThreshold && !_dwellEmitted) {
        _eventBus.emit(CursorDwellEvent(durationSeconds: _dwellSeconds));
        _dwellEmitted = true;
      }
    } else if (_inZone) {
      _dwellSeconds = 0;
      _dwellEmitted = false;
    }
  }

  /// Convert a macOS screen-bottom-left coordinate to Flame screen-top-left.
  /// This requires knowledge of the primary screen height. On macOS,
  /// the native bridge.  The bridge already compensates on modern macOS if
  Offset _convertMacOSOrigin(Offset macOsPos) {
    // The native bridge for macOS is expected to return coordinates already
    return macOsPos;
  }

  static double _velocityMagnitude(Offset v) =>
      math.sqrt(v.dx * v.dx + v.dy * v.dy);
}
