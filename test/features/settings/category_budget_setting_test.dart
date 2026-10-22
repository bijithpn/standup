// test/features/settings/category_budget_setting_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/settings_model.dart';

void main() {
  test(
    'categoryDailyBudgetMinutes defaults to empty and copyWith overrides it',
    () {
      const settings = SettingsModel();
      expect(settings.categoryDailyBudgetMinutes, isEmpty);

      final updated = settings.copyWith(
        categoryDailyBudgetMinutes: const {'browsing': 120},
      );
      expect(updated.categoryDailyBudgetMinutes, {'browsing': 120});
      // copyWith with no arg preserves the existing value
      final unchanged = updated.copyWith();
      expect(unchanged.categoryDailyBudgetMinutes, {'browsing': 120});
    },
  );

  test('round-trips through toMap/fromMap', () {
    const settings = SettingsModel(
      categoryDailyBudgetMinutes: {'browsing': 90, 'coding': 300},
    );

    final restored = SettingsModel.fromMap(settings.toMap());

    expect(restored.categoryDailyBudgetMinutes, {
      'browsing': 90,
      'coding': 300,
    });
  });

  test('fromMap defaults to empty when absent', () {
    final restored = SettingsModel.fromMap(const {});
    expect(restored.categoryDailyBudgetMinutes, isEmpty);
  });
}
