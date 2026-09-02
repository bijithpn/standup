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

  testWidgets('toggling app usage tracking calls onSave with the new value', (tester) async {
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

    expect(find.text('Track App Usage'), findsOneWidget);

    final switchFinder = find.byType(CupertinoSwitch);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.appUsageTrackingEnabled, isTrue);
  });
}
