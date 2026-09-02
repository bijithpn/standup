import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/weekly_digest.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  test('toMarkdown includes break adherence, focus, and milestone lines', () {
    const digest = WeeklyDigest(
      breakAdherenceRate: 0.75,
      breaksCompleted: 15,
      breaksSkipped: 5,
      topFocusCategory: AppCategory.coding,
      longestDeepWorkSessionSeconds: 3600,
      companionMilestoneLabel: 'One Week Strong',
    );

    final markdown = digest.toMarkdown(generatedAt: DateTime(2026, 9, 6));

    expect(markdown, contains('# BreakMate — Week in Review'));
    expect(markdown, contains('_Generated 2026-09-06_'));
    expect(markdown, contains('75% (15/20 taken)'));
    expect(markdown, contains('Coding'));
    expect(markdown, contains('1h 0m'));
    expect(markdown, contains('One Week Strong'));
  });

  test('toMarkdown notes sparse data when nothing was tracked', () {
    const digest = WeeklyDigest(
      breakAdherenceRate: 0.0,
      breaksCompleted: 0,
      breaksSkipped: 0,
      topFocusCategory: null,
      longestDeepWorkSessionSeconds: 0,
      companionMilestoneLabel: null,
    );

    final markdown = digest.toMarkdown(generatedAt: DateTime(2026, 9, 6));

    expect(markdown, contains('Not much tracked data this week yet'));
    expect(markdown, isNot(contains('Break adherence')));
  });

  test('includes the worst over-budget category in both message and markdown', () {
    const digest = WeeklyDigest(
      breakAdherenceRate: 0.0,
      breaksCompleted: 0,
      breaksSkipped: 0,
      topFocusCategory: null,
      longestDeepWorkSessionSeconds: 0,
      companionMilestoneLabel: null,
      daysOverBudgetByCategory: {
        AppCategory.browsing: 5,
        AppCategory.coding: 1,
      },
    );

    expect(digest.toMessage(), contains('Browsing was over its daily budget 5/7 days.'));
    final markdown = digest.toMarkdown(generatedAt: DateTime(2026, 9, 6));
    expect(markdown, contains('- **Browsing over budget:** 5/7 days'));
    expect(markdown, contains('- **Coding over budget:** 1/7 days'));
    // Sparse-data fallback shouldn't fire when budget data exists.
    expect(markdown, isNot(contains('Not much tracked data this week yet')));
  });

  test('daysOverBudgetByCategory defaults to empty', () {
    const digest = WeeklyDigest(
      breakAdherenceRate: 0.0,
      breaksCompleted: 0,
      breaksSkipped: 0,
      topFocusCategory: null,
      longestDeepWorkSessionSeconds: 0,
      companionMilestoneLabel: null,
    );
    expect(digest.daysOverBudgetByCategory, isEmpty);
  });
}
