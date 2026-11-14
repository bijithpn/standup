import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:breakmate/core/native/native_bridge.dart';

/// Shared global cursor poller via the native bridge; runs only while subscribed and slows to restingInterval when the mouse is still.
class CursorFeed {
  CursorFeed({NativeBridgePlatform? bridge})
    : _bridge = bridge ?? NativeBridge.instance;

  static final CursorFeed instance = CursorFeed();

  static const Duration activeInterval = Duration(milliseconds: 32);

  static const Duration restingInterval = Duration(milliseconds: 160);

  static const Duration _restThreshold = Duration(milliseconds: 700);

  static const double _stillEpsilon = 1.5;

  final NativeBridgePlatform _bridge;

  final StreamController<CursorSample> _controller =
      StreamController<CursorSample>.broadcast();

  Timer? _timer;
  bool _sampling = false;
  bool _resting = false;
  int _listeners = 0;

  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMovedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Offset get position => _position;

  Offset get velocity => _velocity;

  double get speed => _velocity.distance;

  bool get isResting => _resting;

  StreamSubscription<CursorSample> subscribe(
    void Function(CursorSample sample) onSample,
  ) {
    _listeners++;
    _ensureRunning();

    return _ReleasingSubscription<CursorSample>(
      _controller.stream.listen(onSample),
      _release,
    );
  }

  void _release() {
    if (_listeners == 0) return;
    _listeners--;
    if (_listeners == 0) _stop();
  }

  void _ensureRunning() {
    if (_timer != null) return;
    _resting = false;
    _lastMovedAt = DateTime.now();
    _schedule(activeInterval);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _velocity = Offset.zero;
  }

  void _schedule(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _sample());
  }

  Future<void> _sample() async {
    if (_sampling || _listeners == 0) return;
    _sampling = true;

    try {
      final raw = await _bridge.getCursorPosition();
      final now = DateTime.now();
      final dt = now.difference(_lastSampleAt).inMicroseconds / 1e6;
      _lastSampleAt = now;

      final moved = (raw - _position).distance;
      if (dt > 0 && dt < 1.0) {
        final instant = (raw - _position) / dt;

        const alpha = 0.35;
        _velocity = Offset(
          _velocity.dx + (instant.dx - _velocity.dx) * alpha,
          _velocity.dy + (instant.dy - _velocity.dy) * alpha,
        );
      } else {
        _velocity = Offset.zero;
      }
      _position = raw;

      if (moved > _stillEpsilon) {
        _lastMovedAt = now;
        if (_resting) {
          _resting = false;
          _schedule(activeInterval);
        }
      } else if (!_resting && now.difference(_lastMovedAt) > _restThreshold) {
        _resting = true;
        _velocity = Offset.zero;
        _schedule(restingInterval);
      }

      if (!_controller.isClosed) {
        _controller.add(
          CursorSample(
            position: _position,
            velocity: _velocity,
            isResting: _resting,
            timestamp: now,
          ),
        );
      }
    } catch (_) {
    } finally {
      _sampling = false;
    }
  }

  Future<void> dispose() async {
    _stop();
    _listeners = 0;
    await _controller.close();
  }
}

/// One polled cursor reading in screen coordinates with velocity and rest flag.
class CursorSample {
  const CursorSample({
    required this.position,
    required this.velocity,
    required this.isResting,
    required this.timestamp,
  });

  final Offset position;

  final Offset velocity;

  final bool isResting;

  final DateTime timestamp;

  double get speed => velocity.distance;

  double get normalizedSpeed => math.min(1.0, speed / 1600.0);
}

/// Wraps a subscription so cancelling it decrements the feed's listener count (stops polling at zero).
class _ReleasingSubscription<T> implements StreamSubscription<T> {
  _ReleasingSubscription(this._inner, this._onRelease);

  final StreamSubscription<T> _inner;
  final void Function() _onRelease;
  bool _released = false;

  void _releaseOnce() {
    if (_released) return;
    _released = true;
    _onRelease();
  }

  @override
  Future<void> cancel() {
    _releaseOnce();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
