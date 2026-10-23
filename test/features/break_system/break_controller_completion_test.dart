import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    hide DailyStats;
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService;

class _Settings extends SettingsRepository {
  final SettingsModel _s;
  _Settings(this._s) : super(storage: FakeStorageService());
  @override
  SettingsModel get currentSettings => _s;
}

class _Meeting extends MeetingDetectionService {
  bool active = false;
  @override
  bool get isMeetingActive => active;
}

class _Presentation extends PresentationDetectionService {
  bool presenting = false;
  _Presentation() : super(displayManager: DisplayManager());
  @override
  bool get isPresenting => presenting;
}

class _Stats extends StatsService {
  int wellnessActions = 0;
  _Stats() : super(storage: FakeStorageService());
  @override
  void recordWellnessAction() => wellnessActions++;
}

void main() {
  late _Meeting meeting;
  late _Presentation presentation;
  late _Stats stats;
  late int chimes;

  BreakController build(SettingsModel settings) {
    final repo = _Settings(settings);
    final engine = TimerEngine(
      settingsRepository: repo,
      meetingDetectionService: meeting,
      presentationDetectionService: presentation,
      eventBus: EventBus.instance,
    );
    return BreakController(
      timerEngine: engine,
      settingsRepo: repo,
      statsService: stats,
    )..onChime = () async => chimes++;
  }

  setUp(() {
    meeting = _Meeting();
    presentation = _Presentation();
    stats = _Stats();
    chimes = 0;
  });

  group('completion chime', () {
    test('plays when enabled', () async {
      final c = build(const SettingsModel(breakChimeEnabled: true));
      await c.completeCurrentBreak();
      expect(chimes, 1);
    });

    test('is off by default', () async {
      final c = build(const SettingsModel());
      await c.completeCurrentBreak();
      expect(chimes, 0);
    });

    test('stays silent during a meeting', () async {
      meeting.active = true;
      final c = build(
        const SettingsModel(breakChimeEnabled: true, detectMeetings: true),
      );
      await c.completeCurrentBreak();
      expect(chimes, 0);
    });

    test('stays silent while presenting', () async {
      presentation.presenting = true;
      final c = build(
        const SettingsModel(
          breakChimeEnabled: true,
          presentationPauseEnabled: true,
        ),
      );
      await c.completeCurrentBreak();
      expect(chimes, 0);
    });
  });

  group('looked-away confirmation', () {
    test('counts as one wellness action', () async {
      final c = build(const SettingsModel());
      await c.completeCurrentBreak(lookedAway: true);
      expect(stats.wellnessActions, 1);
    });

    test('a plain completion counts none', () async {
      final c = build(const SettingsModel());
      await c.completeCurrentBreak();
      expect(stats.wellnessActions, 0);
    });
  });
}
