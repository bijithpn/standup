import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Turns per-tick active-app categories into focus sessions; a session ends on a non-focus category, category change or gap > maxGap.
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

  /// Returns the session that just closed (if long enough), otherwise null.
  FocusSession? onTick(AppCategory category, DateTime now) {
    if (!isFocusCategory(category)) {
      return _closeSession();
    }

    final gapExceeded =
        _lastTick != null && now.difference(_lastTick!) > maxGap;
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
    return FocusSession(
      category: category,
      start: start,
      durationSeconds: duration,
    );
  }
}
