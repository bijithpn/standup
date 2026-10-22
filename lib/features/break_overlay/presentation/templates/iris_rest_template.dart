import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/animated_nature_backdrop.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_activity_graph.dart';

class IrisRestTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const IrisRestTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<IrisRestTemplate> createState() => _IrisRestTemplateState();
}

class _IrisRestTemplateState extends State<IrisRestTemplate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Last (up to) 10 days of break history, oldest first, padded to at
  /// least 2 entries so [BreakActivityGraph] never divides by zero when
  /// history is thin (e.g. a brand-new install).
  List<DailyStats> _recentDays(List<DailyStats> weeklyData) {
    final recent = weeklyData.length > 10
        ? weeklyData.sublist(weeklyData.length - 10)
        : weeklyData;
    if (recent.length >= 2) return recent;
    final placeholder = DailyStats(
      date: '0000-00-00',
      breaksCompleted: 0,
      breaksSkipped: 0,
      usageMinutes: 0,
    );
    return [placeholder, ...recent];
  }

  Color _colorForDay(DailyStats day) {
    final total = day.breaksCompleted + day.breaksSkipped;
    if (total == 0) return BreakOverlayTheme.accentNature;
    final rate = day.breaksCompleted / total;
    if (rate >= 0.75) return const Color(0xFF4ADE80);
    if (rate >= 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<StatsService>(),
      builder: (context, _) {
        final recentDays = _recentDays(sl<StatsService>().stats.weeklyData);
        final dataPoints = recentDays.map((d) => d.breaksCompleted).toList();
        final pointColors = recentDays.map(_colorForDay).toList();

        return Stack(
          fit: StackFit.expand,
          children: [
            const AnimatedNatureBackdrop(
              baseColorTop: Color(0xFF0D1F16),
              baseColorBottom: Color(0xFF060B08),
              blobColors: [
                Color(0xFF2D6A4F),
                Color(0xFF74C69D),
                Color(0xFF1B4332),
              ],
            ),
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entrance,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _formatTime(widget.remainingSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: BreakOverlayTheme.timerFontSizeLg,
                              fontWeight: FontWeight.w200,
                              fontFamily: BreakOverlayTheme.fontFamily,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: -2,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 32),
                          Container(
                            width: 1,
                            height: 56,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 32),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Rest Your Eyes, Refresh Your Mind',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: BreakOverlayTheme.fontFamily,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gentle reminders to protect your vision '
                                  'and boost focus. Take a moment - your '
                                  'eyes deserve it.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontFamily: BreakOverlayTheme.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.35),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entrance,
                  curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BreakActivityGraph(
                        dataPoints: dataPoints,
                        pointColors: pointColors,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Break alert! Let's keep that streak going.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              left: BreakOverlayTheme.skipRight,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entrance,
                  curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                ),
                child: Text(
                  _formatTime(widget.totalSeconds),
                  style: TextStyle(
                    color: BreakOverlayTheme.textDim,
                    fontSize: BreakOverlayTheme.labelFontSize,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
              ),
            ),
            if (!widget.settings.strictMode && widget.onSkip != null)
              Positioned(
                bottom: BreakOverlayTheme.skipBottom,
                right: BreakOverlayTheme.skipRight,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entrance,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                  ),
                  child: GestureDetector(
                    onTap: widget.onSkip,
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
              ),
          ],
        );
      },
    );
  }
}
