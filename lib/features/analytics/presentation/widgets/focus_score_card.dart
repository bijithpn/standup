import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Today's focus score (focus time share of active time) with its sessions and top focus apps.
class FocusScoreCard extends StatelessWidget {
  final bool enabled;
  final double focusScore;
  final List<FocusSession> sessions;

  final List<AppUsageEntry> focusApps;

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
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                  fontFeatures: AppTheme.tabular,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
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

    final slices = <_Slice>[];
    if (focusApps.isNotEmpty) {
      for (var i = 0; i < focusApps.length && i < 5; i++) {
        final a = focusApps[i];
        slices.add(_Slice(a.name, a.seconds, a.category.icon));
      }
      final rest = focusApps.skip(5).fold<int>(0, (t, a) => t + a.seconds);
      if (rest > 0) {
        slices.add(
          _Slice(
            '${focusApps.length - 5} other apps',
            rest,
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
        slices.add(_Slice(e.key.label, e.value, e.key.icon));
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
                          fontWeight: FontWeight.w500,
                          fontFeatures: AppTheme.tabular,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'focus',
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Deep work',
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        verdict,
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // TODO(no-data): comparison baseline needs previous-period stats
                  Text(
                    formatUsageDuration(total),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppTheme.tabular,
                      height: 1.1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'} · longest ${formatUsageDuration(longest)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTheme.tabular,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Time in focus apps',
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        _ranked(slices),
      ],
    );
  }

  Widget _ranked(List<_Slice> items) {
    final total = items.fold<int>(0, (t, e) => t + e.seconds);
    final top = items.isEmpty ? 1 : items.first.seconds;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(items[i].icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : items[i].seconds / top,
                      minHeight: 4,
                      color: i == 0 ? AppTheme.accent : AppTheme.textMuted,
                      backgroundColor: AppTheme.border,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${formatUsageDuration(items[i].seconds)} · ${total == 0 ? 0 : (items[i].seconds * 100 / total).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTheme.tabular,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Slice {
  final String label;
  final int seconds;
  final IconData icon;

  const _Slice(this.label, this.seconds, this.icon);
}
