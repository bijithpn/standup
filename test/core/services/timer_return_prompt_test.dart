import 'package:breakmate/core/services/timer_return_prompt.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.breakmate/native_enhancements');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'native prompt receives the preserved countdown and maps each choice',
    () async {
      for (final (response, expected) in [
        ('continue', TimerReturnChoice.continueSession),
        ('restart', TimerReturnChoice.startOver),
        (null, null),
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'showTimerReturnPrompt');
              expect(call.arguments['remainingSeconds'], 317);
              expect(call.arguments['intervalMinutes'], 20);
              expect(
                call.arguments['theme']['accent'],
                AppTheme.accent.toARGB32(),
              );
              expect(
                call.arguments['theme']['background'],
                AppTheme.surfaceElevated.toARGB32(),
              );
              return response;
            });
        expect(
          await TimerReturnPrompt.show(
            const Duration(seconds: 317),
            const Duration(minutes: 20),
          ),
          expected,
        );
      }
    },
  );

  test('return dialog receives the selected theme and custom accent', () async {
    final previous = AppTheme.activePreset;
    final previousAccent = AppTheme.customAccent;
    addTearDown(
      () => AppTheme.applyPreset(previous, customAccent: previousAccent),
    );
    AppTheme.applyPreset(
      AppThemePreset.tokyoMidnight,
      customAccent: const Color(0xFFC084FC),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.arguments['theme'], {
            'background': AppTheme.surfaceElevated.toARGB32(),
            'surface': AppTheme.surfaceCard.toARGB32(),
            'border': AppTheme.border.toARGB32(),
            'foreground': AppTheme.textPrimary.toARGB32(),
            'secondary': AppTheme.textSecondary.toARGB32(),
            'accent': 0xFFC084FC,
            'onAccent': AppTheme.onAccent.toARGB32(),
            'isDark': true,
          });
          return 'continue';
        });
    expect(
      await TimerReturnPrompt.show(
        const Duration(seconds: 317),
        const Duration(minutes: 20),
      ),
      TimerReturnChoice.continueSession,
    );
  });
}
