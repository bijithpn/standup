import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// A composed "how was your week" summary — pure data, built from services
/// that already track everything it needs ([StatsService], [FocusSessionService],
/// [CompanionStreakService]). This class only holds the result and formats it;
/// [WeeklyDigestService] does the composing and scheduling.
class WeeklyDigest {
  final double breakAdherenceRate;
  final int breaksCompleted;
  final int breaksSkipped;
  final AppCategory? topFocusCategory;
  final int longestDeepWorkSessionSeconds;
  final String? companionMilestoneLabel;

  /// How many of the last 7 tracked days each category (by its
  /// [SettingsModel.categoryDailyBudgetMinutes] key) met or exceeded its
  /// daily budget. A category never over budget, or never budgeted, is
  /// absent from this map — never present with a 0.
  final Map<AppCategory, int> daysOverBudgetByCategory;

  /// Break-adherence rate averaged over the 4 weeks *before* this one —
  /// the trend-regression check from the workflow-analysis plan doc §7.3
  /// ("what changed," not just a snapshot). Null when there isn't at least
  /// a week of prior history to trust a comparison against.
  final double? trailingAverageAdherenceRate;

  const WeeklyDigest({
    required this.breakAdherenceRate,
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.topFocusCategory,
    required this.longestDeepWorkSessionSeconds,
    required this.companionMilestoneLabel,
    this.daysOverBudgetByCategory = const {},
    this.trailingAverageAdherenceRate,
  });

  /// Percentage-point gap between this week's break adherence and
  /// [trailingAverageAdherenceRate]. Positive means this week is better.
  /// Null when there's no trailing average to compare against.
  double? get adherenceDeltaPoints {
    final trailing = trailingAverageAdherenceRate;
    if (trailing == null) return null;
    return (breakAdherenceRate - trailing) * 100;
  }

  /// A one-sentence trend note, only when the swing is large enough to be
  /// worth mentioning (avoids noise on an ordinary week) — shared by
  /// [toMessage] and [toMarkdown] so the wording stays consistent.
  String? _trendNote() {
    final delta = adherenceDeltaPoints;
    if (delta == null || delta.abs() < 10) return null;
    final direction = delta > 0 ? 'better' : 'worse';
    return 'Break adherence is ${delta.abs().round()} points $direction '
        'than your last 4 weeks.';
  }

  String toMessage() {
    final parts = <String>[];
    final totalBreaks = breaksCompleted + breaksSkipped;
    if (totalBreaks > 0) {
      parts.add(
        '${(breakAdherenceRate * 100).round()}% of breaks taken '
        '($breaksCompleted/$totalBreaks).',
      );
    }
    if (topFocusCategory != null && longestDeepWorkSessionSeconds > 0) {
      parts.add(
        'Best focus in ${topFocusCategory!.label} — longest deep-work '
        'session was ${formatUsageDuration(longestDeepWorkSessionSeconds)}.',
      );
    }
    if (companionMilestoneLabel != null) {
      parts.add('Companion milestone: $companionMilestoneLabel.');
    }
    final budgetNote = _budgetSummary();
    if (budgetNote != null) parts.add(budgetNote);
    final trendNote = _trendNote();
    if (trendNote != null) parts.add(trendNote);
    return parts.isEmpty
        ? 'Not much tracked data this week yet — keep going!'
        : parts.join(' ');
  }

  /// A short "over budget N/7 days" note for whichever budgeted category
  /// went over most often this week, or null if nothing did.
  String? _budgetSummary() {
    if (daysOverBudgetByCategory.isEmpty) return null;
    final worst = daysOverBudgetByCategory.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    return '${worst.key.label} was over its daily budget ${worst.value}/7 days.';
  }

  /// Renders the digest as a small Markdown document — for the Statistics
  /// screen's "Export This Week" action, so someone can paste it into a
  /// personal log or a 1:1. Fully local: this only formats data the app
  /// already computed, no cloud call involved.
  String toMarkdown({DateTime? generatedAt}) {
    final date = generatedAt ?? DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final totalBreaks = breaksCompleted + breaksSkipped;

    final buffer = StringBuffer()
      ..writeln('# BreakMate — Week in Review')
      ..writeln()
      ..writeln('_Generated ${dateStr}_')
      ..writeln();

    if (totalBreaks > 0) {
      buffer.writeln(
        '- **Break adherence:** ${(breakAdherenceRate * 100).round()}% '
        '($breaksCompleted/$totalBreaks taken)',
      );
    }
    if (topFocusCategory != null && longestDeepWorkSessionSeconds > 0) {
      buffer
        ..writeln('- **Best focus category:** ${topFocusCategory!.label}')
        ..writeln(
          '- **Longest deep-work session:** '
          '${formatUsageDuration(longestDeepWorkSessionSeconds)}',
        );
    }
    if (companionMilestoneLabel != null) {
      buffer.writeln('- **Companion milestone:** $companionMilestoneLabel');
    }
    for (final entry in daysOverBudgetByCategory.entries) {
      buffer.writeln(
        '- **${entry.key.label} over budget:** ${entry.value}/7 days',
      );
    }
    final trendNote = _trendNote();
    if (trendNote != null) buffer.writeln('- **Trend:** $trendNote');
    if (totalBreaks == 0 &&
        topFocusCategory == null &&
        companionMilestoneLabel == null &&
        daysOverBudgetByCategory.isEmpty) {
      buffer.writeln('_Not much tracked data this week yet._');
    }

    return buffer.toString();
  }
}
