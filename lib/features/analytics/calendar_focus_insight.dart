/// Compares average focus score on meeting-heavy days vs lighter days — a
/// comparison Opsis structurally can't make (it has no calendar access) but
/// BreakMate already can, since it already has both halves of the data
/// (`CalendarService`, `FocusSessionService`/`AppUsageService`). Pure
/// aggregation over data the caller already fetched; see the
/// workflow-analysis plan doc §7.4.
library;

/// A day counts as "meeting-heavy" once it has at least this many events.
const int heavyMeetingDayThreshold = 4;

/// Minimum sample days on each side of the comparison before it's trusted
/// enough to surface — avoids a single unusual day reading as a pattern.
const int minComparisonDays = 3;

/// Meaningful drop, in percentage points, before it's worth mentioning.
const double meaningfulFocusDropPoints = 10;

class CalendarFocusComparison {
  final double heavyDayAverageFocusScore;
  final double lightDayAverageFocusScore;
  final int heavyDayCount;
  final int lightDayCount;

  const CalendarFocusComparison({
    required this.heavyDayAverageFocusScore,
    required this.lightDayAverageFocusScore,
    required this.heavyDayCount,
    required this.lightDayCount,
  });

  /// Requires at least [minComparisonDays] samples on both sides — otherwise
  /// the comparison is meaningless, not just imprecise (same standard
  /// [BreakFocusCorrelation.hasEnoughData] uses).
  bool get hasEnoughData =>
      heavyDayCount >= minComparisonDays && lightDayCount >= minComparisonDays;

  /// Percentage-point gap between light-day and heavy-day focus scores.
  /// Positive means meeting-heavy days have *less* focus.
  double get dropPercentPoints =>
      (lightDayAverageFocusScore - heavyDayAverageFocusScore) * 100;

  String describe() {
    final drop = dropPercentPoints;
    if (drop.abs() < 1) {
      return 'Your focus score looks about the same on meeting-heavy days '
          'as lighter ones.';
    }
    final direction = drop >= 0 ? 'drops' : 'rises';
    return 'Your focus score $direction ${drop.abs().round()} points on '
        'days with $heavyMeetingDayThreshold+ meetings.';
  }

  /// Groups [meetingCountByDate]/[focusScoreByDate] (both keyed by the same
  /// `yyyy-MM-dd` date strings [AppUsageService]/[FocusSessionService]
  /// already use) into heavy vs light days and averages each side. Only
  /// dates present in both maps are counted.
  static CalendarFocusComparison compute({
    required Map<String, int> meetingCountByDate,
    required Map<String, double> focusScoreByDate,
  }) {
    final heavyScores = <double>[];
    final lightScores = <double>[];

    for (final entry in meetingCountByDate.entries) {
      final score = focusScoreByDate[entry.key];
      if (score == null) continue;
      if (entry.value >= heavyMeetingDayThreshold) {
        heavyScores.add(score);
      } else {
        lightScores.add(score);
      }
    }

    return CalendarFocusComparison(
      heavyDayAverageFocusScore: _average(heavyScores),
      lightDayAverageFocusScore: _average(lightScores),
      heavyDayCount: heavyScores.length,
      lightDayCount: lightScores.length,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
