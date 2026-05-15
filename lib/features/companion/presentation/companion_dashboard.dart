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
        
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Companion'),
              backgroundColor: Colors.transparent,
              border: null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainStatus(breakController, nextBreak),
                    const SizedBox(height: 32),
                    _buildAnalyticsGrid(stats),
                    const SizedBox(height: 32),
                    _buildTrendSection(),
                    const SizedBox(height: 32),
                    _buildWellnessSection(breakController),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainStatus(BreakController controller, Duration nextBreak) {
    final isPaused = controller.isPaused;
    final mins = nextBreak.inMinutes;
    final secs = (nextBreak.inSeconds % 60).toString().padLeft(2, '0');

    return AppTheme.glassContainer(
      hasGradient: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaused ? 'TIMER PAUSED' : 'DEEP FOCUS ACTIVE',
                    style: AppTheme.sectionTitle.copyWith(
                      color: isPaused ? AppTheme.upcomingBreakColor : AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPaused ? 'Resume to stay healthy' : 'Next break in $mins:$secs',
                    style: AppTheme.headerStyle.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ),
            _buildActionButton(
              icon: isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
              onTap: () => controller.togglePause(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid(StatsModel stats) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AppTheme.glassContainer(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
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
                        style: AppTheme.headerStyle.copyWith(fontSize: 56),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'pts',
                        style: AppTheme.sidebarItemStyle.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.productivityScore / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accentColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStat('STREAK', '${stats.currentStreak}d', CupertinoIcons.flame_fill, Colors.orange),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      height: 140,
      decoration: AppTheme.glassCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: AppTheme.headerStyle.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.sectionTitle.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection() {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PRODUCTIVITY TREND', style: AppTheme.sectionTitle),
                Icon(CupertinoIcons.info_circle, size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 160,
              child: ProductivityTrendChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessSection(BreakController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildWellnessCard(
            'Hydration',
            '4/8 cups',
            CupertinoIcons.drop_fill,
            Colors.cyan,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildWellnessCard(
            'Eye Care',
            'Good',
            CupertinoIcons.eye_fill,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessCard(String title, String status, IconData icon, Color color) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.sectionTitle.copyWith(fontSize: 9)),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 24),
        ),
      ),
    );
  }
}
