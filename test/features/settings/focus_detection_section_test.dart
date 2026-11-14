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
    // Video calls and Presentation Pause remain — neither is a calendar switch.
    expect(find.byType(CupertinoSwitch), findsNWidgets(2));
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

  testWidgets('toggling a detector saves once', (tester) async {
    final saved = <SettingsModel>[];
    await pumpSection(tester, const SettingsModel(), saved.add);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pump();
    expect(saved.single.detectVideoCalls, isFalse);
  });

  testWidgets('Check again gives feedback without a Scaffold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: FocusDetectionSection(
            settings: SettingsModel(),
            onSave: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
    expect(find.text('Permissions checked'), findsNothing); // auto-cleared after 5s
  });
}

void _noop(SettingsModel _) {}
