import 'dart:async';

import 'package:flutter/material.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/presentation/widgets/daily_budgets_card.dart';
import 'package:breakmate/features/analytics/presentation/productivity/application_usage_section.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_timeline_view.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight_engine.dart'
    show kMinComparableSeconds;
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/page_scroll.dart';

enum ProductivityRange {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30);

  const ProductivityRange(this.label, this.days);

  final String label;
  final int days;
}

/// Segment-based productivity screen: range selector, overview, timeline, app list and insights; loads from ProductivityRepository and offers to enable tracking if off.
class ProductivityPage extends StatefulWidget {
  const ProductivityPage({
    super.key,
    this.repository,
    this.settingsRepository,
    this.embedded = false,
    this.range,
  });

  final bool embedded;
  final ProductivityRange? range;

  final ProductivityRepository? repository;
  final SettingsRepository? settingsRepository;

  @override
  State<ProductivityPage> createState() => _ProductivityPageState();
}

class _ProductivityPageState extends State<ProductivityPage> {
  late ProductivityRange _range = widget.range ?? ProductivityRange.today;
  RangeProductivitySummary? _rangeSummary;
  RangeProductivitySummary? _previousSummary;
  List<ProductivityInsight> _insights = const <ProductivityInsight>[];
  bool _loading = true;
  Widget? _detail;

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
    _settings?.addListener(_onSettingsChanged);
    _repository?.refreshToday();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _repository?.refreshToday();
    });
    _load();
  }

  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repository?.removeListener(_onDataChanged);
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductivityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.range;
    if (next != null && next != _range) _selectRange(next);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  // Re-run on range change; summary and insights are computed off the UI path where large.
  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final summary = await repository.summaryForLastDays(_range.days, now: _now);
    final previous = await repository.summaryForLastDays(
      _range.days,
      now: _now.subtract(Duration(days: _range.days)),
    );
    final goalHours = _settings?.currentSettings.dailyWorkGoalHours;
    final insights = await repository.insights(
      now: _now,
      focusGoalSeconds: goalHours == null ? null : goalHours * 3600,
    );

    if (!mounted) return;
    setState(() {
      _rangeSummary = summary;
      _previousSummary = previous;
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

    final segments = repository.appSegments(_todayKey, app.appKey);
    final history = <String, int>{};
    final days = _rangeSummary?.days ?? const <DailyProductivitySummary>[];
    for (final day in days.length > 7 ? days.sublist(days.length - 7) : days) {
      final match = day.apps.where((a) => a.appKey == app.appKey);
      history[day.date] = match.isEmpty ? 0 : match.first.seconds;
    }

    setState(() {
      _detail = ApplicationDetailSheet(
        app: app,
        totalActiveSeconds: _range == ProductivityRange.today
            ? _today.activeSeconds
            : _rangeSummary?.activeSeconds ?? 0,
        segments: segments,
        dateLabel: _range == ProductivityRange.today
            ? 'Today'
            : 'Last ${_range.days} days',
        historyByDate: _range == ProductivityRange.today ? const {} : history,
        onClose: _closeDetail,
        colour: appColor(_rankOf(app)),
      );
    });
  }

  int _rankOf(AppTotal app) {
    final apps = _range == ProductivityRange.today
        ? _today.apps
        : _rangeSummary?.apps ?? const <AppTotal>[];
    final index = apps.indexWhere((a) => a.appKey == app.appKey);
    return index < 0 ? 0 : index;
  }

  void _closeDetail() {
    if (mounted) setState(() => _detail = null);
  }

  // Shown inside the page rather than as a root-navigator sheet, so the sidebar stays usable.
  Widget _withDetail(Widget page) {
    final detail = _detail;
    if (detail == null) return page;
    return Stack(
      children: <Widget>[
        page,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeDetail,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: detail),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _rangeSummary;
    final showingToday = _range == ProductivityRange.today;
    final hasActivity = showingToday
        ? _today.hasActivity
        : (summary?.hasActivity ?? false);

    if (widget.embedded) {
      if (_loading) {
        return const _ProductivitySkeleton();
      }
      if (!hasActivity) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: ProductivityEmptyState(
            trackingEnabled: _trackingEnabled,
            recordedSeconds: _today.trackedSeconds,
            onEnableTracking: _trackingEnabled ? null : _enableTracking,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _contentChildren(summary, showingToday),
      );
    }

    return _withDetail(
      PageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              range: _range,
              onRangeChanged: _selectRange,
              subtitle: showingToday
                  ? formatDateKey(_todayKey)
                  : 'Last ${_range.days} days',
            ),
            const SizedBox(height: AppTheme.space32),
            if (_loading)
              const _ProductivitySkeleton()
            else if (!hasActivity)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 420),
                child: ProductivityEmptyState(
                  trackingEnabled: _trackingEnabled,
                  recordedSeconds: _today.trackedSeconds,
                  onEnableTracking: _trackingEnabled ? null : _enableTracking,
                ),
              )
            else
              _content(summary, showingToday),
          ],
        ),
      ),
    );
  }

  Widget _content(RangeProductivitySummary? summary, bool showingToday) {
    final primary = _primaryChildren(summary, showingToday);
    final applications = _applications(summary, showingToday);
    final insights = _insightsSection();
    final budgets = _budgets(showingToday);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...primary,
              const SizedBox(height: 48),
              applications,
              const SizedBox(height: 48),
              insights,
              if (budgets != null) ...<Widget>[
                const SizedBox(height: 48),
                budgets,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space32),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[applications],
                  ),
                ),
              ],
            ),
            if (budgets != null) ...<Widget>[
              const SizedBox(height: 40),
              budgets,
            ],
            const SizedBox(height: 40),
            _insightsSection(columns: 2),
          ],
        );
      },
    );
  }

  List<Widget> _contentChildren(
    RangeProductivitySummary? summary,
    bool showingToday,
  ) {
    final budgets = _budgets(showingToday);
    return <Widget>[
      ..._primaryChildren(summary, showingToday),
      _applications(summary, showingToday),
      const SizedBox(height: 48),
      if (budgets != null) ...<Widget>[budgets, const SizedBox(height: 48)],
      _insightsSection(),
    ];
  }

  List<Widget> _primaryChildren(
    RangeProductivitySummary? summary,
    bool showingToday,
  ) {
    final day = _today;
    final activeSeconds = showingToday
        ? day.activeSeconds
        : (summary?.activeSeconds ?? 0);

    return <Widget>[
      if (showingToday &&
          day.trackedSeconds < kMinComparableSeconds) ...<Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: ProductivityDataProgress(recordedSeconds: day.trackedSeconds),
        ),
        const SizedBox(height: 32),
      ],
      ProductivityOverviewCard(
        activeSeconds: activeSeconds,
        idleSeconds: showingToday ? day.idleSeconds : summary?.idleSeconds ?? 0,
        breakSeconds: showingToday
            ? day.breakSeconds
            : summary?.breakSeconds ?? 0,
        contextSwitches: showingToday
            ? day.contextSwitches
            : summary?.contextSwitches ?? 0,
        switchesPerHour: showingToday ? day.switchesPerActiveHour : null,
        previousActiveSeconds: _previousSummary?.activeSeconds,
        versusLabel: showingToday
            ? 'yesterday'
            : 'previous ${_range.days} days',
        focusGoalSeconds: showingToday && _settings != null
            ? _settings!.currentSettings.dailyWorkGoalHours * 3600
            : null,
        caption: showingToday
            ? null
            : 'across ${summary?.activeDayCount ?? 0} '
                  '${(summary?.activeDayCount ?? 0) == 1 ? 'day' : 'days'} '
                  'with activity',
      ),
      const SizedBox(height: 48),

      if (showingToday) ...<Widget>[
        ProductivitySection(
          title: 'Timeline',
          subtitle: day.firstActivityAt == null
              ? null
              : '${formatClock(day.firstActivityAt!)} to '
                    '${formatClock(day.lastActivityAt!)}',
          child: ActivityTimelineView(
            entries:
                _repository?.timelineForDate(_todayKey) ??
                const <TimelineEntry>[],
          ),
        ),
      ] else if (summary != null) ...<Widget>[
        ProductivitySection(
          title: 'Daily activity',
          subtitle: 'Active time per day',
          child: DailyActivityBars(
            days: summary.days,
            goalSeconds: _settings == null
                ? null
                : _settings!.currentSettings.dailyWorkGoalHours * 3600,
          ),
        ),
      ],
    ];
  }

  Widget _applications(RangeProductivitySummary? summary, bool showingToday) {
    final day = _today;
    final apps = showingToday
        ? day.apps
        : (summary?.apps ?? const <AppTotal>[]);
    return ProductivitySection(
      title: 'Applications',
      subtitle: apps.isEmpty
          ? null
          : '${apps.length} ${apps.length == 1 ? 'application' : 'applications'}',
      child: ApplicationUsageList(
        apps: apps,
        totalActiveSeconds: showingToday
            ? day.activeSeconds
            : (summary?.activeSeconds ?? 0),
        limit: 8,
        onSelected: _openApplication,
      ),
    );
  }

  Widget? _budgets(bool showingToday) {
    if (!showingToday ||
        !sl.isRegistered<AppUsageService>() ||
        _settings == null) {
      return null;
    }
    return DailyBudgetsCard(
      usedSecondsByCategory: sl<AppUsageService>().categoryTotals(
        UsagePeriod.today,
      ),
      budgetMinutes: _settings!.currentSettings.categoryDailyBudgetMinutes,
      workDaySeconds: _settings!.currentSettings.officeHours * 3600,
      customCategories: _settings!.currentSettings.customBudgetCategories,
      customUsedSeconds: {
        for (final custom in _settings!.currentSettings.customBudgetCategories)
          custom.id: _today.apps
              .where(
                (app) => custom.appNames.any(
                  (name) => name.toLowerCase() == app.appName.toLowerCase(),
                ),
              )
              .fold<int>(0, (sum, app) => sum + app.seconds),
      },
    );
  }

  Widget _insightsSection({int columns = 1}) => ProductivitySection(
    title: 'Insights',
    subtitle: _insights.isEmpty
        ? 'Not enough data yet'
        : 'What the recorded activity shows',
    child: _insights.isEmpty
        ? _NotEnoughInsights()
        : columns == 1
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final insight in _insights) InsightCard(insight: insight),
            ],
          )
        : LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - AppTheme.space32) / 2;
              return Wrap(
                spacing: AppTheme.space32,
                children: <Widget>[
                  for (final insight in _insights)
                    SizedBox(
                      width: width,
                      child: InsightCard(insight: insight),
                    ),
                ],
              );
            },
          ),
  );
}

