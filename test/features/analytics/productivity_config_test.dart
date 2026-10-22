import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/config/productivity_config.dart';

void main() {
  group('flavour configuration', () {
    test('production hides diagnostics and stays quiet', () {
      const config = ProductivityConfig.production;

      expect(config.diagnosticsVisible, isFalse);
      expect(config.verboseLogging, isFalse);
    });

    test('development differs only in what it exposes', () {
      const dev = ProductivityConfig.development;
      const prod = ProductivityConfig.production;

      // The behaviour under test must be the behaviour that ships, so the two
      // builds record and derive identically.
      expect(dev.enabled, prod.enabled);
      expect(dev.backgroundMonitoringEnabled, prod.backgroundMonitoringEnabled);
      expect(dev.insightsEnabled, prod.insightsEnabled);
      expect(dev.weeklyAnalyticsEnabled, prod.weeklyAnalyticsEnabled);

      expect(dev.diagnosticsVisible, isTrue);
      expect(dev.verboseLogging, isTrue);
    });

    test('falls back to the least-exposing config without a flavour', () {
      // Tests run without FlavorConfig initialised; the safe answer is the
      // one that shows least, not a crash.
      expect(ProductivityConfig.current.diagnosticsVisible, isFalse);
      expect(ProductivityConfig.current.enabled, isTrue);
    });

    test('the module can be switched off without deleting it', () {
      final disabled = ProductivityConfig.production.copyWith(enabled: false);

      expect(disabled.enabled, isFalse);
      expect(disabled.backgroundMonitoringEnabled, isTrue,
          reason: 'copyWith must change only what it was asked to');
    });
  });

  group('retention choices', () {
    test('defaults to the window app usage already kept', () {
      expect(ActivityRetention.defaultChoice, ActivityRetention.month);
      expect(ActivityRetention.defaultChoice.days, 30);
    });

    test('forever means no limit rather than a very large one', () {
      expect(ActivityRetention.forever.days, 0);
    });

    test('round-trips through days and labels', () {
      for (final option in ActivityRetention.values) {
        expect(ActivityRetention.fromDays(option.days), option);
        expect(ActivityRetention.fromLabel(option.label), option);
      }
    });

    test('an unrecognised value falls back to the default', () {
      expect(ActivityRetention.fromDays(13), ActivityRetention.defaultChoice);
      expect(ActivityRetention.fromLabel('nope'), ActivityRetention.defaultChoice);
    });
  });
}
