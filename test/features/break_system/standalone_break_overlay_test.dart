import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/objectbox.g.dart';
import 'package:get_it/get_it.dart';
import 'package:objectbox/objectbox.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/features/break_system/presentation/standalone_break_overlay.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    hide DailyStats;
import 'package:breakmate/core/services/storage_service.dart';

final sl = GetIt.instance;

class FakeStorageService implements StorageService {
  /// Activity history is not part of what these tests exercise.
  @override
  Box<ActivitySegment>? activitySegmentBox;

  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  String? activeDatabasePath;
  @override
  int? openDurationMs;
  @override
  int? initDurationMs;
  @override
  Store get store => throw UnimplementedError();
  @override
  Box<SettingsSnapshot>? settingsBox;
  @override
  Box<DailyStats>? dailyStatsBox;
  @override
  Box<GlobalStats>? globalStatsBox;
  @override
  Box<CompanionPreferences>? companionPreferencesBox;
  @override
  Box<KeyValueRecord>? kvBox;
  @override
  int get migrationDurationMs => 0;
  @override
  set migrationDurationMs(int val) {}
  @override
  Future<void> init() async {}
  @override
  void close() {}
  @override
  void diagnoseAndLogFailure(String storeDir) {}
  @override
  Future<void> diagnoseStorage(String storeDir) async {}
  @override
  Future<int> getDatabaseSize() async => 0;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  int getInt(String key, {int defaultValue = 0}) => defaultValue;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  String getString(String key, {String defaultValue = ''}) => defaultValue;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  double getDouble(String key, {double defaultValue = 0.0}) => defaultValue;
}

class FakeStatsService extends StatsService {
  int breaksCompleted = 0;
  FakeStatsService() : super(storage: FakeStorageService());

  @override
  void recordCompletedBreak() {}

  @override
  void recordSkippedBreak() {}

  @override
  void addUsageMinutes(int minutes) {}

  void updateBreaksCompleted(int count) {
    breaksCompleted = count;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannel desktopBridgeChannel = const MethodChannel(
    'com.breakmate.desktop/bridge',
  );
  final MethodChannel nativeBridgeChannel = const MethodChannel(
    'com.breakmate/native_bridge',
  );
  late FakeStatsService fakeStatsService;

  setUp(() {
    sl.allowReassignment = true;
    fakeStatsService = FakeStatsService();
    sl.registerSingleton<StatsService>(fakeStatsService);

    // Mock bridge channel calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(desktopBridgeChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getOverlayData') {
            return {
              'title': 'Test Focus Break',
              'tip': 'Relax your breathing.',
              'durationSeconds': 120,
              'remainingSeconds': 120,
              'strictMode': false,
              'enableAnimations': false,
              'breakTemplate': 'minimal',
              'breaksCompleted': 5,
            };
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeBridgeChannel, (
          MethodCall methodCall,
        ) async {
          return null;
        });
  });

  tearDown(() {
    sl.reset();
  });

  group('StandaloneBreakOverlay Widget Tests', () {
    testWidgets('renders basic overlay elements cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StandaloneBreakOverlay(
            title: 'Initial Title',
            message: 'Initial Message',
            initialDurationSeconds: 120,
          ),
        ),
      );

