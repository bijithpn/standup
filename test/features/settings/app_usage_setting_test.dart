// test/features/settings/app_usage_setting_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/settings_model.dart';

void main() {
  test(
    'appUsageTrackingEnabled defaults to false and copyWith overrides it',
    () {
      const settings = SettingsModel();
      expect(settings.appUsageTrackingEnabled, isFalse);

      final updated = settings.copyWith(appUsageTrackingEnabled: true);
      expect(updated.appUsageTrackingEnabled, isTrue);
      // copyWith with no arg preserves the existing value
      final unchanged = updated.copyWith();
      expect(unchanged.appUsageTrackingEnabled, isTrue);
    },
  );
}
