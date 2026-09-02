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

  const WeeklyDigest({
    required this.breakAdherenceRate,
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.topFocusCategory,
    required this.longestDeepWorkSessionSeconds,
    required this.companionMilestoneLabel,
  });

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
    return parts.isEmpty
        ? 'Not much tracked data this week yet — keep going!'
        : parts.join(' ');
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
    if (totalBreaks == 0 &&
        topFocusCategory == null &&
        companionMilestoneLabel == null) {
      buffer.writeln('_Not much tracked data this week yet._');
    }

    return buffer.toString();
  }
}
