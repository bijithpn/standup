import 'dart:async';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/services/error_toast_service.dart';

import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingBreakController extends Fake implements BreakController {
  final focusDurations = <int>[];
  final snoozeDurations = <int?>[];
  bool activeFocus = false;
  @override
  bool get isBreakActive => false;
  @override
  bool get isFocusSessionActive => activeFocus;
  @override
  void startFocusSession(int minutes) => focusDurations.add(minutes);
  @override
  void snooze({int? minutes}) => snoozeDurations.add(minutes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native duration picker works without an application window or navigator',
    () async {
      const channel = MethodChannel('com.breakmate/native_enhancements');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.arguments['isFocus'] == true ? 90 : 75;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(ErrorToastService.navigatorKey.currentContext, isNull);
      final breaks = RecordingBreakController();
      final controller = MenuBarController(breakController: breaks);
      await controller.handleAction('focus');
      await controller.handleAction('snooze');
      expect(calls.map((call) => call.method), [
        'showTrayDurationPicker',
        'showTrayDurationPicker',
      ]);
      expect(calls.first.arguments['isFocus'], isTrue);
      expect(calls.first.arguments['initialMinutes'], 25);
      expect(calls.last.arguments['isFocus'], isFalse);
      expect(calls.last.arguments['initialMinutes'], 15);
      for (final call in calls) {
        expect(call.arguments['theme'], {
          'background': AppTheme.surfaceElevated.toARGB32(),
          'surface': AppTheme.surfaceCard.toARGB32(),
          'border': AppTheme.border.toARGB32(),
          'foreground': AppTheme.textPrimary.toARGB32(),
          'secondary': AppTheme.textSecondary.toARGB32(),
          'accent': AppTheme.accent.toARGB32(),
          'onAccent': AppTheme.onAccent.toARGB32(),
          'isDark': AppTheme.activePreset.isDark,
        });
      }
      expect(breaks.focusDurations, [90]);
      expect(breaks.snoozeDurations, [75]);
    },
  );

  test(
    'native cancellation and errors leave timers unchanged and allow retry',
    () async {
      const channel = MethodChannel('com.breakmate/native_enhancements');
      var attempt = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            attempt++;
            if (attempt == 1) return null;
            if (attempt == 2) {
              throw PlatformException(code: 'PICKER_UNAVAILABLE');
            }
            return 60;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final breaks = RecordingBreakController();
      final controller = MenuBarController(breakController: breaks);
      await controller.handleAction('focus');
      await controller.handleAction('focus');
      expect(breaks.focusDurations, isEmpty);
      await controller.handleAction('focus');
      expect(breaks.focusDurations, [60]);
    },
  );

  test('focus and snooze use the chosen duration', () async {
    final breaks = RecordingBreakController();
    final controller = MenuBarController(
      breakController: breaks,
      durationPicker: (focus) async => focus ? 90 : 75,
    );
    await controller.handleAction('focus');
    await controller.handleAction('snooze');
    expect(breaks.focusDurations, [90]);
    expect(breaks.snoozeDurations, [75]);
  });

  test('cancel and invalid durations do not start a timer', () async {
    final breaks = RecordingBreakController();
    for (final minutes in [null, 0, -1, 1440]) {
      final controller = MenuBarController(
        breakController: breaks,
        durationPicker: (_) async => minutes,
      );
      await controller.handleAction('focus');
      await controller.handleAction('snooze');
    }
    expect(breaks.focusDurations, isEmpty);
    expect(breaks.snoozeDurations, isEmpty);
  });

  test(
    'repeated clicks share one picker and active focus is protected',
    () async {
      final breaks = RecordingBreakController();
      final choice = Completer<int?>();
      var opened = 0;
      final controller = MenuBarController(
        breakController: breaks,
        durationPicker: (_) {
          opened++;
          return choice.future;
        },
      );
      final first = controller.handleAction('focus');
      await controller.handleAction('focus');
      expect(opened, 1);
      breaks.activeFocus = true;
      choice.complete(25);
      await first;
      await controller.handleAction('snooze');
      expect(breaks.focusDurations, isEmpty);
      expect(breaks.snoozeDurations, isEmpty);
      expect(opened, 1);
    },
  );
}
