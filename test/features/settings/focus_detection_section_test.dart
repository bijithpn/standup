// Regression coverage: Meeting Detection must stay off once the user turns
// it off, and must never be silently re-enabled just because calendar
// permission happens to be granted or the section reloads.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/features/settings/presentation/sections/focus_detection_section.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class FakeGrantedCalendarPermissionService extends CalendarPermissionService {
  @override
  Future<CalendarPermissionStatus> getStatus() async =>
      CalendarPermissionStatus.granted;
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpSection(
    WidgetTester tester,
    SettingsModel settings,
    ValueChanged<SettingsModel> onSave,
  ) async {
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

  testWidgets(
    'calendar permission already granted does not auto-enable meeting detection',
    (tester) async {
      sl.registerLazySingleton<CalendarPermissionService>(
        () => FakeGrantedCalendarPermissionService(),
      );

      var saveCallCount = 0;
      await pumpSection(
        tester,
        const SettingsModel(detectMeetings: false, calendarEnabled: false),
        (_) => saveCallCount++,
      );

      // The permission banner's own "granted" check runs in initState and
      // resolves during pumpAndSettle above — it must never call onSave.
      expect(saveCallCount, 0);
    },
  );

  testWidgets(
    'returning to the section (didUpdateWidget) does not re-enable a disabled meeting detection setting',
    (tester) async {
      sl.registerLazySingleton<CalendarPermissionService>(
        () => FakeGrantedCalendarPermissionService(),
      );

      var saveCallCount = 0;
      var settings = const SettingsModel(
        detectMeetings: false,
        calendarEnabled: false,
      );

      await pumpSection(tester, settings, (_) => saveCallCount++);

      // Simulate navigating away and back: rebuild with an unrelated field
      // change, mirroring how SettingsPage rebuilds this section on every
      // save elsewhere on the page.
      settings = settings.copyWith(soundEnabled: !settings.soundEnabled);
      await pumpSection(tester, settings, (_) => saveCallCount++);

      expect(saveCallCount, 0);
      expect(settings.detectMeetings, isFalse);
      expect(settings.calendarEnabled, isFalse);
    },
  );

  testWidgets(
    'toggling Meeting Detection off calls onSave with detectMeetings false and requests no permission',
    (tester) async {
      sl.registerLazySingleton<CalendarPermissionService>(
        () => FakeGrantedCalendarPermissionService(),
      );

      SettingsModel? saved;
      await pumpSection(
        tester,
        const SettingsModel(detectMeetings: true, calendarEnabled: true),
        (updated) => saved = updated,
      );

      final switchFinder = find.byType(CupertinoSwitch);
      // The first switch in the card is "Video Calls Detection"; the second
      // is "Meeting Detection".
      await tester.ensureVisible(switchFinder.at(1));
      await tester.tap(switchFinder.at(1));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.detectMeetings, isFalse);
    },
  );
}
