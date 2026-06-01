import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/session_state.dart';
import 'package:objectbox/objectbox.dart';

class SessionStateRepository {
  final StorageService _storage;
  late Box<SessionState> _box;

  SessionStateRepository(this._storage);

  void initialize() {
    _box = _storage.store.box<SessionState>();
  }

  /// Get today's session (or null if different day)
  SessionState? getSessionForToday() {
    try {
      final session = _box.get(1);
      if (session == null) return null;

      final today = DateTime.now();
      final todayStr = _formatDate(today);

      // If session is from a different day, don't return it
      if (session.lastSessionDate != todayStr) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Save current session state
  void saveSession({
    required Duration workElapsed,
    required Duration totalWorkToday,
    required int postureElapsedSeconds,
    required int eyeBlinkElapsedSeconds,
    required bool isPreBreak,
    required String timerState,
    required DateTime? longBreakWindowStartedAt,
  }) {
    try {
      final today = DateTime.now();
      final todayStr = _formatDate(today);

      final session = SessionState(
        id: 1,
        lastSessionDate: todayStr,
        workElapsedSeconds: workElapsed.inSeconds,
        totalWorkTodaySeconds: totalWorkToday.inSeconds,
        postureElapsedSeconds: postureElapsedSeconds,
        eyeBlinkElapsedSeconds: eyeBlinkElapsedSeconds,
        isPreBreak: isPreBreak,
        timerState: timerState,
        longBreakWindowStartedAt: longBreakWindowStartedAt,
      );

      _box.put(session);
    } catch (_) {
      // Silently fail - not critical if session save fails
    }
  }

  /// Clear session (call on new day or when disabled)
  void clearSession() {
    try {
      _box.remove(1);
    } catch (_) {
      // Silently fail
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
