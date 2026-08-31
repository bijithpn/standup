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
}
