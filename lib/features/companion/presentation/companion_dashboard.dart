import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/analytics/stats_model.dart';
import 'package:standup/features/analytics/presentation/widgets/productivity_trend_chart.dart';
import 'package:standup/shared/theme/app_theme.dart';

class CompanionDashboard extends StatelessWidget {

  const CompanionDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BreakController, StatsService>(
      builder: (context, breakController, statsService, _) {
        final stats = statsService.load();
        final nextBreak = breakController.timerEngine.timeUntilNextShortBreak;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 750;
            final horizontalPadding = isNarrow ? 16.0 : 32.0;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (!isNarrow)
                  CupertinoSliverNavigationBar(
                    largeTitle: Text(
                      'Companion',
                      style: AppTheme.headerStyle.copyWith(fontSize: 32),
                    ),
                    backgroundColor: Colors.transparent,
                    border: null,
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isNarrow ? 16 : 0,
                    horizontalPadding,
                    isNarrow ? 32 : 48,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildMainStatus(breakController, nextBreak, isNarrow),
                      const SizedBox(height: 32),
                      _buildAnalyticsGrid(stats, isNarrow),
                      const SizedBox(height: 32),
                      _buildTrendSection(isNarrow),
                      const SizedBox(height: 32),
                      _buildWellnessSection(breakController, isNarrow),
                    ]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainStatus(BreakController controller, Duration nextBreak, bool isNarrow) {
    final isPaused = controller.isPaused;
    final mins = nextBreak.inMinutes;
    final secs = (nextBreak.inSeconds % 60).toString().padLeft(2, '0');

    return AppTheme.glassContainer(
      hasGradient: true,
      opacity: 0.5,
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 20.0 : 32.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaused ? AppTheme.upcomingBreakColor : AppTheme.accentColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaused ? 'TIMER PAUSED' : 'DEEP FOCUS ACTIVE',
                      style: AppTheme.sectionTitle.copyWith(
                        color: isPaused ? AppTheme.upcomingBreakColor : AppTheme.accentColor,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPaused ? 'Resume Session' : 'Next break in $mins:$secs',
                    style: AppTheme.headerStyle.copyWith(
                      fontSize: isNarrow ? 24 : 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildActionButton(
              icon: isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
              onTap: () => controller.togglePause(),
              size: isNarrow ? 48 : 64,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid(StatsModel stats, bool isNarrow) {
    final children = [
      Expanded(
        flex: isNarrow ? 0 : 2,
        child: AppTheme.glassContainer(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HEALTH SCORE', style: AppTheme.sectionTitle),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${stats.productivityScore}',
                      style: AppTheme.headerStyle.copyWith(
                        fontSize: isNarrow ? 48 : 64,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'points',
                      style: AppTheme.subHeaderStyle.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: stats.productivityScore / 100,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentColor, Color(0xFF64D2FF)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 20 : 0),
      Expanded(
        flex: isNarrow ? 0 : 1,
        child: _buildMiniStat('STREAK', '${stats.currentStreak}d', CupertinoIcons.flame_fill, const Color(0xFFFF9F0A)),
      ),
    ];

    return isNarrow 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children.map((e) => e is Expanded ? e.child : e).toList(),
          )
        : Row(children: children);
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: AppTheme.headerStyle.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.sectionTitle.copyWith(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection(bool isNarrow) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PRODUCTIVITY TREND', style: AppTheme.sectionTitle),
                Icon(CupertinoIcons.ellipsis_vertical, size: 14, color: AppTheme.textMuted),
              ],
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isNarrow ? 140 : 180,
              ),
              child: const ProductivityTrendChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessSection(BreakController controller, bool isNarrow) {
    final children = [
      Expanded(
        child: _buildWellnessCard(
          'Hydration',
          '4/8 cups',
          CupertinoIcons.drop_fill,
          const Color(0xFF64D2FF),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: _buildWellnessCard(
          'Eye Care',
          'Good',
          CupertinoIcons.eye_fill,
          const Color(0xFF32D74B),
        ),
      ),
    ];

    if (isNarrow) {
      return Column(
        children: [
          _buildWellnessCard('Hydration', '4/8 cups', CupertinoIcons.drop_fill, const Color(0xFF64D2FF)),
          const SizedBox(height: 16),
          _buildWellnessCard('Eye Care', 'Good', CupertinoIcons.eye_fill, const Color(0xFF32D74B)),
        ],
      );
    }

    return Row(children: children);
  }

  Widget _buildWellnessCard(String title, String status, IconData icon, Color color) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.sectionTitle.copyWith(fontSize: 10, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(status, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap, double size = 56}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: size * 0.4),
          ),
        ),
      ),
    );
  }
}
