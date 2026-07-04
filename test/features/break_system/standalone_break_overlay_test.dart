import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
