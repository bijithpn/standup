import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The deep-work Focus Score for the selected period (the share of tracked
/// time spent in an uninterrupted 15+ minute session in a focus app), the
/// sessions behind it, and, once there is enough break history, whether
/// taking breaks lines up with more focus afterwards.
class FocusScoreCard extends StatelessWidget {
  final bool enabled;
  final double focusScore;
  final List<FocusSession> sessions;

  /// Apps used in focus categories for the period, most-used first.
  final List<AppUsageEntry> focusApps;

  /// Shown under a divider at the bottom of the card (the trend chart).
  final Widget? footer;

  const FocusScoreCard({
    super.key,
    required this.enabled,
    required this.focusScore,
    required this.sessions,
    this.focusApps = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _frame(
        child: _message(
          CupertinoIcons.eye_slash,
          'App tracking is off',
          'Turn on app usage tracking in Settings to see your focus sessions.',
        ),
      );
    }
    if (sessions.isEmpty) {
      return _frame(
        child: _message(
          CupertinoIcons.scope,
          'No deep-work sessions yet',
          'A session needs 15+ uninterrupted minutes in a coding, writing or '
              'design app.',
        ),
      );
    }
    return _frame(child: _populated());
  }

  Widget _frame({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (footer != null) ...[
            const SizedBox(height: 18),
            Divider(height: 1, thickness: 0.5, color: AppTheme.separatorColor),
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _message(IconData icon, String title, String body) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.textMuted.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static (String, Color) _verdict(int percent) => percent >= 50
      ? ('Deep focus', AppTheme.success)
      : percent >= 25
      ? ('Steady', AppTheme.accent)
      : ('Light focus', AppTheme.warning);

  Widget _populated() {
    final percent = (focusScore * 100).round();
    final (verdict, color) = _verdict(percent);
    final total = sessions.fold<int>(0, (s, e) => s + e.durationSeconds);
    final longest = sessions.fold<int>(
      0,
      (m, e) => e.durationSeconds > m ? e.durationSeconds : m,
    );

    // One slice per app (top 5, the rest grouped). Falls back to the
    // category split when no per-app data is available.
    final slices = <_Slice>[];
    if (focusApps.isNotEmpty) {
      for (var i = 0; i < focusApps.length && i < 5; i++) {
        final a = focusApps[i];
        slices.add(_Slice(a.name, a.seconds, _palette[i], a.category.icon));
      }
      final rest = focusApps.skip(5).fold<int>(0, (t, a) => t + a.seconds);
      if (rest > 0) {
        slices.add(
          _Slice(
            '${focusApps.length - 5} other apps',
            rest,
            AppTheme.textMuted,
            CupertinoIcons.ellipsis,
          ),
        );
      }
    } else {
      final byCategory = <AppCategory, int>{};
      for (final s in sessions) {
        byCategory[s.category] =
            (byCategory[s.category] ?? 0) + s.durationSeconds;
      }
      final entries = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in entries) {
        slices.add(_Slice(e.key.label, e.value, e.key.color, e.key.icon));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: focusScore.clamp(0.02, 1.0),
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: AppTheme.border,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'focus',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Deep work',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          verdict,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatUsageDuration(total),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _chip(
                        CupertinoIcons.layers,
                        '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        CupertinoIcons.flame,
                        'longest ${formatUsageDuration(longest)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _label('Time in focus apps'),
        _pie(slices),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.textMuted,
      ),
    ),
  );

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  static const _palette = [
    Color(0xFF38BDF8),
    Color(0xFF4ADE80),
    Color(0xFFF59E0B),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
  ];

  /// The split as a donut, with a legend (name, time, share) beside it.
  Widget _pie(List<_Slice> items) {
    final total = items.fold<int>(0, (t, e) => t + e.seconds);
    return LayoutBuilder(
      builder: (context, box) {
        final chart = SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 42,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final c in items)
                      PieChartSectionData(
                        value: c.seconds.toDouble(),
                        color: c.color,
                        radius: 30,
                        showTitle: total > 0 && c.seconds * 100 / total >= 8,
                        title: '${(c.seconds * 100 / total).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatUsageDuration(total),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'total',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );

        final legend = Column(
          children: [
            for (final c in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: c.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(c.icon, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatUsageDuration(c.seconds),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${total == 0 ? 0 : (c.seconds * 100 / total).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

        // Stack the legend under the chart when the card is narrow.
        if (box.maxWidth < 420) {
          return Column(children: [chart, const SizedBox(height: 14), legend]);
        }
        return Row(
          children: [
            chart,
            const SizedBox(width: 28),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _Slice {
  final String label;
  final int seconds;
  final Color color;
  final IconData icon;

  const _Slice(this.label, this.seconds, this.color, this.icon);
}
