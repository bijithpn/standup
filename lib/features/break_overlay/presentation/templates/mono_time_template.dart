import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class MonoTimeTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MonoTimeTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';
    final accent = settings.clockFaceTextColorHex != 0xFFFFFFFF
        ? Color(settings.clockFaceTextColorHex)
        : const Color(0xFFB5CC7A);

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'break',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 12,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 2,
                      height: 88,
                      color: accent.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatTime(remainingSeconds),
                      style: TextStyle(
                        color: Color(settings.clockFaceTextColorHex),
                        fontSize: 80,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  breakName,
                  style: TextStyle(
                    color: BreakOverlayTheme.textMuted,
                    fontSize: BreakOverlayTheme.labelFontSize,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: Row(
              children: [
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                if (!settings.strictMode && onSkip != null)
                  GestureDetector(
                    onTap: onSkip,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: BreakOverlayTheme.textDim,
                          fontSize: BreakOverlayTheme.labelFontSize,
                          fontWeight: FontWeight.w400,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
