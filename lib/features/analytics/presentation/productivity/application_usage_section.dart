import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Which applications the time went to, and what a single one looks like up
/// close.

class ApplicationUsageList extends StatelessWidget {
  const ApplicationUsageList({
    super.key,
    required this.apps,
    required this.totalActiveSeconds,
    this.limit,
    this.onSelected,
  });

  final List<AppTotal> apps;
  final int totalActiveSeconds;

  /// Show only the busiest few. Null shows everything.
  final int? limit;

  final ValueChanged<AppTotal>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'No application activity recorded',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final shown = limit == null || limit! >= apps.length
        ? apps
        : apps.sublist(0, limit!);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < shown.length; index++) ...<Widget>[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
            _ApplicationRow(
              app: shown[index],
              totalActiveSeconds: totalActiveSeconds,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(shown[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.app,
    required this.totalActiveSeconds,
    this.onTap,
  });

  final AppTotal app;
  final int totalActiveSeconds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final share = totalActiveSeconds == 0
        ? 0.0
        : app.seconds / totalActiveSeconds;
    final colour = categoryColor(app.categoryName);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    app.appName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The share bar sits under the name rather than beside it, so
                  // a long application name never squeezes the measurement.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: share.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: AppTheme.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colour.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatDuration(app.seconds),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(share * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One application, up close: how long, how often, and when.
class ApplicationDetailSheet extends StatelessWidget {
  const ApplicationDetailSheet({
    super.key,
    required this.app,
    required this.totalActiveSeconds,
    required this.segments,
    required this.dateLabel,
    this.historyByDate = const <String, int>{},
  });

  final AppTotal app;
  final int totalActiveSeconds;

  /// This application's stretches on the selected day, oldest first.
  final List<ActivitySegment> segments;

  final String dateLabel;

  /// Seconds per day over the recent past, oldest key first.
  final Map<String, int> historyByDate;

  @override
  Widget build(BuildContext context) {
    final share = totalActiveSeconds == 0
        ? 0.0
        : app.seconds / totalActiveSeconds;

    return Container(
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: categoryColor(app.categoryName),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        app.appName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${categoryLabel(app.categoryName)} · $dateLabel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              shrinkWrap: true,
              children: <Widget>[
                Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: <Widget>[
                    _DetailStat(
                      label: 'Time',
                      value: formatDuration(app.seconds),
                    ),
                    _DetailStat(
                      label: 'Share',
                      value: '${(share * 100).round()}%',
                    ),
                    _DetailStat(
                      label: 'Sessions',
                      value: '${app.sessionCount}',
                    ),
                    _DetailStat(
                      label: 'Average',
                      value: formatDuration(app.averageSessionSeconds),
                    ),
                    _DetailStat(
                      label: 'Longest',
                      value: formatDuration(app.longestSessionSeconds),
                    ),
                  ],
                ),
                if (historyByDate.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _SubHeading('Recent days'),
                  const SizedBox(height: 8),
                  for (final entry in historyByDate.entries)
                    _HistoryRow(
                      label: shortWeekday(entry.key),
                      seconds: entry.value,
                      peakSeconds: historyByDate.values.fold<int>(
                        0,
                        (a, b) => b > a ? b : a,
                      ),
                    ),
                ],
                if (segments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _SubHeading('Sessions on this day'),
                  const SizedBox(height: 8),
                  for (final segment in segments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${formatClock(segment.startedAt)}'
                            '–${formatClock(segment.endedAt)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatDuration(segment.seconds),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
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

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.label,
    required this.seconds,
    required this.peakSeconds,
  });

  final String label;
  final int seconds;
  final int peakSeconds;

  @override
  Widget build(BuildContext context) {
    final fraction = peakSeconds == 0 ? 0.0 : seconds / peakSeconds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppTheme.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              formatDuration(seconds),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
