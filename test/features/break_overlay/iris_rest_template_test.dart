import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/iris_rest_template.dart';
import 'package:breakmate/core/services/storage_service.dart';

final sl = GetIt.instance;

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  int getInt(String key, {int defaultValue = 0}) => defaultValue;
  @override
  String getString(String key, {String defaultValue = ''}) => defaultValue;
  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
  @override
  double getDouble(String key, {double defaultValue = 0.0}) => defaultValue;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sl.allowReassignment = true;
    sl.registerSingleton<StatsService>(
      StatsService(storage: FakeStorageService()),
    );
  });

  const testBreakInfo = BreakModel(
    type: BreakType.short,
    durationSeconds: 20,
    title: 'Rest Your Eyes',
    tip: 'Look 20 feet away for 20 seconds.',
  );
  const testSettings = SettingsModel();

  testWidgets('shows the eye-break title, countdown, and streak graph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IrisRestTemplate(
            breakInfo: testBreakInfo,
            settings: testSettings,
            remainingSeconds: 19,
            totalSeconds: 20,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Rest Your Eyes'), findsOneWidget);
    expect(find.text('00:19'), findsOneWidget);
    expect(
      find.text("Break alert! Let's keep that streak going."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Skip when not in strict mode and onSkip is provided', (
    tester,
  ) async {
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IrisRestTemplate(
            breakInfo: testBreakInfo,
            settings: testSettings,
            remainingSeconds: 19,
            totalSeconds: 20,
            onSkip: () => skipped = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Skip'));
    expect(skipped, isTrue);
  });

  testWidgets('hides Skip in strict mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IrisRestTemplate(
            breakInfo: testBreakInfo,
            settings: const SettingsModel(strictMode: true),
            remainingSeconds: 19,
            totalSeconds: 20,
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Skip'), findsNothing);
  });
}
