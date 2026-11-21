import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

part 'daily_activity_bars.dart';

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
          padding: const EdgeInsets.only(bottom: AppTheme.space12),
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
                        fontFeatures: AppTheme.tabular,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontFamily: 'Inter',
                          fontSize: 12,
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

  final String? caption;

  final int? focusGoalSeconds;

  static String? switchingVerdict(double? perHour, int switches) {
    if (perHour == null || switches == 0) return null;
    if (perHour < 6) return 'Steady focus';
    if (perHour < 12) return 'Some app switching';
    return 'A lot of app switching';
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            // TODO(no-data): comparison baseline needs previous-period stats
            Text(
              formatDuration(activeSeconds),
              style: TextStyle(
                fontFeatures: AppTheme.tabular,
                fontFamily: 'Inter',
                fontSize: 40,
                fontWeight: FontWeight.w400,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'active',
              style: TextStyle(
                fontFeatures: AppTheme.tabular,
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
              fontFeatures: AppTheme.tabular,
              fontFamily: 'Inter',
              fontSize: 12,
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
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.4,
            color: AppTheme.textSecondary,
          ),
        ),
        if (total > 0) ...<Widget>[
          const SizedBox(height: 16),
          _SplitBar(
            active: activeSeconds,
            onBreak: breakSeconds,
            idle: idleSeconds,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = <Widget>[
                _Stat(label: 'Working', value: formatDuration(activeSeconds)),
                _Stat(label: 'Breaks', value: formatDuration(breakSeconds)),
                _Stat(label: 'Away', value: formatDuration(idleSeconds)),
                _Stat(
                  label: 'App switches',
                  value: contextSwitches == 0 ? '—' : '$contextSwitches',
                  footnote:
                      verdict ??
                      (switchesPerHour == null || contextSwitches == 0
                          ? null
                          : '${switchesPerHour!.toStringAsFixed(1)}/hr'),
                ),
              ];

              final columns = constraints.maxWidth >= 440 ? 4 : 2;
              return Column(
                children: <Widget>[
                  for (var r = 0; r < stats.length; r += columns) ...<Widget>[
                    if (r > 0) const SizedBox(height: AppTheme.space16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (var i = r; i < r + columns; i++) ...<Widget>[
                          if (i > r) const SizedBox(width: AppTheme.space16),
                          Expanded(child: stats[i]),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.reached, required this.label});

  final bool reached;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFeatures: AppTheme.tabular,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: reached ? AppTheme.success : AppTheme.textSecondary,
      ),
    );
  }
}

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
      (flex(onBreak), AppTheme.gray400),
      (flex(idle), AppTheme.gray500),
    ].where((e) => e.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < segments.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: segments[i].$1,
                child: ColoredBox(color: segments[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.footnote});

  final String label;
  final String value;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: AppTheme.textPrimary,
          ),
        ),
        if (footnote != null)
          Text(
            footnote!,
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }
}

/// Renders one ProductivityInsight, hedging the wording when confidence is not high.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final ProductivityInsight insight;

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

  @override
  Widget build(BuildContext context) {
    final suggestion = insight.suggestion;
    final low = insight.confidence == InsightConfidence.low;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    low ? 'Possible pattern: ${insight.title}' : insight.title,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
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
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextSpan(text: suggestion),
                        ],
                      ),
                      style: TextStyle(
                        fontFeatures: AppTheme.tabular,
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
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
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
                    ? CupertinoIcons.hourglass
                    : CupertinoIcons.eye_slash,
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
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
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
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 12,
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
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
