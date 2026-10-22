import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:breakmate/core/native/native_bridge.dart';

/// A single, adaptively-paced source of global cursor positions.
///
/// Every widget that wanted to know where the cursor was used to run its own
/// polling timer, so the picture-in-picture window alone made three native
/// round-trips per frame — one for gaze, one for click-through, and one more
/// from the avatar widget nested inside it. This feed polls once, shares the
/// result, and only polls at all while something is listening.
///
/// The rate follows the cursor: still cursors are sampled lazily, moving ones
/// at interaction speed. Idle desktops are the common case, and that is
/// exactly when the old fixed 60 Hz timer was burning the most for nothing.
class CursorFeed {
  CursorFeed({NativeBridgePlatform? bridge})
    : _bridge = bridge ?? NativeBridge.instance;

  static final CursorFeed instance = CursorFeed();

  /// Sampling period while the cursor is actively moving.
  static const Duration activeInterval = Duration(milliseconds: 32);

  /// Sampling period once the cursor has been still for [_restThreshold].
  static const Duration restingInterval = Duration(milliseconds: 160);

  /// How long the cursor must hold still before the feed slows down.
  static const Duration _restThreshold = Duration(milliseconds: 700);

  /// Movement under this many logical pixels counts as holding still.
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

  /// The most recent known cursor position.
  Offset get position => _position;

  /// Smoothed cursor velocity, in logical pixels per second.
  Offset get velocity => _velocity;

  /// Cursor speed in logical pixels per second.
  double get speed => _velocity.distance;

  /// Whether the cursor has been holding still.
  bool get isResting => _resting;

  /// Subscribes to cursor samples, starting the poll loop if it is not running.
  ///
  /// Cancelling the returned subscription releases this listener's claim; the
  /// loop stops once the last one goes away.
  StreamSubscription<CursorSample> subscribe(
    void Function(CursorSample sample) onSample,
  ) {
    _listeners++;
    _ensureRunning();

    // Only the wrapper releases the claim. Hooking `onDone` as well would
    // double-decrement when a listener both outlives the stream and is
    // cancelled, and the count is what keeps the poll loop alive.
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
    // A previous sample is still waiting on the platform channel. Skipping
    // keeps the queue from growing when the channel is slow.
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
        // Exponential smoothing: enough to reject jitter, quick enough that a
        // flick still reads as a flick.
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
      // The cursor is unavailable on some platforms and during teardown. The
      // pet falls back to its idle wandering gaze, which is the right
      // behaviour anyway.
    } finally {
      _sampling = false;
    }
  }

  /// Releases resources. Intended for tests and app shutdown.
  Future<void> dispose() async {
    _stop();
    _listeners = 0;
    await _controller.close();
  }
}

/// One cursor reading.
class CursorSample {
  const CursorSample({
    required this.position,
    required this.velocity,
    required this.isResting,
    required this.timestamp,
  });

  /// Global cursor position in logical pixels.
  final Offset position;

  /// Smoothed velocity in logical pixels per second.
  final Offset velocity;

  /// Whether the cursor has been holding still.
  final bool isResting;

  final DateTime timestamp;

  /// Cursor speed in logical pixels per second.
  double get speed => velocity.distance;

  /// Speed normalised to roughly 0..1 over a comfortable range of motion.
  double get normalizedSpeed => math.min(1.0, speed / 1600.0);
}

/// Wraps a subscription so cancelling it also drops the feed's listener count.
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
