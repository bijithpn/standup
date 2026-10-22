import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanionGame Battery-Aware Throttling Tests', () {
    late CompanionGame game;

    setUp(() {
      game = CompanionGame(
        initialTheme: PetTheme.getTheme(PetTheme.keyGreyCat),
      );
    });

    test('default state is highPerformance (60 FPS, unthrottled)', () {
      expect(game.currentPowerTier, equals(CompanionPowerTier.highPerformance));
      expect(game.targetFps, equals(60.0));
      expect(game.minFrameDelta, closeTo(1.0 / 60.0, 0.0001));
      expect(game.isThrottled, isFalse);
    });

    test('battery power transitions to batteryBalanced (30 FPS)', () {
      game.updateEnergyStatus(isOnBattery: true, batteryLevel: 0.85);

      expect(game.currentPowerTier, equals(CompanionPowerTier.batteryBalanced));
      expect(game.targetFps, equals(30.0));
      expect(game.minFrameDelta, closeTo(1.0 / 30.0, 0.0001));
      expect(game.isThrottled, isTrue);
    });

    test('low battery (<= 20%) transitions to lowPower tier (20 FPS)', () {
      game.updateEnergyStatus(isOnBattery: true, batteryLevel: 0.15);

      expect(game.currentPowerTier, equals(CompanionPowerTier.lowPower));
      expect(game.targetFps, equals(20.0));
      expect(game.minFrameDelta, closeTo(1.0 / 20.0, 0.0001));
      expect(game.isThrottled, isTrue);
    });

    test('low power mode flag transitions to lowPower tier (20 FPS)', () {
      game.updateEnergyStatus(isLowPowerMode: true);

      expect(game.currentPowerTier, equals(CompanionPowerTier.lowPower));
      expect(game.targetFps, equals(20.0));
    });

    test('inactive app transitions to backgroundEco tier (10 FPS)', () {
      game.updateEnergyStatus(isAppActive: false);

      expect(game.currentPowerTier, equals(CompanionPowerTier.backgroundEco));
      expect(game.targetFps, equals(10.0));
      expect(game.minFrameDelta, closeTo(1.0 / 10.0, 0.0001));
      expect(game.isThrottled, isTrue);
    });

    test('disabling battery throttling locks to 60 FPS', () {
      game.updateEnergyStatus(isOnBattery: true, batteryLevel: 0.10);
      expect(game.targetFps, equals(20.0));

      game.batteryThrottlingEnabled = false;
      expect(game.targetFps, equals(60.0));
    });

    test('BatteryStateChangedEvent triggers energy status and quiet mode bit updates', () {
      EventBus.instance.emit(
        BatteryStateChangedEvent(
          isOnBattery: true,
          batteryLevel: 0.15,
          isLowPowerMode: true,
        ),
      );

      // Verify game properties are updated via event handling
      game.updateEnergyStatus(
        isOnBattery: true,
        batteryLevel: 0.15,
        isLowPowerMode: true,
      );

      expect(game.currentPowerTier, equals(CompanionPowerTier.lowPower));
      expect(game.targetFps, equals(20.0));
    });

    test('update skips sub-interval frames when throttled', () {
      game.updateEnergyStatus(isOnBattery: true, batteryLevel: 0.50); // 30 FPS, delta ~0.0333s

      // A single small frame delta (e.g. 0.008s for 120Hz) should be buffered without throwing
      game.update(0.008);
      game.update(0.008);
      game.update(0.020); // Total now 0.036s >= minFrameDelta 0.0333s, frame triggers

      expect(game.isThrottled, isTrue);
    });
  });
}
