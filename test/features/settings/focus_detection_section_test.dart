// Focus Detection no longer owns anything calendar-related: meeting detection
// from the calendar lives only on the Calendar Sync screen, and this section
// just links there. It must never save settings by itself.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/features/settings/presentation/sections/focus_detection_section.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService;

void main() {
  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpSection(
    WidgetTester tester,
    SettingsModel settings,
    ValueChanged<SettingsModel> onSave,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FocusDetectionSection(settings: settings, onSave: onSave),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('building the section never saves settings', (tester) async {
    var saves = 0;
    await pumpSection(
      tester,
      const SettingsModel(detectMeetings: false, calendarEnabled: false),
      (_) => saves++,
    );
    expect(saves, 0);
  });

  testWidgets('has no calendar permission controls of its own', (tester) async {
    await pumpSection(
      tester,
      const SettingsModel(detectMeetings: true, calendarEnabled: true),
      (_) {},
    );
    expect(find.text('Grant Access'), findsNothing);
    expect(find.text('Calendar access granted'), findsNothing);
    // Two switches remain: Focus Mode Detection, Presentation Pause plus the
    // video-call toggle — none of them is a calendar switch.
    expect(find.byType(CupertinoSwitch), findsNWidgets(3));
  });

  testWidgets('links to the single Calendar Sync screen', (tester) async {
    sl.registerSingleton<AppNavigationService>(
      AppNavigationService(FakeStorageService()),
    );
    await pumpSection(tester, const SettingsModel(), (_) {});

    await tester.tap(find.text('Open Calendar Sync'));
    await tester.pump();

    expect(sl<AppNavigationService>().selectedSection.value, 'Calendar Sync');
  });
}
