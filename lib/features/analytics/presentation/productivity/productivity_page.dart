import 'package:flutter/material.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/presentation/productivity/application_usage_section.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_timeline_view.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// How much of the past the page is showing.
enum ProductivityRange {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30);

  const ProductivityRange(this.label, this.days);

  final String label;
  final int days;
}

/// Where the day goes.
///
/// One surface rather than a page per question: the point is to answer "how did
/// I spend today, and what should I pay attention to" in a single read, so the
/// overview, the timeline, the applications and the findings stack in the order
/// someone would actually ask them.
class ProductivityPage extends StatefulWidget {
  const ProductivityPage({
    super.key,
    this.repository,
    this.settingsRepository,
  });

  /// Injected in tests; resolved from the service locator otherwise.
  final ProductivityRepository? repository;
  final SettingsRepository? settingsRepository;

  @override
  State<ProductivityPage> createState() => _ProductivityPageState();
}

class _ProductivityPageState extends State<ProductivityPage> {
  ProductivityRange _range = ProductivityRange.today;
  RangeProductivitySummary? _rangeSummary;
  List<ProductivityInsight> _insights = const <ProductivityInsight>[];
  bool _loading = true;

  late final DateTime _now = DateTime.now();
  late final String _todayKey = ProductivityRepository.dateKey(_now);

  ProductivityRepository? get _repository {
    if (widget.repository != null) return widget.repository;
    return sl.isRegistered<ProductivityRepository>()
        ? sl<ProductivityRepository>()
        : null;
  }

  SettingsRepository? get _settings {
    if (widget.settingsRepository != null) return widget.settingsRepository;
    return sl.isRegistered<SettingsRepository>()
        ? sl<SettingsRepository>()
        : null;
  }

  bool get _trackingEnabled =>
      _settings?.currentSettings.appUsageTrackingEnabled ?? false;

  @override
  void initState() {
    super.initState();
    _repository?.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _repository?.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final summary = await repository.summaryForLastDays(
      _range.days,
      now: _now,
    );
    final insights = await repository.insights(now: _now);

    if (!mounted) return;
    setState(() {
      _rangeSummary = summary;
      _insights = insights;
      _loading = false;
    });
  }

  void _selectRange(ProductivityRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _loading = true;
    });
    _load();
  }

  Future<void> _enableTracking() async {
    final settings = _settings;
    if (settings == null) return;
    await settings.save(
      settings.currentSettings.copyWith(appUsageTrackingEnabled: true),
    );
    if (!mounted) return;
    setState(() {});
  }

  DailyProductivitySummary get _today =>
      _repository?.summaryForDate(_todayKey) ??
      DailyProductivitySummary.empty(_todayKey);

  void _openApplication(AppTotal app) {
    final repository = _repository;
    if (repository == null) return;

    // Only the selected day's stretches, so the session list matches the
    // numbers above it rather than silently spanning the whole range.
    final segments = repository.appSegments(_todayKey, app.appKey);
    final history = <String, int>{};
    final days = _rangeSummary?.days ?? const <DailyProductivitySummary>[];
    for (final day in days.length > 7 ? days.sublist(days.length - 7) : days) {
      final match = day.apps.where((a) => a.appKey == app.appKey);
      history[day.date] = match.isEmpty ? 0 : match.first.seconds;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ApplicationDetailSheet(
        app: app,
        totalActiveSeconds: _range == ProductivityRange.today
            ? _today.activeSeconds
            : _rangeSummary?.activeSeconds ?? 0,
        segments: segments,
        dateLabel: _range == ProductivityRange.today
            ? 'Today'
            : 'Last ${_range.days} days',
        historyByDate: _range == ProductivityRange.today ? const {} : history,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _rangeSummary;
    final showingToday = _range == ProductivityRange.today;
    final hasActivity = showingToday
        ? _today.hasActivity
        : (summary?.hasActivity ?? false);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(
            range: _range,
            onRangeChanged: _selectRange,
            subtitle: showingToday
                ? formatDateKey(_todayKey)
                : 'Last ${_range.days} days',
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !hasActivity
                    ? ProductivityEmptyState(
                        trackingEnabled: _trackingEnabled,
                        onEnableTracking:
                            _trackingEnabled ? null : _enableTracking,
                      )
                    : _content(summary, showingToday),
          ),
        ],
      ),
    );
  }

  Widget _content(RangeProductivitySummary? summary, bool showingToday) {
    final day = _today;
    final apps = showingToday ? day.apps : (summary?.apps ?? const <AppTotal>[]);
    final activeSeconds =
        showingToday ? day.activeSeconds : (summary?.activeSeconds ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: <Widget>[
        ProductivityOverviewCard(
          activeSeconds: activeSeconds,
          idleSeconds: showingToday ? day.idleSeconds : summary?.idleSeconds ?? 0,
          breakSeconds:
              showingToday ? day.breakSeconds : summary?.breakSeconds ?? 0,
          contextSwitches: showingToday
              ? day.contextSwitches
              : summary?.contextSwitches ?? 0,
          switchesPerHour: showingToday ? day.switchesPerActiveHour : null,
          caption: showingToday
              ? null
              : 'across ${summary?.activeDayCount ?? 0} '
                  '${(summary?.activeDayCount ?? 0) == 1 ? 'day' : 'days'} '
                  'with activity',
        ),
        const SizedBox(height: 26),

        if (showingToday) ...<Widget>[
          ProductivitySection(
            title: 'Timeline',
            subtitle: day.firstActivityAt == null
                ? null
                : '${formatClock(day.firstActivityAt!)} to '
                    '${formatClock(day.lastActivityAt!)}',
            child: ActivityTimelineView(
              entries: _repository?.timelineForDate(_todayKey) ??
                  const <TimelineEntry>[],
            ),
          ),
          const SizedBox(height: 26),
        ] else if (summary != null) ...<Widget>[
          ProductivitySection(
            title: 'Daily activity',
            subtitle: 'Active time per day',
            child: DailyActivityBars(days: summary.days),
          ),
          const SizedBox(height: 26),
        ],

        ProductivitySection(
          title: 'Applications',
          subtitle: apps.isEmpty
              ? null
              : '${apps.length} ${apps.length == 1 ? 'application' : 'applications'}',
          child: ApplicationUsageList(
            apps: apps,
            totalActiveSeconds: activeSeconds,
            limit: 8,
            onSelected: _openApplication,
          ),
        ),
        const SizedBox(height: 26),

        ProductivitySection(
          title: 'Insights',
          subtitle: _insights.isEmpty
              ? 'Not enough data yet'
              : 'What the recorded activity shows',
          child: _insights.isEmpty
              ? _NotEnoughInsights()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final insight in _insights)
                      InsightCard(insight: insight),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NotEnoughInsights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        'Keep using BreakMate for a few days and patterns in how you work '
        'will start to appear here.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.5,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.range,
    required this.onRangeChanged,
    required this.subtitle,
  });

  final ProductivityRange range;
  final ValueChanged<ProductivityRange> onRangeChanged;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Productivity',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final option in ProductivityRange.values)
                  _RangeButton(
                    label: option.label,
                    isSelected: option == range,
                    onTap: () => onRangeChanged(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
