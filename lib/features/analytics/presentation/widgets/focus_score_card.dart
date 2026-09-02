import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Shows the deep-work Focus Score for the selected period — the share of
/// tracked time spent in an uninterrupted 15+ minute focus-category session
/// — plus, once there's enough break history, whether taking breaks
/// actually correlates with more focus afterward.
class FocusScoreCard extends StatelessWidget {
  final bool enabled;
  final double focusScore;
  final List<FocusSession> sessions;
  final BreakFocusCorrelation? correlation;

  const FocusScoreCard({
    super.key,
    required this.enabled,
    required this.focusScore,
    required this.sessions,
    this.correlation,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    if (sessions.isEmpty) return _buildEmptyState();
    return _buildPopulatedState();
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Text(
            'No deep-work sessions yet — a session needs 15+ uninterrupted '
            'minutes in a focus app (coding, writing, or design).',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPopulatedState() {
    final percent = (focusScore * 100).round();
    final totalFocusSeconds = sessions.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final topSessions = sessions.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: focusScore.clamp(0.02, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(AppTheme.accentColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${sessions.length} deep-work session${sessions.length == 1 ? '' : 's'} · '
            '${formatUsageDuration(totalFocusSeconds)} total',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          ...topSessions.map(_buildSessionRow),
          if (correlation != null && correlation!.hasEnoughData) ...[
            const SizedBox(height: 12),
            _buildCorrelationInsight(correlation!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(CupertinoIcons.bolt_fill, size: 20, color: AppTheme.accentColor),
        const SizedBox(width: 8),
        Text(
          'Focus Score',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionRow(FocusSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(session.category.icon, size: 14, color: session.category.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.category.label,
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          Text(
            formatUsageDuration(session.durationSeconds),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationInsight(BreakFocusCorrelation correlation) {
    final diff = correlation.differencePoints;
    final direction = diff >= 0 ? 'more' : 'less';
    final message = diff.abs() < 1
        ? "Focus in the hour after a break looks about the same whether you took it or skipped it."
        : 'You focus ${diff.abs().round()} points $direction in the hour '
              'after a break you take vs. one you skip.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.link, size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
