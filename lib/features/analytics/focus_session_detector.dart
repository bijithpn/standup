import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Turns a stream of per-tick category observations into completed deep-work
/// sessions. Pure and clock-independent — the caller supplies `now` on each
/// tick — so it needs no fakes or timers to test.
///
/// A session is a run of ticks in the same focus category ([kFocusCategories])
/// with no gap wider than [maxGap] (tolerates a couple of missed/idle polls
/// without splitting one sitting into several sessions). It closes when the
/// category changes, a gap is exceeded, or [closeOpenSession] is called
/// (e.g. when tracking stops) — and is only reported if it met
/// [minDurationSeconds].
class FocusSessionDetector {
  final Duration maxGap;
  final int minDurationSeconds;

  AppCategory? _activeCategory;
  DateTime? _sessionStart;
  DateTime? _lastTick;

  FocusSessionDetector({
    this.maxGap = const Duration(seconds: 90),
    this.minDurationSeconds = kMinFocusSessionSeconds,
  });

  /// Feed one tick's observed category and timestamp. Returns the session
  /// that just closed, if this tick ended one that met the minimum
  /// duration — otherwise null.
  FocusSession? onTick(AppCategory category, DateTime now) {
    if (!isFocusCategory(category)) {
      return _closeSession();
    }

    final gapExceeded = _lastTick != null && now.difference(_lastTick!) > maxGap;
    if (_activeCategory != category || gapExceeded) {
      final closed = _closeSession();
      _activeCategory = category;
      _sessionStart = now;
      _lastTick = now;
      return closed;
    }

    _lastTick = now;
    return null;
  }

  /// Finalizes whatever session is currently open, e.g. when tracking stops
  /// mid-session. Same minimum-duration rule applies.
  FocusSession? closeOpenSession() => _closeSession();

  FocusSession? _closeSession() {
    final category = _activeCategory;
    final start = _sessionStart;
    final end = _lastTick;
    _activeCategory = null;
    _sessionStart = null;
    _lastTick = null;

    if (category == null || start == null || end == null) return null;
    final duration = end.difference(start).inSeconds;
    if (duration < minDurationSeconds) return null;
    return FocusSession(category: category, start: start, durationSeconds: duration);
  }
}
