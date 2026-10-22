// test/features/analytics/app_usage_insights_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/app_usage_insights.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  group('usageTip', () {
    test('returns a non-empty tip for every category', () {
      for (final category in AppCategory.values) {
        final tip = usageTip(category, 90);
        expect(tip, isNotEmpty);
      }
    });

    test('browsing tip mentions the 20-20-20 rule', () {
      expect(usageTip(AppCategory.browsing, 120), contains('20-20-20'));
    });

    test('coding tip mentions posture', () {
      expect(usageTip(AppCategory.coding, 120).toLowerCase(), contains('posture'));
    });
  });

  group('categoriesOverBudget', () {
    test('returns nothing when no budgets are set', () {
      final result = categoriesOverBudget(
        todayCategorySeconds: {AppCategory.browsing: 999999},
        budgetMinutes: const {},
      );
      expect(result, isEmpty);
    });

    test('returns nothing when usage is under budget', () {
      final result = categoriesOverBudget(
        todayCategorySeconds: {AppCategory.browsing: 60 * 60}, // 60 min
        budgetMinutes: const {'browsing': 120},
      );
      expect(result, isEmpty);
    });

    test('flags a category once usage meets or exceeds its budget', () {
      final result = categoriesOverBudget(
        todayCategorySeconds: {AppCategory.browsing: 120 * 60}, // 120 min
        budgetMinutes: const {'browsing': 120},
      );
      expect(result, [AppCategory.browsing]);
    });

    test('a budget of 0 or less means no budget', () {
      final result = categoriesOverBudget(
        todayCategorySeconds: {AppCategory.browsing: 999999},
        budgetMinutes: const {'browsing': 0},
      );
      expect(result, isEmpty);
    });

    test('flags multiple categories independently', () {
      final result = categoriesOverBudget(
        todayCategorySeconds: {
          AppCategory.browsing: 200 * 60,
          AppCategory.coding: 30 * 60,
        },
        budgetMinutes: const {'browsing': 120, 'coding': 480},
      );
      expect(result, [AppCategory.browsing]);
    });
  });
}
