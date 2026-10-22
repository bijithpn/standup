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

  test(
    'includes the worst over-budget category in both message and markdown',
    () {
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

      expect(
        digest.toMessage(),
        contains('Browsing was over its daily budget 5/7 days.'),
      );
      final markdown = digest.toMarkdown(generatedAt: DateTime(2026, 9, 6));
      expect(markdown, contains('- **Browsing over budget:** 5/7 days'));
      expect(markdown, contains('- **Coding over budget:** 1/7 days'));
      // Sparse-data fallback shouldn't fire when budget data exists.
      expect(markdown, isNot(contains('Not much tracked data this week yet')));
    },
  );

  group('trend regression (§7.3)', () {
    test('adherenceDeltaPoints is null without a trailing average', () {
      const digest = WeeklyDigest(
        breakAdherenceRate: 0.9,
        breaksCompleted: 9,
        breaksSkipped: 1,
        topFocusCategory: null,
        longestDeepWorkSessionSeconds: 0,
        companionMilestoneLabel: null,
      );
      expect(digest.adherenceDeltaPoints, isNull);
      expect(digest.toMessage(), isNot(contains('points')));
    });

    test('notes a meaningfully worse week', () {
      const digest = WeeklyDigest(
        breakAdherenceRate: 0.5,
        breaksCompleted: 5,
        breaksSkipped: 5,
        topFocusCategory: null,
        longestDeepWorkSessionSeconds: 0,
        companionMilestoneLabel: null,
        trailingAverageAdherenceRate: 0.8,
      );
      expect(digest.adherenceDeltaPoints, closeTo(-30, 0.01));
      expect(digest.toMessage(), contains('30 points worse'));
      final markdown = digest.toMarkdown(generatedAt: DateTime(2026, 9, 6));
      expect(markdown, contains('- **Trend:**'));
      expect(markdown, contains('30 points worse'));
    });

    test('notes a meaningfully better week', () {
      const digest = WeeklyDigest(
        breakAdherenceRate: 0.9,
        breaksCompleted: 9,
        breaksSkipped: 1,
        topFocusCategory: null,
        longestDeepWorkSessionSeconds: 0,
        companionMilestoneLabel: null,
        trailingAverageAdherenceRate: 0.6,
      );
      expect(digest.toMessage(), contains('30 points better'));
    });

    test('stays quiet on a small, unremarkable swing', () {
      const digest = WeeklyDigest(
        breakAdherenceRate: 0.82,
        breaksCompleted: 8,
        breaksSkipped: 2,
        topFocusCategory: null,
        longestDeepWorkSessionSeconds: 0,
        companionMilestoneLabel: null,
        trailingAverageAdherenceRate: 0.78,
      );
      expect(digest.adherenceDeltaPoints, closeTo(4, 0.01));
      expect(digest.toMessage(), isNot(contains('points')));
    });
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
