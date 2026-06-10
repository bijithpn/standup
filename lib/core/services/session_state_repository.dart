import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/session_state.dart';
import 'package:objectbox/objectbox.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class SessionStateRepository {
  final StorageService _storage;
  late Box<SessionState> _box;

  SessionStateRepository(this._storage);

  void initialize() {
    _box = _storage.store.box<SessionState>();
  }

  SessionState? getSessionForToday() {
    try {
      final session = _box.get(1);
      if (session == null) return null;

      final today = DateTime.now();
      final todayStr = _formatDate(today);

      if (session.lastSessionDate != todayStr) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

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
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  void clearSession() {
    try {
      _box.remove(1);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
