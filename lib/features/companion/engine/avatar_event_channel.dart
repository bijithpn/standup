import 'dart:async';
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';

abstract class AvatarEvent {
  final DateTime timestamp;
  AvatarEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class AvatarAnimationStartedEvent extends AvatarEvent {
  final AvatarAnimationClip clip;
  AvatarAnimationStartedEvent(this.clip, {super.timestamp});
}

class AvatarAnimationFinishedEvent extends AvatarEvent {
  final AvatarAnimationClip clip;
  AvatarAnimationFinishedEvent(this.clip, {super.timestamp});
}

class AvatarTapEvent extends AvatarEvent {
  final ui.Offset? position;
  final int clickCount;
  AvatarTapEvent({this.position, this.clickCount = 1, super.timestamp});
}

class AvatarDoubleTapEvent extends AvatarEvent {
  final ui.Offset? position;
  AvatarDoubleTapEvent({this.position, super.timestamp});
}

class AvatarLongPressEvent extends AvatarEvent {
  final ui.Offset? position;
  AvatarLongPressEvent({this.position, super.timestamp});
}

class AvatarProximityEvent extends AvatarEvent {
  final double distance;
  final bool isInside;
  AvatarProximityEvent({
    required this.distance,
    required this.isInside,
    super.timestamp,
  });
}

class AvatarGazeEvent extends AvatarEvent {
  final double lookAtX;
  final double lookAtY;
  final double yaw;
  AvatarGazeEvent({
    required this.lookAtX,
    required this.lookAtY,
    required this.yaw,
    super.timestamp,
  });
}

class AvatarEventChannel {
  final StreamController<AvatarEvent> _controller =
      StreamController<AvatarEvent>.broadcast();

  Stream<AvatarEvent> get events => _controller.stream;

  Stream<T> on<T extends AvatarEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  Stream<AvatarAnimationStartedEvent> get onAnimationStarted =>
      on<AvatarAnimationStartedEvent>();

  Stream<AvatarAnimationFinishedEvent> get onAnimationFinished =>
      on<AvatarAnimationFinishedEvent>();

  Stream<AvatarTapEvent> get onTap => on<AvatarTapEvent>();

  Stream<AvatarDoubleTapEvent> get onDoubleTap => on<AvatarDoubleTapEvent>();

  Stream<AvatarLongPressEvent> get onLongPress => on<AvatarLongPressEvent>();

  Stream<AvatarProximityEvent> get onProximity => on<AvatarProximityEvent>();

  Stream<AvatarGazeEvent> get onGaze => on<AvatarGazeEvent>();

  void emit(AvatarEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void handleRawEvent(String eventType, [Map<String, dynamic>? data]) {
    switch (eventType) {
      case 'animation_started':
      case 'animation_start':
        final clipName = data?['clip'] as String?;
        final clip = AvatarAnimationClip.tryParse(clipName);
        if (clip != null) {
          emit(AvatarAnimationStartedEvent(clip));
        }
        break;
      case 'animation_finished':
      case 'animation_end':
      case 'animation_finish':
        final clipName = data?['clip'] as String?;
        final clip = AvatarAnimationClip.tryParse(clipName);
        if (clip != null) {
          emit(AvatarAnimationFinishedEvent(clip));
        }
        break;
      case 'tap':
      case 'click':
        final x = (data?['x'] as num?)?.toDouble();
        final y = (data?['y'] as num?)?.toDouble();
        emit(
          AvatarTapEvent(
            position: x != null && y != null ? ui.Offset(x, y) : null,
          ),
        );
        break;
      case 'double_tap':
      case 'double_click':
        final x = (data?['x'] as num?)?.toDouble();
        final y = (data?['y'] as num?)?.toDouble();
        emit(
          AvatarDoubleTapEvent(
            position: x != null && y != null ? ui.Offset(x, y) : null,
          ),
        );
        break;
      case 'proximity':
        final dist = (data?['distance'] as num?)?.toDouble() ?? 0.0;
        final inside = data?['isInside'] as bool? ?? false;
        emit(AvatarProximityEvent(distance: dist, isInside: inside));
        break;
      case 'gaze':
        final lx = (data?['x'] as num?)?.toDouble() ?? 0.0;
        final ly = (data?['y'] as num?)?.toDouble() ?? 0.0;
        final yaw = (data?['yaw'] as num?)?.toDouble() ?? 0.0;
        emit(AvatarGazeEvent(lookAtX: lx, lookAtY: ly, yaw: yaw));
        break;
    }
  }

  void dispose() {
    _controller.close();
  }
}
