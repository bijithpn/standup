import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/privacy_section.dart';

void main() {
  setUp(() {
    if (!sl.isRegistered<AppTrackingService>()) {
      sl.registerLazySingleton<AppTrackingService>(() => AppTrackingService());
    }
    if (!sl.isRegistered<AppIconCache>()) {
      sl.registerLazySingleton<AppIconCache>(
        () => AppIconCache(appTracking: sl()),
      );
    }
  });

  tearDown(() async {
    await sl.reset();
  });

  /// The settings window is a desktop surface; the default test viewport is
  /// shorter than any real one.
  void useDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Switches tracking on and returns whatever was saved, if anything.
  Future<SettingsModel?> tapTrackingToggle(
    WidgetTester tester, {
    required bool startEnabled,
  }) async {
    useDesktopViewport(tester);
    SettingsModel? saved;
    final usageService = AppUsageService(storage: StorageService());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider<AppUsageService>.value(
              value: usageService,
              child: PrivacySection(
                settings: SettingsModel(appUsageTrackingEnabled: startEnabled),
                onSave: (updated) => saved = updated,
              ),
            ),
          ),
        ),
      ),
    );

    final switchFinder = find.byType(CupertinoSwitch).first;
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    return saved;
  }

  testWidgets('switching tracking on asks for consent before recording',
      (tester) async {
    final saved = await tapTrackingToggle(tester, startEnabled: false);

    // Nothing is recorded on the strength of a toggle alone.
    expect(saved, isNull);
    expect(find.text('Understand where your time goes'), findsOneWidget);
    expect(
      find.textContaining('Window titles, documents or messages'),
      findsOneWidget,
    );
  });

  testWidgets('accepting the explainer turns tracking on', (tester) async {
    useDesktopViewport(tester);
    SettingsModel? saved;
    final usageService = AppUsageService(storage: StorageService());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider<AppUsageService>.value(
              value: usageService,
              child: PrivacySection(
                settings: const SettingsModel(appUsageTrackingEnabled: false),
                onSave: (updated) => saved = updated,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(CupertinoSwitch).first);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start tracking'));
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.appUsageTrackingEnabled, isTrue);
  });

  testWidgets('declining leaves tracking off', (tester) async {
    useDesktopViewport(tester);
    SettingsModel? saved;
    final usageService = AppUsageService(storage: StorageService());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider<AppUsageService>.value(
              value: usageService,
              child: PrivacySection(
                settings: const SettingsModel(appUsageTrackingEnabled: false),
                onSave: (updated) => saved = updated,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(CupertinoSwitch).first);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(saved, isNull, reason: 'declining must change nothing');
  });

  testWidgets('switching tracking off needs no consent', (tester) async {
    final saved = await tapTrackingToggle(tester, startEnabled: true);

    expect(saved, isNotNull);
    expect(saved!.appUsageTrackingEnabled, isFalse);
  });
}
