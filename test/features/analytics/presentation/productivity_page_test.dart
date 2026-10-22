import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/features/analytics/presentation/productivity/activity_timeline_view.dart';
import 'package:breakmate/features/analytics/presentation/productivity/application_usage_section.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_page.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository settings;

  setUp(() {
    settings = MockSettingsRepository();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool trackingEnabled,
    ProductivityRepository? repository,
  }) async {
    when(() => settings.currentSettings).thenReturn(
      SettingsModel(appUsageTrackingEnabled: trackingEnabled),
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductivityPage(
          repository: repository,
          settingsRepository: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('empty states', () {
    testWidgets('offers to turn tracking on when it is off', (tester) async {
      await pumpPage(tester, trackingEnabled: false);

      expect(find.text('Activity tracking is off'), findsOneWidget);
      expect(find.text('Turn on activity tracking'), findsOneWidget);
      expect(
        find.textContaining('private content is never read'),
        findsOneWidget,
        reason: 'the privacy promise belongs where consent is asked for',
      );
    });

    testWidgets('says it is still learning when tracking is on but new',
        (tester) async {
      await pumpPage(tester, trackingEnabled: true);

      expect(find.text('Building your productivity picture'), findsOneWidget);
      expect(
        find.byType(ActivityTimelineView),
        findsNothing,
        reason: 'an empty chart is worse than saying there is no data',
      );
      expect(find.byType(ApplicationUsageList), findsNothing);
    });

    testWidgets('never shows invented numbers before there is data',
        (tester) async {
      await pumpPage(tester, trackingEnabled: true);

      expect(find.byType(ProductivityOverviewCard), findsNothing);
      expect(find.text('0h 0m'), findsNothing);
    });
  });

  group('header', () {
    testWidgets('names itself and offers the three ranges', (tester) async {
      await pumpPage(tester, trackingEnabled: true);

      expect(find.text('Productivity'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
    });
  });

  group('insight cards', () {
    Widget wrapCard(ProductivityInsight insight) => MaterialApp(
          home: Scaffold(body: InsightCard(insight: insight)),
        );

    testWidgets('a confident finding is stated plainly', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const ProductivityInsight(
            id: 'x',
            type: InsightType.focusWindow,
            title: 'Your busiest hours',
            description: 'Most of your active time falls between 9am–12pm.',
            confidence: InsightConfidence.high,
            evidenceDayCount: 9,
          ),
        ),
      );

      expect(find.text('Your busiest hours'), findsOneWidget);
      expect(find.textContaining('Based on'), findsNothing);
    });

    testWidgets('a thin finding announces itself as a possibility',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const ProductivityInsight(
            id: 'x',
            type: InsightType.focusWindow,
            title: 'Your busiest hours',
            description: 'Your active time so far leans toward 9am–12pm.',
            confidence: InsightConfidence.low,
            evidenceDayCount: 2,
          ),
        ),
      );

      expect(
        find.text('Possible pattern'),
        findsOneWidget,
        reason: 'a skimmed heading must not read as a fact',
      );
      expect(find.text('Based on 2 days of activity.'), findsOneWidget);
    });

    testWidgets('a medium finding still carries its evidence', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const ProductivityInsight(
            id: 'x',
            type: InsightType.breakPattern,
            title: 'Break rhythm',
            description: 'You average 40m of breaks a day.',
            confidence: InsightConfidence.medium,
            evidenceDayCount: 5,
          ),
        ),
      );

      expect(find.text('Break rhythm'), findsOneWidget);
      expect(find.text('Based on 5 days of activity.'), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('says so plainly when a day has nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivityTimelineView(entries: <TimelineEntry>[]),
          ),
        ),
      );

      expect(find.text('No activity recorded for this day'), findsOneWidget);
    });
  });
}
