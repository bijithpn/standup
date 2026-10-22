/// A finding derived from recorded activity, and how much to trust it.
///
/// The distinction this file exists to enforce: a pattern seen over two days is
/// not the same claim as one seen over three weeks, and presenting them
/// identically is how an analytics feature starts telling people things that
/// are not true about themselves.
library;

/// How much evidence sits behind a finding.
enum InsightConfidence {
  /// Enough history that the pattern is worth acting on.
  high,

  /// A real signal, but a week could still change it.
  medium,

  /// Suggestive only. Must be phrased as a possibility, never as a fact.
  low;

  /// Whether this may be stated plainly rather than hedged.
  bool get isAssertable => this != InsightConfidence.low;
}

/// What a finding is about, so the UI can group and ice it appropriately.
enum InsightType {
  /// When the user does their most sustained work.
  focusWindow,

  /// How fragmented attention is, and when.
  contextSwitching,

  /// How a particular application is used.
  applicationPattern,

  /// How breaks are spaced and taken.
  breakPattern,

  /// How much of the day went nowhere.
  idleTime,

  /// A suggestion the user could act on.
  focusOpportunity,

  /// How today is going against the daily focus goal.
  goalProgress,

  /// How today compares with the user's usual day.
  comparison,
}

/// One observation about how the user's time was spent.
class ProductivityInsight {
  const ProductivityInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    required this.evidenceDayCount,
    this.supportingData = const <String, Object>{},
    this.suggestion,
    this.priority = 0,
  });

  /// One concrete thing the user could do about the finding, written to be
  /// read on its own. Absent when the finding is simply informative.
  final String? suggestion;

  /// Higher shows first. Findings about right now that the user can act on sit
  /// above background patterns; ties fall back to evidence strength.
  final int priority;

  /// Stable across regenerations of the same finding, so the UI can keep a
  /// dismissed insight dismissed.
  final String id;

  final InsightType type;

  /// A few words. The finding itself lives in [description].
  final String title;

  /// Written as an observation, not a verdict. Low-confidence findings are
  /// already hedged by the time they reach here.
  final String description;

  final InsightConfidence confidence;

  /// How many days of recorded activity this rests on. Surfaced to the user
  /// for anything below [InsightConfidence.high], because "based on 3 days" is
  /// the difference between a finding and a guess.
  final int evidenceDayCount;

  /// The numbers behind the finding, for the detail view and for tests that
  /// need to check the claim rather than the wording.
  final Map<String, Object> supportingData;

  /// True when the finding should carry its own evidence caveat in the UI.
  bool get needsEvidenceNote => confidence != InsightConfidence.high;

  @override
  String toString() =>
      'ProductivityInsight(${type.name}, ${confidence.name}, "$title")';
}

/// How much history a finding needs before it may be shown at all.
///
/// Below [minimumDays] nothing is generated — the dashboard says it is still
/// learning instead, which is honest and takes the same amount of space.
class InsightEvidence {
  const InsightEvidence._();

  /// Fewer days than this and no pattern insight is produced.
  static const int minimumDays = 2;

  /// A pattern seen across this many days may be stated plainly.
  static const int confidentDays = 7;

  /// Between [minimumDays] and this, a finding is medium confidence.
  static const int mediumDays = 4;

  /// Grades a finding by how many days of activity support it.
  static InsightConfidence forDays(int days) {
    if (days >= confidentDays) return InsightConfidence.high;
    if (days >= mediumDays) return InsightConfidence.medium;
    return InsightConfidence.low;
  }

  /// Whether there is enough history to say anything at all.
  static bool isSufficient(int days) => days >= minimumDays;
}
