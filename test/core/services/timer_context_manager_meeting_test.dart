// Regression coverage for the meeting/video-call vs. timer-pause split:
// being in a meeting or video call must never auto-pause the work timer —
// it should only steer how break reminders are displayed (see
// TimerContextManager.isMeetingActive / BreakController._handleGlobalOverlays).
import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
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

/// A MeetingDetectionService whose active flag is fully test-controlled,
/// bypassing the native EventChannel bridge entirely.
class FakeMeetingDetectionService extends MeetingDetectionService {
  bool active = false;

  @override
  bool get isMeetingActive => active;
}

void main() {
  test(
    'health reminders stay quiet through meetings and the post-call grace period',
    () {
      var now = DateTime(2026, 11, 13, 10);
      withClock(Clock(() => now), () {
        final meeting = FakeMeetingDetectionService();
        final context = TimerContextManager(
          settingsRepository: FakeSettingsRepository(
            const SettingsModel(detectMeetings: true),
          ),
          meetingDetectionService: meeting,
        );
        expect(context.shouldSuppressHealthReminders, isFalse);
        meeting.active = true;
        expect(context.shouldSuppressHealthReminders, isTrue);
        now = now.add(const Duration(minutes: 45));
        expect(context.shouldSuppressHealthReminders, isTrue);
        meeting.active = false;
        now = now.add(const Duration(seconds: 29));
        expect(context.shouldSuppressHealthReminders, isTrue);
        now = now.add(const Duration(seconds: 2));
        expect(context.shouldSuppressHealthReminders, isFalse);
      });
    },
  );
  test(
    'a background video call and presenting both suppress health reminders',
    () {
      final smart = SmartDetectionService()
        ..updateDetectionStatus(true, 'browser');
      final presentation = FakePresentationDetectionService();
      final context = TimerContextManager(
        settingsRepository: FakeSettingsRepository(
          const SettingsModel(detectVideoCalls: true),
        ),
        smartDetectionService: smart,
        presentationDetectionService: presentation,
      );
      expect(context.shouldSuppressHealthReminders, isTrue);
      smart.updateDetectionStatus(false, null);
      presentation.presenting = true;
      expect(context.shouldSuppressHealthReminders, isTrue);
      smart.dispose();
    },
  );

  group('meeting/video-call detection never pauses the work timer', () {
    test(
      'isMeetingActive true (calendar meeting) leaves isSmartPauseActive false',
      () {
        final settings = const SettingsModel(detectMeetings: true);
        final repo = FakeSettingsRepository(settings);
        final meetingService = FakeMeetingDetectionService()..active = true;

        final contextManager = TimerContextManager(
          settingsRepository: repo,
          meetingDetectionService: meetingService,
        );

        expect(contextManager.isMeetingActive(), isTrue);
        expect(contextManager.isSmartPauseActive(), isFalse);
        expect(contextManager.shouldRunWorkTimer(), isTrue);
      },
    );

    test(
      'isMeetingActive true (video call) leaves isSmartPauseActive false',
      () {
        final settings = const SettingsModel(detectVideoCalls: true);
        final repo = FakeSettingsRepository(settings);
        final smartDetection = SmartDetectionService()
          ..updateDetectionStatus(true, 'zoom.us');

        final contextManager = TimerContextManager(
          settingsRepository: repo,
          smartDetectionService: smartDetection,
        );

        expect(contextManager.isMeetingActive(), isTrue);
        expect(contextManager.isSmartPauseActive(), isFalse);
        expect(contextManager.shouldRunWorkTimer(), isTrue);
      },
    );

    test(
      'detectMeetings disabled means isMeetingActive is false even if the native signal is on',
      () {
        final settings = const SettingsModel(detectMeetings: false);
        final repo = FakeSettingsRepository(settings);
        final meetingService = FakeMeetingDetectionService()..active = true;

        final contextManager = TimerContextManager(
          settingsRepository: repo,
          meetingDetectionService: meetingService,
        );

        expect(contextManager.isMeetingActive(), isFalse);
      },
    );

    test(
      'switching apps (video call flapping on/off) never toggles isSmartPauseActive',
      () {
        final settings = const SettingsModel(detectVideoCalls: true);
        final repo = FakeSettingsRepository(settings);
        final smartDetection = SmartDetectionService();

        final contextManager = TimerContextManager(
          settingsRepository: repo,
          smartDetectionService: smartDetection,
        );

        // Simulate rapid app switching: meeting app frontmost, then not,
        // then frontmost again — none of this should ever report a pause.
        for (final active in [true, false, true, false, true]) {
          smartDetection.updateDetectionStatus(active, 'zoom.us');
          expect(contextManager.isSmartPauseActive(), isFalse);
          expect(contextManager.shouldRunWorkTimer(), isTrue);
        }
      },
    );

    test('presentation mode still auto-pauses when enabled', () {
      final presentationSettings = const SettingsModel(
        presentationPauseEnabled: true,
      );
      final presentationRepo = FakeSettingsRepository(presentationSettings);
      final presentationService = FakePresentationDetectionService()
        ..presenting = true;
      final presentationContext = TimerContextManager(
        settingsRepository: presentationRepo,
        presentationDetectionService: presentationService,
      );
      expect(presentationContext.isSmartPauseActive(), isTrue);
    });
  });
}

class FakePresentationDetectionService extends PresentationDetectionService {
  FakePresentationDetectionService() : super(displayManager: DisplayManager());

  bool presenting = false;

  @override
  bool get isPresenting => presenting;
}
