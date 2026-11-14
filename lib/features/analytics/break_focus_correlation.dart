import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';

/// Compares focus time in the hour after completed breaks vs skipped ones; feeds the one-time focus insight notification.
class BreakFocusCorrelation {
  final double afterCompletedScore;

  final double afterSkippedScore;

  final int completedSampleCount;
  final int skippedSampleCount;

  const BreakFocusCorrelation({
    required this.afterCompletedScore,
    required this.afterSkippedScore,
    required this.completedSampleCount,
    required this.skippedSampleCount,
  });

  bool get hasEnoughData => completedSampleCount > 0 && skippedSampleCount > 0;

  double get differencePoints =>
      (afterCompletedScore - afterSkippedScore) * 100;

  String describe() {
    final diff = differencePoints;
    final direction = diff >= 0 ? 'more' : 'less';
    if (diff.abs() < 1) {
      return "Focus in the hour after a break looks about the same whether "
          "you took it or skipped it.";
    }
    return 'You focus ${diff.abs().round()} points $direction in the hour '
        'after a break you take vs. one you skip.';
  }

  // Score = share of the window covered by focus sessions, per break event.
  static BreakFocusCorrelation compute({
    required List<BreakEvent> events,
    required List<FocusSession> allSessions,
    Duration window = const Duration(hours: 1),
  }) {
    final completedScores = <double>[];
    final skippedScores = <double>[];

    for (final event in events) {
      final windowEnd = event.time.add(window);
      final focusSeconds = _overlapSeconds(allSessions, event.time, windowEnd);
      final score = (focusSeconds / window.inSeconds).clamp(0.0, 1.0);
      (event.completed ? completedScores : skippedScores).add(score);
    }

    return BreakFocusCorrelation(
      afterCompletedScore: _average(completedScores),
      afterSkippedScore: _average(skippedScores),
      completedSampleCount: completedScores.length,
      skippedSampleCount: skippedScores.length,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static int _overlapSeconds(
    List<FocusSession> sessions,
    DateTime start,
    DateTime end,
  ) {
    var total = 0;
    for (final session in sessions) {
      final overlapStart = session.start.isAfter(start) ? session.start : start;
      final overlapEnd = session.end.isBefore(end) ? session.end : end;
      final overlap = overlapEnd.difference(overlapStart).inSeconds;
      if (overlap > 0) total += overlap;
    }
    return total;
  }
}
