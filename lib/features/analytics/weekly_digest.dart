import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Summary of the last 7 days (adherence, top focus category, budgets, milestone) rendered as a notification message or markdown.
class WeeklyDigest {
  final double breakAdherenceRate;
  final int breaksCompleted;
  final int breaksSkipped;
  final AppCategory? topFocusCategory;
  final int longestDeepWorkSessionSeconds;
  final String? companionMilestoneLabel;

  final Map<AppCategory, int> daysOverBudgetByCategory;

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

  double? get adherenceDeltaPoints {
    final trailing = trailingAverageAdherenceRate;
    if (trailing == null) return null;
    return (breakAdherenceRate - trailing) * 100;
  }

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

  String? _budgetSummary() {
    if (daysOverBudgetByCategory.isEmpty) return null;
    final worst = daysOverBudgetByCategory.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    return '${worst.key.label} was over its daily budget ${worst.value}/7 days.';
  }

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
