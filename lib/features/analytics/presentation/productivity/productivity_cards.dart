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

/// The headline numbers for a day or a range.
class ProductivityOverviewCard extends StatelessWidget {
  const ProductivityOverviewCard({
    super.key,
    required this.activeSeconds,
    required this.idleSeconds,
    required this.breakSeconds,
    required this.contextSwitches,
    this.switchesPerHour,
    this.caption,
  });

  final int activeSeconds;
  final int idleSeconds;
  final int breakSeconds;
  final int contextSwitches;
  final double? switchesPerHour;

  /// Sits under the headline, e.g. "across 5 days".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
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
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'active',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
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
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'Breaks',
                  value: formatDuration(breakSeconds),
                  color: AppTheme.success,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Idle',
                  value: formatDuration(idleSeconds),
                  color: AppTheme.gray500,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Switches',
                  value: contextSwitches == 0 ? '—' : '$contextSwitches',
                  color: AppTheme.warning,
                  footnote: switchesPerHour == null || contextSwitches == 0
                      ? null
                      : '${switchesPerHour!.toStringAsFixed(1)}/hr',
                ),
              ),
            ],
          ),
        ],
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
                    if (insight.confidence == InsightConfidence.low) ...<Widget>[
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
class DailyActivityBars extends StatelessWidget {
  const DailyActivityBars({super.key, required this.days});

  final List<DailyProductivitySummary> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final peak = days
        .map((day) => day.activeSeconds)
        .fold<int>(0, (best, value) => value > best ? value : best);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: SizedBox(
        height: 132,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (final day in days)
              Expanded(
                child: _DayBar(
                  day: day,
                  peakSeconds: peak,
                  showLabel: days.length <= 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.peakSeconds,
    required this.showLabel,
  });

  final DailyProductivitySummary day;
  final int peakSeconds;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final fraction = peakSeconds == 0 ? 0.0 : day.activeSeconds / peakSeconds;

    return Tooltip(
      message: '${formatDateKey(day.date)}\n'
          '${formatDuration(day.activeSeconds)} active',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                // A day with a little activity still gets a visible sliver, so
                // "barely worked" reads differently from "did not work".
                heightFactor: day.activeSeconds == 0
                    ? 0.0
                    : fraction.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                shortWeekday(day.date),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
