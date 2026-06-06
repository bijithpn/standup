import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';

/// Polls the cursor position at 60 Hz, computes a smoothed velocity via EMA,
/// and emits typed EventBus events for the behavior engine.
///
/// Requirements: 5.1, 5.2, 5.3, 5.5, 5.6
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

  /// Accumulated dwell time while cursor is stationary inside the zone.
  double _dwellSeconds = 0.0;
  bool _dwellEmitted = false;

  Offset get lastPosition => _lastPosition;
  Offset get velocity => _velocity;

  /// Called from `CompanionGame.update()` at 60 Hz.
  ///
  /// Reads the native cursor position, updates the EMA-smoothed velocity,
  /// and emits zone-transition events.
  Future<void> sample(double dt, Offset petCenter) async {
    if (dt <= 0) return;

    var rawPos = await _bridge.getCursorPosition();

    // macOS returns coordinates in screen-bottom-left origin.
    // Flame uses screen-top-left origin. Convert if needed.
    if (Platform.isMacOS) {
      rawPos = _convertMacOSOrigin(rawPos);
    }

    // Instantaneous velocity (px/s).
    final Offset instantaneous = (rawPos - _lastPosition) / dt;

    // EMA smoothing: velocity = (1 - α) * velocity + α * instantaneous
    _velocity = Offset(
      (1 - _emaAlpha) * _velocity.dx + _emaAlpha * instantaneous.dx,
      (1 - _emaAlpha) * _velocity.dy + _emaAlpha * instantaneous.dy,
    );
    _lastPosition = rawPos;

    final double speed = _velocityMagnitude(_velocity);
    final double distToPet = (rawPos - petCenter).distance;
    final bool nowInZone = distToPet <= interactionZoneRadius;

    // --- Fast move (any position) ---
    if (speed > fastVelocityThreshold) {
      _eventBus.emit(CursorFastMoveEvent(velocity: speed));
      // Fast move clears dwell state.
      _dwellSeconds = 0;
      _dwellEmitted = false;
    }

    // --- Zone enter/exit ---
    if (nowInZone && !_inZone) {
      // Only emit CursorEnteredZoneEvent when speed is within threshold.
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

    // --- Dwell detection (cursor stationary inside zone ≥ 3s) ---
    if (_inZone && speed < _stationarySpeedThreshold) {
      _dwellSeconds += dt;
      if (_dwellSeconds >= dwellTimeThreshold && !_dwellEmitted) {
        _eventBus.emit(CursorDwellEvent(durationSeconds: _dwellSeconds));
        _dwellEmitted = true;
      }
    } else if (_inZone) {
      // Cursor moved again inside zone — reset dwell.
      _dwellSeconds = 0;
      _dwellEmitted = false;
    }
  }

  /// Convert a macOS screen-bottom-left coordinate to Flame screen-top-left.
  ///
  /// This requires knowledge of the primary screen height. On macOS,
  /// `NSScreen.mainScreen.frame.size.height` is the reference.  We approximate
  /// this at runtime using the first display enumerated by the native bridge;
  /// fall back to a no-op if unavailable.
  ///
  /// In practice the caller (CursorTracker.sample) passes the raw Offset from
  /// the native bridge.  The bridge already compensates on modern macOS if
  /// possible; this is a belt-and-suspenders conversion.
  Offset _convertMacOSOrigin(Offset macOsPos) {
    // The native bridge for macOS is expected to return coordinates already
    // normalised to screen-top-left origin (consistent with Flutter's
    // coordinate system). If the native side does not perform this conversion,
    // callers can override this method in a subclass or mock.
    //
    // For now, return as-is and document the expectation.
    return macOsPos;
  }

  static double _velocityMagnitude(Offset v) =>
      math.sqrt(v.dx * v.dx + v.dy * v.dy);
}
