import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/feedback/timing_suggestion.dart';
import 'package:breakmate/features/feedback/timing_suggestion_dialog.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import '../../helpers/in_memory_settings_repository.dart';

void main() {
  test(
    'suggestions preserve unrelated settings and never shorten long intervals below short',
    () {
      const initial = SettingsModel(
        shortBreakIntervalMinutes: 30,
        longBreakIntervalMinutes: 32,
        shortBreakDurationSeconds: 45,
      );
      final proposal = TimingSuggestion.tooFrequent(initial)!;
      expect(initial.shortBreakIntervalMinutes, 30);
      final updated = proposal.apply(initial.copyWith(soundEnabled: false));
      expect(updated.shortBreakIntervalMinutes, 35);
      expect(updated.longBreakIntervalMinutes, 35);
      expect(updated.shortBreakDurationSeconds, 45);
      expect(updated.soundEnabled, isFalse);
      expect(updated.selectedProfileId, 'custom');
      expect(
        TimingSuggestion.tooFrequent(
          const SettingsModel(shortBreakIntervalMinutes: 180),
        ),
        isNull,
      );
      expect(
        TimingSuggestion.badTiming(
          const SettingsModel(preBreakWarningSeconds: 30),
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'feedback applies only on acceptance and keeps a concurrent unrelated edit',
    (tester) async {
      final repository = InMemorySettingsRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTimingSuggestion(
                  context,
                  TimingSuggestion.tooFrequent(repository.currentSettings),
                  currentSettings: () => repository.currentSettings,
                  onApply: repository.save,
                ),
                child: const Text('Feedback'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep current settings'));
      await tester.pumpAndSettle();
      expect(repository.currentSettings.shortBreakIntervalMinutes, 20);
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      await repository.save(
        repository.currentSettings.copyWith(soundEnabled: false),
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.currentSettings.shortBreakIntervalMinutes, 25);
      expect(repository.currentSettings.soundEnabled, isFalse);
    },
  );
  testWidgets('a failed save keeps the proposal open for retry', (
    tester,
  ) async {
    const settings = SettingsModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTimingSuggestion(
                context,
                TimingSuggestion.badTiming(settings),
                currentSettings: () => settings,
                onApply: (_) async => throw StateError('Storage unavailable'),
              ),
              child: const Text('Feedback'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save this change. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Apply'), findsOneWidget);
  });
}
