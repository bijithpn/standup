import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The small, repeated pieces of the Productivity screens.

/// A titled panel. Every section on the page sits in one of these.
class ProductivitySection extends StatelessWidget {
  const ProductivitySection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// The headline numbers for a day or a range, in plain words: how long you
/// worked, a sentence saying where the rest of the time went, and one bar that
/// splits it into working, breaks and being away.
class ProductivityOverviewCard extends StatelessWidget {
  const ProductivityOverviewCard({
    super.key,
    required this.activeSeconds,
    required this.idleSeconds,
    required this.breakSeconds,
    required this.contextSwitches,
    this.switchesPerHour,
    this.caption,
    this.focusGoalSeconds,
  });

  final int activeSeconds;
  final int idleSeconds;
  final int breakSeconds;
  final int contextSwitches;
  final double? switchesPerHour;

  /// Sits under the headline, e.g. "across 5 days".
  final String? caption;

  /// The day's focus goal in seconds; shows progress towards it when given.
  final int? focusGoalSeconds;

  /// "Steady focus", "Some switching", "A lot of switching".
  static String? switchingVerdict(double? perHour, int switches) {
    if (perHour == null || switches == 0) return null;
    if (perHour < 6) return 'Steady focus';
    if (perHour < 12) return 'Some app switching';
    return 'A lot of app switching';
  }

  /// One sentence for the whole period.
  static String summarySentence({
    required int activeSeconds,
    required int breakSeconds,
    required int idleSeconds,
  }) {
    final parts = <String>[
      'worked for ${formatDuration(activeSeconds)}',
      if (breakSeconds > 0) 'took ${formatDuration(breakSeconds)} of breaks',
      if (idleSeconds > 0) 'were away for ${formatDuration(idleSeconds)}',
    ];
    if (activeSeconds <= 0) return 'No active time recorded yet.';
    final last = parts.removeLast();
    final joined = parts.isEmpty ? last : '${parts.join(', ')} and $last';
    return 'You $joined.';
  }

  @override
  Widget build(BuildContext context) {
    final total = activeSeconds + breakSeconds + idleSeconds;
    final goal = focusGoalSeconds;
    final goalRatio = goal == null || goal <= 0
        ? null
        : (activeSeconds / goal).clamp(0.0, 1.0);
    final verdict = switchingVerdict(switchesPerHour, contextSwitches);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppTheme.accent.withValues(alpha: 0.10),
            AppTheme.surfaceCard,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                formatDuration(activeSeconds),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'active',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (goal != null && goalRatio != null)
                _GoalPill(
                  reached: activeSeconds >= goal,
                  label: activeSeconds >= goal
                      ? 'Goal reached'
                      : '${(goalRatio * 100).round()}% of ${formatDuration(goal)} goal',
                ),
            ],
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            summarySentence(
              activeSeconds: activeSeconds,
              breakSeconds: breakSeconds,
              idleSeconds: idleSeconds,
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          if (total > 0) ...<Widget>[
            const SizedBox(height: 18),
            _SplitBar(
              active: activeSeconds,
              onBreak: breakSeconds,
              idle: idleSeconds,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stats = <Widget>[
                  _Stat(
                    label: 'Working',
                    value: formatDuration(activeSeconds),
                    color: AppTheme.accent,
                    footnote: '${(activeSeconds / total * 100).round()}%',
                  ),
                  _Stat(
                    label: 'Breaks',
                    value: formatDuration(breakSeconds),
                    color: AppTheme.success,
                    footnote: '${(breakSeconds / total * 100).round()}%',
                  ),
                  _Stat(
                    label: 'Away',
                    value: formatDuration(idleSeconds),
                    color: AppTheme.gray500,
                    footnote: '${(idleSeconds / total * 100).round()}%',
                  ),
                  _Stat(
                    label: 'App switches',
                    value: contextSwitches == 0 ? '—' : '$contextSwitches',
                    color: AppTheme.warning,
                    footnote:
                        verdict ??
                        (switchesPerHour == null || contextSwitches == 0
                            ? null
                            : '${switchesPerHour!.toStringAsFixed(1)}/hr'),
                  ),
                ];
                // Four across when there is room, otherwise two by two.
                final columns = constraints.maxWidth >= 440 ? 4 : 2;
                final gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 14,
                  children: <Widget>[
                    for (final stat in stats)
                      SizedBox(width: width, child: stat),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.reached, required this.label});

  final bool reached;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppTheme.success : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// One horizontal bar split into working / breaks / away.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.active,
    required this.onBreak,
    required this.idle,
  });

  final int active;
  final int onBreak;
  final int idle;