class _NotEnoughInsights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Patterns appear after a few days of data.',
      style: TextStyle(
        fontFeatures: AppTheme.tabular,
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.5,
        color: AppTheme.textSecondary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                'Productivity',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            for (final option in ProductivityRange.values)
              _RangeButton(
                label: option.label,
                isSelected: option == range,
                onTap: () => onRangeChanged(option),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          subtitle,
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        hoverColor: AppTheme.hoverOverlay,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductivitySkeleton extends StatefulWidget {
  const _ProductivitySkeleton();

  @override
  State<_ProductivitySkeleton> createState() => _ProductivitySkeletonState();
}

class _ProductivitySkeletonState extends State<_ProductivitySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static Widget _bar(double height, {double? width}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    ),
  );

  static Widget _block(List<double> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _bar(16, width: 96),
      const SizedBox(height: AppTheme.space16),
      for (final h in rows) ...<Widget>[
        _bar(h),
        const SizedBox(height: AppTheme.space12),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
        child: LayoutBuilder(
          builder: (context, box) {
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _block(const <double>[56, 12]),
                const SizedBox(height: 48),
                _block(const <double>[72]),
                const SizedBox(height: 48),
                _block(const <double>[48, 48, 48]),
              ],
            );
            final right = _block(const <double>[40, 40, 40, 40, 40]);
            if (box.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[left, const SizedBox(height: 48), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 3, child: left),
                const SizedBox(width: AppTheme.space32),
                Expanded(flex: 2, child: right),
              ],
            );
          },
        ),
      ),
    );
  }
}
