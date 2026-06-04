import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class HaikuCardTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const HaikuCardTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const _haikus = [
    [
      'Eyes need distance,',
      'the horizon waits —',
      'let the screen dissolve.',
    ],
    [
      'Shoulders drop. Breath slows.',
      'This moment is the only',
      'one that will ever be.',
    ],
    [
      'Step back from the glass.',
      'The world exists beyond it,',
      'wide and unhurried.',
    ],
    [
      'Blink. The tension fades.',
      'Your eyes have earned this rest —',
      'give them the far field.',
    ],
  ];

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final h = _haikus[DateTime.now().minute % 4];
    final isShort = breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in h)
                    Text(
                      line,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Inter',
                        fontStyle: FontStyle.italic,
                        height: 2.0,
                      ),
                    ),
                  const SizedBox(height: 28),
                  Container(
                    width: 40,
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _formatTime(remainingSeconds),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 42,
                      fontWeight: FontWeight.w200,
                      fontFamily: 'Inter',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    breakName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!settings.strictMode && onSkip != null)
            Positioned(
              bottom: 36,
              right: 40,
              child: GestureDetector(
                onTap: onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