  @override
  Widget build(BuildContext context) {
    int flex(int v) => v <= 0 ? 0 : (v < 1 ? 1 : v);
    final segments = <(int, Color)>[
      (flex(active), AppTheme.accent),
      (flex(onBreak), AppTheme.success),
      (flex(idle), AppTheme.gray500),
    ].where((e) => e.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: <Widget>[
            for (final (weight, color) in segments)
              Expanded(
                flex: weight,
                child: Container(
                  margin: const EdgeInsets.only(right: 1.5),
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.footnote,
  });

  final String label;
  final String value;
  final Color color;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (footnote != null)
          Text(
            footnote!,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }
}

/// One finding, with its confidence made visible rather than implied.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final ProductivityInsight insight;

  IconData get _icon {
    switch (insight.type) {
      case InsightType.focusWindow:
        return Icons.schedule_rounded;
      case InsightType.contextSwitching:
        return Icons.swap_horiz_rounded;
      case InsightType.applicationPattern:
        return Icons.apps_rounded;
      case InsightType.breakPattern:
        return Icons.coffee_rounded;
      case InsightType.idleTime:
        return Icons.pause_circle_outline_rounded;
      case InsightType.focusOpportunity:
        return Icons.lightbulb_outline_rounded;
    }
  }

  Color get _accent {
    switch (insight.confidence) {
      case InsightConfidence.high:
        return AppTheme.accent;
      case InsightConfidence.medium:
        return AppTheme.info;
      case InsightConfidence.low:
        return AppTheme.gray500;
    }
  }

  /// What the card calls itself. A low-confidence finding announces that it is
  /// a possibility in its own heading, so the claim is hedged even if the
  /// reader only skims.
  String get _heading => insight.confidence == InsightConfidence.low
      ? 'Possible pattern'
      : insight.title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(_icon, size: 15, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _heading,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (insight.confidence ==
                        InsightConfidence.low) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (insight.needsEvidenceNote) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Based on ${insight.evidenceDayCount} '
                    '${insight.evidenceDayCount == 1 ? 'day' : 'days'} '
                    'of activity.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown before there is enough recorded activity to say anything.
///
/// Deliberately not a dashboard of zeroes or a greyed-out chart: an empty
/// state that imitates data teaches people to distrust the real thing.
class ProductivityEmptyState extends StatelessWidget {
  const ProductivityEmptyState({
    super.key,
    required this.trackingEnabled,
    this.onEnableTracking,
  });

  final bool trackingEnabled;
  final VoidCallback? onEnableTracking;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                trackingEnabled
                    ? Icons.hourglass_empty_rounded
                    : Icons.visibility_off_outlined,
                size: 36,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                trackingEnabled
                    ? 'Building your productivity picture'
                    : 'Activity tracking is off',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trackingEnabled
                    ? 'BreakMate needs a little activity history before it can '
                          'show anything useful. Keep working normally — your '
                          'first insights appear once enough has been recorded.'
                    : 'Turn on activity tracking and BreakMate will record '
                          'which applications you use and when, so it can show '
                          'you where your time goes. Your private content is '
                          'never read.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (!trackingEnabled && onEnableTracking != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onEnableTracking,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.gray950,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Turn on activity tracking'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The daily bars behind the week and month views.
class DailyActivityBars extends StatefulWidget {
  const DailyActivityBars({super.key, required this.days, this.goalSeconds});

  final List<DailyProductivitySummary> days;

  /// The daily focus goal. When set, a dashed line marks it and days that
  /// reach it turn green, so "was this a good day?" needs no arithmetic.
  final int? goalSeconds;

  @override
  State<DailyActivityBars> createState() => _DailyActivityBarsState();
}

class _DailyActivityBarsState extends State<DailyActivityBars> {
  DailyProductivitySummary? _hoveredDay;

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();

    final todayStr = _todayStr();
    final goal = widget.goalSeconds != null && widget.goalSeconds! > 0
        ? widget.goalSeconds
        : null;
    final dataPeak = widget.days
        .map((day) => day.activeSeconds)
        .fold<int>(0, (best, value) => value > best ? value : best);
    // The scale must reach the goal line or it would sit off the chart.
    final peak = goal != null && goal > dataPeak ? goal : dataPeak;

    final activeDays = widget.days.where((d) => d.activeSeconds > 0).toList();
    final totalActiveSeconds = widget.days.fold<int>(
      0,
      (sum, d) => sum + d.activeSeconds,
    );
    final avgActiveSeconds = widget.days.isEmpty
        ? 0
        : totalActiveSeconds ~/ (activeDays.isEmpty ? 1 : activeDays.length);

    DailyProductivitySummary? peakDay;
    for (final day in widget.days) {
      if (peakDay == null || day.activeSeconds > peakDay.activeSeconds) {
        peakDay = day;
      }
    }

    final isSparseLabels = widget.days.length > 10;
    final labelInterval = isSparseLabels
        ? (widget.days.length / 5).ceil().clamp(1, widget.days.length)
        : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderHud(avgActiveSeconds, peakDay, todayStr),
          const SizedBox(height: 16),
          SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildYAxisLabels(peak),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      _buildGuidelines(),
                      if (goal != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 22 + (goal / peak) * (124 - 22),
                          child: _GoalLine(label: formatDuration(goal)),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < widget.days.length; i++)
                            Expanded(
                              child: _buildBarItem(
                                day: widget.days[i],
                                peakSeconds: peak,
                                goalSeconds: goal,
                                isToday: widget.days[i].date == todayStr,
                                isHovered:
                                    _hoveredDay?.date == widget.days[i].date,
                                showLabel:
                                    !isSparseLabels ||
                                    i == 0 ||
                                    i == widget.days.length - 1 ||
                                    i % labelInterval == 0,
                                isSparseLabels: isSparseLabels,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (goal != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _LegendDot(color: AppTheme.success, label: 'Reached goal'),
                const SizedBox(width: 14),
                _LegendDot(color: AppTheme.accent, label: 'Below goal'),
                const SizedBox(width: 14),
                Text(
                  'Dashed line = daily goal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderHud(
    int avgActiveSeconds,
    DailyProductivitySummary? peakDay,
    String todayStr,
  ) {
    if (_hoveredDay != null) {
      final day = _hoveredDay!;
      final isToday = day.date == todayStr;
      final parsed = DateTime.tryParse(day.date);
      final monthName = parsed != null ? _monthNames[parsed.month - 1] : '';
      final dateLabel = isToday
          ? 'Today'
          : parsed != null
          ? '${shortWeekday(day.date)}, ${parsed.day} $monthName'
          : day.date;

      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatDuration(day.activeSeconds)} active',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (day.breakSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatDuration(day.breakSeconds)} breaks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ],
          if (day.contextSwitches > 0) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              '${day.contextSwitches} switches',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.warning,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Daily average: ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textMuted,
              ),
            ),
            Text(
              formatDuration(avgActiveSeconds),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (peakDay != null && peakDay.activeSeconds > 0)
          Text(
            'Peak: ${formatDuration(peakDay.activeSeconds)} (${shortWeekday(peakDay.date)})',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _buildYAxisLabels(int peakSeconds) {
    final peakHours = peakSeconds > 0 ? (peakSeconds / 3600) : 0.0;
    final topLabel = peakHours >= 1
        ? '${peakHours.round()}h'
        : peakSeconds > 0
        ? '${(peakSeconds / 60).round()}m'
        : '0h';
    final midLabel = peakHours >= 1
        ? '${(peakHours / 2).round()}h'
        : peakSeconds > 0
        ? '${(peakSeconds / 120).round()}m'
        : '';

    return SizedBox(
      width: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            topLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted.withValues(alpha: 0.65),
            ),
          ),
          if (midLabel.isNotEmpty)
            Text(
              midLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    return Positioned.fill(
      bottom: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.08),
          ),
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.06),
          ),
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required DailyProductivitySummary day,
    required int peakSeconds,
    required int? goalSeconds,
    required bool isToday,
    required bool isHovered,
    required bool showLabel,
    required bool isSparseLabels,
  }) {
    final fraction = peakSeconds == 0 ? 0.0 : day.activeSeconds / peakSeconds;
    final reachedGoal = goalSeconds != null && day.activeSeconds >= goalSeconds;
    final barColor = reachedGoal ? AppTheme.success : AppTheme.accent;
    final parsed = DateTime.tryParse(day.date);
    final bottomLabel = isSparseLabels
        ? (isToday
              ? 'Today'
              : parsed != null
              ? '${parsed.day}'
              : '')
        : shortWeekday(day.date);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredDay = day),
      onExit: (_) => setState(() {
        if (_hoveredDay?.date == day.date) _hoveredDay = null;
      }),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSparseLabels ? 1.5 : 4),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: day.activeSeconds == 0
                        ? 0.0
                        : fraction.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isHovered
                              ? [
                                  barColor,
                                  Color.lerp(barColor, Colors.white, 0.35) ??
                                      barColor,
                                ]
                              : isToday
                              ? [
                                  barColor,
                                  Color.lerp(barColor, Colors.white, 0.2) ??
                                      barColor,
                                ]
                              : [
                                  barColor.withValues(alpha: 0.55),
                                  barColor.withValues(alpha: 0.9),
                                ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, -1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: showLabel
                  ? Text(
                      bottomLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isSparseLabels ? 9 : 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? AppTheme.accent
                            : AppTheme.textMuted.withValues(alpha: 0.8),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final dashes = (c.maxWidth / 8).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < dashes; i++)
                    Container(
                      width: 4,
                      height: 1.2,
                      color: AppTheme.success.withValues(alpha: 0.7),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
