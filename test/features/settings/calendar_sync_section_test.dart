import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/features/settings/presentation/sections/calendar_sync_section.dart';

import '../../helpers/fake_calendar_sync_controller.dart';

void main() {
  late FakeCalendarSyncController controller;

  setUp(() async {
    await sl.reset();
    controller = FakeCalendarSyncController();
    sl.registerSingleton<CalendarSyncController>(controller);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CalendarSyncSection()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opening the screen triggers exactly one refresh', (t) async {
    await pump(t);
    expect(controller.refreshCalls, 1);
  });

  testWidgets('disconnected: offers Connect only', (t) async {
    await pump(t);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsNothing);
  });

  testWidgets('connected: sync now and disconnect available', (t) async {
    controller.fakeState = CalendarConnectionState.connected;
    await pump(t);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('blocked: sends the user to System Settings', (t) async {
    controller
      ..fakeState = CalendarConnectionState.permissionBlocked
      ..fakePermission = CalendarPermissionStatus.permanentlyDenied;
    await pump(t);
    expect(find.text('Calendar access blocked'), findsOneWidget);
    await t.tap(find.text('Open System Settings'));
    expect(controller.openSettingsCalls, 1);
    expect(find.text('Recheck'), findsOneWidget);
  });

  testWidgets('sync error is reported with a retry', (t) async {
    controller.fakeState = CalendarConnectionState.error;
    await pump(t);
    expect(find.textContaining('Couldn'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
  });

  testWidgets('checking state shows progress text, no actions', (t) async {
    controller.fakeState = CalendarConnectionState.checking;
    await pump(t);
    expect(find.text('Checking calendar access…'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('meeting preference is explained when not connected', (t) async {
    await pump(t);
    expect(find.text('Connect your calendar to use this.'), findsOneWidget);
  });
}
