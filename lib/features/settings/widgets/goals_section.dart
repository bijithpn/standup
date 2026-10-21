import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsRepository>(
      builder: (context, repo, child) {
        final s = repo.currentSettings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'Personal Goals',
              subtitle: 'Set daily and weekly targets for your wellbeing.',
            ),
            const SizedBox(height: 4),

            _GoalCard(
              icon: CupertinoIcons.timer,
              iconColor: AppTheme.info,
              title: 'Daily Focus Goal',
              description: 'How much focused work you aim to log each day.',
              value: s.dailyWorkGoalHours.toDouble(),
              min: 1,
              max: 12,
              valueLabel: '${s.dailyWorkGoalHours}h',
              progress: (s.dailyWorkGoalHours - 1) / (12 - 1),
              onChanged: (val) =>
                  repo.save(s.copyWith(dailyWorkGoalHours: val.round())),
            ),
            const SizedBox(height: 12),
            _GoalCard(
              icon: CupertinoIcons.leaf_arrow_circlepath,
              iconColor: AppTheme.success,
              title: 'Daily Break Goal',
              description: 'Number of breaks to take every day to recharge.',
              value: s.dailyBreakGoalCount.toDouble(),
              min: 1,
              max: 30,
              valueLabel: '${s.dailyBreakGoalCount}',
              progress: (s.dailyBreakGoalCount - 1) / (30 - 1),
              onChanged: (val) =>
                  repo.save(s.copyWith(dailyBreakGoalCount: val.round())),
            ),
            const SizedBox(height: 12),
            _GoalCard(
              icon: CupertinoIcons.person_alt,
              iconColor: AppTheme.warning,
              title: 'Sitting Limit',
              description: 'Get nudged to move after sitting this long.',
              value: s.maxContinuousSittingMinutes.toDouble(),
              min: 20,
              max: 120,
              valueLabel: '${s.maxContinuousSittingMinutes}m',
              progress: (s.maxContinuousSittingMinutes - 20) / (120 - 20),
              onChanged: (val) => repo.save(
                s.copyWith(maxContinuousSittingMinutes: val.round()),
              ),
            ),
            const SizedBox(height: 12),
            _GoalCard(
              icon: CupertinoIcons.calendar,
              iconColor: AppTheme.longBreak,
              title: 'Weekly Consistency',
              description: 'Active days per week you\'re aiming for.',
              value: s.weeklyConsistencyTargetDays.toDouble(),
              min: 1,
              max: 7,
              valueLabel:
                  '${s.weeklyConsistencyTargetDays} day${s.weeklyConsistencyTargetDays == 1 ? '' : 's'}',
              progress: (s.weeklyConsistencyTargetDays - 1) / (7 - 1),
              onChanged: (val) => repo.save(
                s.copyWith(weeklyConsistencyTargetDays: val.round()),
              ),
            ),

            const SizedBox(height: 28),
            sectionHeader(
              'Calendar Integration',
              subtitle: 'Automatically pause breaks during your meetings.',
            ),
            const SizedBox(height: 16),
            buildCard([
              toggleRow(
                'Enable Calendar Sync',
                'Check for upcoming meetings to avoid interruptions.',
                s.calendarEnabled,
                (val) {
                  repo.save(s.copyWith(calendarEnabled: val));
                },
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final double progress;
  final ValueChanged<double> onChanged;

  const _GoalCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.progress,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 24,
            child: _GoalSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: iconColor,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A slightly heavier-weight slider than [MinimalSlider] with a filled
/// track and a color that matches the goal it controls, so each card
/// reads as its own self-contained control at a glance.
class _GoalSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _GoalSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  State<_GoalSlider> createState() => _GoalSliderState();
}

class _GoalSliderState extends State<_GoalSlider> {
  bool _isHovering = false;
  bool _isDragging = false;

  void _updateValue(Offset localPosition, double width) {
    if (width <= 0) return;
    final percent = (localPosition.dx / width).clamp(0.0, 1.0);
    widget.onChanged(widget.min + (widget.max - widget.min) * percent);
  }

  @override
  Widget build(BuildContext context) {
    final percent =
        ((widget.value - widget.min) / (widget.max - widget.min)).clamp(
          0.0,
          1.0,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              setState(() => _isDragging = true);
              _updateValue(d.localPosition, width);
            },
            onPanUpdate: (d) => _updateValue(d.localPosition, width),
            onPanEnd: (_) => setState(() => _isDragging = false),
            onPanCancel: () => setState(() => _isDragging = false),
            onTapDown: (d) => _updateValue(d.localPosition, width),
            child: Center(
              child: SizedBox(
                height: 6,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.activeColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (width * percent) - 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        width: _isHovering || _isDragging ? 18 : 16,
                        height: _isHovering || _isDragging ? 18 : 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.activeColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
