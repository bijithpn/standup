import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/constants/app_strings.dart';

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
            backgroundColor: AppTheme.surface,
            body: SafeArea(child: content),
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.surface,
          toolBar: const ToolBar(
            title: Text(
              AppStrings.today,
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
          AppStrings.dashboardSubtitle,
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
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
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

        String statusText = AppStrings.readyToFocus;
        if (isRunning) statusText = AppStrings.focusing;
        if (isPaused) statusText = AppStrings.paused;
        if (engine.isPreBreak) statusText = AppStrings.breakComingUp;

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
                  Row(
                    children: [
                      if (isPaused)
                        _SnoozeButton(
                          onTap: () => controller.snooze(minutes: 15),
                          label: '+15m',
                        ),
                      const SizedBox(width: 8),
                      _PrimaryButton(
                        onTap: () => controller.togglePause(),
                        label: isPaused ? AppStrings.resume : AppStrings.pause,
                        icon: isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        isPrimary: true,
                        semanticsLabel: isPaused
                            ? 'Resume focus timer'
                            : 'Pause focus timer',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SecondaryButton(
                    onTap: () => controller.takeBreakNow(),
                    label: AppStrings.takeBreakNow,
                    icon: Icons.coffee_rounded,
                    semanticsLabel: 'Start break immediately',
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
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        return Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: AppStrings.companion,
                subtitle: controller.timerEngine.state == TimerState.running
                    ? 'Active and watching'
                    : 'Resting',
                icon: Icons.pets_rounded,
                isActive: controller.timerEngine.state == TimerState.running,
                onTap: () {
                  // Action logic
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                title: AppStrings.quietMode,
                subtitle: controller.quietModeEnabled
                    ? 'All alerts silenced'
                    : 'Notifications on',
                icon: Icons.do_not_disturb_on_rounded,
                isActive: controller.quietModeEnabled,
                onTap: () => controller.toggleQuietMode(),
                semanticsLabel: 'Toggle quiet mode',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Consumer<StatsService>(
      builder: (context, statsService, child) {
        final stats = statsService.load();
        final todayStats = stats.weeklyData.isNotEmpty
            ? stats.weeklyData.last
            : null;

        final hasData =
            todayStats != null &&
            (todayStats.breaksCompleted > 0 || todayStats.breaksSkipped > 0);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.todayActivity,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (hasData) _RecommendationChip(stats: stats),
                ],
              ),
              const SizedBox(height: 24),
              if (!hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      AppStrings.noActivityRecorded,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: AppStrings.completed,
                      value: '${todayStats.breaksCompleted}',
                      color: AppTheme.success,
                    ),
                    _StatItem(
                      label: AppStrings.skipped,
                      value: '${todayStats.breaksSkipped}',
                      color: AppTheme.error,
                    ),
                    _StatItem(
                      label: AppStrings.focusTimeMins,
                      value: '${todayStats.usageMinutes}',
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

class _RecommendationChip extends StatelessWidget {
  final StatsModel stats;
  const _RecommendationChip({required this.stats});

  @override
  Widget build(BuildContext context) {
    String recommendation = 'Keep it up!';
    if (stats.completionRate < 0.5 && stats.breaksCompleted > 2) {
      recommendation = 'High skips. Try a longer interval?';
    } else if (stats.dailyUsageMinutes > 120 && stats.wellnessScore < 40) {
      recommendation = 'Intense day. Take a long break?';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        recommendation,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final String? semanticsLabel;

  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      child: InkWell(
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
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _SnoozeButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final String? semanticsLabel;

  const _SecondaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _PrimaryButton(
      onTap: onTap,
      label: label,
      icon: icon,
      isPrimary: false,
      semanticsLabel: semanticsLabel,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? semanticsLabel;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isActive = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$title: $subtitle',
      button: true,
      child: InkWell(
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
                  color: isActive
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppTheme.accent : AppTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
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
