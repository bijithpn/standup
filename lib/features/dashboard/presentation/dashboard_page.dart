import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final padding = isSmall ? 20.0 : 40.0;

        final content = SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(context),
                  const SizedBox(height: 40),
                  _buildTimerSection(context),
                  const SizedBox(height: 40),
                  _buildActionGrid(context),
                  const SizedBox(height: 40),
                  _buildSummarySection(context),
                ],
              ),
            ),
          ),
        );

        if (isSmall) {
          return Scaffold(
            backgroundColor: AppTheme.contentBackground,
            body: SafeArea(child: content),
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.contentBackground,
          toolBar: const ToolBar(
            title: Text(
              'Today',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            titleWidth: 260,
            actions: [],
          ),
          children: [
            ContentArea(builder: (context, scrollController) => content),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Here is how your focus sessions are looking today.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildTimerSection(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, child) {
        final engine = controller.timerEngine;
        final isRunning = engine.state == TimerState.running;
        final isPaused = engine.state == TimerState.paused;

        final duration = Duration(seconds: engine.countdownSeconds);
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

        String statusText = 'Ready to focus';
        if (isRunning) statusText = 'Focusing...';
        if (isPaused) statusText = 'Paused';
        if (engine.isPreBreak) statusText = 'Break coming up...';

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: AppTheme.cardDecoration(elevated: true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PrimaryButton(
                    onTap: () => controller.togglePause(),
                    label: isPaused ? 'Resume' : 'Pause',
                    icon: isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                  _SecondaryButton(
                    onTap: () => controller.takeBreakNow(),
                    label: 'Take Break Now',
                    icon: Icons.coffee_rounded,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'Companion',
            subtitle: 'Your desk buddy',
            icon: Icons.pets_rounded,
            onTap: () {
              // Action logic handled via provider if needed or navigate to Companion settings
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            title: 'Quiet Mode',
            subtitle: 'Pause distractions',
            icon: Icons.do_not_disturb_on_rounded,
            onTap: () {
              // Toggle quiet mode logic
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Consumer<StatsService>(
      builder: (context, statsService, child) {
        final stats = statsService.load();
        final todayStats = stats.weeklyData.isNotEmpty
            ? stats.weeklyData.last
            : null;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Activity",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Completed',
                    value: '${todayStats?.breaksCompleted ?? 0}',
                    color: AppTheme.success,
                  ),
                  _StatItem(
                    label: 'Skipped',
                    value: '${todayStats?.breaksSkipped ?? 0}',
                    color: AppTheme.error,
                  ),
                  _StatItem(
                    label: 'Focus Time (m)',
                    value: '${todayStats?.usageMinutes ?? 0}',
                    color: AppTheme.warning,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool isPrimary;

  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.accent : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary ? AppTheme.accent : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? Colors.white : AppTheme.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _SecondaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _PrimaryButton(
      onTap: onTap,
      label: label,
      icon: icon,
      isPrimary: false,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
