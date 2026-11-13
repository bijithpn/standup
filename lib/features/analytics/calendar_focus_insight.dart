library;

const int heavyMeetingDayThreshold = 4;

const int minComparisonDays = 3;

const double meaningfulFocusDropPoints = 10;

/// Compares average focus score on meeting-heavy days vs lighter days (needs a few days of each).
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

  bool get hasEnoughData =>
      heavyDayCount >= minComparisonDays && lightDayCount >= minComparisonDays;

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
