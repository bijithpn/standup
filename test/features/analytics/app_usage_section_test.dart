import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/widgets/app_usage_section.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  final iconCache = AppIconCache(appTracking: AppTrackingService());

  Map<AppCategory, int> emptyCategoryTotals() => {
    for (final c in AppCategory.values) c: 0,
  };

  testWidgets('disabled state shows an Enable button that calls onEnable', (
    tester,
  ) async {
    var enabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUsageSection(
            enabled: false,
            topApps: const [],
            categoryTotals: emptyCategoryTotals(),
            iconCache: iconCache,
            onEnable: () => enabled = true,
          ),
        ),
      ),
    );

    expect(find.text('Enable'), findsOneWidget);
    await tester.tap(find.text('Enable'));
    expect(enabled, isTrue);
  });

  testWidgets('enabled with no data shows the empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUsageSection(
            enabled: true,
            topApps: const [],
            categoryTotals: emptyCategoryTotals(),
            iconCache: iconCache,
            onEnable: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('gathering data'), findsOneWidget);
  });

  testWidgets('enabled with data renders top apps and a tip', (tester) async {
    final totals = emptyCategoryTotals();
    totals[AppCategory.browsing] = 3600;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUsageSection(
            enabled: true,
            topApps: const [
              AppUsageEntry(
                appKey: 'com.google.chrome',
                name: 'Chrome',
                category: AppCategory.browsing,
                seconds: 3600,
              ),
            ],
            categoryTotals: totals,
            iconCache: iconCache,
            onEnable: () {},
          ),
        ),
      ),
    );

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('1h 0m'), findsOneWidget);
    expect(find.textContaining('20-20-20'), findsOneWidget);
  });
}
