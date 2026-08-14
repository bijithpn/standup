import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class DayStackTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const DayStackTemplate({
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
    const accent = Color(0xFF93C5FD);

    return ListenableBuilder(
      listenable: sl<StatsService>(),
      builder: (context, _) {
        final stats = sl<StatsService>().stats;
        return ColoredBox(
          color: BreakOverlayTheme.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.breaksCompleted}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (stats.breaksCompleted / 8).clamp(0.0, 1.0),
                        minHeight: 1,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(accent),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formatTime(remainingSeconds),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          fontFamily: BreakOverlayTheme.fontFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        breakName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.33),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!settings.strictMode && onSkip != null)
                Positioned(
                  bottom: BreakOverlayTheme.skipBottom,
                  right: BreakOverlayTheme.skipRight,
                  child: GestureDetector(
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
                ),
            ],
          ),
        );
      },
    );
  }
}
