import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

part 'daily_activity_bars.dart';

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

/// One finding: what it is, what it means, and — when there is one — the
/// concrete thing to do about it. Confidence stays visible rather than implied.
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
      case InsightType.goalProgress:
        return Icons.flag_rounded;
      case InsightType.comparison:
        return Icons.compare_arrows_rounded;
    }
  }

  /// A short word for what kind of finding this is.
  String get _kind {
    switch (insight.type) {
      case InsightType.focusWindow:
        return 'When you focus';
      case InsightType.contextSwitching:
        return 'Attention';
      case InsightType.applicationPattern:
        return 'Apps';
      case InsightType.breakPattern:
        return 'Breaks';
      case InsightType.idleTime:
        return 'Time away';
      case InsightType.focusOpportunity:
        return 'Tip';
      case InsightType.goalProgress:
        return 'Goal';
      case InsightType.comparison:
        return 'Compared with usual';
    }
  }

  Color get _accent {
    switch (insight.type) {
      case InsightType.breakPattern:
        return AppTheme.success;
      case InsightType.contextSwitching:
        return AppTheme.warning;
      case InsightType.goalProgress:
        return AppTheme.info;
      case InsightType.idleTime:
        return AppTheme.gray500;
      default:
        return insight.confidence == InsightConfidence.low
            ? AppTheme.gray500
            : AppTheme.accent;
    }
  }

  /// One finding, written as a plain entry in a list rather than a card: the
  /// finding first, what it means under it, and the suggestion as a sentence.
  /// The only colour is a small marker that says what kind of finding it is.
  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final suggestion = insight.suggestion;
    final low = insight.confidence == InsightConfidence.low;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_icon, size: 18, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    low ? 'Possible pattern: ${insight.title}' : insight.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (suggestion != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Try this: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextSpan(text: suggestion),
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      _kind,
                      if (insight.needsEvidenceNote)
                        'from ${insight.evidenceDayCount} '
                            '${insight.evidenceDayCount == 1 ? 'day' : 'days'}'
                            ' of activity',
                    ].join(', '),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
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
