import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';

/// Answers the question neither break-taking stats nor app-usage stats can
/// answer alone: does taking a break actually correlate with better focus
/// afterward? Compares the average focus-session coverage of the hour
/// following a *completed* break against the hour following a *skipped*
/// one, both derived from data the app already tracks ([BreakHistoryService],
/// [FocusSessionService]) — this only adds the comparison.
class BreakFocusCorrelation {
  /// Average share (0.0-1.0) of the window after a completed break spent in
  /// a deep-work session.
  final double afterCompletedScore;

  /// Same, but after a skipped break.
  final double afterSkippedScore;

  final int completedSampleCount;
  final int skippedSampleCount;

  const BreakFocusCorrelation({
    required this.afterCompletedScore,
    required this.afterSkippedScore,
    required this.completedSampleCount,
    required this.skippedSampleCount,
  });

  /// Requires at least one sample of each kind — otherwise the comparison
  /// is meaningless, not just imprecise.
  bool get hasEnoughData => completedSampleCount > 0 && skippedSampleCount > 0;

  /// Percentage-point gap between the two scores. Positive means completed
  /// breaks were followed by more focus.
  double get differencePoints =>
      (afterCompletedScore - afterSkippedScore) * 100;

  /// A one-sentence, human-readable summary — shared by the Focus Score
  /// card and the one-time proactive insight notification, so the wording
  /// stays consistent wherever this comparison is surfaced.
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
