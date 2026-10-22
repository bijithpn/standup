import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';

typedef JsEvaluator = FutureOr<dynamic> Function(String script);

class AvatarEngineController {
  AvatarEngineController({
    JsEvaluator? jsEvaluator,
    AvatarEventChannel? eventChannel,
  }) : _jsEvaluator = jsEvaluator,
       _eventChannel = eventChannel ?? AvatarEventChannel();

  final JsEvaluator? _jsEvaluator;
  final AvatarEventChannel _eventChannel;

  AvatarEventChannel get eventChannel => _eventChannel;

  ui.Offset _currentLookAt = ui.Offset.zero;
  ui.Offset get currentLookAt => _currentLookAt;

  double _currentYaw = 0.0;
  double get currentYaw => _currentYaw;

  AvatarAnimationClip? _currentClip;
  AvatarAnimationClip? get currentClip => _currentClip;

  AvatarDefinition? _currentDefinition;
  AvatarDefinition? get currentDefinition => _currentDefinition;

  AvatarPalette? _currentPalette;
  AvatarPalette? get currentPalette => _currentPalette;

  // Gaze calculation & smoothing state
  ui.Offset _gazeSmoothed = ui.Offset.zero;
  ui.Offset _lastCursorPosition = ui.Offset.zero;
  double _idleTime = 0.0;
  double get idleTime => _idleTime;
  double _saccadeTimer = 0.0;
  ui.Offset _saccadeOffset = ui.Offset.zero;
  final math.Random _random = math.Random();
  StreamSubscription<ui.Offset>? _cursorSubscription;

  Future<dynamic> evaluateJs(String script) async {
    if (_jsEvaluator != null) {
      return await _jsEvaluator(script);
    }
    return null;
  }

  Future<void> setLookAt(double x, double y) async {
    final clampedX = x.clamp(-1.0, 1.0);
    final clampedY = y.clamp(-1.0, 1.0);
    _currentLookAt = ui.Offset(clampedX, clampedY);
    await evaluateJs('window.AvatarBridge.setLookAt($clampedX, $clampedY);');
  }

  Future<void> setYaw(double radians) async {
    _currentYaw = radians;
    await evaluateJs('window.AvatarBridge.setYaw($radians);');
  }

  Future<void> playAnimation(
    AvatarAnimationClip clip, {
    bool loop = true,
    double speed = 1.0,
  }) async {
    _currentClip = clip;
    _eventChannel.emit(AvatarAnimationStartedEvent(clip));
    await evaluateJs(
      "window.AvatarBridge.playAnimation('${clip.name}', { loop: $loop, speed: $speed });",
    );
  }

  Future<void> setDefinition(AvatarDefinition definition) async {
    _currentDefinition = definition;
    final jsonStr = jsonEncode(definition.toJson());
    await evaluateJs('window.AvatarBridge.setDefinition($jsonStr);');
  }

  Future<void> setPalette(AvatarPalette palette) async {
    _currentPalette = palette;
    final jsonStr = jsonEncode(palette.toJson());
    await evaluateJs('window.AvatarBridge.setPalette($jsonStr);');
  }

  Future<dynamic> capturePng() async {
    return await evaluateJs('window.AvatarBridge.capturePng();');
  }

  ui.Offset calculateGaze({
    required ui.Offset petScreenPosition,
    required ui.Offset cursorScreenPosition,
    double maxDistance = 600.0,
    double damping = 0.15,
    double dt = 0.016,
    bool enableSmoothing = true,
    bool enableSaccades = true,
  }) {
    final dx = cursorScreenPosition.dx - petScreenPosition.dx;
    final dy = cursorScreenPosition.dy - petScreenPosition.dy;

    final double rawTargetX = maxDistance > 0
        ? (dx / maxDistance).clamp(-1.0, 1.0)
        : 0.0;
    final double rawTargetY = maxDistance > 0
        ? (dy / maxDistance).clamp(-1.0, 1.0)
        : 0.0;

    final cursorDelta = (cursorScreenPosition - _lastCursorPosition).distance;
    _lastCursorPosition = cursorScreenPosition;

    if (cursorDelta < 2.0) {
      _idleTime += dt;
    } else {
      _idleTime = 0.0;
      _saccadeOffset = ui.Offset.zero;
    }

    if (enableSaccades) {
      _saccadeTimer += dt;
      if (_saccadeTimer >= 0.05) {
        _saccadeTimer = 0.0;
        final double saccadeX = (_random.nextDouble() * 2 - 1) * 0.04;
        final double saccadeY = (_random.nextDouble() * 2 - 1) * 0.03;
        _saccadeOffset = ui.Offset(saccadeX, saccadeY);
      }
    } else {
      _saccadeOffset = ui.Offset.zero;
    }

    final double targetWithSaccadesX = (rawTargetX + _saccadeOffset.dx).clamp(
      -1.0,
      1.0,
    );
    final double targetWithSaccadesY = (rawTargetY + _saccadeOffset.dy).clamp(
      -1.0,
      1.0,
    );

    if (enableSmoothing) {
      final double smoothFactor = (damping * 60.0 * dt).clamp(0.0, 1.0);
      final double smoothedX =
          ui.lerpDouble(_gazeSmoothed.dx, targetWithSaccadesX, smoothFactor) ??
          targetWithSaccadesX;
      final double smoothedY =
          ui.lerpDouble(_gazeSmoothed.dy, targetWithSaccadesY, smoothFactor) ??
          targetWithSaccadesY;
      _gazeSmoothed = ui.Offset(
        smoothedX.clamp(-1.0, 1.0),
        smoothedY.clamp(-1.0, 1.0),
      );
    } else {
      _gazeSmoothed = ui.Offset(targetWithSaccadesX, targetWithSaccadesY);
    }

    return _gazeSmoothed;
  }

  Future<void> updateGaze({
    required ui.Offset petScreenPosition,
    required ui.Offset cursorScreenPosition,
    double maxDistance = 600.0,
    double damping = 0.15,
    double dt = 0.016,
    bool enableSmoothing = true,
    bool enableSaccades = true,
    double proximityThreshold = 80.0,
  }) async {
    final gaze = calculateGaze(
      petScreenPosition: petScreenPosition,
      cursorScreenPosition: cursorScreenPosition,
      maxDistance: maxDistance,
      damping: damping,
      dt: dt,
      enableSmoothing: enableSmoothing,
      enableSaccades: enableSaccades,
    );

    final distance = (cursorScreenPosition - petScreenPosition).distance;
    final isInside = distance <= proximityThreshold;
    _eventChannel.emit(
      AvatarProximityEvent(distance: distance, isInside: isInside),
    );
    _eventChannel.emit(
      AvatarGazeEvent(lookAtX: gaze.dx, lookAtY: gaze.dy, yaw: _currentYaw),
    );

    await setLookAt(gaze.dx, gaze.dy);
  }

  void attachCursorTracker(
    CursorTracker tracker, {
    required ui.Offset Function() getPetPosition,
    double maxDistance = 600.0,
  }) {
    _cursorSubscription?.cancel();
    _cursorSubscription = tracker.positionStream.listen((cursorPos) {
      updateGaze(
        petScreenPosition: getPetPosition(),
        cursorScreenPosition: cursorPos,
        maxDistance: maxDistance,
      );
    });
  }

  void dispose() {
    _cursorSubscription?.cancel();
    _eventChannel.dispose();
  }
}
