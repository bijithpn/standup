import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/features/onboarding/presentation/onboarding_page.dart';
import 'package:breakmate/features/onboarding/presentation/first_break_demo.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import '../../helpers/in_memory_settings_repository.dart';

void main() {
  tearDown(() => sl.reset());

  testWidgets(
    'setup saves the selected goal and intensity only after finishing',
    (tester) async {
      tester.view.physicalSize = const Size(620, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = InMemorySettingsRepository();
      sl.registerSingleton<SettingsRepository>(repo);
      await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
      await tester.tap(find.text(AppStrings.continueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eye rest'));
      await tester.pumpAndSettle();
      expect(repo.currentSettings.hasCompletedOnboarding, isFalse);
      await tester.tap(find.text(AppStrings.continueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gentle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.continueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No Thanks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.continueButton));
      await tester.pumpAndSettle();
      expect(find.text('Try a 20-second demo'), findsOneWidget);
      await tester.tap(find.text('Try a 20-second demo'));
      await tester.pumpAndSettle();
      expect(find.text('20 seconds'), findsOneWidget);
      await tester.tap(find.text('End demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.getStarted));
      await tester.pumpAndSettle();
      expect(repo.currentSettings.hasCompletedOnboarding, isTrue);
      expect(repo.currentSettings.selectedProfileId, 'health');
      expect(repo.currentSettings.preBreakWarningSeconds, 30);
      expect(repo.currentSettings.soundEnabled, isFalse);
      expect(repo.currentSettings.companionEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'practice break completes and can close without waiting for timers',
    (tester) async {
      var now = DateTime(2026, 11, 16, 9);
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: FirstBreakDemo())),
        );
        now = now.add(const Duration(seconds: 20));
        await tester.pump(const Duration(seconds: 20));
        expect(
          find.text('Your first practice break is complete'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    },
  );
}
