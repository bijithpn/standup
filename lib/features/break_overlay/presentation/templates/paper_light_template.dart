import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class PaperLightTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const PaperLightTemplate({
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
    const primary = Color(0xFF1A1814);
    const secondary = Color(0xFF6B6560);
    const accent = Color(0xFF2D6A4F);
    final isShort = breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';

    return ColoredBox(
      color: const Color(0xFFF5F3EE),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.leaf,
                    size: 20,
                    color: accent.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    breakName,
                    style: const TextStyle(
                      color: secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatTime(remainingSeconds),
                    style: const TextStyle(
                      color: primary,
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      fontFamily: 'Inter',
                      fontFeatures: [FontFeature.tabularFigures()],
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 0.5,
                    color: const Color(0xFFD4CFC9),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: Text(
                      breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                        height: 1.6,
                      ),
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
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 12,
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