      // Let the initial frame and settings render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify template switcher renders
      expect(find.byType(StandaloneBreakOverlay), findsOneWidget);
    });

    testWidgets('skip button functions when dismissible', (
      WidgetTester tester,
    ) async {
      bool skipInvoked = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(desktopBridgeChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'skipBreak') {
              skipInvoked = true;
            }
            if (methodCall.method == 'getOverlayData') {
              return {
                'title': 'Test Focus Break',
                'tip': 'Relax your breathing.',
                'durationSeconds': 120,
                'remainingSeconds': 120,
                'strictMode': false,
                'enableAnimations': false,
                'breakTemplate': 'minimal',
                'breaksCompleted': 5,
              };
            }
            return null;
          });

      await tester.pumpWidget(
        const MaterialApp(
          home: StandaloneBreakOverlay(
            title: 'Initial Title',
            message: 'Initial Message',
            initialDurationSeconds: 120,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final skipBtnFinder = find.byTooltip('Skip break');
      expect(skipBtnFinder, findsOneWidget);

      await tester.tap(skipBtnFinder);
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 900)); // Wait for timer / animation

      // Skip action invokes native bridge skipBreak
      expect(skipInvoked, isTrue);
    });

    testWidgets(
      'a quickReminder with allowFullPoster never touches GetIt for '
      'services this isolate does not register (SettingsRepository, '
      'meeting/presentation detection) — regression for the black-screen '
      'crash where the poster reminder tried to look those up itself',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(desktopBridgeChannel, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'getOverlayData') {
                return {
                  'overlayType': 'quickReminder',
                  'reminderType': 'posture',
                  'allowFullPoster': true,
                  'durationSeconds': 2,
                  'remainingSeconds': 2,
                };
              }
              return null;
            });

        // Only StatsService is registered (setUp above) — exactly the
        // minimal set the real overlay isolate provides via `overlayMain()`.
        // SettingsRepository and the detection services are deliberately
        // left unregistered so any code path that reaches for them here
        // throws immediately, the same way it did in production.
        await tester.pumpWidget(
          const MaterialApp(home: StandaloneBreakOverlay()),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Watch your posture!'), findsOneWidget);

        // Let the reminder's own auto-dismiss timer
        // (AppConstants.healthReminderDismissDuration) run out so it
        // doesn't leak past the end of the test.
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'fades back in when reused for a new session after fading out — '
      'the native side now keeps this engine warm and reuses it instead '
      'of recreating it each time (see warmPool in '
      'MainFlutterWindow.swift), so this same widget instance can '
      'receive a second, unrelated updateOverlayData payload after '
      'already having faded to invisible once',
      (WidgetTester tester) async {
        Future<void> sendUpdate(Map<String, dynamic> data) async {
          final codedCall = const StandardMethodCodec().encodeMethodCall(
            MethodCall('updateOverlayData', data),
          );
          await TestDefaultBinaryMessengerBinding.instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                'com.breakmate.desktop/bridge',
                codedCall,
                (_) {},
              );
        }

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(desktopBridgeChannel, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'getOverlayData') {
                return {
                  'overlayType': 'quickReminder',
                  'reminderType': 'posture',
                  'allowFullPoster': true,
                  'durationSeconds': 2,
                  'remainingSeconds': 2,
                };
              }
              return null;
            });

        await tester.pumpWidget(
          const MaterialApp(home: StandaloneBreakOverlay()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Scoped to descend from StandaloneBreakOverlay itself — a bare
        // find.byType(FadeTransition).first would instead match
        // MaterialApp's own route-entry transition, which reaches 1.0 once
        // and stays there regardless of this widget's own fade state.
        FadeTransition fadeTransition() => tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(StandaloneBreakOverlay),
                matching: find.byType(FadeTransition),
              )
              .first,
        );

        // Fully faded in from the first session.
        await tester.pump(const Duration(seconds: 1));
        expect(fadeTransition().opacity.value, equals(1.0));

        // First session dismisses — fades out to invisible.
        await sendUpdate({
          'overlayType': 'quickReminder',
          'reminderType': 'posture',
          'allowFullPoster': true,
          'durationSeconds': 2,
          'remainingSeconds': 0,
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(fadeTransition().opacity.value, equals(0.0));

        // A second, unrelated session reuses the same (warm) engine —
        // must fade back in, not stay stuck invisible.
        await sendUpdate({
          'overlayType': 'quickReminder',
          'reminderType': 'eye',
          'allowFullPoster': true,
          'durationSeconds': 2,
          'remainingSeconds': 2,
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(fadeTransition().opacity.value, equals(1.0));
        expect(find.text('Rest your eyes!'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'shows nothing (not the full break-timer template) before the real '
      'bridge payload arrives — regression for a black/wrong-template '
      'flash: this window cannot know from local prefs alone whether it '
      'was opened as a quickReminder or a full break screen, so guessing '
      "'breakScreen' as a placeholder used to briefly show the wrong, "
      'heavy template every time',
      (WidgetTester tester) async {
        final bridgeResponse = Completer<Map<String, dynamic>>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(desktopBridgeChannel, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'getOverlayData') {
                return bridgeResponse.future;
              }
              return null;
            });

        await tester.pumpWidget(
          const MaterialApp(home: StandaloneBreakOverlay()),
        );
        await tester.pump();

        // No bridge response yet — must not have guessed the full
        // break-timer template (would render e.g. a countdown ring/time
        // text) or anything else; the window should be visually empty.
        expect(find.byType(Text), findsNothing);

        bridgeResponse.complete({
          'overlayType': 'quickReminder',
          'reminderType': 'posture',
          'allowFullPoster': true,
          'durationSeconds': 2,
          'remainingSeconds': 2,
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Watch your posture!'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'hides the skip affordance in strict mode for a real break screen',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(desktopBridgeChannel, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'getOverlayData') {
                return {
                  'overlayType': 'breakScreen',
                  'title': 'Strict Break',
                  'tip': 'No skipping.',
                  'durationSeconds': 120,
                  'remainingSeconds': 120,
                  'strictMode': true,
                  'enableAnimations': false,
                  'breakTemplate': 'minimal',
                  'breaksCompleted': 5,
                };
              }
              return null;
            });

        await tester.pumpWidget(
          const MaterialApp(home: StandaloneBreakOverlay()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byTooltip('Skip break'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tearing down the overlay mid-break (dispose) does not throw',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: StandaloneBreakOverlay(
              title: 'Initial Title',
              message: 'Initial Message',
              initialDurationSeconds: 120,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Let the countdown/animation controllers actually tick before the
        // widget (and its TickerProviderStateMixin controllers) get torn
        // down mid-flight — the regression this guards is a controller
        // disposed while still animating throwing on removal.
        await tester.pump(const Duration(seconds: 1));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
