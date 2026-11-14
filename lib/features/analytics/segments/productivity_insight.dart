library;

/// How much evidence backs an insight; low ones should be hedged, not asserted.
enum InsightConfidence {
  high,

  medium,

  low;

  bool get isAssertable => this != InsightConfidence.low;
}

enum InsightType {
  focusWindow,

  contextSwitching,

  applicationPattern,

  breakPattern,

  idleTime,

  focusOpportunity,

  goalProgress,

  comparison,
}

/// A single insight (title, description, optional suggestion) with its confidence and supporting data.
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

  final String? suggestion;

  final int priority;

  final String id;

  final InsightType type;

  final String title;

  final String description;

  final InsightConfidence confidence;

  final int evidenceDayCount;

  final Map<String, Object> supportingData;

  bool get needsEvidenceNote => confidence != InsightConfidence.high;

  @override
  String toString() =>
      'ProductivityInsight(${type.name}, ${confidence.name}, "$title")';
}

/// Maps number of days of data to a confidence level.
class InsightEvidence {
  const InsightEvidence._();

  static const int minimumDays = 2;

  static const int confidentDays = 7;

  static const int mediumDays = 4;

  static InsightConfidence forDays(int days) {
    if (days >= confidentDays) return InsightConfidence.high;
    if (days >= mediumDays) return InsightConfidence.medium;
    return InsightConfidence.low;
  }

  static bool isSufficient(int days) => days >= minimumDays;
}
