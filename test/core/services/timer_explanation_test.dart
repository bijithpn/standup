// Coverage for the "why did BreakMate do that?" explain panel (plan doc
// Phase 2) — templated text over TimerContextManager's existing
// predicates, no AI call.
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/core/services/timer_explanation.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsRepository extends SettingsRepository {
  final SettingsModel _settings;
  FakeSettingsRepository(this._settings) : super(storage: FakeStorageService());

  @override
  SettingsModel get currentSettings => _settings;
}

class FakeTimerContextManager extends TimerContextManager {
  final bool smartPause;
  final bool withinHours;
  final bool presenting;
  final bool meeting;
  final bool highSwitch;
  final int switchCount;

  FakeTimerContextManager({
    required super.settingsRepository,
    this.smartPause = false,
    this.withinHours = true,
    this.presenting = false,
    this.meeting = false,
    this.highSwitch = false,
    this.switchCount = 0,
  });

  @override
  bool isSmartPauseActive() => smartPause;
  @override
  bool isWithinWorkingHours() => withinHours;
  @override
  bool isPresentationActive() => presenting;
  @override
  bool isMeetingActive() => meeting;
  @override
  bool isHighContextSwitchRate({DateTime? now}) => highSwitch;
  @override
  int recentContextSwitchCount({DateTime? now}) => switchCount;
}

void main() {
  group('buildTimerExplanation', () {
    test('a normally running timer has no reasons', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.running,
        contextManager: FakeTimerContextManager(settingsRepository: repo),
        settings: repo.currentSettings,
      );

      expect(explanation.stateSummary, 'Timer is running normally.');
      expect(explanation.reasons, isEmpty);
    });

    test('an active break is summarized directly', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.breakActive,
        contextManager: FakeTimerContextManager(settingsRepository: repo),
        settings: repo.currentSettings,
      );
      expect(explanation.stateSummary, 'A break is active right now.');
    });

    test('explains a presentation pause', () {
      final repo = FakeSettingsRepository(
        const SettingsModel(presentationPauseEnabled: true),
      );
      final explanation = buildTimerExplanation(
        timerState: TimerState.paused,
        contextManager: FakeTimerContextManager(
          settingsRepository: repo,
          smartPause: true,
          presenting: true,
        ),
        settings: repo.currentSettings,
      );

      expect(explanation.stateSummary, contains('smart-detection rule'));
      expect(
        explanation.reasons,
        contains(
          'A presentation or screen share is active, so the timer is paused.',
        ),
      );
    });

    test('a manual pause with no smart-pause reason is labeled manual', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.paused,
        contextManager: FakeTimerContextManager(settingsRepository: repo),
        settings: repo.currentSettings,
      );
      expect(explanation.stateSummary, 'Timer is manually paused.');
    });

    test('notes being outside working hours', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.idle,
        contextManager: FakeTimerContextManager(
          settingsRepository: repo,
          withinHours: false,
        ),
        settings: repo.currentSettings,
      );
      expect(
        explanation.reasons,
        contains("You're outside your configured working hours."),
      );
    });

    test('notes being in a meeting without implying the timer paused', () {
      final repo = FakeSettingsRepository(
        const SettingsModel(detectMeetings: true),
      );
      final explanation = buildTimerExplanation(
        timerState: TimerState.running,
        contextManager: FakeTimerContextManager(
          settingsRepository: repo,
          meeting: true,
        ),
        settings: repo.currentSettings,
      );
      expect(explanation.reasons, hasLength(1));
      expect(explanation.reasons.single, contains('meeting or video call'));
      expect(explanation.stateSummary, 'Timer is running normally.');
    });

    test('notes a high context-switch rate with the count', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.running,
        contextManager: FakeTimerContextManager(
          settingsRepository: repo,
          highSwitch: true,
          switchCount: 12,
        ),
        settings: repo.currentSettings,
      );
      expect(explanation.reasons.single, contains('12 times'));
    });

    test('lists only the smart features actually enabled', () {
      final repo = FakeSettingsRepository(
        const SettingsModel(
          detectMeetings: true,
          presentationPauseEnabled: false,
          detectVideoCalls: false,
          calendarEnabled: false,
          appUsageTrackingEnabled: false,
        ),
      );
      final explanation = buildTimerExplanation(
        timerState: TimerState.running,
        contextManager: FakeTimerContextManager(settingsRepository: repo),
        settings: repo.currentSettings,
      );
      expect(explanation.activeSmartFeatures, ['Meeting detection']);
    });

    test('windDown state is summarized directly', () {
      final repo = FakeSettingsRepository(const SettingsModel());
      final explanation = buildTimerExplanation(
        timerState: TimerState.windDown,
        contextManager: FakeTimerContextManager(settingsRepository: repo),
        settings: repo.currentSettings,
      );
      expect(explanation.stateSummary, 'Timer is winding down for the day.');
    });
  });
}
