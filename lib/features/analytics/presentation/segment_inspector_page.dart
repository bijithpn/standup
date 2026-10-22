import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// A development-only window onto what activity tracking actually recorded.
///
/// Every number the Productivity screens will show is derived from these rows.
/// A fault in how a day is cut up — a midnight split an hour out, a sleep gap
/// attributed to whatever was open, a break landing in the wrong place — passes
/// unit tests happily and is obvious the moment someone reads their own
/// afternoon back. This exists so that reading is possible before screens are
/// built on the data.
class SegmentInspectorPage extends StatefulWidget {
  const SegmentInspectorPage({super.key});

  @override
  State<SegmentInspectorPage> createState() => _SegmentInspectorPageState();
}

class _SegmentInspectorPageState extends State<SegmentInspectorPage> {
  late String _date = ProductivityRepository.dateKey(DateTime.now());
  String? _exportedTo;
  List<ProductivityInsight> _insights = const <ProductivityInsight>[];

  ActivitySegmentRepository get _segments => sl<ActivitySegmentRepository>();
  ProductivityRepository get _productivity => sl<ProductivityRepository>();

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final insights = await _productivity.insights();
    if (!mounted) return;
    setState(() => _insights = insights);
  }

  /// Flushes anything buffered so the view shows the current minute, not the
  /// last time the tracker happened to write.
  void _refresh() {
    _segments.flush();
    _productivity.invalidate();
    setState(() => _exportedTo = null);
    _loadInsights();
  }

  String _buildReport() {
    final segments = _segments.segmentsForDate(_date);
    final summary = _productivity.summaryForDate(_date);
    final timeline = _productivity.timelineForDate(_date);
    final buffer = StringBuffer()
      ..writeln('BreakMate activity segments — $_date')
      ..writeln('Generated ${DateTime.now()}')
      ..writeln('Segments stored in total: ${_segments.count()}')
      ..writeln()
      ..writeln('── Derived totals ──')
      ..writeln('Active   ${_hms(summary.activeSeconds)}')
      ..writeln('Idle     ${_hms(summary.idleSeconds)}')
      ..writeln('Break    ${_hms(summary.breakSeconds)}')
      ..writeln('Tracked  ${_hms(summary.trackedSeconds)}')
      ..writeln(
        'Switches ${summary.contextSwitches} '
        '(${summary.switchesPerActiveHour.toStringAsFixed(1)}/active hour)',
      )
      ..writeln('First    ${summary.firstActivityAt}')
      ..writeln('Last     ${summary.lastActivityAt}')
      ..writeln()
      ..writeln('── Applications ──');

    for (final app in summary.apps) {
      buffer.writeln(
        '${_hms(app.seconds).padLeft(9)}  '
        '${app.sessionCount.toString().padLeft(3)} sessions  '
        '${app.categoryName.padRight(14)} ${app.appName}',
      );
    }

    buffer
      ..writeln()
      ..writeln('── Hour by hour (active) ──');
    for (var hour = 0; hour < 24; hour++) {
      final seconds = summary.hourlyActiveSeconds[hour];
      if (seconds == 0) continue;
      final switches = summary.hourlySwitches[hour];
      buffer.writeln(
        '${hour.toString().padLeft(2)}:00  '
        '${_hms(seconds).padLeft(9)}  $switches switches',
      );
    }

    buffer
      ..writeln()
      ..writeln('── Timeline (merged for display) ──');
    for (final entry in timeline) {
      buffer.writeln(
        '${_clock(entry.startedAt)}–${_clock(entry.endedAt)}  '
        '${_hms(entry.seconds).padLeft(9)}  '
        '${entry.kind.name.padRight(8)} '
        '${entry.appName.isEmpty ? '-' : entry.appName}',
      );
    }

    buffer
      ..writeln()
      ..writeln('── Raw segments (${segments.length}) ──');
    for (final segment in segments) {
      buffer.writeln(
        '${_clock(segment.startedAt)}–${_clock(segment.endedAt)}  '
        '${_hms(segment.seconds).padLeft(9)}  '
        '${segment.activityKind.name.padRight(8)} '
        '${segment.appName.isEmpty ? '-' : segment.appName}',
      );
    }

    buffer
      ..writeln()
      ..writeln('── Insights (${_insights.length}) ──');
    for (final insight in _insights) {
      buffer
        ..writeln(
          '[${insight.confidence.name}] ${insight.title} '
          '(${insight.evidenceDayCount}d)',
        )
        ..writeln('  ${insight.description}')
        ..writeln('  ${insight.supportingData}');
    }

    return buffer.toString();
  }

  Future<void> _export() async {
    final report = _buildReport();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/breakmate-segments-$_date.txt');
      await file.writeAsString(report);
      if (!mounted) return;
      setState(() => _exportedTo = file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportedTo = 'Export failed: $e');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));
    if (!mounted) return;
    setState(() => _exportedTo = 'Copied to clipboard');
  }

  void _shiftDay(int days) {
    final current = DateTime.parse(_date).add(Duration(days: days));
    setState(() {
      _date = ProductivityRepository.dateKey(current);
      _exportedTo = null;
    });
  }

  static String _hms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final summary = _productivity.summaryForDate(_date);
    final segments = _segments.segmentsForDate(_date);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(summary, segments.length),
          const _PurposeBanner(),
          Expanded(
            child: segments.isEmpty
                ? _empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: segments.length,
                    itemBuilder: (context, index) =>
                        _SegmentRow(segment: segments[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(DailyProductivitySummary summary, int segmentCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Activity segments',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _shiftDay(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                color: AppTheme.textSecondary,
                tooltip: 'Previous day',
              ),
              Text(
                _date,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => _shiftDay(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                color: AppTheme.textSecondary,
                tooltip: 'Next day',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: <Widget>[
              _stat('Active', _hms(summary.activeSeconds)),
              _stat('Idle', _hms(summary.idleSeconds)),
              _stat('Break', _hms(summary.breakSeconds)),
              _stat('Switches', '${summary.contextSwitches}'),
              _stat('Segments', '$segmentCount'),
              _stat('Stored', '${_segments.count()}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Flush & refresh'),
                style: _buttonStyle,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy report'),
                style: _buttonStyle,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.save_alt_rounded, size: 15),
                label: const Text('Save to file'),
                style: _buttonStyle,
              ),
            ],
          ),
          if (_exportedTo != null) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(
              _exportedTo!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppTheme.textPrimary,
    side: BorderSide(color: AppTheme.border),
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.timeline_rounded, size: 34, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Nothing recorded for $_date',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Activity tracking has to be switched on in Privacy before '
              'anything is recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment});

  final ActivitySegment segment;

  Color get _kindColour {
    switch (segment.activityKind) {
      case ActivityKind.active:
        return AppTheme.accent;
      case ActivityKind.idle:
        return AppTheme.gray500;
      case ActivityKind.onBreak:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 26, color: _kindColour),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: Text(
              '${_SegmentInspectorPageState._clock(segment.startedAt)}'
              '–${_SegmentInspectorPageState._clock(segment.endedAt)}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _SegmentInspectorPageState._hms(segment.seconds),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              segment.activityKind.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: _kindColour,
              ),
            ),
          ),
          Expanded(
            child: Text(
              segment.appName.isEmpty ? '—' : segment.appName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (segment.categoryName.isNotEmpty)
            Text(
              segment.categoryName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                color: AppTheme.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Says in plain words what this screen is for, since it is a developer tool
/// that sits outside the normal navigation of a release build.
class _PurposeBanner extends StatelessWidget {
  const _PurposeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Text(
        'What is this? Activity tracking records your day as short stretches '
        'of time — "active in an app", "idle" or "on a break". Those stretches '
        'are the raw data behind every Productivity number: the timeline, '
        'per-app time and the insights. This developer view lists them so '
        'the numbers can be checked against what really happened, and is only '
        'shown in development builds.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.45,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
